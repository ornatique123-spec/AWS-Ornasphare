// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
//
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:provider/provider.dart';
//
// import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Dashboard/HomeScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/ItemProvider.dart';
// import '../Extra/PremiumSearchableDropdown.dart';
// import '../Offline Data/offline_api_helper.dart';
//
// class Createapprovalreturn extends StatefulWidget {
//   const Createapprovalreturn({super.key});
//
//   @override
//   State<Createapprovalreturn> createState() => _CreateapprovalreturnState();
// }
//
// class _CreateapprovalreturnState extends State<Createapprovalreturn>
//     with RouteAware {
//   /// ============================================================
//   /// CONTROLLERS
//   /// ============================================================
//
//   final TextEditingController searchController = TextEditingController();
//
//   final TextEditingController remarksController = TextEditingController();
//
//   final FocusNode searchFocusNode = FocusNode();
//
//   final Map<String, TextEditingController> controllers = {};
//
//   /// ============================================================
//   /// TIMERS
//   /// ============================================================
//
//   Timer? _huidTimer;
//   Timer? _calculationDebounce;
//
//   /// ============================================================
//   /// DATA
//   /// ============================================================
//
//   List userlist = [];
//
//   String? selectedItem;
//
//   List<Map<String, dynamic>> tableRows = [];
//
//   int apiRowCount = 0;
//
//   List customerlist = [];
//
//   String? selectedUser;
//   String? selectedCompanyId;
//   String? selectedUserId;
//   String? selectedUserName;
//
//   DateTime? birthDate;
//   DateTime? anniversaryDate;
//
//   List cartItems = [];
//
//   bool isLoading = false;
//
//   List<Map<String, dynamic>> items = [];
//   List<Map<String, dynamic>> allItems = [];
//
//   List searchResults = [];
//   List combinedItems = [];
//
//   List<Map<String, dynamic>> finalItems = [];
//
//   Set<int> selectedItems = {};
//
//   List approvalAddedItems = [];
//
//   bool showScannerFull = false;
//
//   bool isSearchEnabled = false;
//
//   /// ============================================================
//   /// SCANNER
//   /// ============================================================
//
//   bool isProcessing = false;
//   bool isBusy = false;
//
//   String? lastCode;
//
//   /// ============================================================
//   /// CALCULATION
//   /// ============================================================
//
//   bool _isCalculating = false;
//
//   /// ============================================================
//   /// INIT
//   /// ============================================================
//   /// Device ma ek j vaar generate thay, SharedPreferences ma save rahe
//   String? deviceId;
//
//   /// Aa screen khule tyare j ek vaar generate thay (session unique)
//   String? voucherSessionId;
//   @override
//   void initState() {
//     super.initState();
//     voucherSessionId = 'APP-${DateTime.now().millisecondsSinceEpoch}';
//     Future.microtask(() {
//       if (!mounted) return;
//
//       Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
//     });
//   }
//
//   @override
//   void didPopNext() {
//     super.didPopNext();
//
//     Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
//   }
//
//   /// ============================================================
//   /// DISPOSE
//   /// ============================================================
//
//   @override
//   void dispose() {
//     _huidTimer?.cancel();
//     _calculationDebounce?.cancel();
//
//     searchController.dispose();
//     remarksController.dispose();
//     searchFocusNode.dispose();
//
//     for (final controller in controllers.values) {
//       controller.dispose();
//     }
//
//     controllers.clear();
//
//     super.dispose();
//   }
//
//   /// ============================================================
//   /// BUILD
//   /// ============================================================
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//
//     final width = size.width;
//
//     final bool isMobile = width < 600;
//
//     /// ==========================================================
//     /// DISPLAY ITEMS
//     /// ==========================================================
//
//     final List<dynamic> combinedItemsList = [
//       ...items,
//
//       ...approvalAddedItems,
//
//       ...cartItems.map(
//         (e) => {
//           ...Map<String, dynamic>.from(e),
//
//           "id": e["id"],
//
//           "name": e["item_name"] ?? e["item"]?["item_name"] ?? e["name"] ?? "",
//
//           "code": e["qr_code"] ?? e["huid"] ?? e["code"] ?? "",
//
//           "gross_weight": e["gross_weight"] ?? "0",
//
//           "other_weight": e["other_weight"] ?? "0",
//
//           "net_weight": e["net_weight"] ?? "0",
//
//           "purity": e["purity"] ?? "0",
//
//           "waste": e["waste"] ?? "0",
//
//           "net_purity": e["net_purity"] ?? "0",
//
//           "fine_weight": e["fine_weight"] ?? "0",
//
//           "metal_rate": e["metal_rate"] ?? "0",
//
//           "metal_amount": e["metal_amount"] ?? "0",
//
//           "labour_rate": e["labour_rate"] ?? "0",
//
//           "labour_amount": e["labour_amount"] ?? "0",
//
//           "other_amount": e["other_amount"] ?? "0",
//
//           "total_amount": e["total_amount"] ?? e["amount"] ?? "0",
//
//           "source": "sale",
//
//           "itemset_id": e["itemset_id"],
//         },
//       ),
//     ];
//
//     /// ==========================================================
//     /// REMOVE DUPLICATE
//     /// ==========================================================
//
//     final displayMap = <String, dynamic>{};
//
//     for (final rawItem in combinedItemsList) {
//       final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
//
//       final key =
//           item["approval_item_id"] ??
//           item["itemset_id"] ??
//           item["id"] ??
//           item["code"] ??
//           identityHashCode(item);
//
//       displayMap[key.toString()] = item;
//     }
//
//     final List<Map<String, dynamic>> displayItems = displayMap.values
//         .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
//         .toList()
//         .reversed
//         .toList();
//
//     return PopScope(
//       canPop: false,
//
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//
//         Navigator.pop(context, true);
//       },
//
//       child: Scaffold(
//         backgroundColor: AppColors.white,
//
//         body: Stack(
//           children: [
//             /// ===================================================
//             /// MAIN CONTENT
//             /// ===================================================
//             Column(
//               children: [
//                 SizedBox(height: MediaQuery.of(context).padding.top + 30),
//
//                 Expanded(
//                   child: showScannerFull
//                       ? _buildScannerMode(displayItems)
//                       : _buildNormalMode(displayItems),
//                 ),
//
//                 /// =================================================
//                 /// SUMMARY
//                 /// =================================================
//                 buildSummaryRow(),
//
//                 /// =================================================
//                 /// SAVE BUTTON
//                 /// =================================================
//                 InkWell(
//                   onTap: () {
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     savefinalizeBulkItems();
//                   },
//
//                   borderRadius: BorderRadius.circular(10),
//
//                   child: Padding(
//                     padding: const EdgeInsets.only(bottom: 8),
//
//                     child: Container(
//                       margin: const EdgeInsets.all(16),
//
//                       padding: const EdgeInsets.symmetric(vertical: 14),
//
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             AppColors.primaryDark.withOpacity(0.7),
//
//                             AppColors.secondaryDark.withOpacity(0.7),
//                           ],
//                         ),
//
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//
//                       child: const Center(
//                         child: Text(
//                           "Save Approval Return",
//
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//
//                             color: Colors.white,
//
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
//             /// ===================================================
//             /// APPBAR
//             /// ===================================================
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//
//               child: Container(
//                 padding: const EdgeInsets.only(
//                   top: 30,
//                   left: 16,
//                   right: 16,
//                   bottom: 16,
//                 ),
//
//                 child: Stack(
//                   alignment: Alignment.center,
//
//                   children: [
//                     const Text(
//                       "Create Approval Return",
//
//                       style: TextStyle(
//                         color: Colors.black,
//
//                         fontSize: 16,
//
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     Align(
//                       alignment: Alignment.centerLeft,
//
//                       child: InkWell(
//                         onTap: () {
//                           FocusManager.instance.primaryFocus?.unfocus();
//
//                           Navigator.pop(context,true);
//                         },
//
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//
//                           decoration: BoxDecoration(
//                             color: AppColors.primaryDark,
//
//                             borderRadius: BorderRadius.circular(8),
//
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//
//                           child: Icon(
//                             Icons.arrow_back,
//
//                             color: Colors.white,
//
//                             size: isMobile ? 20 : 24,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// NORMAL MODE
//   /// ============================================================
//
//   Widget _buildNormalMode(List<Map<String, dynamic>> displayItems) {
//     return Column(
//       children: [
//         const SizedBox(height: 10),
//
//         Expanded(
//           child: SingleChildScrollView(
//             physics: const BouncingScrollPhysics(),
//
//             keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
//
//             child: Column(
//               children: [
//                 filterWidget(),
//
//                 Container(
//                   margin: const EdgeInsets.only(top: 10),
//
//                   width: double.infinity,
//
//                   height: 2,
//
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         AppColors.primaryDark.withOpacity(0.1),
//
//                         AppColors.primaryDark,
//
//                         AppColors.secondaryDark.withOpacity(0.4),
//
//                         AppColors.primaryDark.withOpacity(0.1),
//                       ],
//                     ),
//
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//
//                 displayItems.isEmpty
//                     ? const Padding(
//                         padding: EdgeInsets.only(top: 50),
//
//                         child: Center(
//                           child: Text(
//                             "No Data Found",
//
//                             style: TextStyle(
//                               fontSize: 16,
//
//                               fontWeight: FontWeight.w500,
//
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
//
//                         shrinkWrap: true,
//
//                         physics: const NeverScrollableScrollPhysics(),
//
//                         itemCount: displayItems.length,
//
//                         itemBuilder: (context, index) {
//                           return approvalItemCard(
//                             displayItems[index],
//                             index,
//                             displayItems.length,
//                           );
//                         },
//                       ),
//
//                 const SizedBox(height: 80),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   /// ============================================================
//   /// SCANNER MODE
//   /// ============================================================
//
//   Widget _buildScannerMode(List<Map<String, dynamic>> displayItems) {
//     return Column(
//       children: [
//         const SizedBox(height: 10),
//
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(10),
//
//             border: Border.all(color: Colors.grey.shade300),
//           ),
//
//           child: Consumer<ItemProvider>(
//             builder: (context, provider, child) {
//               final customers = provider.customers;
//
//               return DropdownButtonFormField<String>(
//                 value:
//                     selectedItem != null &&
//                         customers.any((e) => e["id"].toString() == selectedItem)
//                     ? selectedItem
//                     : null,
//
//                 icon: const Icon(
//                   Icons.keyboard_arrow_down,
//                   color: Colors.black,
//                 ),
//
//                 dropdownColor: Colors.white,
//
//                 hint: Text(
//                   "Select Customer",
//
//                   style: TextStyle(color: Colors.grey.shade600),
//                 ),
//
//                 style: const TextStyle(color: Colors.black, fontSize: 14),
//
//                 decoration: InputDecoration(
//                   filled: true,
//
//                   fillColor: Colors.white,
//
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 0,
//                   ),
//
//                   border: OutlineInputBorder(
//                     borderSide: BorderSide(color: AppColors.border),
//
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: AppColors.border),
//
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: AppColors.border),
//
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                 ),
//
//                 items: customers.map<DropdownMenuItem<String>>((item) {
//                   return DropdownMenuItem<String>(
//                     value: item["id"].toString(),
//
//                     child: Text(
//                       item["name"] ?? "",
//
//                       style: const TextStyle(color: Colors.black),
//                     ),
//                   );
//                 }).toList(),
//
//                 onChanged: (value) {
//                   setState(() {
//                     selectedItem = value;
//
//                     final selectedData = customers.firstWhere(
//                       (user) => user["id"].toString() == value,
//
//                       orElse: () => {},
//                     );
//
//                     if (selectedData.isNotEmpty) {
//                       selectedCompanyId = selectedData["company_id"]
//                           ?.toString();
//
//                       selectedUserId = selectedData["id"]?.toString();
//                     }
//                   });
//                 },
//               );
//             },
//           ),
//         ),
//
//         const SizedBox(height: 10),
//
//         Center(
//           child: Stack(
//             children: [
//               Container(
//                 height: 150,
//                 width: 150,
//
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//
//                   color: Colors.black,
//
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.greenAccent.withOpacity(0.4),
//
//                       blurRadius: 20,
//                     ),
//                   ],
//                 ),
//
//                 child: Stack(
//                   children: [
//                     _buildScannerSection(),
//
//                     const _ScannerLineAnimation(),
//                   ],
//                 ),
//               ),
//
//               Positioned(
//                 top: 6,
//                 right: 6,
//
//                 child: GestureDetector(
//                   onTap: () {
//                     setState(() {
//                       showScannerFull = false;
//                     });
//                   },
//
//                   child: Container(
//                     padding: const EdgeInsets.all(4),
//
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.5),
//
//                       shape: BoxShape.circle,
//
//                       border: Border.all(color: Colors.white, width: 1.5),
//                     ),
//
//                     child: const Icon(
//                       Icons.close,
//
//                       size: 10,
//
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         const SizedBox(height: 5),
//
//         Container(
//           margin: const EdgeInsets.only(top: 10),
//
//           width: double.infinity,
//
//           height: 2,
//
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 AppColors.primaryDark.withOpacity(0.1),
//
//                 AppColors.primaryDark,
//
//                 AppColors.secondaryDark.withOpacity(0.4),
//
//                 AppColors.primaryDark.withOpacity(0.1),
//               ],
//             ),
//
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//
//         Expanded(
//           child: displayItems.isEmpty
//               ? const Center(child: Text("No Data Added"))
//               : ListView.builder(
//                   keyboardDismissBehavior:
//                       ScrollViewKeyboardDismissBehavior.onDrag,
//
//                   padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
//
//                   itemCount: displayItems.length,
//
//                   itemBuilder: (context, index) {
//                     return approvalItemCard(
//                       displayItems[index],
//                       index,
//                       displayItems.length,
//                     );
//                   },
//                 ),
//         ),
//       ],
//     );
//   }
//
//   /// ============================================================
//   /// FILTER WIDGET
//   /// ============================================================
//
//   Widget filterWidget() {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
//
//       padding: const EdgeInsets.all(12),
//
//       decoration: BoxDecoration(
//         color: AppColors.cardBackground,
//
//         borderRadius: BorderRadius.circular(5),
//
//         border: Border.all(color: AppColors.border),
//
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//
//             blurRadius: 8,
//
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//
//       child: Column(
//         children: [
//           /// =====================================================
//           /// CUSTOMER
//           /// =====================================================
//           Container(
//             padding: EdgeInsets.zero,
//
//             decoration: BoxDecoration(
//               color: AppColors.background,
//
//               border: Border.all(color: AppColors.border),
//
//               borderRadius: BorderRadius.circular(5),
//             ),
//
//             child: Consumer<ItemProvider>(
//               builder: (context, provider, child) {
//                 final List<Map<String, dynamic>> customers = provider.customers
//                     .map<Map<String, dynamic>>(
//                       (e) => Map<String, dynamic>.from(e),
//                     )
//                     .toList();
//
//                 Map<String, dynamic>? selectedCustomer;
//
//                 if (selectedItem != null) {
//                   try {
//                     selectedCustomer = customers.firstWhere(
//                       (e) => e["id"]?.toString() == selectedItem.toString(),
//                     );
//                   } catch (_) {
//                     selectedCustomer = null;
//                   }
//                 }
//
//                 return PremiumSearchableDropdown<Map<String, dynamic>>(
//                   label: "",
//
//                   hint: "Select Customer",
//
//                   items: customers,
//
//                   value: selectedCustomer,
//
//                   prefixIcon: Icons.person_outline_rounded,
//
//                   dropdownMaxHeight: 350,
//
//                   itemLabel: (customer) {
//                     return customer["name"]?.toString() ?? "";
//                   },
//
//                   searchText: (customer) {
//                     final name = customer["name"]?.toString() ?? "";
//
//                     final mobile =
//                         customer["mobile"]?.toString() ??
//                         customer["mobile_no"]?.toString() ??
//                         customer["phone"]?.toString() ??
//                         "";
//
//                     final code =
//                         customer["code"]?.toString() ??
//                         customer["customer_code"]?.toString() ??
//                         "";
//
//                     return "$name $mobile $code";
//                   },
//
//                   onChanged: (customer) {
//                     if (customer == null) {
//                       setState(() {
//                         selectedItem = null;
//
//                         selectedCompanyId = null;
//
//                         selectedUserId = null;
//                       });
//
//                       return;
//                     }
//
//                     setState(() {
//                       selectedItem = customer["id"]?.toString();
//
//                       selectedCompanyId = customer["company_id"]?.toString();
//
//                       selectedUserId = customer["id"]?.toString();
//                     });
//
//                     debugPrint("Selected Customer: ${customer["name"]}");
//
//                     debugPrint("Selected Company ID: $selectedCompanyId");
//
//                     debugPrint("Selected User ID: $selectedUserId");
//                   },
//                 );
//               },
//             ),
//           ),
//
//           const SizedBox(height: 10),
//
//           /// =====================================================
//           /// REMARKS
//           /// =====================================================
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: remarksController,
//
//                   style: const TextStyle(
//                     color: Colors.black,
//
//                     fontSize: 14,
//
//                     fontWeight: FontWeight.w500,
//                   ),
//
//                   decoration: InputDecoration(
//                     hintText: "Enter Remarks",
//
//                     hintStyle: TextStyle(color: Colors.grey.shade600),
//
//                     filled: true,
//
//                     fillColor: Colors.white,
//
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 14,
//                     ),
//
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           /// =====================================================
//           /// BUTTONS
//           /// =====================================================
//           Row(
//             children: [
//               Expanded(
//                 flex: 1,
//
//                 child: InkWell(
//                   onTap: () {
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     setState(() {
//                       showScannerFull = true;
//                     });
//                   },
//
//                   borderRadius: BorderRadius.circular(8),
//
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//
//                           AppColors.border.withOpacity(0.7),
//
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//
//                     child: const Center(
//                       child: Icon(
//                         Icons.qr_code_scanner,
//
//                         color: Colors.white,
//
//                         size: 22,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(width: 10),
//
//               Expanded(
//                 flex: 3,
//
//                 child: InkWell(
//                   onTap: () {
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     if (selectedItem == null) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text("Please select customer first"),
//
//                           backgroundColor: Colors.red,
//                         ),
//                       );
//
//                       return;
//                     }
//
//                     getApprovalDetails(int.parse(selectedItem.toString()));
//                   },
//
//                   borderRadius: BorderRadius.circular(8),
//
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//
//                       borderRadius: BorderRadius.circular(8),
//
//                       border: Border.all(color: Colors.grey.shade300),
//
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.05),
//
//                           blurRadius: 6,
//
//                           offset: const Offset(0, 3),
//                         ),
//                       ],
//                     ),
//
//                     child: const Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//
//                       children: [
//                         Icon(Icons.add, size: 18, color: Colors.black),
//
//                         SizedBox(width: 6),
//
//                         Text(
//                           "Add Label Return Approval",
//
//                           style: TextStyle(
//                             fontWeight: FontWeight.w600,
//
//                             color: Colors.black,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// SEARCH ITEMS
//   /// ============================================================
//
//   Future<void> searchItemsApi(String keyword) async {
//     if (keyword.isEmpty) {
//       if (!mounted) return;
//
//       setState(() {
//         searchResults = [];
//       });
//
//       return;
//     }
//
//     if (selectedItem == null) {
//       return;
//     }
//
//     final body = {"customer_id": int.parse(selectedItem!), "keyword": keyword};
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.returns_search,
//       body,
//     );
//
//     if (!mounted) return;
//
//     if (response != null && response.statusCode == 200) {
//       final List allResults = response.data["data"] ?? [];
//
//       final filtered = allResults.where((item) {
//         final itemsetId = item["itemset_id"];
//
//         final saleItemId = item["sale_item_id"];
//
//         final approvalItemId = item["approval_item_id"];
//
//         final bool alreadyAdded =
//             items.any((e) => e["itemset_id"] == itemsetId) ||
//             approvalAddedItems.any(
//               (e) =>
//                   e["itemset_id"] == itemsetId ||
//                   e["approval_item_id"] == approvalItemId,
//             ) ||
//             cartItems.any(
//               (e) =>
//                   e["itemset_id"] == itemsetId ||
//                   e["sale_item_id"] == saleItemId,
//             );
//
//         return !alreadyAdded;
//       }).toList();
//
//       setState(() {
//         searchResults = filtered;
//       });
//     }
//   }
//
//   /// ============================================================
//   /// ADD MANUAL ITEM
//   /// ============================================================
//
//   void addItemToCard(dynamic e) {
//     final itemsetId = e["itemset_id"] ?? e["id"];
//
//     final bool isDuplicate =
//         items.any((item) => (item["itemset_id"] ?? item["id"]) == itemsetId) ||
//         approvalAddedItems.any((item) => item["itemset_id"] == itemsetId) ||
//         cartItems.any(
//           (item) => item["itemset_id"] == itemsetId || item["id"] == itemsetId,
//         );
//
//     if (isDuplicate) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Item already added to the list"),
//
//           backgroundColor: Colors.orange,
//         ),
//       );
//
//       searchController.clear();
//
//       setState(() {
//         searchResults.clear();
//       });
//
//       return;
//     }
//
//     final Map<String, dynamic> newItem = {
//       "id": e["itemset_id"] ?? e["id"],
//
//       "itemset_id": e["itemset_id"] ?? e["id"],
//
//       "item_name": e["item"]?["item_name"] ?? e["item_name"] ?? e["name"] ?? "",
//
//       "name": e["item"]?["item_name"] ?? e["item_name"] ?? e["name"] ?? "",
//
//       "huid": e["HUID"] ?? e["huid"] ?? "",
//
//       "qr_code": e["qr_code"] ?? "",
//
//       "code": e["qr_code"] ?? e["code"] ?? "",
//
//       "gross_weight": e["gross_weight"]?.toString() ?? "0",
//
//       "other_weight": e["other_weight"]?.toString() ?? "0",
//
//       "net_weight": e["net_weight"]?.toString() ?? "0",
//
//       "purity": e["purity"]?.toString() ?? "0",
//
//       "waste": e["waste_percent"]?.toString() ?? e["waste"]?.toString() ?? "0",
//
//       "net_purity": e["net_purity"]?.toString() ?? "0",
//
//       "fine_weight": e["fine_weight"]?.toString() ?? "0",
//
//       "metal_rate": e["metal_rate"]?.toString() ?? "0",
//
//       "metal_amount": e["metal_amount"]?.toString() ?? "0",
//
//       "labour_rate": e["labour_rate"]?.toString() ?? "0",
//
//       "labour_amount": e["labour_amount"]?.toString() ?? "0",
//
//       "other_amount": e["other_amount"]?.toString() ?? "0",
//
//       "total_amount": e["total_amount"]?.toString() ?? "0",
//
//       "source": e["source"] ?? "manual",
//
//       "expanded": false,
//
//       "manual_metal": true,
//       "manual_labour": true,
//     };
//
//     /// Controller create before UI
//     _initializeItemControllers(newItem);
//
//     calculateItem(newItem);
//
//     items.add(newItem);
//
//     searchController.clear();
//     searchResults.clear();
//
//     updateFinalItems();
//   }
//
//   /// ============================================================
//   /// APPROVAL DETAILS
//   /// ============================================================
//
//   Future<void> getApprovalDetails(int? customerId) async {
//     if (customerId == null) {
//       return;
//     }
//
//     FocusManager.instance.primaryFocus?.unfocus();
//
//     showDialog(
//       context: context,
//
//       barrierDismissible: false,
//
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(
//       "${ApiConstants.returns_approval_items}?customer_id=$customerId",
//     );
//
//     if (!mounted) return;
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//
//       final List approvalItems = data["data"] ?? [];
//
//       if (approvalItems.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Data Not Found"),
//
//             backgroundColor: Colors.red,
//           ),
//         );
//
//         return;
//       }
//
//       final Set<int> addedIds = approvalAddedItems
//           .map<int>((e) => int.tryParse(e["approval_item_id"].toString()) ?? 0)
//           .toSet();
//
//       final List filteredItems = approvalItems.where((item) {
//         final int id = int.tryParse(item["approval_item_id"].toString()) ?? 0;
//
//         return !addedIds.contains(id);
//       }).toList();
//
//       if (filteredItems.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("All approval items already added")),
//         );
//
//         return;
//       }
//
//       final addedCartData = await showApprovalDialog(filteredItems);
//
//       if (addedCartData != null && addedCartData.isNotEmpty) {
//         addSelectedItems(addedCartData, approvalItems);
//       }
//     }
//   }
//
//   /// ============================================================
//   /// ADD APPROVAL ITEMS
//   /// ============================================================
//
//   void addSelectedItems(Set<int> selectedIds, List allItems) {
//     final List selectedData = allItems.where((item) {
//       final int id = int.tryParse(item["approval_item_id"].toString()) ?? 0;
//
//       return selectedIds.contains(id);
//     }).toList();
//
//     for (final rawItem in selectedData) {
//       final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
//
//       final approvalId = item["approval_item_id"];
//
//       final bool exists = approvalAddedItems.any(
//         (e) => e["approval_item_id"] == approvalId,
//       );
//
//       if (exists) continue;
//
//       item["source"] = item["source"] ?? "approval";
//
//       item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
//
//       item["other_weight"] = item["other_weight"]?.toString() ?? "0";
//
//       item["purity"] = item["purity"]?.toString() ?? "0";
//
//       item["waste"] =
//           item["waste"]?.toString() ?? item["waste_percent"]?.toString() ?? "0";
//
//       item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
//
//       item["labour_rate"] = item["labour_rate"]?.toString() ?? "0";
//
//       item["other_amount"] = item["other_amount"]?.toString() ?? "0";
//
//       item["manual_metal"] = item["manual_metal"] ?? true;
//
//       item["manual_labour"] = item["manual_labour"] ?? true;
//
//       _initializeItemControllers(item);
//
//       calculateItem(item);
//
//       approvalAddedItems.add(item);
//     }
//
//     updateFinalItems();
//   }
//
//   /// ============================================================
//   /// APPROVAL DIALOG
//   /// ============================================================
//
//   Future<Set<int>?> showApprovalDialog(List approvalItems) async {
//     selectedItems.clear();
//
//     List filteredItems = List.from(approvalItems);
//
//     bool showScanner = false;
//
//     /// 🔥 Jena API e "already locked by another user" kahyu hoy
//     /// evi item ids — list ma alag background thi highlight thashe
//     final Set<int> lockedItemIds = {};
//
//     final TextEditingController approveSearchController =
//     TextEditingController();
//
//     final result = await showDialog<Set<int>>(
//       context: context,
//
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return Dialog(
//               backgroundColor: AppColors.background,
//
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//
//               insetPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 24,
//               ),
//
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.92,
//
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 14,
//                 ),
//
//                 child: SingleChildScrollView(
//                   keyboardDismissBehavior:
//                   ScrollViewKeyboardDismissBehavior.onDrag,
//
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//
//                     children: [
//                       /// HEADER
//                       Row(
//                         children: [
//                           const Text(
//                             "Approval Items Return",
//
//                             style: TextStyle(
//                               fontSize: 18,
//
//                               color: Colors.black,
//
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//
//                           const Spacer(),
//
//                           InkWell(
//                             onTap: () {
//                               FocusManager.instance.primaryFocus?.unfocus();
//
//                               setDialogState(() {
//                                 showScanner = !showScanner;
//                               });
//                             },
//
//                             borderRadius: BorderRadius.circular(5),
//
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 5,
//                                 horizontal: 5,
//                               ),
//
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark.withOpacity(0.7),
//
//                                     AppColors.border.withOpacity(0.7),
//
//                                     AppColors.secondaryDark.withOpacity(0.7),
//                                   ],
//                                 ),
//
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//
//                               child: const Icon(
//                                 Icons.qr_code_scanner,
//
//                                 color: Colors.black,
//
//                                 size: 20,
//                               ),
//                             ),
//                           ),
//
//                           const SizedBox(width: 8),
//
//                           InkWell(
//                             onTap: () {
//                               FocusManager.instance.primaryFocus?.unfocus();
//
//                               Navigator.pop(context);
//                             },
//
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 6,
//                               ),
//
//                               decoration: BoxDecoration(
//                                 color: Colors.black,
//
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//
//                               child: const Text(
//                                 "Back",
//
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       /// SEARCH
//                       TextField(
//                         controller: approveSearchController,
//
//                         style: const TextStyle(color: Colors.black),
//
//                         onChanged: (value) {
//                           final search = value.trim().toLowerCase();
//
//                           setDialogState(() {
//                             if (search.isEmpty) {
//                               filteredItems = List.from(approvalItems);
//                             } else {
//                               filteredItems = approvalItems.where((item) {
//                                 final name =
//                                     item["name"]?.toString().toLowerCase() ??
//                                         "";
//
//                                 final code =
//                                     item["qr_code"]?.toString().toLowerCase() ??
//                                         "";
//
//                                 final huid =
//                                     item["HUID"]?.toString().toLowerCase() ??
//                                         item["huid"]?.toString().toLowerCase() ??
//                                         "";
//
//                                 return name.contains(search) ||
//                                     code.contains(search) ||
//                                     huid.contains(search);
//                               }).toList();
//                             }
//                           });
//                         },
//
//                         decoration: InputDecoration(
//                           hintText: "Search Item",
//
//                           hintStyle: const TextStyle(color: Colors.black),
//
//                           prefixIcon: const Icon(
//                             Icons.search,
//
//                             color: Colors.black54,
//                           ),
//
//                           filled: true,
//
//                           fillColor: Colors.white,
//
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 0,
//                           ),
//
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//
//                             borderSide: BorderSide(color: Colors.grey.shade300),
//                           ),
//
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//
//                             borderSide: BorderSide(color: Colors.grey.shade300),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       /// SCANNER
//                       AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 300),
//
//                         transitionBuilder: (child, animation) {
//                           final offsetAnimation = Tween<Offset>(
//                             begin: const Offset(0, -1),
//
//                             end: Offset.zero,
//                           ).animate(animation);
//
//                           return ClipRRect(
//                             borderRadius: BorderRadius.circular(12),
//
//                             child: SlideTransition(
//                               position: offsetAnimation,
//
//                               child: child,
//                             ),
//                           );
//                         },
//
//                         child: showScanner
//                             ? Center(
//                           child: Container(
//                             key: const ValueKey("scanner"),
//
//                             height: 150,
//
//                             width: 150,
//
//                             margin: const EdgeInsets.only(bottom: 12),
//
//                             decoration: BoxDecoration(
//                               color: Colors.black,
//
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//
//                             child: Stack(
//                               children: [
//                                 _buildScannerSection(),
//
//                                 const _ScannerLineAnimation(),
//                               ],
//                             ),
//                           ),
//                         )
//                             : const SizedBox(key: ValueKey("empty")),
//                       ),
//
//                       /// LIST
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.30,
//
//                         child: ListView.builder(
//                           keyboardDismissBehavior:
//                           ScrollViewKeyboardDismissBehavior.onDrag,
//
//                           itemCount: filteredItems.length,
//
//                           itemBuilder: (context, index) {
//                             final item = filteredItems[index];
//
//                             final int id =
//                                 int.tryParse(
//                                   item["approval_item_id"].toString(),
//                                 ) ??
//                                     0;
//
//                             final code = item["qr_code"] ?? "-";
//
//                             final name = item["name"] ?? "-";
//
//                             final gross =
//                                 item["gross_weight"]?.toString() ?? "-";
//
//                             final bool isSelected = selectedItems.contains(id);
//
//                             final bool isLocked = lockedItemIds.contains(id);
//
//                             return Container(
//                               margin: const EdgeInsets.symmetric(vertical: 4),
//
//                               padding: const EdgeInsets.all(10),
//
//                               decoration: BoxDecoration(
//                                 /// 🔥 Locked item — alag background jethi user
//                                 /// samje ke aa item unselect karvanu che
//                                 color: isLocked
//                                     ? Colors.red.shade50
//                                     : Colors.white,
//
//                                 borderRadius: BorderRadius.circular(8),
//
//                                 border: Border.all(
//                                   color: isLocked
//                                       ? Colors.red.shade300
//                                       : Colors.grey.shade300,
//                                   width: isLocked ? 1.4 : 1,
//                                 ),
//                               ),
//
//                               child: Row(
//                                 children: [
//                                   Checkbox(
//                                     value: isSelected,
//
//                                     activeColor: AppColors.border,
//
//                                     onChanged: (value) {
//                                       setDialogState(() {
//                                         if (value == true) {
//                                           selectedItems.add(id);
//                                         } else {
//                                           selectedItems.remove(id);
//
//                                           /// User pote unselect karyu,
//                                           /// etle locked flag hatavi do
//                                           lockedItemIds.remove(id);
//                                         }
//                                       });
//                                     },
//                                   ),
//
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                       CrossAxisAlignment.start,
//
//                                       children: [
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: Text(
//                                                 "Name: $name",
//
//                                                 style: const TextStyle(
//                                                   fontSize: 12,
//
//                                                   color: Colors.black,
//                                                 ),
//
//                                                 overflow: TextOverflow.ellipsis,
//                                               ),
//                                             ),
//
//                                             const SizedBox(width: 4),
//
//                                             Expanded(
//                                               child: Text(
//                                                 "Code: $code",
//
//                                                 style: const TextStyle(
//                                                   fontSize: 12,
//
//                                                   color: Colors.black,
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//
//                                         const SizedBox(height: 4),
//
//                                         Text(
//                                           "Gross: $gross",
//
//                                           style: const TextStyle(
//                                             fontSize: 12,
//
//                                             color: Colors.black,
//                                           ),
//                                         ),
//
//                                         if (isLocked) ...[
//                                           const SizedBox(height: 4),
//                                           Row(
//                                             children: [
//                                               Icon(
//                                                 Icons.lock_outline,
//                                                 size: 13,
//                                                 color: Colors.red.shade700,
//                                               ),
//                                               const SizedBox(width: 4),
//                                               Expanded(
//                                                 child: Text(
//                                                   "Already selected by another user. Please unselect.",
//                                                   style: TextStyle(
//                                                     fontSize: 11,
//                                                     fontWeight: FontWeight.w600,
//                                                     color: Colors.red.shade700,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ],
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       InkWell(
//                         onTap: () async {
//                           FocusManager.instance.primaryFocus?.unfocus();
//
//                           if (selectedItems.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text("Please select at least one item"),
//                                 backgroundColor: Colors.red,
//                               ),
//                             );
//                             return;
//                           }
//
//                           /// 🔥 device_id fetch/cache
//                           if (deviceId == null || deviceId!.trim().isEmpty) {
//                             try {
//                               final DeviceInfoPlugin deviceInfo =
//                               DeviceInfoPlugin();
//
//                               if (Platform.isAndroid) {
//                                 final AndroidDeviceInfo androidInfo =
//                                 await deviceInfo.androidInfo;
//                                 deviceId = androidInfo.id;
//                               } else if (Platform.isIOS) {
//                                 final IosDeviceInfo iosInfo =
//                                 await deviceInfo.iosInfo;
//                                 deviceId = iosInfo.identifierForVendor ?? "";
//                               }
//                             } catch (e) {
//                               debugPrint("DeviceInfo Error: $e");
//                             }
//                           }
//
//                           /// 🔥 voucher_session_id — ek j session mate same rahe
//                           voucherSessionId ??=
//                           'RET-${DateTime.now().millisecondsSinceEpoch}';
//
//                           /// 🔥 SELECTED ITEMS ARRAY BANAO
//                           final List<Map<String, dynamic>> itemsArray =
//                           selectedItems.map((id) {
//                             return {
//                               "approval_item_id": id,
//                               "device_entry_id":
//                               "${deviceId ?? 'unknown-device'}-${voucherSessionId}-${id}-${DateTime.now().microsecondsSinceEpoch}",
//                             };
//                           }).toList();
//
//                           final Map<String, dynamic> body = {
//                             "customer_id": selectedUserId != null
//                                 ? int.tryParse(selectedUserId!)
//                                 : null,
//                             "device_id": deviceId,
//                             "voucher_session_id": voucherSessionId,
//                             "items": itemsArray,
//                           };
//
//                           debugPrint("📤 APPROVAL CART ADD BODY => $body");
//
//                           final response = await ApiHelper().postRequest(
//                             ApiConstants.approval_cart_add,
//                             body,
//                           );
//
//                           if (!context.mounted) return;
//
//                           if (response != null &&
//                               response.statusCode == 200 &&
//                               response.data["success"] == true) {
//                             Navigator.pop(
//                               context,
//                               Set<int>.from(selectedItems),
//                             );
//                           } else {
//                             final dynamic responseData = response?.data;
//
//                             final String code = responseData is Map
//                                 ? responseData["code"]?.toString() ?? ""
//                                 : "";
//
//                             final String message = responseData is Map
//                                 ? responseData["message"]?.toString() ??
//                                 "Failed to add items"
//                                 : "Failed to add items";
//
//                             /// 🔥 RETURN_CART_ITEM_LOCKED — specific item ne
//                             /// locked mark karo, jethi list ma highlight thay
//                             if (code == "RETURN_CART_ITEM_LOCKED") {
//                               final dynamic lockedApprovalItemId =
//                               responseData is Map
//                                   ? responseData["approval_item_id"]
//                                   : null;
//
//                               final int? lockedId = int.tryParse(
//                                 lockedApprovalItemId?.toString() ?? "",
//                               );
//
//                               if (lockedId != null) {
//                                 setDialogState(() {
//                                   lockedItemIds.add(lockedId);
//
//                                   /// User ne clear samjay etle aa item
//                                   /// automatically unselect kari do
//                                   selectedItems.remove(lockedId);
//                                 });
//                               }
//                             }
//
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text(message),
//                                 backgroundColor: Colors.red,
//                                 duration: const Duration(seconds: 3),
//                               ),
//                             );
//                           }
//                         },
//
//                         child: Center(
//                           child: Container(
//                             width: 100,
//
//                             height: 40,
//
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 6,
//                             ),
//
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   AppColors.primaryDark.withOpacity(0.7),
//
//                                   AppColors.border.withOpacity(0.7),
//
//                                   AppColors.secondaryDark.withOpacity(0.7),
//                                 ],
//                               ),
//
//                               borderRadius: BorderRadius.circular(5),
//                             ),
//
//                             child: const Center(
//                               child: Text(
//                                 "Add",
//
//                                 style: TextStyle(
//                                   color: Colors.black,
//
//                                   fontSize: 16,
//
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//
//     approveSearchController.dispose();
//
//     return result;
//   }
//
//   /// ============================================================
//   /// APPROVAL ITEM CARD
//   /// ============================================================
//
//   Widget approvalItemCard(
//     Map<String, dynamic> item,
//     int index,
//     int totalCount,
//   ) {
//     final bool isExpanded = item["expanded"] ?? false;
//
//     final String itemName =
//         item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";
//
//     final String qrCode =
//         item["qr_code"]?.toString() ??
//         item["itemset"]?["qr_code"]?.toString() ??
//         item["code"]?.toString() ??
//         item["itemset"]?["barcode"]?.toString() ??
//         "-";
//
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//
//       decoration: BoxDecoration(
//         color: Colors.white,
//
//         borderRadius: BorderRadius.circular(5),
//
//         border: Border.all(color: AppColors.border),
//
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//
//             blurRadius: 8,
//
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//
//         children: [
//           /// =====================================================
//           /// HEADER
//           /// =====================================================
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//
//             decoration: BoxDecoration(
//               color: AppColors.primaryDark.withOpacity(0.10),
//
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(5),
//
//                 topRight: Radius.circular(5),
//               ),
//             ),
//
//             child: Row(
//               children: [
//                 Container(
//                   width: 26,
//                   height: 26,
//
//                   alignment: Alignment.center,
//
//                   decoration: BoxDecoration(
//                     color: AppColors.gradientBlue,
//
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//
//                   child: Text(
//                     "${totalCount - index}",
//
//                     style: const TextStyle(
//                       color: Colors.white,
//
//                       fontSize: 11,
//
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//
//                     children: [
//                       const Text(
//                         "ITEM",
//
//                         style: TextStyle(
//                           color: Colors.black45,
//
//                           fontSize: 9,
//
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//
//                       const SizedBox(height: 1),
//
//                       Text(
//                         itemName,
//
//                         maxLines: 1,
//
//                         overflow: TextOverflow.ellipsis,
//
//                         style: const TextStyle(
//                           color: Colors.black,
//
//                           fontSize: 13,
//
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 Container(
//                   constraints: const BoxConstraints(maxWidth: 125),
//
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 7,
//                     vertical: 5,
//                   ),
//
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//
//                     borderRadius: BorderRadius.circular(5),
//
//                     border: Border.all(color: AppColors.border),
//                   ),
//
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//
//                     children: [
//                       const Icon(
//                         Icons.qr_code_2,
//
//                         size: 14,
//
//                         color: AppColors.primaryDark,
//                       ),
//
//                       const SizedBox(width: 4),
//
//                       Flexible(
//                         child: Text(
//                           qrCode,
//
//                           maxLines: 1,
//
//                           overflow: TextOverflow.ellipsis,
//
//                           style: const TextStyle(
//                             color: Colors.black87,
//
//                             fontSize: 11,
//
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
//                 InkWell(
//                   onTap: () {
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     _removeItem(item);
//                   },
//
//                   borderRadius: BorderRadius.circular(5),
//
//                   child: Container(
//                     width: 27,
//                     height: 27,
//
//                     alignment: Alignment.center,
//
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xffFF8A80), Color(0xffD32F2F)],
//                       ),
//
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//
//                     child: const Icon(
//                       Icons.delete_outline,
//
//                       color: Colors.white,
//
//                       size: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           /// =====================================================
//           /// FIELDS
//           /// =====================================================
//           if (!isExpanded)
//             Container(
//               padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
//
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//
//                 physics: const BouncingScrollPhysics(),
//
//                 keyboardDismissBehavior:
//                     ScrollViewKeyboardDismissBehavior.onDrag,
//
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//
//                   children: [
//                     _miniField("Gross", item, "gross_weight"),
//
//                     _miniField("Other", item, "other_weight"),
//
//                     _miniField("Net", item, "net_weight"),
//
//                     _miniField("Purity", item, "purity"),
//
//                     _miniField("Waste", item, "waste"),
//
//                     _miniField("Net Purity", item, "net_purity"),
//
//                     _miniField("Fine", item, "fine_weight"),
//
//                     _miniField("Metal Rate", item, "metal_rate"),
//
//                     _miniField("Metal Amount", item, "metal_amount"),
//
//                     _miniField("Labour Rate", item, "labour_rate"),
//
//                     _miniField("Labour Amount", item, "labour_amount"),
//
//                     _miniField("Other Amount", item, "other_amount"),
//
//                     _miniField("Total Amount", item, "total_amount"),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// REMOVE ITEM
//   /// ============================================================
//
//   void _removeItem(Map<String, dynamic> item) {
//     final approvalId = item["approval_item_id"];
//
//     final itemsetId = item["itemset_id"];
//
//     final itemId = item["id"];
//
//     final cartId = item["cart_id"];
//
//     final String source = item["source"]?.toString() ?? "";
//
//     final String itemName =
//         item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";
//
//     final String itemCode =
//     item["qr_code"]?.toString().trim().isNotEmpty == true
//         ? item["qr_code"].toString()
//         : (item["code"]?.toString().trim().isNotEmpty == true
//         ? item["code"].toString()
//         : (item["huid"]?.toString().trim().isNotEmpty == true
//         ? item["huid"].toString()
//         : ""));
//
//     final String itemLabel =
//     itemCode.isNotEmpty ? "$itemName ($itemCode)" : itemName;
//
//     /// 🔥 IMPORTANT: "Scan" (QR scan), "sale" ane "approval" — trane
//     /// j server side "cart" (returns_cart) ma row banave che, etle
//     /// delete karta trane j mate SAME API (returns_cart_remove)
//     /// vaparvi che.
//     if (source == "Scan" || source == "sale" || source == "approval") {
//       if (source == "approval") {
//         /// ✅ APPROVAL DIALOG SE ADDED ITEM — local list mathi remove
//         approvalAddedItems.removeWhere(
//               (e) => e["approval_item_id"]?.toString() == approvalId.toString(),
//         );
//       } else {
//         /// ✅ SCANNED / SALE ITEM — cartItems mathi remove
//         cartItems.removeWhere(
//               (e) =>
//           (e["itemset_id"] ?? e["id"])?.toString() ==
//               (itemsetId ?? itemId)?.toString(),
//         );
//       }
//
//       final String? deleteId = (cartId ?? itemId)?.toString();
//
//       if (deleteId != null && deleteId.isNotEmpty && deleteId != "null") {
//         deleteUser(deleteId);
//
//         /// 🔥 REMOVE MESSAGE
//         if (mounted) {
//           AppMessage.success(context, "$itemLabel removed");
//         }
//       } else {
//         debugPrint("⚠️ CART DELETE SKIPPED — no cart_id/id found on item");
//
//         /// 🔥 REMOVE MESSAGE (local list se to nikadi didhu, pan
//         /// server side id na malva thi API delete thai shaki nathi)
//         if (mounted) {
//           AppMessage.error(
//             context,
//             "$itemLabel removed from list, but could not delete on server",
//           );
//         }
//       }
//     } else {
//       /// ✅ MANUAL SEARCH SE ADDED ITEM
//       items.removeWhere(
//             (e) =>
//         (e["itemset_id"] ?? e["id"])?.toString() ==
//             (itemsetId ?? itemId)?.toString(),
//       );
//
//       /// 🔥 REMOVE MESSAGE
//       if (mounted) {
//         AppMessage.success(context, "$itemLabel removed");
//       }
//     }
//
//     _disposeItemControllers(item);
//
//     updateFinalItems();
//   }
//
//
//   /// ============================================================
//   /// MINI FIELD
//   /// ============================================================
//
//   Widget _miniField(String title, Map<String, dynamic> item, String key) {
//     final bool isOtherField = key == "other_amount";
//
//     final bool isMetalRateField = key == "metal_rate";
//
//     final bool isLabourRateField = key == "labour_rate";
//
//     final controller = getController(item, key);
//
//     final bool editable = key == "metal_rate"
//         ? (item["manual_metal"] ?? true)
//         : key == "labour_rate"
//         ? (item["manual_labour"] ?? true)
//         : isEditableField(key);
//
//     return Container(
//       width: 105,
//
//       margin: const EdgeInsets.only(right: 7),
//
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//
//         children: [
//           Padding(
//             padding: const EdgeInsets.only(left: 2, bottom: 4),
//
//             child: Text(
//               title,
//
//               maxLines: 1,
//
//               overflow: TextOverflow.ellipsis,
//
//               style: const TextStyle(
//                 fontSize: 10,
//
//                 color: Colors.black54,
//
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//
//           Container(
//             height: 36,
//
//             decoration: BoxDecoration(
//               color: editable ? Colors.white : Colors.grey.shade50,
//
//               borderRadius: BorderRadius.circular(5),
//
//               border: Border.all(color: AppColors.border),
//             ),
//
//             child: Stack(
//               alignment: Alignment.centerRight,
//
//               children: [
//                 TextFormField(
//                   controller: controller,
//
//                   /// 🔒 ALL FIELDS READ ONLY
//                   readOnly: true,
//
//                   /// 🔥 Keyboard / Focus completely disable
//                   canRequestFocus: false,
//                   showCursor: false,
//                   enableInteractiveSelection: false,
//
//                   textAlign: TextAlign.left,
//
//                   style: const TextStyle(
//                     color: Colors.black54,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//
//                   decoration: InputDecoration(
//                     isDense: true,
//
//                     contentPadding: EdgeInsets.only(
//                       left: 8,
//                       right:
//                           (isOtherField ||
//                               isMetalRateField ||
//                               isLabourRateField)
//                           ? 30
//                           : 8,
//                       top: 9,
//                       bottom: 9,
//                     ),
//
//                     border: InputBorder.none,
//                     enabledBorder: InputBorder.none,
//                     focusedBorder: InputBorder.none,
//                   ),
//                 ),
//
//                 /// OTHER AMOUNT
//                 if (isOtherField)
//                   Positioned(
//                     right: 4,
//
//                     child: InkWell(
//                       onTap: () async {
//                         FocusManager.instance.primaryFocus?.unfocus();
//
//                         await getreturnDetails(
//                           item["id"],
//                           item,
//                         );
//
//                         if (!mounted) {
//                           return;
//                         }
//
//                         controller.text =
//                             item["other_amount"]?.toString() ?? "0";
//
//                         calculateItem(item);
//
//                         updateFinalItems();
//                       },
//
//                       borderRadius: BorderRadius.circular(4),
//
//                       child: Container(
//                         width: 22,
//
//                         height: 22,
//
//                         alignment: Alignment.center,
//
//                         decoration: BoxDecoration(
//                           color: const Color(0xffC8A96A),
//
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//
//                         child: const Icon(
//                           Icons.add,
//
//                           size: 15,
//
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 /// METAL CHECKBOX
//                 if (isMetalRateField)
//                   Positioned(
//                     right: 2,
//
//                     child: SizedBox(
//                       width: 27,
//                       height: 27,
//
//                       child: Transform.scale(
//                         scale: 0.78,
//
//                         child: Checkbox(
//                           materialTapTargetSize:
//                               MaterialTapTargetSize.shrinkWrap,
//
//                           value:
//                               (double.tryParse(
//                                     controller.text.isEmpty
//                                         ? "0"
//                                         : controller.text,
//                                   ) ??
//                                   0) >
//                               0,
//                           onChanged: null,
//                           // onChanged: (
//                           //     value,
//                           //     ) {
//                           //   FocusManager
//                           //       .instance
//                           //       .primaryFocus
//                           //       ?.unfocus();
//                           //
//                           //   if (value ==
//                           //       true) {
//                           //     item["manual_metal"] =
//                           //     true;
//                           //
//                           //     if ((double.tryParse(
//                           //       controller
//                           //           .text
//                           //           .isEmpty
//                           //           ? "0"
//                           //           : controller
//                           //           .text,
//                           //     ) ??
//                           //         0) ==
//                           //         0) {
//                           //       controller.text =
//                           //       "1";
//                           //
//                           //       item["metal_rate"] =
//                           //       "1";
//                           //     }
//                           //   } else {
//                           //     item["manual_metal"] =
//                           //     false;
//                           //
//                           //     controller.text =
//                           //     "0.00";
//                           //
//                           //     item["metal_rate"] =
//                           //     "0.00";
//                           //   }
//                           //
//                           //   calculateItem(
//                           //     item,
//                           //   );
//                           //
//                           //   updateFinalItems();
//                           // },
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 /// LABOUR CHECKBOX
//                 if (isLabourRateField)
//                   Positioned(
//                     right: 2,
//
//                     child: SizedBox(
//                       width: 27,
//                       height: 27,
//
//                       child: Transform.scale(
//                         scale: 0.78,
//
//                         child: Checkbox(
//                           materialTapTargetSize:
//                               MaterialTapTargetSize.shrinkWrap,
//
//                           value:
//                               (double.tryParse(
//                                     controller.text.isEmpty
//                                         ? "0"
//                                         : controller.text,
//                                   ) ??
//                                   0) >
//                               0,
//                           onChanged: null,
//                           // onChanged: (
//                           //     value,
//                           //     ) {
//                           //   FocusManager
//                           //       .instance
//                           //       .primaryFocus
//                           //       ?.unfocus();
//                           //
//                           //   if (value ==
//                           //       false) {
//                           //     item["manual_labour"] =
//                           //     false;
//                           //
//                           //     controller.text =
//                           //     "0.00";
//                           //
//                           //     item["labour_rate"] =
//                           //     "0.00";
//                           //   } else {
//                           //     item["manual_labour"] =
//                           //     true;
//                           //
//                           //     if ((double.tryParse(
//                           //       controller
//                           //           .text
//                           //           .isEmpty
//                           //           ? "0"
//                           //           : controller
//                           //           .text,
//                           //     ) ??
//                           //         0) ==
//                           //         0) {
//                           //       controller.text =
//                           //       "1";
//                           //
//                           //       item["labour_rate"] =
//                           //       "1";
//                           //     }
//                           //   }
//                           //
//                           //   calculateItem(
//                           //     item,
//                           //   );
//                           //
//                           //   updateFinalItems();
//                           // },
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
//   /// ============================================================
//   /// CONTROLLER UNIQUE ID
//   /// ============================================================
//
//   String _itemUniqueId(Map item) {
//     return (item["approval_item_id"] ??
//             item["itemset_id"] ??
//             item["id"] ??
//             item["qr_code"] ??
//             item["code"] ??
//             identityHashCode(item))
//         .toString();
//   }
//
//   /// ============================================================
//   /// GET CONTROLLER
//   /// ============================================================
//
//   TextEditingController getController(Map item, String key) {
//     final uniqueKey = "${_itemUniqueId(item)}_$key";
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
//   /// ============================================================
//   /// SET CONTROLLER
//   /// ============================================================
//
//   void setController(Map<String, dynamic> item, String key, dynamic value) {
//     final controller = getController(item, key);
//
//     final String newValue = value?.toString() ?? "";
//
//     if (controller.text == newValue) {
//       return;
//     }
//
//     controller.value = TextEditingValue(
//       text: newValue,
//
//       selection: TextSelection.collapsed(offset: newValue.length),
//     );
//   }
//
//   /// ============================================================
//   /// UPDATE CONTROLLER
//   /// ============================================================
//
//   void updateController(Map item, String key) {
//     final uniqueKey = "${_itemUniqueId(item)}_$key";
//
//     final controller = controllers[uniqueKey];
//
//     if (controller == null) {
//       return;
//     }
//
//     final String newValue = item[key]?.toString() ?? "";
//
//     if (controller.text == newValue) {
//       return;
//     }
//
//     controller.value = TextEditingValue(
//       text: newValue,
//
//       selection: TextSelection.collapsed(offset: newValue.length),
//     );
//   }
//
//   /// ============================================================
//   /// INITIALIZE ITEM CONTROLLERS
//   /// ============================================================
//
//   void _initializeItemControllers(Map<String, dynamic> item) {
//     const fields = [
//       "gross_weight",
//       "other_weight",
//       "net_weight",
//       "purity",
//       "waste",
//       "net_purity",
//       "fine_weight",
//       "metal_rate",
//       "metal_amount",
//       "labour_rate",
//       "labour_amount",
//       "other_amount",
//       "total_amount",
//     ];
//
//     for (final key in fields) {
//       getController(item, key);
//     }
//   }
//
//   /// ============================================================
//   /// DISPOSE SINGLE ITEM CONTROLLERS
//   /// ============================================================
//
//   void _disposeItemControllers(Map item) {
//     final id = _itemUniqueId(item);
//
//     final keys = controllers.keys
//         .where((key) => key.startsWith("${id}_"))
//         .toList();
//
//     for (final key in keys) {
//       controllers[key]?.dispose();
//
//       controllers.remove(key);
//     }
//   }
//
//   /// ============================================================
//   /// GET VALUE
//   /// ============================================================
//
//   double getValue(Map item, String key) {
//     final uniqueKey = "${_itemUniqueId(item)}_$key";
//
//     final controller = controllers[uniqueKey];
//
//     if (controller != null) {
//       return double.tryParse(controller.text.trim()) ?? 0;
//     }
//
//     return double.tryParse(item[key]?.toString() ?? "0") ?? 0;
//   }
//
//   /// ============================================================
//   /// EDITABLE
//   /// ============================================================
//
//   bool isEditableField(String key) {
//     return [
//       "gross_weight",
//       "other_weight",
//       "purity",
//       "waste",
//       "labour_rate",
//       "metal_rate",
//     ].contains(key);
//   }
//
//   /// ============================================================
//   /// CALCULATE ITEM
//   /// ============================================================
//
//   void calculateItem(Map<String, dynamic> item) {
//     if (_isCalculating) {
//       return;
//     }
//
//     _isCalculating = true;
//
//     try {
//       final double gross =
//           double.tryParse(getController(item, "gross_weight").text) ?? 0;
//
//       final double other =
//           double.tryParse(getController(item, "other_weight").text) ?? 0;
//
//       final double purity =
//           double.tryParse(getController(item, "purity").text) ?? 0;
//
//       final double waste =
//           double.tryParse(getController(item, "waste").text) ?? 0;
//
//       final double metalRate =
//           double.tryParse(getController(item, "metal_rate").text) ?? 0;
//
//       final double labourRate =
//           double.tryParse(getController(item, "labour_rate").text) ?? 0;
//
//       final double otherAmount =
//           double.tryParse(getController(item, "other_amount").text) ?? 0;
//
//       final double net = gross - other;
//
//       final double netPurity = purity + waste;
//
//       final double fineWeight = net * (netPurity / 100);
//
//       final bool manualMetal = item["manual_metal"] ?? true;
//
//       final bool manualLabour = item["manual_labour"] ?? true;
//
//       final double metalAmount = manualMetal ? net * metalRate : 0;
//
//       final double labourAmount = manualLabour ? net * labourRate : 0;
//
//       final double totalAmount = metalAmount + labourAmount + otherAmount;
//
//       item["net_weight"] = net.toStringAsFixed(3);
//
//       item["net_purity"] = netPurity.toStringAsFixed(2);
//
//       item["fine_weight"] = fineWeight.toStringAsFixed(3);
//
//       item["metal_amount"] = metalAmount.toStringAsFixed(2);
//
//       item["labour_amount"] = labourAmount.toStringAsFixed(2);
//
//       item["total_amount"] = totalAmount.toStringAsFixed(2);
//
//       /// Only calculated fields update.
//       /// User typing field ne touch nathi karta.
//
//       updateController(item, "net_weight");
//
//       updateController(item, "net_purity");
//
//       updateController(item, "fine_weight");
//
//       updateController(item, "metal_amount");
//
//       updateController(item, "labour_amount");
//
//       updateController(item, "total_amount");
//     } finally {
//       _isCalculating = false;
//     }
//   }
//
//   /// ============================================================
//   /// DEBOUNCE FINAL UPDATE
//   /// ============================================================
//
//   void _scheduleFinalItemsUpdate() {
//     _calculationDebounce?.cancel();
//
//     _calculationDebounce = Timer(const Duration(milliseconds: 180), () {
//       if (!mounted) return;
//
//       updateFinalItems();
//     });
//   }
//
//   /// ============================================================
//   /// BUILD ITEM DATA
//   /// ============================================================
//
//   Map<String, dynamic> buildItemData(Map item, String source) {
//     final double gross = getValue(item, "gross_weight");
//
//     final double other = getValue(item, "other_weight");
//
//     final double net = gross - other;
//
//     final double purity = getValue(item, "purity");
//
//     final double waste = getValue(item, "waste");
//
//     final double netPurity = purity + waste;
//
//     final double fineWeight = net * (netPurity / 100);
//
//     final double metalRate = getValue(item, "metal_rate");
//
//     final double labourRate = getValue(item, "labour_rate");
//
//     final double otherAmount = getValue(item, "other_amount");
//
//     final bool manualMetal = item["manual_metal"] ?? true;
//
//     final bool manualLabour = item["manual_labour"] ?? true;
//
//     final double metalAmount = manualMetal ? net * metalRate : 0;
//
//     final double labourAmount = manualLabour ? net * labourRate : 0;
//
//     double totalAmount;
//
//     if (source == "Scan") {
//       final apiAmount = double.tryParse(item["amount"]?.toString() ?? "");
//
//       totalAmount = apiAmount ?? (metalAmount + labourAmount + otherAmount);
//     } else {
//       totalAmount = metalAmount + labourAmount + otherAmount;
//     }
//
//     return {
//       ...Map<String, dynamic>.from(item),
//
//       "source": source,
//
//       "itemset_id": item["itemset_id"] ?? item["id"],
//
//       "approval_item_id": item["approval_item_id"],
//
//       "gross_weight": gross,
//
//       "other_weight": other,
//
//       "net_weight": net,
//
//       "purity": purity,
//
//       "waste": waste,
//
//       "net_purity": netPurity,
//
//       "fine_weight": fineWeight,
//
//       "metal_rate": metalRate,
//
//       "metal_amount": metalAmount,
//
//       "labour_rate": labourRate,
//
//       "labour_amount": labourAmount,
//
//       "other_amount": otherAmount,
//
//       "total_amount": totalAmount,
//     };
//   }
//
//   /// ============================================================
//   /// UPDATE FINAL ITEMS
//   /// ============================================================
//
//   void updateFinalItems() {
//     final List<Map<String, dynamic>> updatedList = [];
//
//     /// MANUAL
//     for (final item in items) {
//       if (item["id"] == null && item["itemset_id"] == null) {
//         continue;
//       }
//
//       updatedList.add(buildItemData(item, "manual"));
//     }
//
//     /// APPROVAL
//     for (final rawItem in approvalAddedItems) {
//       final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
//
//       if (item["itemset_id"] == null || item["approval_item_id"] == null) {
//         continue;
//       }
//
//       final bool alreadyExists = updatedList.any(
//         (e) =>
//             e["itemset_id"]?.toString() == item["itemset_id"]?.toString() &&
//             e["approval_item_id"]?.toString() ==
//                 item["approval_item_id"]?.toString(),
//       );
//
//       if (!alreadyExists) {
//         updatedList.add(buildItemData(item, "approval"));
//       }
//     }
//
//     /// SCANNER
//     for (final rawItem in cartItems) {
//       final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
//
//       if (item["itemset_id"] == null) {
//         continue;
//       }
//
//       final bool alreadyExists = updatedList.any(
//         (e) => e["itemset_id"]?.toString() == item["itemset_id"]?.toString(),
//       );
//
//       if (!alreadyExists) {
//         updatedList.add(buildItemData(item, "Scan"));
//       }
//     }
//
//     if (!mounted) return;
//
//     setState(() {
//       finalItems = updatedList;
//     });
//
//     debugPrint("🔥 LIVE FINAL ITEMS: $finalItems");
//   }
//
//   /// ============================================================
//   /// SAVE
//   /// ============================================================
//
//   Future<void> savefinalizeBulkItems() async {
//     FocusManager.instance.primaryFocus?.unfocus();
//
//     _calculationDebounce?.cancel();
//
//     updateFinalItems();
//
//     if (selectedUserId == null || selectedUserId!.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please select customer first"),
//
//           backgroundColor: Colors.red,
//         ),
//       );
//
//       return;
//     }
//
//     final List<int> returnItems = [];
//
//     for (final item in finalItems) {
//       final id = item["itemset_id"];
//
//       if (id == null) continue;
//
//       final parsed = int.tryParse(id.toString());
//
//       if (parsed != null && !returnItems.contains(parsed)) {
//         returnItems.add(parsed);
//       }
//     }
//
//     if (returnItems.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("No items selected")));
//
//       return;
//     }
//     if (deviceId == null || deviceId!.trim().isEmpty) {
//       try {
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//           deviceId = androidInfo.id;
//         } else if (Platform.isIOS) {
//           final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//           deviceId = iosInfo.identifierForVendor ?? "";
//         }
//       } catch (e) {
//         debugPrint("DeviceInfo Error (Return Scan): $e");
//       }
//     }
//     final String entryId = _generateDeviceEntryId();
//     final prefs = await SharedPreferences.getInstance();
//     final String? loggedInUserId = prefs.getString('user_id');
//     final body = {
//       "customer_id": int.parse(selectedUserId!),
//
//       "return_items": returnItems,
//
//       "remarks": remarksController.text.trim(),
//       "device_id": deviceId,
//
//       "voucher_session_id": voucherSessionId,
//
//       "device_entry_id": entryId,
//       "Created By": loggedInUserId,
//     };
//
//     debugPrint("📤 REQUEST BODY: $body");
//
//     final response = await OfflineApiHelper.instance.postRequest(
//       ApiConstants.returns_store,
//       body,
//     );
//
//     if (!mounted) return;
//
//     if (response != null &&
//         (response.statusCode == 200 || response.statusCode == 202)) {
//       if (response.statusCode == 202) {
//         AppMessage.success(context, "No Internet. Update saved offline.");
//       } else {
//         AppMessage.success(context, "Saved Successfully");
//       }
//
//       finalItems.clear();
//       cartItems.clear();
//       approvalAddedItems.clear();
//       items.clear();
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const Approvalreturnscreen(),
//         ),
//             (route) => route.isFirst,
//       );
//     } else {
//       /// 🔥 Server thi actual error message extract karo
//       /// (jem: "Please select at least one available approval
//       /// item for return."), generic "Failed To Save" na badle.
//       String errorMessage = "Failed To Save";
//
//       try {
//         final dynamic data = response?.data;
//
//         if (data is Map && data["message"] != null) {
//           errorMessage = data["message"].toString();
//         }
//       } catch (_) {}
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//
//       /// 🔥 IMPORTANT: Yaha koi Navigator.push/redirect nathi —
//       /// user aa j screen par rahese jethi te selection fari
//       /// check kari shake.
//     }
//   }
//
//   /// ============================================================
//   /// SCANNER
//   /// ============================================================
//
//   Widget _buildScannerSection() {
//     double scannerSize = MediaQuery.of(context).size.width * 0.4;
//
//     if (MediaQuery.of(context).size.width > 600) {
//       scannerSize = 350;
//     }
//
//     return Container(
//       width: scannerSize,
//
//       height: scannerSize,
//
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(20),
//
//         border: Border.all(color: Colors.white10),
//       ),
//
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(20),
//
//         child: MobileScanner(
//           controller: MobileScannerController(
//             detectionSpeed: DetectionSpeed.unrestricted,
//
//             formats: [BarcodeFormat.qrCode],
//           ),
//
//           onDetect: (barcodeCapture) {
//             for (final barcode in barcodeCapture.barcodes) {
//               final String? code = barcode.rawValue;
//
//               if (code == null || code.isEmpty) {
//                 continue;
//               }
//
//               if (lastCode == code) {
//                 continue;
//               }
//
//               if (isBusy) {
//                 continue;
//               }
//
//               if (selectedUserId == null || selectedUserId!.isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text("Please select customer first"),
//
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//
//                 return;
//               }
//
//               lastCode = code;
//
//               isBusy = true;
//
//               debugPrint("⚡ FAST SCAN: $code");
//
//               scanApiCall(code);
//
//               Future.delayed(const Duration(milliseconds: 600), () {
//                 isBusy = false;
//               });
//
//               Future.delayed(const Duration(seconds: 2), () {
//                 if (lastCode == code) {
//                   lastCode = null;
//                 }
//               });
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// SCAN API
//   /// ============================================================
//
//   Future<void> scanApiCall(String code) async {
//     if (selectedUserId == null) {
//       return;
//     }
//
//     /// =========================================================
//     /// 🔥 DUPLICATE SCAN CHECK
//     ///
//     /// Backend already-scanned item mate pan "success: true" j
//     /// return kare che, etle niche ni API call thai jata pehla j
//     /// aapde locally check kari laiye ke aa qr_code cartItems /
//     /// items / approvalAddedItems ma pehla thi j hazar che ke nai.
//     /// Hoy to API call j na karvi — sidhu "Item already scanned"
//     /// batavi devanu.
//     /// =========================================================
//
//     final String trimmedCode = code.trim();
//
//     final bool alreadyScanned =
//         cartItems.any(
//               (e) => (e["qr_code"]?.toString().trim() ?? "") == trimmedCode,
//         ) ||
//             items.any(
//                   (e) => (e["qr_code"]?.toString().trim() ?? "") == trimmedCode,
//             ) ||
//             approvalAddedItems.any(
//                   (e) => (e["qr_code"]?.toString().trim() ?? "") == trimmedCode,
//             );
//
//     if (alreadyScanned) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Item already scanned"),
//
//             backgroundColor: Colors.orange,
//
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//
//       return;
//     }
//     /// 🔥 device_id ek vaar j fetch karo (already set hoy to skip)
//     if (deviceId == null || deviceId!.trim().isEmpty) {
//       try {
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//           deviceId = androidInfo.id;
//         } else if (Platform.isIOS) {
//           final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//           deviceId = iosInfo.identifierForVendor ?? "";
//         }
//       } catch (e) {
//         debugPrint("DeviceInfo Error (Return Scan): $e");
//       }
//     }
//
//     /// 🔥 voucher_session_id na hoy to fallback generate karo
//     voucherSessionId ??= 'RET-${DateTime.now().millisecondsSinceEpoch}';
//
//     final String entryId = _generateDeviceEntryId();
//
//     final String url =
//         "${ApiConstants.Approval_return_qr_item}"
//         "?customer_id=$selectedUserId"
//         "&qr_code=${Uri.encodeQueryComponent(code)}"
//         "&device_id=${Uri.encodeQueryComponent(deviceId ?? "")}"
//         "&voucher_session_id=${Uri.encodeQueryComponent(voucherSessionId ?? "")}"
//         "&device_entry_id=${Uri.encodeQueryComponent(entryId)}";
//
//     debugPrint("📤 GET API URL: $url");
//
//     debugPrint("📤 GET API URL: $url");
//
//     final response = await ApiHelper().getRequest(url);
//
//     if (!mounted) return;
//
//     if (response == null) {
//       return;
//     }
//
//     debugPrint("📥 Status Code: ${response.statusCode}");
//
//     debugPrint("📥 Response Data: ${response.data}");
//
//     if (response.statusCode == 200 && response.data["success"] == true) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Item Scan Successfully"),
//
//           backgroundColor: Colors.green,
//
//           duration: Duration(seconds: 2),
//         ),
//       );
//
//       await getCartItems();
//     } else {
//       final String message =
//           response.data["message"]?.toString() ?? "Scan failed";
//
//       /// Backend potej "already" wala message aapi ne success:false
//       /// karto hoy to pan orange color ma spashth batavo
//       final bool isDuplicateFromApi = message.toLowerCase().contains(
//         "already",
//       );
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   }
//
//   /// ============================================================
//   /// CART ITEMS
//   /// ============================================================
//
//   Future<void> getCartItems() async {
//     final response = await ApiHelper().getRequest(ApiConstants.return_Qr_list);
//
//     if (response != null && response.statusCode == 200) {
//       final List rawData = response.data["data"] ?? [];
//
//       final List<Map<String, dynamic>> newCartItems = rawData
//           .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
//           .toList();
//
//       /// ==========================================
//       /// IMPORTANT:
//       /// Heavy work outside setState
//       /// ==========================================
//
//       for (final item in newCartItems) {
//         item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
//
//         item["other_weight"] = item["other_weight"]?.toString() ?? "0";
//
//         item["net_weight"] = item["net_weight"]?.toString() ?? "0";
//
//         item["purity"] = item["purity"]?.toString() ?? "0";
//
//         item["waste"] =
//             item["waste"]?.toString() ??
//             item["waste_percent"]?.toString() ??
//             "0";
//
//         item["labour_rate"] = item["labour_rate"]?.toString() ?? "0";
//
//         item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
//
//         item["other_amount"] = item["other_amount"]?.toString() ?? "0";
//
//         item["total_amount"] =
//             item["amount"]?.toString() ??
//             item["total_amount"]?.toString() ??
//             "0";
//
//         item["manual_metal"] = item["manual_metal"] ?? true;
//
//         item["manual_labour"] = item["manual_labour"] ?? true;
//
//         _initializeItemControllers(item);
//
//         calculateItem(item);
//       }
//
//       cartItems = newCartItems;
//
//       updateFinalItems();
//
//       debugPrint("Total Cart Items: ${cartItems.length}");
//     } else {
//       if (!mounted) return;
//
//       setState(() {
//         cartItems = [];
//         finalItems = [];
//       });
//     }
//   }
//
//   /// ============================================================
//   /// DELETE CART
//   /// ============================================================
//
//   Future<void> deleteUser(String id) async {
//     try {
//       final response = await ApiHelper().deleteRequest(
//         "${ApiConstants.returns_cart_remove}/$id",
//       );
//
//       if (response?.statusCode == 200) {
//         debugPrint("✅ Deleted Successfully");
//
//         await getCartItems();
//       }
//     } catch (e) {
//       debugPrint("❌ Delete exception: $e");
//     }
//   }
//
//   /// ============================================================
//   /// OTHER CHARGE API
//   /// ============================================================
//
//   Future<void> getreturnDetails(
//     dynamic id,
//     Map<String, dynamic> mainItem,
//   ) async {
//     showDialog(
//       context: context,
//
//       barrierDismissible: false,
//
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(ApiConstants.other_charge);
//
//     if (!mounted) return;
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//
//       final List apiList = data["data"] is List ? data["data"] : [];
//
//       showOtherChargesPopup(mainItem, apiList);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
//     }
//   }
//
//   /// ============================================================
//   /// OTHER CHARGES POPUP
//   /// ============================================================
//
//   void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
//     /// ============================================================
//     /// 🔥 FIX: PREVIOUSLY SELECTED CHARGES (persist thi)
//     /// Apply time "other_charge_ids" (comma-separated ids) item ma
//     /// save thai chuklu hoy — e j ids sathe match kari ne pre-select.
//     /// ============================================================
//     final Set<String> previouslySelectedIds = (item["other_charge_ids"]
//         ?.toString() ??
//         "")
//         .split(",")
//         .map((e) => e.trim())
//         .where((e) => e.isNotEmpty)
//         .toSet();
//
//     // ============================================================
//     // API DATA -> POPUP DATA (id add karyu — persistence mate jaruri)
//     // ============================================================
//     final List<Map<String, dynamic>> charges = apiList
//         .map<Map<String, dynamic>>((e) {
//       final String chargeId = e["id"]?.toString() ?? "";
//
//       /// 🔥 FIX: pre-select — saved ids ma hoy, ya API j is_selected
//       /// batavtu hoy (fallback), to select rakhvanu
//       final bool isSelected = previouslySelectedIds.contains(chargeId) ||
//           (e["is_selected"] ?? false) == true;
//
//       return {
//         "id": e["id"],
//         "charge": e["name"] ?? "",
//         "amount": (e["default_amount"] ?? 0).toString(),
//         "qty": (e["quantity_pcs"] ?? 1).toString(),
//         "weight": (e["default_weight"] ?? 0).toString(),
//         "wt_formula": e["weight_formula"] == "per_quantity" ? "per_qty" : "flat",
//         "amt_formula_type": e["other_amt_formula"] == "per_quantity"
//             ? "per_qty"
//             : e["other_amt_formula"] == "per_weight"
//             ? "per_weight"
//             : e["other_amt_formula"] == "per_qty_weight"
//             ? "per_qty_weight"
//             : "flat",
//         "total_weight": "0.0",
//         "total_amt": "0",
//         "is_selected": isSelected,
//       };
//     }).toList();
//
//     /// ============================================================
//     /// 🔥 PERSISTENT CONTROLLERS (PERFORMANCE FIX)
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
//     /// 🔥 SINGLE-ROW CALCULATION (PERFORMANCE FIX)
//     /// ============================================================
//     void calculateSingleCharge(Map<String, dynamic> c) {
//       final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//       final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//       final double weight = double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;
//
//       final String amtFormula = c["amt_formula_type"] ?? "flat";
//       final String wtFormula = c["wt_formula"] ?? "flat";
//
//       double totalAmt = 0;
//       double totalWeight = 0;
//
//       switch (wtFormula) {
//         case "flat":
//           totalWeight = weight;
//           break;
//         case "per_qty":
//           totalWeight = weight * qty;
//           break;
//         case "per_weight":
//           totalWeight = weight;
//           break;
//         default:
//           totalWeight = weight;
//       }
//
//       c["total_weight"] = totalWeight.toStringAsFixed(2);
//
//       switch (amtFormula) {
//         case "flat":
//           totalAmt = amt;
//           break;
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
//     int selectedCount() {
//       return charges.where((c) => c["is_selected"] == true).length;
//     }
//
//     final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
//     final ValueNotifier<int> selectedCountNotifier = ValueNotifier<int>(selectedCount());
//
//     // ============================================================
//     // SHOW DIALOG — PREMIUM UI (SAME AS BEFORE)
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
//                   // BLUE HEADER
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
//                   // BODY
//                   Flexible(
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
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
//                               ValueListenableBuilder<int>(
//                                 valueListenable: selectedCountNotifier,
//                                 builder: (context, count, _) {
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
//                                           "$count Selected",
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
//                           SingleChildScrollView(
//                             scrollDirection: Axis.horizontal,
//                             keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
//                                       keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
//                                             final bool selected = c["is_selected"] == true;
//
//                                             return AnimatedContainer(
//                                               duration: const Duration(milliseconds: 150),
//                                               padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//                                               decoration: BoxDecoration(
//                                                 color: selected
//                                                     ? AppColors.primaryDark.withOpacity(0.035)
//                                                     : Colors.white,
//                                                 border: Border(
//                                                   left: BorderSide(
//                                                     color: selected ? AppColors.primaryDark : Colors.transparent,
//                                                     width: 3,
//                                                   ),
//                                                 ),
//                                               ),
//                                               child: Row(
//                                                 children: [
//                                                   SizedBox(
//                                                     width: 110,
//                                                     child: Padding(
//                                                       padding: const EdgeInsets.symmetric(horizontal: 5),
//                                                       child: Row(
//                                                         children: [
//                                                           Container(
//                                                             width: 24,
//                                                             height: 24,
//                                                             alignment: Alignment.center,
//                                                             decoration: BoxDecoration(
//                                                               color: selected
//                                                                   ? AppColors.primaryDark.withOpacity(0.12)
//                                                                   : AppColors.iconBg,
//                                                               borderRadius: BorderRadius.circular(6),
//                                                             ),
//                                                             child: Text(
//                                                               "${index + 1}",
//                                                               style: const TextStyle(
//                                                                 color: AppColors.primaryDark,
//                                                                 fontSize: 9,
//                                                                 fontWeight: FontWeight.w700,
//                                                               ),
//                                                             ),
//                                                           ),
//                                                           const SizedBox(width: 5),
//                                                           Expanded(
//                                                             child: Text(
//                                                               c["charge"]?.toString() ?? "",
//                                                               maxLines: 1,
//                                                               overflow: TextOverflow.ellipsis,
//                                                               style: TextStyle(
//                                                                 fontSize: 10.5,
//                                                                 fontWeight:
//                                                                 selected ? FontWeight.w700 : FontWeight.w600,
//                                                                 color: AppColors.textPrimary,
//                                                               ),
//                                                             ),
//                                                           ),
//                                                         ],
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 90,
//                                                     child: Padding(
//                                                       padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                       child: TextFormField(
//                                                         controller: rowControllers[index]!["amount"],
//                                                         style: const TextStyle(
//                                                           fontSize: 11,
//                                                           fontWeight: FontWeight.w600,
//                                                           color: AppColors.textPrimary,
//                                                         ),
//                                                         textAlign: TextAlign.center,
//                                                         keyboardType:
//                                                         const TextInputType.numberWithOptions(decimal: true),
//                                                         decoration: inputDecoration(),
//                                                         onChanged: (_) => onFieldChanged(),
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 70,
//                                                     child: Padding(
//                                                       padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                       child: TextFormField(
//                                                         controller: rowControllers[index]!["qty"],
//                                                         style: const TextStyle(
//                                                           fontSize: 11,
//                                                           fontWeight: FontWeight.w600,
//                                                           color: AppColors.textPrimary,
//                                                         ),
//                                                         textAlign: TextAlign.center,
//                                                         keyboardType:
//                                                         const TextInputType.numberWithOptions(decimal: true),
//                                                         decoration: inputDecoration(),
//                                                         onChanged: (_) => onFieldChanged(),
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 90,
//                                                     child: Padding(
//                                                       padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                       child: TextFormField(
//                                                         controller: rowControllers[index]!["weight"],
//                                                         style: const TextStyle(
//                                                           fontSize: 11,
//                                                           fontWeight: FontWeight.w600,
//                                                           color: AppColors.textPrimary,
//                                                         ),
//                                                         textAlign: TextAlign.center,
//                                                         keyboardType:
//                                                         const TextInputType.numberWithOptions(decimal: true),
//                                                         decoration: inputDecoration(),
//                                                         onChanged: (_) => onFieldChanged(),
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 105,
//                                                     child: Padding(
//                                                       padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                       child: DropdownButtonFormField<String>(
//                                                         value: c["wt_formula"],
//                                                         isExpanded: true,
//                                                         dropdownColor: Colors.white,
//                                                         icon: const Icon(
//                                                           Icons.keyboard_arrow_down_rounded,
//                                                           color: AppColors.primaryDark,
//                                                           size: 17,
//                                                         ),
//                                                         style: const TextStyle(
//                                                           fontSize: 10,
//                                                           color: AppColors.textPrimary,
//                                                           fontWeight: FontWeight.w600,
//                                                         ),
//                                                         decoration: inputDecoration(),
//                                                         items: const [
//                                                           DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                                           DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                                           DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                                         ],
//                                                         onChanged: (v) {
//                                                           if (v == null) return;
//                                                           c["wt_formula"] = v;
//                                                           onFieldChanged();
//                                                         },
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 90,
//                                                     child: Center(
//                                                       child: Text(
//                                                         c["total_weight"]?.toString() ?? "0",
//                                                         textAlign: TextAlign.center,
//                                                         style: const TextStyle(
//                                                           fontSize: 10.5,
//                                                           fontWeight: FontWeight.w700,
//                                                           color: AppColors.textPrimary,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 115,
//                                                     child: Padding(
//                                                       padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                       child: DropdownButtonFormField<String>(
//                                                         value: c["amt_formula_type"] ?? "flat",
//                                                         isExpanded: true,
//                                                         dropdownColor: Colors.white,
//                                                         icon: const Icon(
//                                                           Icons.keyboard_arrow_down_rounded,
//                                                           color: AppColors.primaryDark,
//                                                           size: 17,
//                                                         ),
//                                                         style: const TextStyle(
//                                                           fontSize: 9.8,
//                                                           color: AppColors.textPrimary,
//                                                           fontWeight: FontWeight.w600,
//                                                         ),
//                                                         decoration: inputDecoration(),
//                                                         items: const [
//                                                           DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                                           DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                                           DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                                           DropdownMenuItem(
//                                                               value: "per_qty_weight", child: Text("Qty × Wt")),
//                                                         ],
//                                                         onChanged: (v) {
//                                                           if (v == null) return;
//                                                           c["amt_formula_type"] = v;
//                                                           onFieldChanged();
//                                                         },
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   SizedBox(
//                                                     width: 105,
//                                                     child: Center(
//                                                       child: Container(
//                                                         constraints: const BoxConstraints(minWidth: 70),
//                                                         padding:
//                                                         const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
//                                                         decoration: BoxDecoration(
//                                                           color: const Color(0xFFEAF1FF),
//                                                           borderRadius: BorderRadius.circular(6),
//                                                           border: Border.all(
//                                                             color: AppColors.primaryDark.withOpacity(0.12),
//                                                           ),
//                                                         ),
//                                                         child: Text(
//                                                           c["total_amt"]?.toString() ?? "0",
//                                                           textAlign: TextAlign.center,
//                                                           style: const TextStyle(
//                                                             fontSize: 10.5,
//                                                             fontWeight: FontWeight.w800,
//                                                             color: AppColors.primaryDark,
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   ),
//
//                                                   /// CHECKBOX (MULTI-SELECT)
//                                                   SizedBox(
//                                                     width: 45,
//                                                     child: Center(
//                                                       child: Transform.scale(
//                                                         scale: 0.88,
//                                                         child: Checkbox(
//                                                           value: c["is_selected"] == true,
//                                                           activeColor: AppColors.primaryDark,
//                                                           checkColor: Colors.white,
//                                                           side: const BorderSide(
//                                                             color: AppColors.primaryDark,
//                                                             width: 1.3,
//                                                           ),
//                                                           shape: RoundedRectangleBorder(
//                                                             borderRadius: BorderRadius.circular(4),
//                                                           ),
//                                                           onChanged: (val) {
//                                                             c["is_selected"] = val ?? false;
//
//                                                             setStateRow(() {});
//
//                                                             totalNotifier.value = calcTotal();
//                                                             selectedCountNotifier.value = selectedCount();
//                                                           },
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
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
//                                       ValueListenableBuilder<int>(
//                                         valueListenable: selectedCountNotifier,
//                                         builder: (context, count, _) {
//                                           return Text(
//                                             "$count of ${charges.length} charges selected",
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
//                   // BOTTOM ACTION BAR
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       border: Border(top: BorderSide(color: AppColors.border)),
//                     ),
//                     child: Row(
//                       children: [
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
//
//                                   double selectedTotal = 0;
//
//                                   /// 🔥 FIX: selected charge ids collect karo
//                                   final List<String> selectedIds = [];
//
//                                   for (final c in charges) {
//                                     if (c["is_selected"] == true) {
//                                       selectedTotal +=
//                                           double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
//
//                                       selectedIds.add(c["id"]?.toString() ?? "");
//                                     }
//                                   }
//
//                                   item["other_amount"] = selectedTotal.toStringAsFixed(2);
//
//                                   /// 🔥 FIX: SAVE SELECTED IDS — NEXT TIME PRE-SELECT MATE
//                                   item["other_charge_ids"] = selectedIds.join(",");
//
//                                   setController(
//                                     item,
//                                     "other_amount",
//                                     item["other_amount"],
//                                   );
//
//                                   calculateItem(item);
//
//                                   updateFinalItems();
//
//                                   disposeControllers();
//
//                                   Navigator.pop(dialogContext);
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
//   /// ============================================================
//   /// SUMMARY
//   /// ============================================================
//
//   Widget buildSummaryRow() {
//     final totals = calculateTotals();
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
//
//       decoration: BoxDecoration(
//         color: AppColors.background,
//
//         border: Border.all(color: AppColors.border, width: 1.5),
//
//         borderRadius: BorderRadius.circular(6),
//       ),
//
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//
//         child: Row(
//           children: [
//             _summaryBox("Items", "${finalItems.length}"),
//
//             _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
//
//             _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
//
//             _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),
//
//             _summaryBox("Purity", totals["purity"]!.toStringAsFixed(2)),
//
//             _summaryBox("Waste", totals["waste"]!.toStringAsFixed(2)),
//
//             _summaryBox("Net Purity", totals["netPurity"]!.toStringAsFixed(2)),
//
//             _summaryBox("Fine", totals["fine"]!.toStringAsFixed(3)),
//
//             _summaryBox("Metal Rate", totals["metalRate"]!.toStringAsFixed(2)),
//
//             _summaryBox("Metal Amt", totals["metal"]!.toStringAsFixed(2)),
//
//             _summaryBox(
//               "Labour Rate",
//               totals["labourRate"]!.toStringAsFixed(2),
//             ),
//
//             _summaryBox("Labour Amt", totals["labour"]!.toStringAsFixed(2)),
//
//             _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),
//
//             _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// TOTALS
//   /// ============================================================
//
//   Map<String, double> calculateTotals() {
//     double gross = 0;
//     double other = 0;
//     double net = 0;
//
//     double purity = 0;
//     double waste = 0;
//     double netPurity = 0;
//
//     double fine = 0;
//
//     double metalRate = 0;
//     double metal = 0;
//
//     double labourRate = 0;
//     double labour = 0;
//
//     double otherAmt = 0;
//     double total = 0;
//
//     for (final item in finalItems) {
//       gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
//
//       other += double.tryParse(item["other_weight"]?.toString() ?? "0") ?? 0;
//
//       net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;
//
//       purity += double.tryParse(item["purity"]?.toString() ?? "0") ?? 0;
//
//       waste += double.tryParse(item["waste"]?.toString() ?? "0") ?? 0;
//
//       netPurity += double.tryParse(item["net_purity"]?.toString() ?? "0") ?? 0;
//
//       fine += double.tryParse(item["fine_weight"]?.toString() ?? "0") ?? 0;
//
//       metalRate += double.tryParse(item["metal_rate"]?.toString() ?? "0") ?? 0;
//
//       metal += double.tryParse(item["metal_amount"]?.toString() ?? "0") ?? 0;
//
//       labourRate +=
//           double.tryParse(item["labour_rate"]?.toString() ?? "0") ?? 0;
//
//       labour += double.tryParse(item["labour_amount"]?.toString() ?? "0") ?? 0;
//
//       otherAmt += double.tryParse(item["other_amount"]?.toString() ?? "0") ?? 0;
//
//       total += double.tryParse(item["total_amount"]?.toString() ?? "0") ?? 0;
//     }
//
//     return {
//       "gross": gross,
//
//       "other": other,
//
//       "net": net,
//
//       "purity": purity,
//
//       "waste": waste,
//
//       "netPurity": netPurity,
//
//       "fine": fine,
//
//       "metalRate": metalRate,
//
//       "metal": metal,
//
//       "labourRate": labourRate,
//
//       "labour": labour,
//
//       "otherAmt": otherAmt,
//
//       "total": total,
//     };
//   }
//
//   /// ============================================================
//   /// SUMMARY BOX
//   /// ============================================================
//
//   Widget _summaryBox(String title, String value) {
//     return Container(
//       width: 90,
//
//       margin: const EdgeInsets.only(right: 8),
//
//       padding: const EdgeInsets.symmetric(vertical: 6),
//
//       decoration: BoxDecoration(
//         color: Colors.white,
//
//         borderRadius: BorderRadius.circular(6),
//
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//
//       child: Column(
//         children: [
//           Text(
//             title,
//
//             style: const TextStyle(fontSize: 11, color: Colors.black54),
//           ),
//
//           const SizedBox(height: 4),
//
//           Text(
//             value,
//
//             style: const TextStyle(
//               fontSize: 13,
//
//               fontWeight: FontWeight.bold,
//
//               color: Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// OPTIONAL OLD HELPERS
//   /// ============================================================
//
//   void calculateNetWeight(int index) {
//     if (index < 0 || index >= tableRows.length) {
//       return;
//     }
//
//     final grossController = tableRows[index]["gross"];
//
//     final otherController = tableRows[index]["other"];
//
//     final netController = tableRows[index]["net"];
//
//     if (grossController is! TextEditingController ||
//         otherController is! TextEditingController ||
//         netController is! TextEditingController) {
//       return;
//     }
//
//     final double gross = double.tryParse(grossController.text) ?? 0;
//
//     final double other = double.tryParse(otherController.text) ?? 0;
//
//     final double net = gross - other;
//
//     netController.text = net.toStringAsFixed(3);
//   }
//
//   Widget _erpRow(String t1, String v1, String t2, String v2) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//
//       child: Row(
//         children: [
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 3,
//
//                   child: Text(
//                     t1,
//
//                     style: const TextStyle(fontSize: 12, color: Colors.black),
//                   ),
//                 ),
//
//                 Expanded(
//                   flex: 4,
//
//                   child: Text(
//                     v1,
//
//                     style: const TextStyle(
//                       fontSize: 12,
//
//                       color: Colors.black,
//
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//
//                   child: Text(
//                     t2,
//
//                     style: const TextStyle(fontSize: 12, color: Colors.black),
//                   ),
//                 ),
//
//                 Expanded(
//                   flex: 3,
//
//                   child: Text(
//                     v2,
//
//                     overflow: TextOverflow.ellipsis,
//
//                     style: const TextStyle(
//                       fontSize: 12,
//
//                       color: Colors.black,
//
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
//   Widget statusChip(String status) {
//     Color startColor;
//     Color endColor;
//     String label;
//
//     switch (status.toLowerCase()) {
//       case "gold":
//         startColor = const Color(0xffC8A96A);
//
//         endColor = const Color(0xffE6C58A);
//
//         label = "Gold";
//         break;
//
//       case "silver":
//         startColor = const Color(0xffD9534F);
//
//         endColor = const Color(0xffF28B82);
//
//         label = "Silver";
//         break;
//
//       case "platinum":
//         startColor = const Color(0xffB07A3F);
//
//         endColor = const Color(0xffE0A96D);
//
//         label = "Platinum";
//         break;
//
//       case "other":
//         startColor = const Color(0xff7B5E57);
//
//         endColor = const Color(0xffBCAAA4);
//
//         label = "Other";
//         break;
//
//       default:
//         startColor = const Color(0xff9E9E9E);
//
//         endColor = const Color(0xffCFCFCF);
//
//         label = "Unknown";
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: [startColor, endColor]),
//
//         borderRadius: BorderRadius.circular(8),
//
//         border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
//       ),
//
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//
//         children: [
//           Container(
//             width: 6,
//             height: 6,
//
//             decoration: const BoxDecoration(
//               color: Colors.white,
//
//               shape: BoxShape.circle,
//             ),
//           ),
//
//           const SizedBox(width: 6),
//
//           Text(
//             label,
//
//             style: const TextStyle(
//               color: Colors.black,
//
//               fontWeight: FontWeight.w600,
//
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget premiumIconBtn(
//     IconData icon,
//     Color color, {
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//
//       borderRadius: BorderRadius.circular(10),
//
//       child: Container(
//         padding: const EdgeInsets.all(6),
//
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.12),
//
//           borderRadius: BorderRadius.circular(10),
//         ),
//
//         child: Icon(icon, color: color, size: 20),
//       ),
//     );
//   }
//
//   void _showDeleteDialog(Map user) {
//     showGeneralDialog(
//       context: context,
//
//       barrierLabel: "Delete",
//
//       barrierDismissible: true,
//
//       barrierColor: Colors.black.withOpacity(0.4),
//
//       transitionDuration: const Duration(milliseconds: 300),
//
//       pageBuilder: (context, anim1, anim2) {
//         final screenWidth = MediaQuery.of(context).size.width;
//
//         return BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//
//           child: Center(
//             child: Container(
//               width: screenWidth * 0.85,
//
//               padding: const EdgeInsets.all(22),
//
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(25),
//
//                 color: Colors.white.withOpacity(0.1),
//
//                 border: Border.all(color: Colors.white.withOpacity(0.2)),
//
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//
//                     blurRadius: 20,
//
//                     offset: const Offset(0, 10),
//                   ),
//                 ],
//               ),
//
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(14),
//
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//
//                       gradient: LinearGradient(
//                         colors: [Color(0xffff4e50), Color(0xfff00000)],
//                       ),
//                     ),
//
//                     child: const Icon(
//                       Icons.delete,
//
//                       size: 32,
//
//                       color: Colors.white,
//                     ),
//                   ),
//
//                   const SizedBox(height: 18),
//
//                   const Text(
//                     "Delete User?",
//
//                     style: TextStyle(
//                       fontSize: 20,
//
//                       fontWeight: FontWeight.bold,
//
//                       color: Colors.white,
//
//                       decoration: TextDecoration.none,
//                     ),
//                   ),
//
//                   const SizedBox(height: 10),
//
//                   Text(
//                     "Are you sure you want to delete ${user["name"]}?",
//
//                     textAlign: TextAlign.center,
//
//                     style: const TextStyle(
//                       fontSize: 14,
//
//                       color: Colors.white70,
//
//                       decoration: TextDecoration.none,
//                     ),
//                   ),
//
//                   const SizedBox(height: 25),
//
//                   Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.grey.shade800,
//
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//
//                           onPressed: () {
//                             Navigator.pop(context);
//                           },
//
//                           child: const Text(
//                             "Cancel",
//
//                             style: TextStyle(color: Colors.white),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(width: 12),
//
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xfff00000),
//
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//
//                           onPressed: () async {
//                             Navigator.pop(context);
//
//                             final id = user["cart_id"] ?? user["id"];
//
//                             if (id != null) {
//                               await deleteUser(id.toString());
//                             }
//                           },
//
//                           child: const Text(
//                             "Delete",
//
//                             style: TextStyle(
//                               color: Colors.white,
//
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
//
//       transitionBuilder: (context, anim, _, child) {
//         return FadeTransition(
//           opacity: anim,
//
//           child: ScaleTransition(
//             scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
//
//             child: child,
//           ),
//         );
//       },
//     );
//   }
//
//   Widget buildUserCard(Map item) {
//     final size = MediaQuery.of(context).size;
//
//     final bool isTablet = size.width >= 600;
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//
//       padding: EdgeInsets.all(isTablet ? 16 : 12),
//
//       decoration: BoxDecoration(
//         color: const Color(0xffFAF7F2).withOpacity(0.9),
//
//         borderRadius: BorderRadius.circular(15),
//
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//
//         children: [
//           Row(
//             children: [
//               statusChip(item["metal"]?.toString() ?? ""),
//
//               const Spacer(),
//
//               Row(
//                 children: [
//                   premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),
//
//                   SizedBox(width: isTablet ? 10 : 8),
//
//                   premiumIconBtn(
//                     Icons.delete,
//                     Colors.red,
//                     onTap: () {
//                       _showDeleteDialog(item);
//                     },
//                   ),
//                 ],
//               ),
//             ],
//           ),
//
//           SizedBox(height: isTablet ? 10 : 8),
//
//           Row(
//             children: [
//               Text(
//                 item["item_name"] ?? "",
//
//                 style: const TextStyle(
//                   fontSize: 15,
//
//                   color: Colors.black,
//
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//
//               const Spacer(),
//
//               Text(
//                 item["qr_code"] ?? "",
//
//                 style: const TextStyle(
//                   fontSize: 15,
//
//                   color: Colors.black,
//
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//
//             decoration: BoxDecoration(
//               color: Colors.white,
//
//               border: Border.all(color: Colors.grey.shade200, width: 1.5),
//
//               borderRadius: BorderRadius.circular(6),
//             ),
//
//             child: Column(
//               children: [
//                 _erpRow(
//                   "Gross",
//
//                   item["gross_weight"]?.toString() ?? "-",
//
//                   "Net",
//
//                   item["net_weight"] == "0.000" || item["net_weight"] == null
//                       ? "-"
//                       : item["net_weight"].toString(),
//                 ),
//
//                 Divider(height: 1, color: Colors.grey.shade200),
//
//                 _erpRow(
//                   "Purity",
//
//                   item["purity"]?.toString() ?? "-",
//
//                   "Amount",
//
//                   "₹ ${item["amount"] ?? 0}",
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _generateDeviceEntryId() {
//     final String base = deviceId ?? 'unknown-device';
//
//     return "$base-${DateTime.now().microsecondsSinceEpoch}";
//   }
// }
//
// /// ==================================================================
// /// SCANNER LINE
// /// ==================================================================
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
//
//   late Animation<double> animation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     controller = AnimationController(
//       vsync: this,
//
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
//
//       builder: (context, child) {
//         return Align(
//           alignment: Alignment(0, animation.value * 2 - 1),
//
//           child: Container(
//             width: double.infinity,
//
//             height: 3,
//
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [
//                   Colors.transparent,
//
//                   Colors.greenAccent,
//
//                   Colors.transparent,
//                 ],
//               ),
//
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.greenAccent.withOpacity(0.6),
//
//                   blurRadius: 10,
//
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
//
//     super.dispose();
//   }
// }


import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import '../Offline Data/offline_api_helper.dart';

class Createapprovalreturn extends StatefulWidget {
  const Createapprovalreturn({super.key});

  @override
  State<Createapprovalreturn> createState() => _CreateapprovalreturnState();
}

class _CreateapprovalreturnState extends State<Createapprovalreturn>
    with RouteAware {
  /// ============================================================
  /// CONTROLLERS
  /// ============================================================

  final TextEditingController searchController = TextEditingController();

  final TextEditingController remarksController = TextEditingController();

  final FocusNode searchFocusNode = FocusNode();

  final Map<String, TextEditingController> controllers = {};

  /// ============================================================
  /// TIMERS
  /// ============================================================

  Timer? _huidTimer;
  Timer? _calculationDebounce;

  /// ============================================================
  /// DATA
  /// ============================================================

  List userlist = [];

  String? selectedItem;

  List<Map<String, dynamic>> tableRows = [];

  int apiRowCount = 0;

  List customerlist = [];

  String? selectedUser;
  String? selectedCompanyId;
  String? selectedUserId;
  String? selectedUserName;

  DateTime? birthDate;
  DateTime? anniversaryDate;

  List cartItems = [];

  bool isLoading = false;

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];

  List searchResults = [];
  List combinedItems = [];

  List<Map<String, dynamic>> finalItems = [];

  Set<int> selectedItems = {};

  List approvalAddedItems = [];

  bool showScannerFull = false;

  bool isSearchEnabled = false;

  /// ============================================================
  /// SCANNER
  /// ============================================================

  bool isProcessing = false;
  bool isBusy = false;

  String? lastCode;

  /// ============================================================
  /// CALCULATION
  /// ============================================================

  bool _isCalculating = false;

  /// ============================================================
  /// INIT
  /// ============================================================
  /// Device ma ek j vaar generate thay, SharedPreferences ma save rahe
  String? deviceId;

  /// Aa screen khule tyare j ek vaar generate thay (session unique)
  String? voucherSessionId;
  @override
  void initState() {
    super.initState();
    voucherSessionId = 'APP-${DateTime.now().millisecondsSinceEpoch}';
    Future.microtask(() {
      if (!mounted) return;

      Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();

    Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
  }

  /// ============================================================
  /// DISPOSE
  /// ============================================================

  @override
  void dispose() {
    _huidTimer?.cancel();
    _calculationDebounce?.cancel();

    searchController.dispose();
    remarksController.dispose();
    searchFocusNode.dispose();

    for (final controller in controllers.values) {
      controller.dispose();
    }

    controllers.clear();

    super.dispose();
  }

  /// ============================================================
  /// BUILD
  /// ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final width = size.width;

    final bool isMobile = width < 600;

    /// ==========================================================
    /// DISPLAY ITEMS
    /// ==========================================================

    final List<dynamic> combinedItemsList = [
      ...items,

      ...approvalAddedItems,

      ...cartItems.map(
            (e) => {
          ...Map<String, dynamic>.from(e),

          "id": e["id"],

          "name": e["item_name"] ?? e["item"]?["item_name"] ?? e["name"] ?? "",

          "code": e["qr_code"] ?? e["huid"] ?? e["code"] ?? "",

          "gross_weight": e["gross_weight"] ?? "0",

          "other_weight": e["other_weight"] ?? "0",

          "net_weight": e["net_weight"] ?? "0",

          "purity": e["purity"] ?? "0",

          "waste": e["waste"] ?? "0",

          "net_purity": e["net_purity"] ?? "0",

          "fine_weight": e["fine_weight"] ?? "0",

          "metal_rate": e["metal_rate"] ?? "0",

          "metal_amount": e["metal_amount"] ?? "0",

          "labour_rate": e["labour_rate"] ?? "0",

          "labour_amount": e["labour_amount"] ?? "0",

          "other_amount": e["other_amount"] ?? "0",

          "total_amount": e["total_amount"] ?? e["amount"] ?? "0",

          "source": "sale",

          "itemset_id": e["itemset_id"],
        },
      ),
    ];

    /// ==========================================================
    /// REMOVE DUPLICATE
    /// ==========================================================

    final displayMap = <String, dynamic>{};

    for (final rawItem in combinedItemsList) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

      final key =
          item["approval_item_id"] ??
              item["itemset_id"] ??
              item["id"] ??
              item["code"] ??
              identityHashCode(item);

      displayMap[key.toString()] = item;
    }

    final List<Map<String, dynamic>> displayItems = displayMap.values
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList()
        .reversed
        .toList();

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
            /// ===================================================
            /// MAIN CONTENT
            /// ===================================================
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 30),

                Expanded(
                  child: showScannerFull
                      ? _buildScannerMode(displayItems)
                      : _buildNormalMode(displayItems),
                ),

                /// =================================================
                /// SUMMARY
                /// =================================================
                buildSummaryRow(),

                /// =================================================
                /// SAVE BUTTON
                /// =================================================
                InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();

                    savefinalizeBulkItems();
                  },

                  borderRadius: BorderRadius.circular(10),

                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),

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
                          "Save Approval Return",

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
              ],
            ),

            /// ===================================================
            /// APPBAR
            /// ===================================================
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
                      "Create Approval Return",

                      style: TextStyle(
                        color: Colors.black,

                        fontSize: 16,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerLeft,

                      child: InkWell(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();

                          Navigator.pop(context,true);
                        },

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
      ),
    );
  }

  /// ============================================================
  /// NORMAL MODE
  /// ============================================================

  Widget _buildNormalMode(List<Map<String, dynamic>> displayItems) {
    return Column(
      children: [
        const SizedBox(height: 10),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),

            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

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

                displayItems.isEmpty
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
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),

                  shrinkWrap: true,

                  physics: const NeverScrollableScrollPhysics(),

                  itemCount: displayItems.length,

                  itemBuilder: (context, index) {
                    return approvalItemCard(
                      displayItems[index],
                      index,
                      displayItems.length,
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// SCANNER MODE
  /// ============================================================

  Widget _buildScannerMode(List<Map<String, dynamic>> displayItems) {
    return Column(
      children: [
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),

            border: Border.all(color: Colors.grey.shade300),
          ),

          child: Consumer<ItemProvider>(
            builder: (context, provider, child) {
              final customers = provider.customers;

              return DropdownButtonFormField<String>(
                value:
                selectedItem != null &&
                    customers.any((e) => e["id"].toString() == selectedItem)
                    ? selectedItem
                    : null,

                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.black,
                ),

                dropdownColor: Colors.white,

                hint: Text(
                  "Select Customer",

                  style: TextStyle(color: Colors.grey.shade600),
                ),

                style: const TextStyle(color: Colors.black, fontSize: 14),

                decoration: InputDecoration(
                  filled: true,

                  fillColor: Colors.white,

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),

                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),

                    borderRadius: BorderRadius.circular(5),
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),

                    borderRadius: BorderRadius.circular(5),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),

                    borderRadius: BorderRadius.circular(5),
                  ),
                ),

                items: customers.map<DropdownMenuItem<String>>((item) {
                  return DropdownMenuItem<String>(
                    value: item["id"].toString(),

                    child: Text(
                      item["name"] ?? "",

                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }).toList(),

                onChanged: (value) async {
                  if (value == selectedItem) return;

                  final selectedData = customers.firstWhere(
                        (user) => user["id"].toString() == value,
                    orElse: () => {},
                  );

                  _resetCustomerData(
                    customer: selectedData.isEmpty
                        ? null
                        : Map<String, dynamic>.from(selectedData),
                  );

                  if (value != null) {
                    await getCartItems();
                  }
                },
              );
            },
          ),
        ),

        const SizedBox(height: 10),

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
                      color: Colors.greenAccent.withOpacity(0.4),

                      blurRadius: 20,
                    ),
                  ],
                ),

                child: Stack(
                  children: [
                    _buildScannerSection(),

                    const _ScannerLineAnimation(),
                  ],
                ),
              ),

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

                      border: Border.all(color: Colors.white, width: 1.5),
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

        Expanded(
          child: displayItems.isEmpty
              ? const Center(child: Text("No Data Added"))
              : ListView.builder(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,

            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),

            itemCount: displayItems.length,

            itemBuilder: (context, index) {
              return approvalItemCard(
                displayItems[index],
                index,
                displayItems.length,
              );
            },
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// FILTER WIDGET
  /// ============================================================

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),

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
          /// =====================================================
          /// CUSTOMER
          /// =====================================================
          Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final List<Map<String, dynamic>> customers = provider.customers
                    .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                    .toList();

                Map<String, dynamic>? selectedCustomer;

                if (selectedItem != null) {
                  try {
                    selectedCustomer = customers.firstWhere(
                          (e) => e["id"]?.toString() == selectedItem.toString(),
                    );
                  } catch (_) {
                    selectedCustomer = null;
                  }
                }

                return Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    PremiumSearchableDropdown<Map<String, dynamic>>(
                      label: "",
                      hint: "Select Customer",
                      items: customers,
                      value: selectedCustomer,
                      prefixIcon: Icons.person_outline_rounded,
                      dropdownMaxHeight: 350,
                      itemLabel: (customer) => customer["name"]?.toString() ?? "",
                      searchText: (customer) {
                        final name = customer["name"]?.toString() ?? "";
                        final mobile = customer["mobile"]?.toString() ??
                            customer["mobile_no"]?.toString() ??
                            customer["phone"]?.toString() ??
                            "";
                        final code = customer["code"]?.toString() ??
                            customer["customer_code"]?.toString() ??
                            "";
                        return "$name $mobile $code";
                      },
                      onChanged: (customer) async {
                        _resetCustomerData(customer: customer);

                        if (customer == null) return;

                        debugPrint("Selected Customer: ${customer["name"]}");
                        debugPrint("Selected User ID: $selectedUserId");

                        await getCartItems();
                      },
                    ),

                    /// ❌ CLEAR — dropdown ની અંદર, arrow ની ડાબી બાજુ
                    if (selectedCustomer != null)
                      Positioned(
                        right: 40, // 🔥 arrow icon થી અંતર — જરૂર મુજબ 32–48 કરો
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _resetCustomerData(customer: null);
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
                                size: 13, // 🔥 20 ના circle માં 16 મોટું પડતું હતું
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

          const SizedBox(height: 10),

          /// =====================================================
          /// REMARKS
          /// =====================================================
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: remarksController,

                  style: const TextStyle(
                    color: Colors.black,

                    fontSize: 14,

                    fontWeight: FontWeight.w500,
                  ),

                  decoration: InputDecoration(
                    hintText: "Enter Remarks",

                    hintStyle: TextStyle(color: Colors.grey.shade600),

                    filled: true,

                    fillColor: Colors.white,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
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

                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// =====================================================
          /// BUTTONS
          /// =====================================================
          Row(
            children: [
              Expanded(
                flex: 1,

                child: InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();

                    setState(() {
                      showScannerFull = true;
                    });
                  },

                  borderRadius: BorderRadius.circular(8),

                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),

                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(0.7),

                          AppColors.border.withOpacity(0.7),

                          AppColors.secondaryDark.withOpacity(0.7),
                        ],
                      ),

                      borderRadius: BorderRadius.circular(5),
                    ),

                    child: const Center(
                      child: Icon(
                        Icons.qr_code_scanner,

                        color: Colors.white,

                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 3,

                child: InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();

                    if (selectedItem == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select customer first"),

                          backgroundColor: Colors.red,
                        ),
                      );

                      return;
                    }

                    getApprovalDetails(int.parse(selectedItem.toString()));
                  },

                  borderRadius: BorderRadius.circular(8),

                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(color: Colors.grey.shade300),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),

                          blurRadius: 6,

                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),

                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(Icons.add, size: 18, color: Colors.black),

                        SizedBox(width: 6),

                        Text(
                          "Add Label Return Approval",

                          style: TextStyle(
                            fontWeight: FontWeight.w600,

                            color: Colors.black,
                          ),
                        ),
                      ],
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
  /// SEARCH ITEMS
  /// ============================================================

  Future<void> searchItemsApi(String keyword) async {
    if (keyword.isEmpty) {
      if (!mounted) return;

      setState(() {
        searchResults = [];
      });

      return;
    }

    if (selectedItem == null) {
      return;
    }

    final body = {"customer_id": int.parse(selectedItem!), "keyword": keyword};

    final response = await ApiHelper().postRequest(
      ApiConstants.returns_search,
      body,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final List allResults = response.data["data"] ?? [];

      final filtered = allResults.where((item) {
        final itemsetId = item["itemset_id"];

        final saleItemId = item["sale_item_id"];

        final approvalItemId = item["approval_item_id"];

        final bool alreadyAdded =
            items.any((e) => e["itemset_id"] == itemsetId) ||
                approvalAddedItems.any(
                      (e) =>
                  e["itemset_id"] == itemsetId ||
                      e["approval_item_id"] == approvalItemId,
                ) ||
                cartItems.any(
                      (e) =>
                  e["itemset_id"] == itemsetId ||
                      e["sale_item_id"] == saleItemId,
                );

        return !alreadyAdded;
      }).toList();

      setState(() {
        searchResults = filtered;
      });
    }
  }

  /// ============================================================
  /// ADD MANUAL ITEM
  /// ============================================================

  void addItemToCard(dynamic e) {
    final itemsetId = e["itemset_id"] ?? e["id"];

    final bool isDuplicate =
        items.any((item) => (item["itemset_id"] ?? item["id"]) == itemsetId) ||
            approvalAddedItems.any((item) => item["itemset_id"] == itemsetId) ||
            cartItems.any(
                  (item) => item["itemset_id"] == itemsetId || item["id"] == itemsetId,
            );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item already added to the list"),

          backgroundColor: Colors.orange,
        ),
      );

      searchController.clear();

      setState(() {
        searchResults.clear();
      });

      return;
    }

    final Map<String, dynamic> newItem = {
      "id": e["itemset_id"] ?? e["id"],

      "itemset_id": e["itemset_id"] ?? e["id"],

      "item_name": e["item"]?["item_name"] ?? e["item_name"] ?? e["name"] ?? "",

      "name": e["item"]?["item_name"] ?? e["item_name"] ?? e["name"] ?? "",

      "huid": e["HUID"] ?? e["huid"] ?? "",

      "qr_code": e["qr_code"] ?? "",

      "code": e["qr_code"] ?? e["code"] ?? "",

      "gross_weight": e["gross_weight"]?.toString() ?? "0",

      "other_weight": e["other_weight"]?.toString() ?? "0",

      "net_weight": e["net_weight"]?.toString() ?? "0",

      "purity": e["purity"]?.toString() ?? "0",

      "waste": e["waste_percent"]?.toString() ?? e["waste"]?.toString() ?? "0",

      "net_purity": e["net_purity"]?.toString() ?? "0",

      "fine_weight": e["fine_weight"]?.toString() ?? "0",

      "metal_rate": e["metal_rate"]?.toString() ?? "0",

      "metal_amount": e["metal_amount"]?.toString() ?? "0",

      "labour_rate": e["labour_rate"]?.toString() ?? "0",

      "labour_amount": e["labour_amount"]?.toString() ?? "0",

      "other_amount": e["other_amount"]?.toString() ?? "0",

      "total_amount": e["total_amount"]?.toString() ?? "0",

      "source": e["source"] ?? "manual",

      "expanded": false,

      "manual_metal": true,
      "manual_labour": true,
    };

    /// Controller create before UI
    _initializeItemControllers(newItem);

    calculateItem(newItem);

    items.add(newItem);

    searchController.clear();
    searchResults.clear();

    updateFinalItems();
  }

  /// ============================================================
  /// APPROVAL DETAILS
  /// ============================================================

  Future<void> getApprovalDetails(int? customerId) async {
    if (customerId == null) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(
      "${ApiConstants.returns_approval_items}?customer_id=$customerId",
    );

    if (!mounted) return;

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final List approvalItems = data["data"] ?? [];

      if (approvalItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data Not Found"),

            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final Set<int> addedIds = cartItems
          .map<int>(
            (e) => int.tryParse(e["approval_item_id"]?.toString() ?? "") ?? 0,
      )
          .where((id) => id != 0)
          .toSet();

      final List filteredItems = approvalItems.where((item) {
        final int id = int.tryParse(item["approval_item_id"].toString()) ?? 0;

        return !addedIds.contains(id);
      }).toList();

      if (filteredItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All approval items already added")),
        );

        return;
      }

      final addedCartData = await showApprovalDialog(filteredItems);

      if (addedCartData != null && addedCartData.isNotEmpty) {
        _claimNextCartFetch = true; // 🔥 navi item aa customer ni
        await getCartItems();
      }
    }
  }

  /// ============================================================
  /// ADD APPROVAL ITEMS
  /// ============================================================

  void addSelectedItems(List addedCartData, List allItems) {
    for (final rawCartEntry in addedCartData) {
      final Map<String, dynamic> cartEntry = Map<String, dynamic>.from(
        rawCartEntry,
      );

      final int? approvalId = int.tryParse(
        cartEntry["approval_item_id"]?.toString() ?? "",
      );

      if (approvalId == null) continue;

      final bool exists = approvalAddedItems.any(
            (e) => e["approval_item_id"]?.toString() == approvalId.toString(),
      );

      if (exists) continue;

      /// 🔥 Full item data (name, weights etc.) original approval
      /// list mathi lai levu — cart response ma badha fields na hoy
      Map<String, dynamic> item;

      try {
        item = Map<String, dynamic>.from(
          allItems.firstWhere(
                (e) =>
            int.tryParse(e["approval_item_id"].toString()) == approvalId,
          ),
        );
      } catch (_) {
        item = Map<String, dynamic>.from(cartEntry);
      }

      /// 🔥 IMPORTANT: cart_id store karo — delete API (same as
      /// Scan/sale items) mate aa j id joie chhe.
      item["cart_id"] = cartEntry["cart_id"] ?? item["cart_id"];

      item["source"] = "approval";

      item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";

      item["other_weight"] = item["other_weight"]?.toString() ?? "0";

      item["purity"] = item["purity"]?.toString() ?? "0";

      item["waste"] =
          item["waste"]?.toString() ?? item["waste_percent"]?.toString() ?? "0";

      item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";

      item["labour_rate"] = item["labour_rate"]?.toString() ?? "0";

      item["other_amount"] = item["other_amount"]?.toString() ?? "0";

      item["manual_metal"] = item["manual_metal"] ?? true;

      item["manual_labour"] = item["manual_labour"] ?? true;

      _initializeItemControllers(item);

      calculateItem(item);

      approvalAddedItems.add(item);
    }

    updateFinalItems();
  }

  /// ============================================================
  /// APPROVAL DIALOG (BOTTOM SHEET)
  /// ============================================================

  Future<List<dynamic>?> showApprovalDialog(List approvalItems) async {
    selectedItems.clear();

    List filteredItems = List.from(approvalItems);

    bool showScanner = false;

    /// 🔥 Jena API e "already locked by another user" kahyu hoy
    /// evi item ids — list ma alag background thi highlight thashe
    final Set<int> lockedItemIds = {};

    final TextEditingController approveSearchController =
    TextEditingController();

    final result = await showModalBottomSheet<List<dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double screenHeight = MediaQuery.of(context).size.height;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: screenHeight * 0.88,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    /// ================================================
                    /// DRAG HANDLE
                    /// ================================================
                    Container(
                      margin: const EdgeInsets.only(top: 0, bottom: 0),
                      width: 42,
                      height: 0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.gradientBlue,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                    ),

                    /// ================================================
                    /// PREMIUM HEADER
                    /// ================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.gradientBlue,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
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
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.assignment_return_outlined,
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
                                  "Approval Items Return",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Select items to return",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// SCANNER TOGGLE
                          InkWell(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();

                              setDialogState(() {
                                showScanner = !showScanner;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),

                          const SizedBox(width: 7),

                          /// CLOSE
                          InkWell(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();

                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ================================================
                    /// BODY (scrollable content)
                    /// ================================================
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// SEARCH
                            TextField(
                              controller: approveSearchController,

                              style: const TextStyle(color: Colors.black),

                              onChanged: (value) {
                                final search = value.trim().toLowerCase();

                                setDialogState(() {
                                  if (search.isEmpty) {
                                    filteredItems = List.from(approvalItems);
                                  } else {
                                    filteredItems = approvalItems.where((
                                        item,
                                        ) {
                                      final name =
                                          item["name"]
                                              ?.toString()
                                              .toLowerCase() ??
                                              "";

                                      final code =
                                          item["qr_code"]
                                              ?.toString()
                                              .toLowerCase() ??
                                              "";

                                      final huid =
                                          item["HUID"]
                                              ?.toString()
                                              .toLowerCase() ??
                                              item["huid"]
                                                  ?.toString()
                                                  .toLowerCase() ??
                                              "";

                                      return name.contains(search) ||
                                          code.contains(search) ||
                                          huid.contains(search);
                                    }).toList();
                                  }
                                });
                              },

                              decoration: InputDecoration(
                                hintText: "Search Item",

                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                ),

                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.black54,
                                ),

                                filled: true,

                                fillColor: Colors.white,

                                contentPadding: const EdgeInsets.symmetric(
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
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryDark,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            /// SCANNER
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
                                  margin: const EdgeInsets.only(
                                    bottom: 12,
                                    top: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    children: [
                                      _buildScannerSection(),
                                      const _ScannerLineAnimation(),
                                    ],
                                  ),
                                ),
                              )
                                  : const SizedBox(key: ValueKey("empty")),
                            ),

                            /// ITEM COUNT + SELECTED COUNT
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                                bottom: 8,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "${filteredItems.length} Items",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primaryDark
                                            .withOpacity(0.15),
                                      ),
                                    ),
                                    child: Text(
                                      "${selectedItems.length} Selected",
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// LIST
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),

                              itemCount: filteredItems.length,

                              itemBuilder: (context, index) {
                                final item = filteredItems[index];

                                final int id =
                                    int.tryParse(
                                      item["approval_item_id"].toString(),
                                    ) ??
                                        0;

                                final code = item["qr_code"] ?? "-";

                                final name = item["name"] ?? "-";

                                final gross =
                                    item["gross_weight"]?.toString() ?? "-";

                                final bool isSelected = selectedItems
                                    .contains(id);

                                final bool isLocked = lockedItemIds.contains(
                                  id,
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),

                                  padding: const EdgeInsets.all(10),

                                  decoration: BoxDecoration(
                                    /// 🔥 Locked item — alag background
                                    /// jethi user samje ke aa item
                                    /// unselect karvanu che
                                    color: isLocked
                                        ? Colors.red.shade50
                                        : (isSelected
                                        ? AppColors.primaryDark
                                        .withOpacity(0.035)
                                        : Colors.white),

                                    borderRadius: BorderRadius.circular(9),

                                    border: Border.all(
                                      color: isLocked
                                          ? Colors.red.shade300
                                          : (isSelected
                                          ? AppColors.primaryDark
                                          .withOpacity(0.35)
                                          : Colors.grey.shade300),
                                      width: (isLocked || isSelected)
                                          ? 1.4
                                          : 1,
                                    ),

                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          0.025,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),

                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: isSelected,

                                        activeColor: AppColors.primaryDark,
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(5),
                                        ),

                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (value == true) {
                                              selectedItems.add(id);
                                            } else {
                                              selectedItems.remove(id);

                                              /// User pote unselect
                                              /// karyu, etle locked
                                              /// flag hatavi do
                                              lockedItemIds.remove(id);
                                            }
                                          });
                                        },
                                      ),

                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,

                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                        FontWeight.w700,
                                                        color: Colors.black,
                                                      ),

                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 6),

                                                  Container(
                                                    padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .primaryDark
                                                          .withOpacity(0.08),
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        5,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                      MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.qr_code_2,
                                                          size: 11,
                                                          color: AppColors
                                                              .primaryDark,
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          code,
                                                          style: const TextStyle(
                                                            color: AppColors
                                                                .primaryDark,
                                                            fontSize: 10,
                                                            fontWeight:
                                                            FontWeight
                                                                .w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 4),

                                              Text(
                                                "Gross: $gross",

                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),

                                              if (isLocked) ...[
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.lock_outline,
                                                      size: 13,
                                                      color:
                                                      Colors.red.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        "Already selected by another user. Please unselect.",
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                          FontWeight.w600,
                                                          color: Colors
                                                              .red
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    /// ================================================
                    /// BOTTOM ACTION BAR
                    /// ================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () async {
                              FocusManager.instance.primaryFocus?.unfocus();

                              if (selectedItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please select at least one item",
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              /// 🔥 device_id fetch/cache
                              if (deviceId == null ||
                                  deviceId!.trim().isEmpty) {
                                try {
                                  final DeviceInfoPlugin deviceInfo =
                                  DeviceInfoPlugin();

                                  if (Platform.isAndroid) {
                                    final AndroidDeviceInfo androidInfo =
                                    await deviceInfo.androidInfo;
                                    deviceId = androidInfo.id;
                                  } else if (Platform.isIOS) {
                                    final IosDeviceInfo iosInfo =
                                    await deviceInfo.iosInfo;
                                    deviceId =
                                        iosInfo.identifierForVendor ?? "";
                                  }
                                } catch (e) {
                                  debugPrint("DeviceInfo Error: $e");
                                }
                              }

                              /// 🔥 voucher_session_id — ek j session mate
                              /// same rahe
                              voucherSessionId ??=
                              'RET-${DateTime.now().millisecondsSinceEpoch}';

                              /// 🔥 SELECTED ITEMS ARRAY BANAO
                              final List<Map<String, dynamic>> itemsArray =
                              selectedItems.map((id) {
                                return {
                                  "approval_item_id": id,
                                  "device_entry_id":
                                  "${deviceId ?? 'unknown-device'}-${voucherSessionId}-${id}-${DateTime.now().microsecondsSinceEpoch}",
                                };
                              }).toList();

                              final Map<String, dynamic> body = {
                                "customer_id": selectedUserId != null
                                    ? int.tryParse(selectedUserId!)
                                    : null,
                                "device_id": deviceId,
                                "voucher_session_id": voucherSessionId,
                                "items": itemsArray,
                              };

                              debugPrint(
                                "📤 APPROVAL CART ADD BODY => $body",
                              );

                              final response = await ApiHelper().postRequest(
                                ApiConstants.approval_cart_add,
                                body,
                              );

                              if (!context.mounted) return;

                              if (response != null &&
                                  response.statusCode == 200 &&
                                  response.data["success"] == true) {
                                /// 🔥 IMPORTANT: server thi cart_id sahit
                                /// added items ni list "items" key ma
                                /// male chhe. Delete vakhte SACHO
                                /// cart_id joie chhe, etle aa list j
                                /// return karvi.
                                final dynamic successData = response.data;

                                final List addedCartItems =
                                (successData is Map &&
                                    successData["items"] is List)
                                    ? successData["items"]
                                    : selectedItems
                                    .map(
                                      (id) => {
                                    "approval_item_id": id,
                                  },
                                )
                                    .toList();

                                Navigator.pop(context, addedCartItems);
                              } else {
                                final dynamic responseData = response?.data;

                                final String code = responseData is Map
                                    ? responseData["code"]?.toString() ?? ""
                                    : "";

                                final String message = responseData is Map
                                    ? responseData["message"]?.toString() ??
                                    "Failed to add items"
                                    : "Failed to add items";

                                /// 🔥 RETURN_CART_ITEM_LOCKED — specific
                                /// item ne locked mark karo, jethi list
                                /// ma highlight thay
                                if (code == "RETURN_CART_ITEM_LOCKED") {
                                  final dynamic lockedApprovalItemId =
                                  responseData is Map
                                      ? responseData["approval_item_id"]
                                      : null;

                                  final int? lockedId = int.tryParse(
                                    lockedApprovalItemId?.toString() ?? "",
                                  );

                                  if (lockedId != null) {
                                    setDialogState(() {
                                      lockedItemIds.add(lockedId);

                                      /// User ne clear samjay etle aa
                                      /// item automatically unselect
                                      /// kari do
                                      selectedItems.remove(lockedId);
                                    });
                                  }
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.gradientBlue,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withOpacity(
                                      0.22,
                                    ),
                                    blurRadius: 8,
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
                                    size: 18,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    "Add Selected Items",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
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
                    SizedBox(height: 10,)
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    approveSearchController.dispose();

    return result;
  }

  /// ============================================================
  /// APPROVAL ITEM CARD
  /// ============================================================

  Widget approvalItemCard(
      Map<String, dynamic> item,
      int index,
      int totalCount,
      ) {
    final bool isExpanded = item["expanded"] ?? false;

    final String itemName =
        item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";

    final String qrCode =
        item["qr_code"]?.toString() ??
            item["itemset"]?["qr_code"]?.toString() ??
            item["code"]?.toString() ??
            item["itemset"]?["barcode"]?.toString() ??
            "-";

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
          /// =====================================================
          /// HEADER
          /// =====================================================
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
                    "${totalCount - index}",

                    style: const TextStyle(
                      color: Colors.white,

                      fontSize: 11,

                      fontWeight: FontWeight.bold,
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
                  constraints: const BoxConstraints(maxWidth: 125),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
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
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    await _removeItem(item);
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

          /// =====================================================
          /// FIELDS
          /// =====================================================
          if (!isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),

              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,

                physics: const BouncingScrollPhysics(),

                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [
                    _miniField("Gross", item, "gross_weight"),

                    _miniField("Other", item, "other_weight"),

                    _miniField("Net", item, "net_weight"),

                    _miniField("Purity", item, "purity"),

                    _miniField("Waste", item, "waste"),

                    _miniField("Net Purity", item, "net_purity"),

                    _miniField("Fine", item, "fine_weight"),

                    _miniField("Metal Rate", item, "metal_rate"),

                    _miniField("Metal Amount", item, "metal_amount"),

                    _miniField("Labour Rate", item, "labour_rate"),

                    _miniField("Labour Amount", item, "labour_amount"),

                    _miniField("Other Amount", item, "other_amount"),

                    _miniField("Total Amount", item, "total_amount"),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ============================================================
  /// REMOVE ITEM
  /// ============================================================

  Future<void> _removeItem(Map<String, dynamic> item) async {
    final approvalId = item["approval_item_id"];

    final itemsetId = item["itemset_id"];

    final itemId = item["id"];

    final cartId = item["cart_id"];

    final String source = item["source"]?.toString() ?? "";

    final String itemName =
        item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";

    final String itemCode =
    item["qr_code"]?.toString().trim().isNotEmpty == true
        ? item["qr_code"].toString()
        : (item["code"]?.toString().trim().isNotEmpty == true
        ? item["code"].toString()
        : (item["huid"]?.toString().trim().isNotEmpty == true
        ? item["huid"].toString()
        : ""));

    final String itemLabel =
    itemCode.isNotEmpty ? "$itemName ($itemCode)" : itemName;

    /// 🔥 IMPORTANT: "Scan" (QR scan), "sale" ane "approval" — trane
    /// j server side "cart" (returns_cart) ma row banave che, etle
    /// delete karta trane j mate SAME API (returns_cart_remove)
    /// vaparvi che.
    if (source == "Scan" || source == "sale" || source == "approval") {
      final String? deleteId = (cartId ?? itemId)?.toString();

      if (deleteId == null || deleteId.isEmpty || deleteId == "null") {
        debugPrint("⚠️ CART DELETE SKIPPED — no cart_id/id found on item");

        if (mounted) {
          AppMessage.error(
            context,
            "Could not delete $itemLabel — missing server id",
          );
        }

        return;
      }

      /// 🔥 IMPORTANT: API call complete thay tyaan sudhi wait karo,
      /// pachi j success/fail nakki karo. Aa rite server par delete
      /// fail thay to local list ma item unnecessarily disappear
      /// nahi thashe, ane stale state (refresh issue) na thashe.
      final bool success = await deleteUser(deleteId);

      if (!success) {
        /// Delete fail thayu — item list ma j rahi jashe, error
        /// message deleteUser() ma already dekhadi didhu che.
        return;
      }

      /// ✅ Delete success — have local list mathi remove karo
      if (source == "approval") {
        approvalAddedItems.removeWhere(
              (e) => e["approval_item_id"]?.toString() == approvalId.toString(),
        );
      } else {
        /// Scan/sale items — deleteUser() andar getCartItems() thi
        /// pehla j fresh list mai gayu che, pan safety mate manually
        /// pan remove kari daiye (jo koi race condition hoy)
        cartItems.removeWhere(
              (e) =>
          (e["itemset_id"] ?? e["id"])?.toString() ==
              (itemsetId ?? itemId)?.toString(),
        );
      }

      if (mounted) {
        AppMessage.success(context, "$itemLabel removed");
      }
    } else {
      /// ✅ MANUAL SEARCH SE ADDED ITEM — server par koi cart record
      /// nathi, khali local list mathi j remove karvanu
      items.removeWhere(
            (e) =>
        (e["itemset_id"] ?? e["id"])?.toString() ==
            (itemsetId ?? itemId)?.toString(),
      );

      if (mounted) {
        AppMessage.success(context, "$itemLabel removed");
      }
    }

    _disposeItemControllers(item);

    updateFinalItems();
  }


  /// ============================================================
  /// MINI FIELD
  /// ============================================================

  Widget _miniField(String title, Map<String, dynamic> item, String key) {
    final bool isOtherField = key == "other_amount";

    final bool isMetalRateField = key == "metal_rate";

    final bool isLabourRateField = key == "labour_rate";

    final controller = getController(item, key);

    final bool editable = key == "metal_rate"
        ? (item["manual_metal"] ?? true)
        : key == "labour_rate"
        ? (item["manual_labour"] ?? true)
        : isEditableField(key);

    return Container(
      width: 105,

      margin: const EdgeInsets.only(right: 7),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),

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
              color: editable ? Colors.white : Colors.grey.shade50,

              borderRadius: BorderRadius.circular(5),

              border: Border.all(color: AppColors.border),
            ),

            child: Stack(
              alignment: Alignment.centerRight,

              children: [
                TextFormField(
                  controller: controller,

                  /// 🔒 ALL FIELDS READ ONLY
                  readOnly: true,

                  /// 🔥 Keyboard / Focus completely disable
                  canRequestFocus: false,
                  showCursor: false,
                  enableInteractiveSelection: false,

                  textAlign: TextAlign.left,

                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),

                  decoration: InputDecoration(
                    isDense: true,

                    contentPadding: EdgeInsets.only(
                      left: 8,
                      right:
                      (isOtherField ||
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

                /// OTHER AMOUNT
                if (isOtherField)
                  Positioned(
                    right: 4,

                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();

                        await getreturnDetails(
                          item["id"],
                          item,
                        );

                        if (!mounted) {
                          return;
                        }

                        controller.text =
                            item["other_amount"]?.toString() ?? "0";

                        calculateItem(item);

                        updateFinalItems();
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

                /// METAL CHECKBOX
                if (isMetalRateField)
                  Positioned(
                    right: 2,

                    child: SizedBox(
                      width: 27,
                      height: 27,

                      child: Transform.scale(
                        scale: 0.78,

                        child: Checkbox(
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,

                          value:
                          (double.tryParse(
                            controller.text.isEmpty
                                ? "0"
                                : controller.text,
                          ) ??
                              0) >
                              0,
                          onChanged: null,
                        ),
                      ),
                    ),
                  ),

                /// LABOUR CHECKBOX
                if (isLabourRateField)
                  Positioned(
                    right: 2,

                    child: SizedBox(
                      width: 27,
                      height: 27,

                      child: Transform.scale(
                        scale: 0.78,

                        child: Checkbox(
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,

                          value:
                          (double.tryParse(
                            controller.text.isEmpty
                                ? "0"
                                : controller.text,
                          ) ??
                              0) >
                              0,
                          onChanged: null,
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

  /// ============================================================
  /// CONTROLLER UNIQUE ID
  /// ============================================================

  String _itemUniqueId(Map item) {
    return (item["approval_item_id"] ??
        item["itemset_id"] ??
        item["id"] ??
        item["qr_code"] ??
        item["code"] ??
        identityHashCode(item))
        .toString();
  }

  /// ============================================================
  /// GET CONTROLLER
  /// ============================================================

  TextEditingController getController(Map item, String key) {
    final uniqueKey = "${_itemUniqueId(item)}_$key";

    if (!controllers.containsKey(uniqueKey)) {
      controllers[uniqueKey] = TextEditingController(
        text: item[key]?.toString() ?? "",
      );
    }

    return controllers[uniqueKey]!;
  }

  /// ============================================================
  /// SET CONTROLLER
  /// ============================================================

  void setController(Map<String, dynamic> item, String key, dynamic value) {
    final controller = getController(item, key);

    final String newValue = value?.toString() ?? "";

    if (controller.text == newValue) {
      return;
    }

    controller.value = TextEditingValue(
      text: newValue,

      selection: TextSelection.collapsed(offset: newValue.length),
    );
  }

  /// ============================================================
  /// UPDATE CONTROLLER
  /// ============================================================

  void updateController(Map item, String key) {
    final uniqueKey = "${_itemUniqueId(item)}_$key";

    final controller = controllers[uniqueKey];

    if (controller == null) {
      return;
    }

    final String newValue = item[key]?.toString() ?? "";

    if (controller.text == newValue) {
      return;
    }

    controller.value = TextEditingValue(
      text: newValue,

      selection: TextSelection.collapsed(offset: newValue.length),
    );
  }

  /// ============================================================
  /// INITIALIZE ITEM CONTROLLERS
  /// ============================================================

  void _initializeItemControllers(Map<String, dynamic> item) {
    const fields = [
      "gross_weight",
      "other_weight",
      "net_weight",
      "purity",
      "waste",
      "net_purity",
      "fine_weight",
      "metal_rate",
      "metal_amount",
      "labour_rate",
      "labour_amount",
      "other_amount",
      "total_amount",
    ];

    for (final key in fields) {
      getController(item, key);
    }
  }

  /// ============================================================
  /// DISPOSE SINGLE ITEM CONTROLLERS
  /// ============================================================

  void _disposeItemControllers(Map item) {
    final id = _itemUniqueId(item);

    final keys = controllers.keys
        .where((key) => key.startsWith("${id}_"))
        .toList();

    for (final key in keys) {
      controllers[key]?.dispose();

      controllers.remove(key);
    }
  }

  /// ============================================================
  /// GET VALUE
  /// ============================================================

  double getValue(Map item, String key) {
    final uniqueKey = "${_itemUniqueId(item)}_$key";

    final controller = controllers[uniqueKey];

    if (controller != null) {
      return double.tryParse(controller.text.trim()) ?? 0;
    }

    return double.tryParse(item[key]?.toString() ?? "0") ?? 0;
  }

  /// ============================================================
  /// EDITABLE
  /// ============================================================

  bool isEditableField(String key) {
    return [
      "gross_weight",
      "other_weight",
      "purity",
      "waste",
      "labour_rate",
      "metal_rate",
    ].contains(key);
  }

  /// ============================================================
  /// CALCULATE ITEM
  /// ============================================================

  void calculateItem(Map<String, dynamic> item) {
    if (_isCalculating) {
      return;
    }

    _isCalculating = true;

    try {
      final double gross =
          double.tryParse(getController(item, "gross_weight").text) ?? 0;

      final double other =
          double.tryParse(getController(item, "other_weight").text) ?? 0;

      final double purity =
          double.tryParse(getController(item, "purity").text) ?? 0;

      final double waste =
          double.tryParse(getController(item, "waste").text) ?? 0;

      final double metalRate =
          double.tryParse(getController(item, "metal_rate").text) ?? 0;

      final double labourRate =
          double.tryParse(getController(item, "labour_rate").text) ?? 0;

      final double otherAmount =
          double.tryParse(getController(item, "other_amount").text) ?? 0;

      final double net = gross - other;

      final double netPurity = purity + waste;

      final double fineWeight = net * (netPurity / 100);

      final bool manualMetal = item["manual_metal"] ?? true;

      final bool manualLabour = item["manual_labour"] ?? true;

      final double metalAmount = manualMetal ? net * metalRate : 0;

      final double labourAmount = manualLabour ? net * labourRate : 0;

      final double totalAmount = metalAmount + labourAmount + otherAmount;

      item["net_weight"] = net.toStringAsFixed(3);

      item["net_purity"] = netPurity.toStringAsFixed(2);

      item["fine_weight"] = fineWeight.toStringAsFixed(3);

      item["metal_amount"] = metalAmount.toStringAsFixed(2);

      item["labour_amount"] = labourAmount.toStringAsFixed(2);

      item["total_amount"] = totalAmount.toStringAsFixed(2);

      /// Only calculated fields update.
      /// User typing field ne touch nathi karta.

      updateController(item, "net_weight");

      updateController(item, "net_purity");

      updateController(item, "fine_weight");

      updateController(item, "metal_amount");

      updateController(item, "labour_amount");

      updateController(item, "total_amount");
    } finally {
      _isCalculating = false;
    }
  }

  /// ============================================================
  /// DEBOUNCE FINAL UPDATE
  /// ============================================================

  void _scheduleFinalItemsUpdate() {
    _calculationDebounce?.cancel();

    _calculationDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;

      updateFinalItems();
    });
  }

  /// ============================================================
  /// BUILD ITEM DATA
  /// ============================================================

  Map<String, dynamic> buildItemData(Map item, String source) {
    final double gross = getValue(item, "gross_weight");

    final double other = getValue(item, "other_weight");

    final double net = gross - other;

    final double purity = getValue(item, "purity");

    final double waste = getValue(item, "waste");

    final double netPurity = purity + waste;

    final double fineWeight = net * (netPurity / 100);

    final double metalRate = getValue(item, "metal_rate");

    final double labourRate = getValue(item, "labour_rate");

    final double otherAmount = getValue(item, "other_amount");

    final bool manualMetal = item["manual_metal"] ?? true;

    final bool manualLabour = item["manual_labour"] ?? true;

    final double metalAmount = manualMetal ? net * metalRate : 0;

    final double labourAmount = manualLabour ? net * labourRate : 0;

    double totalAmount;

    if (source == "Scan") {
      final apiAmount = double.tryParse(item["amount"]?.toString() ?? "");

      totalAmount = apiAmount ?? (metalAmount + labourAmount + otherAmount);
    } else {
      totalAmount = metalAmount + labourAmount + otherAmount;
    }

    return {
      ...Map<String, dynamic>.from(item),

      "source": source,

      "itemset_id": item["itemset_id"] ?? item["id"],

      "approval_item_id": item["approval_item_id"],

      "gross_weight": gross,

      "other_weight": other,

      "net_weight": net,

      "purity": purity,

      "waste": waste,

      "net_purity": netPurity,

      "fine_weight": fineWeight,

      "metal_rate": metalRate,

      "metal_amount": metalAmount,

      "labour_rate": labourRate,

      "labour_amount": labourAmount,

      "other_amount": otherAmount,

      "total_amount": totalAmount,
    };
  }

  /// ============================================================
  /// UPDATE FINAL ITEMS
  /// ============================================================

  void updateFinalItems() {
    final List<Map<String, dynamic>> updatedList = [];

    /// MANUAL
    for (final item in items) {
      if (item["id"] == null && item["itemset_id"] == null) {
        continue;
      }

      updatedList.add(buildItemData(item, "manual"));
    }

    /// APPROVAL
    for (final rawItem in approvalAddedItems) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

      if (item["itemset_id"] == null || item["approval_item_id"] == null) {
        continue;
      }

      final bool alreadyExists = updatedList.any(
            (e) =>
        e["itemset_id"]?.toString() == item["itemset_id"]?.toString() &&
            e["approval_item_id"]?.toString() ==
                item["approval_item_id"]?.toString(),
      );

      if (!alreadyExists) {
        updatedList.add(buildItemData(item, "approval"));
      }
    }

    /// SCANNER
    for (final rawItem in cartItems) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

      if (item["itemset_id"] == null) {
        continue;
      }

      final bool alreadyExists = updatedList.any(
            (e) => e["itemset_id"]?.toString() == item["itemset_id"]?.toString(),
      );

      if (!alreadyExists) {
        updatedList.add(buildItemData(item, "Scan"));
      }
    }

    if (!mounted) return;

    setState(() {
      finalItems = updatedList;
    });

    debugPrint("🔥 LIVE FINAL ITEMS: $finalItems");
  }

  /// ============================================================
  /// SAVE
  /// ============================================================

  Future<void> savefinalizeBulkItems() async {
    FocusManager.instance.primaryFocus?.unfocus();

    _calculationDebounce?.cancel();

    updateFinalItems();

    if (selectedUserId == null || selectedUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select customer first"),

          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final List<int> returnItems = [];

    for (final item in finalItems) {
      final id = item["itemset_id"];

      if (id == null) continue;

      final parsed = int.tryParse(id.toString());

      if (parsed != null && !returnItems.contains(parsed)) {
        returnItems.add(parsed);
      }
    }

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No items selected")));

      return;
    }
    if (deviceId == null || deviceId!.trim().isEmpty) {
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

        if (Platform.isAndroid) {
          final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? "";
        }
      } catch (e) {
        debugPrint("DeviceInfo Error (Return Scan): $e");
      }
    }
    final String entryId = _generateDeviceEntryId();
    final prefs = await SharedPreferences.getInstance();
    final String? loggedInUserId = prefs.getString('user_id');
    final body = {
      "customer_id": int.parse(selectedUserId!),

      "return_items": returnItems,

      "remarks": remarksController.text.trim(),
      "device_id": deviceId,

      "voucher_session_id": voucherSessionId,

      "device_entry_id": entryId,
      "Created By": loggedInUserId,
    };

    debugPrint("📤 REQUEST BODY: $body");

    final response = await OfflineApiHelper.instance.postRequest(
      ApiConstants.returns_store,
      body,
    );

    if (!mounted) return;

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 202)) {
      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Update saved offline.");
      } else {
        AppMessage.success(context, "Saved Successfully");
      }

      finalItems.clear();
      cartItems.clear();
      approvalAddedItems.clear();
      items.clear();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const Approvalreturnscreen(),
        ),
            (route) => route.isFirst,
      );
    } else {
      /// 🔥 Server thi actual error message extract karo
      /// (jem: "Please select at least one available approval
      /// item for return."), generic "Failed To Save" na badle.
      String errorMessage = "Failed To Save";

      try {
        final dynamic data = response?.data;

        if (data is Map && data["message"] != null) {
          errorMessage = data["message"].toString();
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      /// 🔥 IMPORTANT: Yaha koi Navigator.push/redirect nathi —
      /// user aa j screen par rahese jethi te selection fari
      /// check kari shake.
    }
  }

  /// ============================================================
  /// SCANNER
  /// ============================================================

  Widget _buildScannerSection() {
    double scannerSize = MediaQuery.of(context).size.width * 0.4;

    if (MediaQuery.of(context).size.width > 600) {
      scannerSize = 350;
    }

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
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.unrestricted,

            formats: [BarcodeFormat.qrCode],
          ),

          onDetect: (barcodeCapture) {
            for (final barcode in barcodeCapture.barcodes) {
              final String? code = barcode.rawValue;

              if (code == null || code.isEmpty) {
                continue;
              }

              if (lastCode == code) {
                continue;
              }

              if (isBusy) {
                continue;
              }

              if (selectedUserId == null || selectedUserId!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select customer first"),

                    backgroundColor: Colors.red,
                  ),
                );

                return;
              }

              lastCode = code;

              isBusy = true;

              debugPrint("⚡ FAST SCAN: $code");

              scanApiCall(code);

              Future.delayed(const Duration(milliseconds: 600), () {
                isBusy = false;
              });

              Future.delayed(const Duration(seconds: 2), () {
                if (lastCode == code) {
                  lastCode = null;
                }
              });
            }
          },
        ),
      ),
    );
  }

  /// ============================================================
  /// SCAN API
  /// ============================================================

  Future<void> scanApiCall(String code) async {
    if (selectedUserId == null) {
      return;
    }

    /// =========================================================
    /// 🔥 DUPLICATE SCAN CHECK
    ///
    /// Backend already-scanned item mate pan "success: true" j
    /// return kare che, etle niche ni API call thai jata pehla j
    /// aapde locally check kari laiye ke aa qr_code cartItems /
    /// items / approvalAddedItems ma pehla thi j hazar che ke nai.
    /// Hoy to API call j na karvi — sidhu "Item already scanned"
    /// batavi devanu.
    /// =========================================================

    final String trimmedCode = code.trim();

    final bool alreadyScanned =
        cartItems.any(
              (e) => (e["qr_code"]?.toString().trim() ?? "") == trimmedCode,
        ) ||
            items.any(
                  (e) => (e["qr_code"]?.toString().trim() ?? "") == trimmedCode,
            ) ||
            approvalAddedItems.any(
                  (e) => (e["qr_code"]?.toString().trim() ?? "") == trimmedCode,
            );

    if (alreadyScanned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Item already scanned"),

            backgroundColor: Colors.orange,

            duration: Duration(seconds: 2),
          ),
        );
      }

      return;
    }
    /// 🔥 device_id ek vaar j fetch karo (already set hoy to skip)
    if (deviceId == null || deviceId!.trim().isEmpty) {
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

        if (Platform.isAndroid) {
          final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? "";
        }
      } catch (e) {
        debugPrint("DeviceInfo Error (Return Scan): $e");
      }
    }

    /// 🔥 voucher_session_id na hoy to fallback generate karo
    voucherSessionId ??= 'RET-${DateTime.now().millisecondsSinceEpoch}';

    final String entryId = _generateDeviceEntryId();

    final String url =
        "${ApiConstants.Approval_return_qr_item}"
        "?customer_id=$selectedUserId"
        "&qr_code=${Uri.encodeQueryComponent(code)}"
        "&device_id=${Uri.encodeQueryComponent(deviceId ?? "")}"
        "&voucher_session_id=${Uri.encodeQueryComponent(voucherSessionId ?? "")}"
        "&device_entry_id=${Uri.encodeQueryComponent(entryId)}";

    debugPrint("📤 GET API URL: $url");

    final response = await ApiHelper().getRequest(url);

    if (!mounted) return;

    if (response == null) {
      return;
    }

    debugPrint("📥 Status Code: ${response.statusCode}");

    debugPrint("📥 Response Data: ${response.data}");

    if (response.statusCode == 200 && response.data["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item Scan Successfully"),

          backgroundColor: Colors.green,

          duration: Duration(seconds: 2),
        ),
      );
      _claimNextCartFetch = true; // 🔥 navi item aa customer ni
      await getCartItems();
    } else {
      final String message =
          response.data["message"]?.toString() ?? "Scan failed";

      /// Backend potej "already" wala message aapi ne success:false
      /// karto hoy to pan orange color ma spashth batavo
      final bool isDuplicateFromApi = message.toLowerCase().contains(
        "already",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// ============================================================
  /// CART ITEMS
  /// ============================================================

  int _cartRequestId = 0;

  /// 🔥 cart key → customer id (API customer_id na moklave to pan
  /// local rite khabar rahe ke item kya customer ni chhe)
  final Map<String, String> _cartKeyOwner = {};

  /// Scan / approval add pachhi j navi item current customer ni gani shakay
  bool _claimNextCartFetch = false;

  static const String _unknownOwner = "__unknown__";

  String _cartItemKey(Map e) {
    return (e["cart_id"] ?? e["id"] ?? e["itemset_id"])?.toString() ?? "";
  }

  /// API ma customer_id koi pan rite aave — direct ke nested
  String _cartItemCustomerId(Map e) {
    final dynamic v = e["customer_id"] ??
        (e["customer"] is Map ? e["customer"]["id"] : null) ??
        e["approval_customer_id"];
    return v?.toString().trim() ?? "";
  }

  Future<void> getCartItems() async {
    final int requestId = ++_cartRequestId;
    final String? customerId = selectedUserId;

    /// Aa fetch scan/approval add pachhi thay chhe ke nahi
    final bool claimNew = _claimNextCartFetch;
    _claimNextCartFetch = false;

    /// Customer j select nathi → cart khali
    if (customerId == null || customerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        cartItems = [];
        finalItems = [];
      });
      return;
    }

    String url = ApiConstants.return_Qr_list;
    url += "${url.contains('?') ? '&' : '?'}customer_id=$customerId";

    debugPrint("📤 CART LIST URL: $url");

    final response = await ApiHelper().getRequest(url);

    /// 🔥 Vachche customer badlayo hoy to aa juno response ignore
    if (!mounted ||
        requestId != _cartRequestId ||
        customerId != selectedUserId) {
      return;
    }

    if (response != null && response.statusCode == 200) {
      final List rawData = response.data["data"] ?? [];

      List<Map<String, dynamic>> newCartItems = rawData
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      /// =====================================================
      /// 🔥 STRICT CUSTOMER FILTER
      /// =====================================================
      newCartItems = newCartItems.where((e) {
        final String key = _cartItemKey(e);
        final String cid = _cartItemCustomerId(e);

        /// 1) API e customer_id aapyo → sidho match
        if (cid.isNotEmpty) {
          if (key.isNotEmpty) _cartKeyOwner[key] = cid;
          return cid == customerId;
        }

        /// 2) customer_id nathi → local tracking thi nakki karo
        final String? owner = _cartKeyOwner[key];

        if (owner != null && owner != _unknownOwner) {
          return owner == customerId;
        }

        /// 3) Navi item, ane hamna j scan/add thayu → current customer ni
        if (claimNew && owner == null && key.isNotEmpty) {
          _cartKeyOwner[key] = customerId;
          return true;
        }

        /// 4) Kono che khabar nathi → batavvanu nahi
        if (key.isNotEmpty) {
          _cartKeyOwner.putIfAbsent(key, () => _unknownOwner);
        }
        return false;
      }).toList();

      for (final item in newCartItems) {
        item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
        item["other_weight"] = item["other_weight"]?.toString() ?? "0";
        item["net_weight"] = item["net_weight"]?.toString() ?? "0";
        item["purity"] = item["purity"]?.toString() ?? "0";
        item["waste"] = item["waste"]?.toString() ??
            item["waste_percent"]?.toString() ??
            "0";
        item["labour_rate"] = item["labour_rate"]?.toString() ?? "0";
        item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
        item["other_amount"] = item["other_amount"]?.toString() ?? "0";
        item["total_amount"] = item["amount"]?.toString() ??
            item["total_amount"]?.toString() ??
            "0";
        item["manual_metal"] = item["manual_metal"] ?? true;
        item["manual_labour"] = item["manual_labour"] ?? true;

        _initializeItemControllers(item);
        calculateItem(item);
      }

      cartItems = newCartItems;
      updateFinalItems();

      debugPrint("Customer $customerId → Cart Items: ${cartItems.length}");
    } else {
      setState(() {
        cartItems = [];
        finalItems = [];
      });
    }
  }

  /// ============================================================
  /// DELETE CART
  /// ============================================================

  /// 🔥 Return type bool — success/fail upar caller (_removeItem)
  /// decide kare che ke local list mathi remove karvu ke nahi.
  Future<bool> deleteUser(String id) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.returns_cart_remove}/$id",
      );

      final bool success =
          response?.statusCode == 200 &&
              response?.data is Map &&
              response?.data["success"] == true;

      if (success) {
        debugPrint("✅ Deleted Successfully");

        /// 🔥 Server thi fresh cart list levi (scan/sale items mate)
        await getCartItems();

        return true;
      } else {
        final String message = response?.data is Map
            ? response?.data["message"]?.toString() ?? "Delete failed"
            : "Delete failed";

        debugPrint("❌ Delete failed: $message");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }

        return false;
      }
    } catch (e) {
      debugPrint("❌ Delete exception: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong while deleting"),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  /// ============================================================
  /// OTHER CHARGE API
  /// ============================================================

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

    if (!mounted) return;

    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final List apiList = data["data"] is List ? data["data"] : [];

      showOtherChargesPopup(mainItem, apiList);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  /// ============================================================
  /// OTHER CHARGES POPUP
  /// ============================================================

  void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
    /// ============================================================
    /// 🔥 FIX: PREVIOUSLY SELECTED CHARGES (persist thi)
    /// Apply time "other_charge_ids" (comma-separated ids) item ma
    /// save thai chuklu hoy — e j ids sathe match kari ne pre-select.
    /// ============================================================
    final Set<String> previouslySelectedIds = (item["other_charge_ids"]
        ?.toString() ??
        "")
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    // ============================================================
    // API DATA -> POPUP DATA (id add karyu — persistence mate jaruri)
    // ============================================================
    final List<Map<String, dynamic>> charges = apiList
        .map<Map<String, dynamic>>((e) {
      final String chargeId = e["id"]?.toString() ?? "";

      /// 🔥 FIX: pre-select — saved ids ma hoy, ya API j is_selected
      /// batavtu hoy (fallback), to select rakhvanu
      final bool isSelected = previouslySelectedIds.contains(chargeId) ||
          (e["is_selected"] ?? false) == true;

      return {
        "id": e["id"],
        "charge": e["name"] ?? "",
        "amount": (e["default_amount"] ?? 0).toString(),
        "qty": (e["quantity_pcs"] ?? 1).toString(),
        "weight": (e["default_weight"] ?? 0).toString(),
        "wt_formula": e["weight_formula"] == "per_quantity" ? "per_qty" : "flat",
        "amt_formula_type": e["other_amt_formula"] == "per_quantity"
            ? "per_qty"
            : e["other_amt_formula"] == "per_weight"
            ? "per_weight"
            : e["other_amt_formula"] == "per_qty_weight"
            ? "per_qty_weight"
            : "flat",
        "total_weight": "0.0",
        "total_amt": "0",
        "is_selected": isSelected,
      };
    }).toList();

    /// ============================================================
    /// 🔥 PERSISTENT CONTROLLERS (PERFORMANCE FIX)
    /// ============================================================
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

    /// ============================================================
    /// 🔥 SINGLE-ROW CALCULATION (PERFORMANCE FIX)
    /// ============================================================
    void calculateSingleCharge(Map<String, dynamic> c) {
      final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
      final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
      final double weight = double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;

      final String amtFormula = c["amt_formula_type"] ?? "flat";
      final String wtFormula = c["wt_formula"] ?? "flat";

      double totalAmt = 0;
      double totalWeight = 0;

      switch (wtFormula) {
        case "flat":
          totalWeight = weight;
          break;
        case "per_qty":
          totalWeight = weight * qty;
          break;
        case "per_weight":
          totalWeight = weight;
          break;
        default:
          totalWeight = weight;
      }

      c["total_weight"] = totalWeight.toStringAsFixed(2);

      switch (amtFormula) {
        case "flat":
          totalAmt = amt;
          break;
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

    double calcTotal() {
      double total = 0;
      for (final c in charges) {
        if (c["is_selected"] == true) {
          total += double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
        }
      }
      return total;
    }

    int selectedCount() {
      return charges.where((c) => c["is_selected"] == true).length;
    }

    final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
    final ValueNotifier<int> selectedCountNotifier = ValueNotifier<int>(selectedCount());

    // ============================================================
    // SHOW DIALOG — PREMIUM UI (SAME AS BEFORE)
    // ============================================================
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
                  // BLUE HEADER
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
                            disposeControllers();
                            Navigator.pop(dialogContext);
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
                              ValueListenableBuilder<int>(
                                valueListenable: selectedCountNotifier,
                                builder: (context, count, _) {
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
                                          "$count Selected",
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
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

                                            final bool selected = c["is_selected"] == true;

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
                                                        c["total_weight"]?.toString() ?? "0",
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
                                                          c["total_amt"]?.toString() ?? "0",
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

                                                  /// CHECKBOX (MULTI-SELECT)
                                                  SizedBox(
                                                    width: 45,
                                                    child: Center(
                                                      child: Transform.scale(
                                                        scale: 0.88,
                                                        child: Checkbox(
                                                          value: c["is_selected"] == true,
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
                                                            c["is_selected"] = val ?? false;

                                                            setStateRow(() {});

                                                            totalNotifier.value = calcTotal();
                                                            selectedCountNotifier.value = selectedCount();
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
                                      ValueListenableBuilder<int>(
                                        valueListenable: selectedCountNotifier,
                                        builder: (context, count, _) {
                                          return Text(
                                            "$count of ${charges.length} charges selected",
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

                  // BOTTOM ACTION BAR
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
                                disposeControllers();
                                Navigator.pop(dialogContext);
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

                                  double selectedTotal = 0;

                                  /// 🔥 FIX: selected charge ids collect karo
                                  final List<String> selectedIds = [];

                                  for (final c in charges) {
                                    if (c["is_selected"] == true) {
                                      selectedTotal +=
                                          double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;

                                      selectedIds.add(c["id"]?.toString() ?? "");
                                    }
                                  }

                                  item["other_amount"] = selectedTotal.toStringAsFixed(2);

                                  /// 🔥 FIX: SAVE SELECTED IDS — NEXT TIME PRE-SELECT MATE
                                  item["other_charge_ids"] = selectedIds.join(",");

                                  setController(
                                    item,
                                    "other_amount",
                                    item["other_amount"],
                                  );

                                  calculateItem(item);

                                  updateFinalItems();

                                  disposeControllers();

                                  Navigator.pop(dialogContext);
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

  /// ============================================================
  /// SUMMARY
  /// ============================================================

  Widget buildSummaryRow() {
    final totals = calculateTotals();

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
            _summaryBox("Items", "${finalItems.length}"),

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
              totals["labourRate"]!.toStringAsFixed(2),
            ),

            _summaryBox("Labour Amt", totals["labour"]!.toStringAsFixed(2)),

            _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),

            _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// TOTALS
  /// ============================================================

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

    for (final item in finalItems) {
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
          double.tryParse(item["labour_rate"]?.toString() ?? "0") ?? 0;

      labour += double.tryParse(item["labour_amount"]?.toString() ?? "0") ?? 0;

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

      "labourRate": labourRate,

      "labour": labour,

      "otherAmt": otherAmt,

      "total": total,
    };
  }

  /// ============================================================
  /// SUMMARY BOX
  /// ============================================================

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

  /// ============================================================
  /// OPTIONAL OLD HELPERS
  /// ============================================================

  void calculateNetWeight(int index) {
    if (index < 0 || index >= tableRows.length) {
      return;
    }

    final grossController = tableRows[index]["gross"];

    final otherController = tableRows[index]["other"];

    final netController = tableRows[index]["net"];

    if (grossController is! TextEditingController ||
        otherController is! TextEditingController ||
        netController is! TextEditingController) {
      return;
    }

    final double gross = double.tryParse(grossController.text) ?? 0;

    final double other = double.tryParse(otherController.text) ?? 0;

    final double net = gross - other;

    netController.text = net.toStringAsFixed(3);
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
                  flex: 3,

                  child: Text(
                    t1,

                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),

                Expanded(
                  flex: 4,

                  child: Text(
                    v1,

                    style: const TextStyle(
                      fontSize: 12,

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

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 12,

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

                            final id = user["cart_id"] ?? user["id"];

                            if (id != null) {
                              await deleteUser(id.toString());
                            }
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

  Widget buildUserCard(Map item) {
    final size = MediaQuery.of(context).size;

    final bool isTablet = size.width >= 600;

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
              statusChip(item["metal"]?.toString() ?? ""),

              const Spacer(),

              Row(
                children: [
                  premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),

                  SizedBox(width: isTablet ? 10 : 8),

                  premiumIconBtn(
                    Icons.delete,
                    Colors.red,
                    onTap: () {
                      _showDeleteDialog(item);
                    },
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: isTablet ? 10 : 8),

          Row(
            children: [
              Text(
                item["item_name"] ?? "",

                style: const TextStyle(
                  fontSize: 15,

                  color: Colors.black,

                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                item["qr_code"] ?? "",

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

                  item["gross_weight"]?.toString() ?? "-",

                  "Net",

                  item["net_weight"] == "0.000" || item["net_weight"] == null
                      ? "-"
                      : item["net_weight"].toString(),
                ),

                Divider(height: 1, color: Colors.grey.shade200),

                _erpRow(
                  "Purity",

                  item["purity"]?.toString() ?? "-",

                  "Amount",

                  "₹ ${item["amount"] ?? 0}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateDeviceEntryId() {
    final String base = deviceId ?? 'unknown-device';

    return "$base-${DateTime.now().microsecondsSinceEpoch}";
  }

  /// 🔥 Customer બદલાય / clear થાય → જૂનો data સાફ
  void _resetCustomerData({Map<String, dynamic>? customer}) {
    /// Controllers ને તરત dispose ના કરો — જૂના TextFields હજુ
    /// screen પર છે. પહેલા UI બદલાય, પછી frame પૂરી થયે dispose.
    final oldControllers = controllers.values.toList();
    controllers.clear();

    setState(() {
      selectedItem = customer?["id"]?.toString();
      selectedCompanyId = customer?["company_id"]?.toString();
      selectedUserId = customer?["id"]?.toString();

      cartItems = [];
      approvalAddedItems = [];
      items = [];
      finalItems = [];

      searchResults = [];   // 🔥
      lastCode = null;      // 🔥 navo customer → same QR fari scan thai shake
    });

    _cartRequestId++;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldControllers) {
        c.dispose();
      }
    });
  }
}

/// ==================================================================
/// SCANNER LINE
/// ==================================================================

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

    animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
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
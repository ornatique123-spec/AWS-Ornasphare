// import 'dart:async';
// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Qr_Screen.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/ItemProvider.dart';
// import 'Sell_retun_voucher_Screen.dart';
//
// class SellReturnScreen extends StatefulWidget {
//   const SellReturnScreen({super.key});
//
//   @override
//   State<SellReturnScreen> createState() => _SellReturnScreenState();
// }
//
// class _SellReturnScreenState extends State<SellReturnScreen> {
//   TextEditingController searchController = TextEditingController();
//   List userlist = [];
//   String? selectedItem;
//   List<Map<String, dynamic>> tableRows = [];
//   Timer? _huidTimer;
//   int apiRowCount = 0;
//   List customerlist = [];
//   String? selectedUser;
//   String? selectedCompanyId;
//   String? selectedUserId;
//   String? selectedUserName;
//   DateTime? birthDate;
//   DateTime? anniversaryDate;
//   List cartItems = [];
//   bool isLoading = false;
//   List<Map<String, dynamic>> items = [];
//   List<Map<String, dynamic>> allItems = [];
//   List searchResults = [];
//   List combinedItems = [];
//   List<Map<String, dynamic>> finalItems = [];
//   Set<int> selectedItems = {}; // ✅ MUST BE int
//   List approvalAddedItems = []; // 🔥 new list
//   bool showScannerFull = false;
//   List<Map<String, dynamic>> uniqueItems = [];
//   FocusNode searchFocusNode = FocusNode();
//   bool isSearchEnabled = false;
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).loadCustomers();
//     });
//     getCartItems();
//   }
//
//
//
//
//
//
//
//
//   @override
//   Widget build(BuildContext context) {
//
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//     /// 🔥 UNIFIED LIST: Combine all sources
//     List combinedItemsList = [
//       ...items,               // From Manual Search
//       ...approvalAddedItems,  // From Return Approval Dialog
//       ...cartItems.map((e) => {
//         "id": e["id"],
//         "name": e["item_name"] ?? e["item"]?["item_name"] ?? "",
//         "code": e["qr_code"] ?? e["huid"] ?? "",
//         "gross_weight": e["gross_weight"] ?? "0",
//         "net_weight": e["net_weight"] ?? "0",
//         "purity": e["purity"] ?? "-",
//         "source": "sale",
//         "itemset_id": e["itemset_id"],
//       }).toList(),            // From Scanner
//     ];
//
//     // Remove duplicates based on ID or Code
//     final uniqueItems = {
//       for (var item in combinedItemsList)
//         (item["approval_item_id"] ?? item["id"] ?? item["code"]): item
//     }.values.toList().reversed.toList();
//     return Scaffold(
//       resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
//       body: SafeArea(
//         child: Stack(
//           children: [
//
//             /// ✅ Background Image
//             Container(
//               decoration: const BoxDecoration(
//                 image: DecorationImage(
//                   image: AssetImage("assets/static/img_3.png"),
//                   fit: BoxFit.fill,
//                 ),
//               ),
//             ),
//
//
//             /// ✅ Main Content
//             Column(
//               children: [
//                 /// IMPORTANT: top padding space leave karvu (AppBar mate)
//                 SizedBox(height: MediaQuery.of(context).padding.top + 30),
//
//                 Expanded(
//                   child: showScannerFull
//                       ? Column(
//                     children: [
//                       const SizedBox(height: 10),
//
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(10),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Consumer<ItemProvider>(
//                           builder: (context, provider, child) {
//                             final customers = provider.customers;
//
//                             return DropdownButtonFormField<String>(
//                                 value:
//                                 (selectedItem != null &&
//                                     customers.any(
//                                           (e) => e["id"].toString() == selectedItem,
//                                     ))
//                                     ? selectedItem
//                                     : null,
//
//                                 icon: const Icon(
//                                   Icons.keyboard_arrow_down,
//                                   color: Colors.black,
//                                 ),
//                                 dropdownColor: Colors.white, // 🔥 ADD THIS
//                                 hint: Text(
//                                   // 🔥 IMPORTANT: hint here, not only in decoration
//                                   "Select Customer",
//                                   style: TextStyle(color: Colors.grey.shade600),
//                                 ),
//                                 style: const TextStyle(
//                                   color: Colors.black, // 🔥 selected value color
//                                   fontSize: 14,
//                                 ),
//
//                                 decoration: InputDecoration(
//                                   filled: true,
//                                   fillColor: Colors.white,
//
//                                   contentPadding: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 0,
//                                   ),
//
//                                   border: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                     borderSide: BorderSide(color: Colors.grey.shade300),
//                                   ),
//
//                                   enabledBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                     borderSide: BorderSide(color: Colors.grey.shade300),
//                                   ),
//
//                                   focusedBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                     borderSide: BorderSide(
//                                       color: Colors.grey.shade300,
//                                     ), // 🔥 focus black
//                                   ),
//                                 ),
//
//                                 items: customers.map<DropdownMenuItem<String>>((item) {
//                                   return DropdownMenuItem<String>(
//                                     value: item["id"].toString(),
//                                     child: Text(
//                                       item["name"] ?? "",
//                                       style: const TextStyle(
//                                         color: Colors.black,
//                                       ), // 🔥 list text black
//                                     ),
//                                   );
//                                 }).toList(),
//
//                                 onChanged: (value) {
//                                   setState(() {
//                                     selectedItem = value;
//
//                                     final selectedData = customers.firstWhere(
//                                           (user) => user["id"].toString() == value,
//                                       orElse: () => {},
//                                     );
//
//                                     if (selectedData.isNotEmpty) {
//                                       selectedCompanyId = selectedData["company_id"]?.toString();
//                                       selectedUserId = selectedData["id"]?.toString();
//
//                                       print("Selected Company ID: $selectedCompanyId");
//                                       print("Selected User ID: $selectedUserId");
//                                     } else {
//                                       print("⚠️ Customer not found");
//                                     }
//                                   });
//                                 }
//
//                             );
//                           },
//                         ),
//                       ),
//                       const SizedBox(height: 10),
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
//                                     color: Colors.greenAccent.withOpacity(0.4),
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
//                                     border: Border.all(color: Colors.white,width: 1.5),
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
//                         margin: const EdgeInsets.only(top: 10, bottom: 0),
//                         child: Image.asset(
//                           "assets/static/divider.png",
//                           fit: BoxFit.fill,
//                           width: double.infinity,
//                           height: 25,
//                         ),
//                       ),
//
//
//
//                       /// 🔽 LIST
//                       Expanded(
//                         child: uniqueItems.isEmpty
//                             ? const Center(child: Text("No Data Added"))
//                             : ListView.builder(
//                           padding: EdgeInsets.fromLTRB(12, 12, 12,
//                             MediaQuery.of(context).viewInsets.bottom, // 🔥 MAGIC
//                           ),
//                           itemCount: uniqueItems.length,
//                           itemBuilder: (context, index) {
//                             return approvalItemCard(
//                               uniqueItems[index],
//                               index,uniqueItems.length
//                             );
//                           },
//                         ),
//                       ),
//
//                     ],
//                   )
//                       : Column(
//                     children: [
//                       filterWidget(),
//                       Container(
//                         margin: const EdgeInsets.only(top: 10, bottom: 0),
//                         child: Image.asset(
//                           "assets/static/divider.png",
//                           fit: BoxFit.fill,
//                           width: double.infinity,
//                           height: 25,
//                         ),
//                       ),
//
//                       Expanded(
//                         child: uniqueItems.isEmpty
//                             ? const Center(child: Text("No Data Added"))
//                             : ListView.builder(
//                           padding: EdgeInsets.fromLTRB(12, 12, 12,
//                             MediaQuery.of(context).viewInsets.bottom, // 🔥 MAGIC
//                           ),
//                           itemCount: uniqueItems.length,
//                           itemBuilder: (context, index) {
//                             return approvalItemCard(
//                               uniqueItems[index],
//                               index,uniqueItems.length
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//
//                 /// 🔥 Dynamic Bottom Section
//                 // Expanded(
//                 //   child: _buildRecentScansList(height),
//                 // ),
//
//                 // Expanded(
//                 //   child: uniqueItems.isEmpty
//                 //       ? const Center(child: Text("No Data Added"))
//                 //       : ListView.builder(
//                 //     padding: const EdgeInsets.all(12),
//                 //     itemCount: uniqueItems.length,
//                 //     itemBuilder: (context, index) {
//                 //       return approvalItemCard(
//                 //         uniqueItems[index],
//                 //         index,
//                 //       );
//                 //     },
//                 //   ),
//                 // ),
//                 /// 🔥 BOTTOM SUMMARY
//                 buildSummaryRow(),
//
//                 /// Bottom Button
//                 InkWell(
//                   onTap: () {
//                     savefinalizeBulkItems();
//                   },
//                   borderRadius: BorderRadius.circular(15),
//                   child: Container(
//                     margin: const EdgeInsets.all(16),
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [
//                           Color(0xffE6C58A),
//                           Color(0xffC8A96A),
//                           Color(0xffE6C58A),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(15),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         "Save Return Sale",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                           fontSize: 16,
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
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     /// ✅ CENTER TITLE
//                     const Text(
//                       "Sale For Return",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     /// ✅ LEFT BACK ICON
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: InkWell(
//                         onTap: () => Navigator.pop(context),
//                         child: const Icon(
//                           Icons.arrow_back,
//                           color: Colors.white,
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
//       //bottomNavigationBar: _buildSaveButton(),
//
//     );
//   }
//
//
//   void calculateNetWeight(int index) {
//     double gross =
//         double.tryParse(tableRows[index]["gross"]!.text) ?? 0;
//
//     double other =
//         double.tryParse(tableRows[index]["other"]!.text) ?? 0;
//
//     double net = gross - other;
//
//     tableRows[index]["net"]!.text = net.toStringAsFixed(3);
//   }
//
//
//
//
//
//
//   Widget filterWidget() {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xffFAF7F2).withOpacity(0.95),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xffE5DDD0)),
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
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: Consumer<ItemProvider>(
//               builder: (context, provider, child) {
//                 final customers = provider.customers;
//
//                 return DropdownButtonFormField<String>(
//                     value:
//                     (selectedItem != null &&
//                         customers.any(
//                               (e) => e["id"].toString() == selectedItem,
//                         ))
//                         ? selectedItem
//                         : null,
//
//                     icon: const Icon(
//                       Icons.keyboard_arrow_down,
//                       color: Colors.black,
//                     ),
//                     dropdownColor: Colors.white, // 🔥 ADD THIS
//                     hint: Text(
//                       // 🔥 IMPORTANT: hint here, not only in decoration
//                       "Select Customer",
//                       style: TextStyle(color: Colors.grey.shade600),
//                     ),
//                     style: const TextStyle(
//                       color: Colors.black, // 🔥 selected value color
//                       fontSize: 14,
//                     ),
//
//                     decoration: InputDecoration(
//                       filled: true,
//                       fillColor: Colors.white,
//
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 0,
//                       ),
//
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide(color: Colors.grey.shade300),
//                       ),
//
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide(color: Colors.grey.shade300),
//                       ),
//
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide(
//                           color: Colors.grey.shade300,
//                         ), // 🔥 focus black
//                       ),
//                     ),
//
//                     items: customers.map<DropdownMenuItem<String>>((item) {
//                       return DropdownMenuItem<String>(
//                         value: item["id"].toString(),
//                         child: Text(
//                           item["name"] ?? "",
//                           style: const TextStyle(
//                             color: Colors.black,
//                           ), // 🔥 list text black
//                         ),
//                       );
//                     }).toList(),
//
//                     onChanged: (value) {
//                       setState(() {
//                         selectedItem = value;
//
//                         final selectedData = customers.firstWhere(
//                               (user) => user["id"].toString() == value,
//                           orElse: () => {},
//                         );
//
//                         if (selectedData.isNotEmpty) {
//                           selectedCompanyId = selectedData["company_id"]?.toString();
//                           selectedUserId = selectedData["id"]?.toString();
//
//                           print("Selected Company ID: $selectedCompanyId");
//                           print("Selected User ID: $selectedUserId");
//                         } else {
//                           print("⚠️ Customer not found");
//                         }
//                       });
//                     }
//
//                 );
//               },
//             ),
//           ),
//           const SizedBox(height: 10),
//
//           /// 🔍 SEARCH FIELD
//           Column(
//             children: [
//               /// 🔍 SEARCH FIELD
//               TextField(
//                 controller: searchController,
//                 focusNode: searchFocusNode,
//                 readOnly: !isSearchEnabled, // 🔥 KEY
//                 onTap: () {
//                   setState(() {
//                     isSearchEnabled = true; // 🔥 enable typing
//                   });
//
//                   // 🔥 manually keyboard open
//                   searchFocusNode.requestFocus();
//                 },
//                 onChanged: (value) {
//                   if (selectedItem == null) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text("Please select customer first"),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                     return;
//                   }else{
//                     searchItemsApi(value);
//                   }
//
//                 },
//                 decoration: InputDecoration(
//                   hintText: "Search (HUID / QR)",
//                   hintStyle: TextStyle(color: Colors.grey.shade600),
//                   prefixIcon: const Icon(Icons.search, color: Colors.black54),
//                   filled: true,
//                   fillColor: Colors.white,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 0),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: Colors.grey.shade300),
//                   ),
//                 ),
//               ),
//
//               /// 🔥 DROPDOWN RESULT LIST
//               /// 🔥 SEARCH RESULT DROPDOWN
//               if (searchController.text.isNotEmpty)
//                 Container(
//                   margin: const EdgeInsets.only(top: 0),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.grey.shade300),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.08),
//                         blurRadius: 6,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   constraints: const BoxConstraints(maxHeight: 200),
//                   child: isLoading
//                       ? const Padding(
//                     padding: EdgeInsets.all(0),
//                     child: Center(child: CircularProgressIndicator()),
//                   )
//                       : searchResults.isEmpty
//                       ? const Padding(
//                     padding: EdgeInsets.all(12),
//                     child: Center(
//                       child: Text(
//                         "No items found",
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     ),
//                   )
//                       : ListView.builder(
//                     shrinkWrap: true,
//                     padding: EdgeInsets.zero, // 🔥 MUST ADD
//                     itemCount: searchResults.length,
//                     itemBuilder: (context, index) {
//                       final item = searchResults[index];
//
//                       final itemName =
//                           item["item"]?["item_name"] ?? "Item";
//                       final huid = item["HUID"] ?? "-";
//                       final qr = item["qr_code"] ?? "-";
//
//                       return InkWell(
//                         onTap: () {
//
//                           // 🔥 KEYBOARD CLOSE
//                           FocusScope.of(context).unfocus();
//
//                           addItemToCard(item); // 🔥 IMPORTANT
//                           updateFinalItems();
//                           // 🔥 RESET SEARCH
//                           setState(() {
//                             searchController.clear();
//                             searchResults.clear();
//                             isSearchEnabled = false; // 🔥 again disable
//                           });
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 10,
//                           ),
//                           decoration: BoxDecoration(
//                             border: Border(
//                               bottom: BorderSide(
//                                 color: index == searchResults.length - 1
//                                     ? Colors.transparent
//                                     : Colors.grey.shade200,
//                               ),
//                             ),
//                           ),
//                           child: Row(
//                             children: [
//                               /// 🔹 LEFT INFO
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment:
//                                   CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       itemName,
//                                       style: const TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.w600,
//                                         color: Colors.black,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 2),
//                                     Text(
//                                       "HUID: $huid | QR: $qr",
//                                       style: const TextStyle(
//                                         fontSize: 12,
//                                         color: Colors.grey,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//
//                               /// ➕ ADD ICON
//                               const Icon(
//                                 Icons.add_circle,
//                                 color: Color(0xffC8A96A),
//                                 size: 20,
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 10),
//
//           /// 🔥 BUTTONS
//           Row(
//             children: [
//               /// 🔍 SCAN BUTTON
//               Expanded(
//                 flex: 1,
//                 child: InkWell(
//                   onTap: () {
//                     // Navigator.push(
//                     //   context,
//                     //   MaterialPageRoute(builder: (_) => PremiumScannerScreen()),
//                     // );
//                     setState(() {
//                       showScannerFull = true;
//                     });
//                     print("Scan QR");
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xffE6C58A), Color(0xffC8A96A)],
//                       ),
//                       borderRadius: BorderRadius.circular(8),
//                       boxShadow: [
//                         BoxShadow(
//                           color: const Color(0xffC8A96A).withOpacity(0.4),
//                           blurRadius: 8,
//                           offset: const Offset(0, 3),
//                         ),
//                       ],
//                     ),
//                     child: const Center(
//                       child: Icon(
//                         Icons.qr_code_scanner,
//                         color: Colors.white,
//                         size: 22,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(width: 10),
//
//               /// ➕ ADD LABEL BUTTON
//               Expanded(
//                 flex: 3,
//                 child: InkWell(
//                   onTap: () {
//                     /// 🔥 VALIDATION
//                     if (selectedItem == null) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text("Please select customer first"),
//                           backgroundColor: Colors.red,
//                         ),
//                       );
//                       return;
//                     }else{
//                       getApprovalDetails(
//                         int.parse(selectedItem.toString()),
//                       ); // 🔥 id pass karo
//                       print("Add Label Return Approval");
//                     }
//
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.grey.shade300),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.05),
//                           blurRadius: 6,
//                           offset: const Offset(0, 3),
//                         ),
//                       ],
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: const [
//                         Icon(Icons.add, size: 18, color: Colors.black),
//                         SizedBox(width: 6),
//                         Text(
//                           "Add Label Return Approval",
//                           style: TextStyle(
//                             fontWeight: FontWeight.w600,
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
//   // Future<void> searchItemsApi(String keyword) async {
//   //   if (keyword.isEmpty) {
//   //     setState(() {
//   //       searchResults = [];
//   //     });
//   //     return;
//   //   }
//   //
//   //   final body = {
//   //     "customer_id": int.parse(selectedItem!), // ideally from login/session
//   //     "keyword": keyword,
//   //   };
//   //
//   //   final response = await ApiHelper().postRequest(
//   //     ApiConstants.returns_search,
//   //     body,
//   //   );
//   //
//   //   if (response != null && response.statusCode == 200) {
//   //     setState(() {
//   //       searchResults = response.data["data"] ?? [];
//   //     });
//   //   } else {
//   //     print("Search API Failed");
//   //   }
//   // }
//
//   Future<void> searchItemsApi(String keyword) async {
//     if (keyword.isEmpty) {
//       setState(() {
//         searchResults = [];
//       });
//       return;
//     }
//
//     final body = {
//       "customer_id": int.parse(selectedItem!),
//       "keyword": keyword,
//     };
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.returns_search,
//       body,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       List allResults = response.data["data"] ?? [];
//
//       // 🔥 Filter results: Je item pahle thi added che tene kadhi nakho
//       setState(() {
//         searchResults = allResults.where((item) {
//
//           final itemsetId = item["itemset_id"];
//           final saleItemId = item["sale_item_id"];
//           final approvalItemId = item["approval_item_id"];
//
//           bool alreadyAdded =
//
//           /// 🔹 Manual items
//           items.any((e) => e["itemset_id"] == itemsetId) ||
//
//               /// 🔹 Approval items
//               approvalAddedItems.any((e) =>
//               e["itemset_id"] == itemsetId ||
//                   e["approval_item_id"] == approvalItemId) ||
//
//               /// 🔹 Scan items
//               cartItems.any((e) =>
//               e["itemset_id"] == itemsetId ||
//                   e["sale_item_id"] == saleItemId);
//
//           return !alreadyAdded;
//         }).toList();
//       });
//
//     } else {
//       print("Search API Failed");
//     }
//   }
//
//
//   // void  addItemToCard(dynamic e) {
//   //   setState(() {
//   //
//   //     final itemsetId = e["id"]; // 🔥 IMPORTANT
//   //
//   //     /// 🔥 API LIST ma add karo
//   //     if (!finalItems.any((item) => item["itemset_id"] == itemsetId)) {
//   //       finalItems.add({
//   //         "source": e["source"] ?? "sale", // ✅ API mathi
//   //         "itemset_id": itemsetId,
//   //         "total_amount": e["total_amount"] ?? 0, // ✅ API mathi
//   //       });
//   //     }
//   //
//   //
//   //
//   //     /// 🔥 UI LIST ma add karo
//   //     items.add({
//   //       "id": e["id"],
//   //       "item_name": e["item"]?["item_name"] ?? "",
//   //       "huid": e["HUID"] ?? "",
//   //       "qr_code": e["qr_code"] ?? "",
//   //       "gross_weight": e["gross_weight"] ?? "",
//   //       "other_weight": e["other"] ?? "",
//   //       "net_weight": e["net_weight"] ?? "",
//   //       "purity": e["item"]?["outward_carat"] ?? "",
//   //       "waste": "",
//   //       "net_purity": e["item"]?["outward_carat"] ?? "",
//   //       "fine_weight": "",
//   //       "metal_rate": "",
//   //       "labour_rate": "",
//   //       "expanded": false,
//   //     });
//   //
//   //     /// 🔥 CLEAR SEARCH
//   //     searchController.clear();
//   //     searchResults.clear();
//   //   });
//   // }
//
//   void addItemToCard(dynamic e) {
//     final itemsetId = e["id"];
//
//     // ✅ Check if item already exists in ANY list (Manual, Approval, or Scan)
//     bool isDuplicate = items.any((item) => item["id"] == itemsetId) ||
//         approvalAddedItems.any((item) => item["itemset_id"] == itemsetId || item["approval_item_id"] == itemsetId) ||
//         cartItems.any((item) => item["id"] == itemsetId || item["itemset_id"] == itemsetId);
//
//     if (isDuplicate) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Item already added to the list"),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       setState(() {
//         searchController.clear();
//         searchResults.clear();
//       });
//       return;
//     }
//
//     setState(() {
//       /// 🔥 API LIST ma add karo
//       if (!finalItems.any((item) => item["itemset_id"] == itemsetId)) {
//         finalItems.add({
//           "source": e["source"] ?? "sale",
//           "itemset_id": itemsetId,
//           "total_amount": e["total_amount"] ?? 0,
//         });
//       }
//
//       /// 🔥 UI LIST ma add karo
//       items.add({
//         "id": e["id"],
//         "item_name": e["item"]?["item_name"] ?? "",
//         "huid": e["HUID"] ?? "",
//         "qr_code": e["qr_code"] ?? "",
//         "gross_weight": e["gross_weight"] ?? "",
//         "other_weight": e["other_weight"] ?? "",
//         "net_weight": e["net_weight"] ?? "",
//         "purity": e["purity"] ?? "",
//         "waste": e["waste_percent"] ?? "",
//         "net_purity": e["net_purity"]?? "",
//         "fine_weight":e["fine_weight"]?? "",
//         "metal_rate":e["metal_rate"]?? "",
//         "metal_amount":e["metal_amount"]?? "",
//         "labour_rate": e["labour_rate"]?? "",
//         "labour_amount": e["labour_amount"]?? "",
//         "other_amount": e["other_amount"]?? "",
//         "total_amount": e["total_amount"]?? "",
//         "expanded": false,
//       });
//
//       /// 🔥 CLEAR SEARCH
//       searchController.clear();
//       searchResults.clear();
//       updateFinalItems();
//     });
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
//       "${ApiConstants.label_Approval_list}?customer_id=$customerId",
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
//           updateFinalItems(); // ✅ parent ma call
//           setState(() {
//
//           });
//         }
//       }else{
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Data Not Found"),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//   void addSelectedItems(Set<int> selectedIds, List allItems) {
//
//     List selectedData = allItems.where((item) {
//       int id = int.tryParse(item["approval_item_id"].toString()) ?? 0;
//       return selectedIds.contains(id);
//     }).toList();
//
//     setState(() {
//       for (var item in selectedData) {
//
//         final itemsetId = item["itemset_id"];
//         final approvalId = item["approval_item_id"];
//
//         /// 🔥 API LIST
//         if (!finalItems.any((e) => e["approval_item_id"] == approvalId)) {
//           finalItems.add({
//             "source": item["source"] ?? "approval", // ✅ API mathi
//             "approval_item_id": approvalId,
//             "total_amount": item["total_amount"] ?? 0, // ✅ API mathi
//           });
//         }
//
//
//
//         /// 🔥 UI LIST
//         if (!approvalAddedItems.any(
//                 (e) => e["approval_item_id"] == approvalId)) {
//
//           approvalAddedItems.add(item);
//         }
//       }
//     });
//   }
//
//
//
//   Future<Set<int>?> showApprovalDialog(List items) async {
//     // String val(dynamic v) => v == null ? "-" : v.toString();
//     //
//     // List items = item["items"] ?? []; // ✅ correct list
//     selectedItems.clear(); // ✅ IMPORTANT
//     List filteredItems = List.from(items);
//     bool showScanner = false; // ✅ OUTSIDE builder
//     TextEditingController approvesearchController = TextEditingController();
//     return showDialog<Set<int>>(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//
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
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       /// 🔝 HEADER
//                       Row(
//                         children: [
//                           const Text(
//                             "Approval Items Return",
//                             style: TextStyle(
//                               fontSize: 18,
//                               color: Colors.black,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const Spacer(),
//                           InkWell(
//                             onTap: () {
//                               setState(() {
//                                 showScanner = !showScanner;
//                               });
//                             },
//                             borderRadius: BorderRadius.circular(5),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(vertical: 5,horizontal: 5),
//                               decoration: BoxDecoration(
//                                 gradient: const LinearGradient(
//                                   colors: [Color(0xffE6C58A), Color(0xffC8A96A)],
//                                 ),
//                                 borderRadius: BorderRadius.circular(5),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: const Color(0xffC8A96A).withOpacity(0.4),
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 3),
//                                   ),
//                                 ],
//                               ),
//                               child: const Center(
//                                 child: Icon(
//                                   Icons.qr_code_scanner,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           InkWell(
//                             onTap: () => Navigator.pop(context),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 6,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.black,
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                               child: const Text(
//                                 "Back",
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 12),
//                       /// 🔍 SEARCH FIELD
//                       TextField(
//                         controller: approvesearchController,
//                         style: TextStyle(color: Colors.black),
//                         onChanged: (value) {
//                           setState(() {
//                             if (value.isEmpty) {
//                               filteredItems = items;
//                             } else {
//                               filteredItems = items.where((item) {
//                                 final name = item["name"]?.toString().toLowerCase() ?? "";
//                                 final code = item["code"]?.toString().toLowerCase() ?? "";
//                                 final huid = item["HUID"]?.toString().toLowerCase() ?? "";
//
//                                 return name.contains(value.toLowerCase()) ||
//                                     code.contains(value.toLowerCase()) ||
//                                     huid.contains(value.toLowerCase());
//                               }).toList();
//                             }
//                           });
//                         },
//                         decoration: InputDecoration(
//                           hintText: "Search Item",
//                           hintStyle: TextStyle(color: Colors.black),
//                           prefixIcon: const Icon(Icons.search, color: Colors.black54),
//                           filled: true,
//                           fillColor: Colors.white,
//                           contentPadding: const EdgeInsets.symmetric(vertical: 0),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide(color: Colors.grey.shade300),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide(color: Colors.grey.shade300),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       /// 🔥 SCANNER (BETWEEN SEARCH & LIST)
//                       AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 300),
//                         transitionBuilder: (child, animation) {
//                           final offsetAnimation = Tween<Offset>(
//                             begin: const Offset(0, -1), // TOP thi start
//                             end: Offset.zero,           // normal position
//                           ).animate(animation);
//
//                           return ClipRRect(
//                             borderRadius: BorderRadius.circular(12),
//                             child: SlideTransition(
//                               position: offsetAnimation,
//                               child: child,
//                             ),
//                           );
//                         },
//                         child: showScanner
//                             ? Center(
//                           child: Container(
//                             key: const ValueKey("scanner"),
//                             height: 150,
//                             width: 150,
//                             margin: const EdgeInsets.only(bottom: 12),
//                             decoration: BoxDecoration(
//                               color: Colors.black,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Stack(
//                               children: [
//                                 _buildScannerSection(),
//                                 _ScannerLineAnimation(),
//                               ],
//                             ),
//                           ),
//                         )
//                             : const SizedBox(key: ValueKey("empty")),
//                       ),
//                       /// 🔥 LIST
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.30,
//                         child: ListView.builder(
//                           itemCount: filteredItems.length, // ✅ FIX
//                           itemBuilder: (context, index) {
//                             final item = filteredItems[index];
//
//                             final id =
//                                 int.tryParse(
//                                   item["approval_item_id"].toString(),
//                                 ) ??
//                                     0;
//                             final code = item["code"] ?? "-";
//                             final name = item["name"] ?? "-";
//                             final gross = item["gross_weight"]?.toString() ?? "-";
//
//                             final isSelected = selectedItems.contains(id);
//
//                             return Container(
//                               margin: const EdgeInsets.symmetric(vertical: 4),
//                               padding: const EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: Colors.grey.shade300),
//                               ),
//                               child: Row(
//                                 children: [
//                                   /// ✅ CHECKBOX
//                                   Checkbox(
//                                     value: isSelected,
//                                     activeColor: const Color(0xffC8A96A),
//                                     onChanged: (value) {
//                                       setState(() {
//                                         if (value == true) {
//                                           selectedItems.add(id);
//                                         } else {
//                                           selectedItems.remove(id);
//                                         }
//                                       });
//                                     },
//                                   ),
//
//                                   /// 🔹 TEXT
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                       CrossAxisAlignment.start,
//                                       children: [
//                                         /// Row 1
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: Text(
//                                                 "Name: $name",
//                                                 style: TextStyle(
//                                                   fontSize: 12,
//                                                   color: Colors.black, // ✅ FIX
//                                                 ),
//                                                 overflow: TextOverflow.ellipsis,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 4),
//                                             Expanded(
//                                               child: Text(
//                                                 "Code: $code",
//                                                 style: TextStyle(
//                                                   fontSize: 12,
//                                                   color: Colors.black, // ✅ FIX
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//
//                                         /// Row 2
//                                         Text(
//                                           "Gross: $gross",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.black, // ✅ FIX
//                                           ),
//                                         ),
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
//
//
//                       const SizedBox(height: 12),
//
//                       /// CLOSE BUTTON
//                       InkWell(
//                         onTap: () {
//                           Navigator.pop(context, selectedItems);
//                           /// 🔥 CLOSE KEYBOARD
//                           FocusManager.instance.primaryFocus?.unfocus();
//                         },
//                         child: Center(
//                           child: Container(
//                             width: 100,
//                             height: 40,
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 6,
//                             ),
//                             decoration: BoxDecoration(
//                               gradient: const LinearGradient(
//                                 colors: [Color(0xffC8A96A), Color(0xffE6C58A)],
//                                 begin: Alignment.topLeft,
//                                 end: Alignment.bottomRight,
//                               ),
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                             child: Center(
//                               child: const Text(
//                                 "Add",
//                                 style: TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 16,
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
//   }
//
//   Widget approvalItemCard(Map<String, dynamic> item, int index,int totalCount) {
//     bool isExpanded = item["expanded"] ?? false;
//
//     return Stack(
//       children: [
//         Container(
//           margin: const EdgeInsets.symmetric(vertical: 4),
//           padding: const EdgeInsets.only(left: 12, right: 12, top: 3),
//           decoration: BoxDecoration(
//             color: const Color(0xffFAF7F2).withOpacity(0.95),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: const Color(0xffE5DDD0)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               /// 🔝 HEADER
//               Row(
//                 children: [
//                   const SizedBox(width: 30),
//                   Text(
//                     "Item : ${item["name"] ?? item["item_name"] ?? "Item"}",
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                       color: Colors.black,
//                     ),
//                   ),
//                   const Spacer(),
//                   Text(
//                     "${item["qr_code"]
//                         ?? item["itemset"]?["qr_code"]
//                         ?? item["code"]
//                         ?? item["itemset"]?["barcode"]
//                         ?? "-"}",
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                       color: Colors.black,
//                     ),
//                   ),
//                   const Spacer(),
//
//                   InkWell(
//                     // Inside approvalItemCard widget's delete button InkWell:
//                     onTap: () {
//                       setState(() {
//                         final approvalId = item["approval_item_id"];
//                         final itemId = item["id"];
//
//                         if (approvalId != null) {
//                           // 1. Remove from Return Approval items list
//                           approvalAddedItems.removeWhere((e) => e["approval_item_id"] == approvalId);
//                         } else if (item["source"] == "sale") {
//                           // 2. Handle Scanned items (Cart items)
//                           deleteUser(itemId.toString()); // API Call
//                           cartItems.removeWhere((e) => e["id"] == itemId);
//                         } else {
//                           // 3. Remove from Manual Search items list
//                           items.removeWhere((e) => e["id"] == itemId);
//                         }
//                       });
//                     },
//                     borderRadius: BorderRadius.circular(10),
//                     child: Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         gradient: const LinearGradient(
//                           colors: [
//                             Color(0xffFF8A80),
//                             Color(0xffD32F2F),
//                           ],
//                         ),
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: const Icon(
//                         Icons.delete,
//                         color: Colors.white,
//                         size: 14,
//                       ),
//                     ),
//                   ),
//
//                 ],
//               ),
//
//               const SizedBox(height: 10),
//
//               /// 🔥 COLLAPSED = HORIZONTAL SCROLL
//               if (!isExpanded)
//                 SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: [
//                       _miniField("Gross", item, "gross_weight"),
//                       _miniField("Other", item, "other_weight"),
//                       _miniField("Net", item, "net_weight"),
//                       _miniField("Purity", item, "purity"),
//                       _miniField("Waste", item, "waste"),
//                       _miniField("Net Purity", item, "net_purity"),
//                       _miniField("Fine", item, "fine_weight"),
//                       _miniField("Metal Rate", item, "metal_rate"),
//                       _miniField("Metal Amount", item, "metal_amount"),
//                       _miniField("Labour rate", item, "labour_rate"),
//                       _miniField("La.amuount", item, "labour_amount"),
//                       _miniField(
//                         "Other Amount",
//                         item,
//                         "other_amount",
//                       ),
//                       _miniField("Total Amount", item, "total_amount"),
//                     ],
//                   ),
//                 ),
//               const SizedBox(height: 8),
//
//               // /// 🔹 ALWAYS VISIBLE
//               // Row(
//               //   children: [
//               //     Expanded(child: _inputField("Gross Wt", item, "gross_weight")),
//               //     const SizedBox(width: 8),
//               //     Expanded(child: _inputField("Net Wt", item, "net_weight")),
//               //   ],
//               // ),
//               // const SizedBox(height: 8),
//               // Row(
//               //   children: [
//               //     Expanded(child: _inputField("Gross Wt", item, "gross_weight")),
//               //     const SizedBox(width: 8),
//               //     Expanded(child: _inputField("Net Wt", item, "net_weight")),
//               //   ],
//               // ),
//
//               /// 🔽 EXPAND PART
//             ],
//           ),
//         ),
//         /// 🔥 TOP LEFT INDEX BADGE
//         Positioned(
//           top: 5,
//           left: 0,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//             decoration: const BoxDecoration(
//               color: Color(0xffC8A96A),
//               borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(5),
//                 bottomRight: Radius.circular(5),
//               ),
//             ),
//             child: Text(
//               "${totalCount - index}", // 🔥 હવે અહીં સ
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget buildUserCard(Map item) {
//     final size = MediaQuery.of(context).size;
//     final isTablet = size.width >= 600;
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
//
//           /// STATUS + ACTIONS ROW
//           Row(
//             children: [
//               statusChip(item["metal"].toString()),
//               const Spacer(),
//
//               Row(
//                 children: [
//                   premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),
//
//                   SizedBox(width: isTablet ? 10 : 8),
//
//                   premiumIconBtn(Icons.delete, Colors.red, onTap: () {
//                     setState(() {
//                       _showDeleteDialog(item);
//                     });
//                   }),
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
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color: Colors.black,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 item["qr_code"] ?? "",
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
//                   item["gross_weight"] ?? "-",
//                   "Net",
//                   (item["net_weight"] == "0.000" || item["net_weight"] == null)
//                       ? "-"
//                       : item["net_weight"],
//                 ),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 _erpRow(
//                   "Purity",
//                   item["purity"] ?? "-",
//                   "Amount",
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
//
//
//   Widget _miniField(String title, Map<String, dynamic> item, String key) {
//     final isOtherField = key == "other_amount";
//     /// 🔥 CHANGE HERE
//     final isMetalRateField = key == "metal_rate";
//     final isLabourRateField = key == "labour_rate";
//     final controller = getController(item, key);
//
//     return Container(
//       width: 90,
//       margin: const EdgeInsets.only(right: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title,
//               style: const TextStyle(fontSize: 12, color: Colors.black54)),
//           const SizedBox(height: 4),
//
//           Stack(
//             alignment: Alignment.centerRight,
//             children: [
//
//               TextFormField(
//                 controller: controller,
//                 /// 🔥 READONLY LOGIC
//                 readOnly: key == "metal_rate"
//                     ? !(item["manual_metal"] ?? true)
//                     : key == "labour_rate"
//                     ? !(item["manual_labour"] ?? true)
//                     : !isEditableField(key),
//                 keyboardType: TextInputType.number,
//                 enableInteractiveSelection: isEditableField(key), // 🔥 ADD THIS
//                 showCursor: isEditableField(key),        // 🔥 ADD
//                 canRequestFocus: isEditableField(key),   // 🔥 ADD (MAIN FIX)
//                 style: const TextStyle(color: Colors.black, fontSize: 12),
//
//                 onTap: () {
//                   if (controller.text == "0" || controller.text == "0.0") {
//                     controller.clear();
//                   } else {
//                     /// 🔥 FULL TEXT SELECT (best UX)
//                     controller.selection = TextSelection(
//                       baseOffset: 0,
//                       extentOffset: controller.text.length,
//                     );
//                   }
//                 },
//                 onEditingComplete: () {
//                   if (controller.text.isEmpty) {
//                     controller.text = "0";
//                   }
//                 },
//
//                 onChanged: (val) {
//                   item[key] = val;
//
//                   calculateItem(item);
//                   updateFinalItems(); // 🔥 ADD THIS
//                   setState(() {});
//                 },
//
//                 decoration: InputDecoration(
//                   isDense: true,
//                   contentPadding: const EdgeInsets.only(
//                     left: 6,
//                     right: 24,
//                     top: 6,
//                     bottom: 6,
//                   ),
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: InputBorder.none,
//                 ),
//               ),
//
//               /// 🔥 OTHER BUTTON
//               if (isOtherField)
//                 Positioned(
//                   right: 2,
//                   child: InkWell(
//                     onTap: () async {
//                       FocusManager.instance.primaryFocus?.unfocus();
//
//                       await getreturnDetails(item["id"], item);
//
//                       /// 🔥 ADD THIS (AFTER AWAIT)
//                       Future.delayed(Duration(milliseconds: 100), () {
//                         FocusManager.instance.primaryFocus?.unfocus();
//                       });
//
//                       /// 🔥 update controller
//                       controller.text = item["other_amount"] ?? "0";
//
//                       calculateItem(item);
//                       updateFinalItems(); // 🔥 ADD THIS
//                       setState(() {});
//                     },
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: const Color(0xffC8A96A),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: const Icon(Icons.add, size: 14, color: Colors.white),
//                     ),
//                   ),
//                 ),
//
//               if (isMetalRateField)
//                 Positioned(
//                   right: 4,
//                   top: 5,
//                   child: SizedBox(
//                     height: 20,
//                     width: 16,
//                     child: Checkbox(
//                       /// 🔥 FIX: controller base karo
//                       value: (double.tryParse(
//                           controller.text.isEmpty ? "0" : controller.text) ??
//                           0) >
//                           0,
//
//                       onChanged: (val) {
//                         setState(() {
//                           if (val == true) {
//                             /// 🔥 ON → jo 0 hoy to default aapo
//                             if ((double.tryParse(controller.text.isEmpty
//                                 ? "0"
//                                 : controller.text) ??
//                                 0) ==
//                                 0) {
//                               controller.text = "1";
//                               item["metal_rate"] = "1";
//                             }
//                           } else {
//                             /// 🔥 OFF → 0 set
//                             controller.text = "0.00";
//                             item["metal_rate"] = "0.00";
//                           }
//
//                           updateController(item, "metal_rate");
//
//                           calculateItem(item);
//                           updateFinalItems();
//                         });
//                       },
//                     ),
//                   ),
//                 ),
//
//
//
//
//               /// 🔥 LABOUR RATE CHECKBOX
//               if (isLabourRateField)
//                 Positioned(
//                   right: 4,
//                   top: 5,
//                   child: SizedBox(
//                     height: 20,
//                     width: 16,
//                     child: Checkbox(
//                       /// 🔥 CONTROLLER BASED VALUE
//                       value: (double.tryParse(
//                           controller.text.isEmpty ? "0" : controller.text) ??
//                           0) >
//                           0,
//
//                       onChanged: (val) {
//                         setState(() {
//                           if (val == false) {
//                             /// 🔥 OFF → 0 set
//                             controller.text = "0.00";   // ✅ IMPORTANT
//                             item["labour_rate"] = "0.00";
//                           } else {
//                             /// 🔥 ON → jo 0 hoy to empty rehva do (user fill kare)
//                             if ((double.tryParse(controller.text.isEmpty
//                                 ? "0"
//                                 : controller.text) ??
//                                 0) ==
//                                 0) {
//                               controller.clear(); // optional UX better
//                             }
//                           }
//
//                           updateController(item, "labour_rate");
//
//                           calculateItem(item);
//                           updateFinalItems();
//                         });
//                       },
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
//
//
//   Future<void> savefinalizeBulkItems() async {
//     if (selectedUserId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please select Customer")),
//       );
//       return;
//     }
//
//     /// 🔥 FIRST UPDATE DATA
//     updateFinalItems();
//     // /// 1. Scanner mathi aavela data ne format karo
//     // final preparedScanItems = cartItems.map((item) {
//     //   return {
//     //     "source": "sale",
//     //     "itemset_id": item["itemset_id"],
//     //     "total_amount": item["amount"] ?? 0,
//     //   };
//     // }).toList();
//
//     // /// 2. 🔥 Badha items ne ek j Array ma bhega (Combine) karo
//     // final allItemsToSave = [
//     //   ...finalItems,        // Search ane Approval mathi aavelo data
//     //   ...preparedScanItems, // Scanner mathi aavelo data
//     // ];
//
//     final allItemsToSave = [
//       ...finalItems,        // Search ane Approval mathi aavelo data
//     ];
//
//     if (allItemsToSave.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("No items to save")),
//       );
//       return;
//     }
//
//     final body = {
//       "customer_id": int.parse(selectedUserId!),
//       "items": allItemsToSave, // ✅ Have badho data ek sathe jase
//     };
//
//     print("📤 REQUEST BODY: $body");
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.returns_store,
//       body,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Saved successfully")),
//       );
//       // Success pachi lists clear kari shakiye
//       setState(() {
//         finalItems.clear();
//         cartItems.clear();
//         approvalAddedItems.clear();
//         items.clear();
//       });
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to Save Data")),
//       );
//     }
//   }
//
//   bool isProcessing = false;
//   String? lastCode;
//   bool isBusy = false;
//   Widget _buildScannerSection() {
//
//     double scannerSize = MediaQuery.of(context).size.width * 0.4;
//
//     if (MediaQuery.of(context).size.width > 600) {
//       scannerSize = 350; // tablet
//     }
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
//           controller: MobileScannerController(
//             detectionSpeed: DetectionSpeed.unrestricted, // ⚡ FAST
//             formats: [BarcodeFormat.qrCode], // 🔥 only QR
//           ),
//           onDetect: (barcodeCapture) {
//             for (final barcode in barcodeCapture.barcodes) {
//               final String? code = barcode.rawValue;
//
//               if (code == null) return;
//
//               /// 🔥 SAME CODE IGNORE
//               if (lastCode == code) return;
//
//               /// 🔥 API RUNNING → IGNORE
//               if (isBusy) return;
//
//               lastCode = code;
//               isBusy = true;
//
//               print("⚡ FAST SCAN: $code");
//
//               /// 🔊 SOUND
//               //playScanSound();
//
//               /// 🔥 API CALL (NO await → FAST)
//               scanApiCall(code);
//
//               /// 🔥 SMALL RESET DELAY
//               Future.delayed(const Duration(milliseconds: 300), () {
//                 isBusy = false;
//               });
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   Future<void> scanApiCall(String code) async {
//
//     Map<String, dynamic> body = {
//       "qr_code": code,
//       "customer_id":int.parse(selectedUserId.toString())
//     };
//
//     print("📤 API URL: ${ApiConstants.return_Qr_Sale}");
//     print("📤 Request Body: $body");
//
//     final response = await ApiHelper().postRequest(
//         ApiConstants.return_Qr_Sale,
//         body
//     );
//
//     if (response != null) {
//
//       print("📥 Status Code: ${response.statusCode}");
//       print("📥 Response Data: ${response.data}");
//
//       if (response.statusCode == 200) {
//
//         /// ✅ Success Message
//         ///
//         if(response.data["success"] == true){
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Item Scan Successfully"),
//               backgroundColor: Colors.green,
//               duration: Duration(seconds: 2),
//             ),
//           );
//           /// ✅ SUCCESS pachi cart list refresh
//           await getCartItems();
//         }else{
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(response.data['message'].toString()),
//               backgroundColor: Colors.green,
//               duration: const Duration(seconds: 2),
//             ),
//           );
//           //await getCartItems();
//         }
//
//
//
//       } else {
//
//         print("❌ Scan Failed");
//
//       }
//
//     } else {
//
//       print("❌ Response NULL");
//
//     }
//
//   }
//
//   Future<void> getCartItems() async {
//
//     final response =
//     await ApiHelper().getRequest(ApiConstants.return_Qr_list);
//
//     print("Cart API URL: https://ornasphere.com/api/sales/cart-items");
//     print("Cart Raw Response: ${response.toString()}");
//
//     if (response != null && response.statusCode == 200) {
//
//       final List data = response.data["data"]; // 🔥 important
//
//       setState(() {
//         cartItems = data;
//
//         for (var item in cartItems) {
//
//           print("🟡 RAW ITEM: $item");
//
//           /// 🔥 DIRECT mapping (NO itemset)
//           item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
//           item["other_weight"] = "0"; // API માં નથી
//           item["net_weight"] = item["net_weight"]?.toString() ?? "0";
//
//           item["labour_rate"] = "0";
//           item["labour_amount"] = "0";
//
//           item["metal_rate"] = "0";
//           item["other_amount"] = "0";
//
//           /// 🔥 amount → total_amount
//           item["total_amount"] = item["amount"]?.toString() ?? "0";
//
//           print("🟢 MAPPED ITEM: $item");
//
//           /// 🔥 controller sync
//           setController(item, "gross_weight", item["gross_weight"]);
//           setController(item, "other_weight", item["other_weight"]);
//           setController(item, "metal_rate", item["metal_rate"]);
//           setController(item, "labour_rate", item["labour_rate"]);
//           setController(item, "other_amount", item["other_amount"]);
//           setController(item, "total_amount", item["total_amount"]);
//
//           /// 🔥 calculation
//           calculateItem(item);
//
//           /// 🔥 IMPORTANT: loop બહાર call કર
//           updateFinalItems();
//         }
//
//       });
//
//
//       print("Total Cart Items: ${cartItems.length}");
//
//     } else {
//
//       setState(() {
//         cartItems = [];
//       });
//
//       print("Cart API Failed");
//
//     }
//   }
//
//   void setController(Map<String, dynamic> item, String key, String value) {
//     final controller = getController(item, key);
//     controller.text = value;
//   }
//
//   Widget _erpRow(String t1, String v1, String t2, String v2) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//       child: Row(
//         children: [
//
//           /// Left Field
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 3,
//                   child: Text(
//                     t1,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.black, // ✅ FIX
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 4,
//                   child: Text(
//                     v1,
//                     style: const TextStyle(
//                       fontSize: 12,
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
//                       fontSize: 12,
//                       overflow: TextOverflow.ellipsis,
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
//   Widget statusChip(String status) {
//
//     Color startColor;
//     Color endColor;
//     String label;
//
//     switch (status.toLowerCase()) {
//
//       case "gold":
//         startColor = const Color(0xffC8A96A);
//         endColor   = const Color(0xffE6C58A);
//         label = "Gold";
//         break;
//
//       case "silver":
//         startColor = const Color(0xffD9534F);
//         endColor   = const Color(0xffF28B82);
//         label = "Silver";
//         break;
//
//       case "platinum":
//         startColor = const Color(0xffB07A3F);
//         endColor   = const Color(0xffE0A96D);
//         label = "Platinum";
//         break;
//
//       case "other":
//         startColor = const Color(0xff7B5E57);
//         endColor   = const Color(0xffBCAAA4);
//         label = "Other";
//         break;
//
//       default:
//         startColor = const Color(0xff9E9E9E);
//         endColor   = const Color(0xffCFCFCF);
//         label = "Unknown";
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [startColor, endColor],
//         ),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.4),
//           width: 0.8,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           )
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//
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
//
//
//   Widget premiumIconBtn(IconData icon, Color color, {required VoidCallback onTap}) {
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
//                 border: Border.all(
//                   color: Colors.white.withOpacity(0.2),
//                 ),
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
//
//                   /// 🔥 Delete Icon
//                   Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: LinearGradient(
//                         colors: [
//                           Color(0xffff4e50),
//                           Color(0xfff00000),
//                         ],
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
//
//                       /// Cancel Button
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.grey.shade800,
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
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
//                                 borderRadius: BorderRadius.circular(12)),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           onPressed: () async {
//
//                             Navigator.pop(context); // close dialog
//
//                             deleteUser(user["cart_id"].toString()); // Your API call
//
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
//             scale: CurvedAnimation(
//               parent: anim,
//               curve: Curves.easeOutBack,
//             ),
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
//         "${ApiConstants.returns_cart_remove}/$ID",
//       );
//
//       if (response?.statusCode == 200) {
//         print("✅ Deleted Successfully");
//         print("Response: ${response?.data}");
//
//         getCartItems();
//
//       } else {
//         print("❌ Logout failed | Status: ${response?.statusCode}");
//       }
//
//     } catch (e) {
//       print("❌ Logout exception: $e");
//     }
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
//     double purity =
//         double.tryParse(getController(item, "purity").text) ?? 0;
//
//     double waste =
//         double.tryParse(getController(item, "waste").text) ?? 0;
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
//       metalAmount = net * metalRate;
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
//
//     //double metalAmount = net * metalRate;
//     // double labourAmount = net * labourRate;
//
//     double totalAmount = metalAmount + labourAmount + otherAmount;
//
//
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
//
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
//
//   bool isEditableField(String key) {
//     return [
//       "gross_weight",
//       "other_weight",
//       "purity",
//       "waste",
//       "labour_rate",
//       "metal_rate",
//       //"other_amount"
//     ].contains(key);
//   }
//
//   Future<void> getreturnDetails(dynamic id, Map<String, dynamic> mainItem) async {
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(
//       ApiConstants.other_charge,
//     );
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//
//       /// 🔥 BYTES → STRING → JSON
//       final data = response.data;
//
//       final item = data["data"] is List
//           ? data["data"][0]
//           : data["data"];
//
//       showOtherChargesPopup(
//         mainItem, // 🔥 ORIGINAL ITEM
//         data["data"], // 🔥 API LIST
//       );
//
//
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to load details")),
//       );
//     }
//   }
//
//   void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
//
//     /// 🔥 MAP API → UI STRUCTURE
//     List<Map<String, dynamic>> charges =
//     apiList.map<Map<String, dynamic>>((e) {
//       return {
//         "charge": e["name"] ?? "",
//         "amount": (e["default_amount"] ?? 0).toString(),
//         "qty": (e["quantity_pcs"] ?? 1).toString(),
//         "weight": "0.0", // 🔥 NEW FIELD
//
//         "wt_formula":
//         (e["weight_formula"] == "per_quantity") ? "per_qty" : "flat",
//
//         "amt_formula":
//         (e["weight_formula"] == "per_quantity") ? "per_qty" : "flat",
//
//         //"amt_formula": "",
//         "total_weight": "0.0",
//         "total_amt": "0",
//         "is_selected": false,
//       };
//     }).toList();
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return Dialog(
//           backgroundColor: const Color(0xffF8F5F0),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           insetPadding:
//           const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
//           child: StatefulBuilder(
//             builder: (context, setStateDialog) {
//
//               /// 🔥 CALCULATION
//               // void calculateCharges() {
//               //   for (var c in charges) {
//               //     double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//               //     double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//               //     double weight = double.tryParse(c["weight"]?.toString() ?? "1") ?? 1;
//               //
//               //     String formula = c["amt_formula_type"] ?? "flat";
//               //
//               //     double total = 0;
//               //     double totalWeight = 0;
//               //
//               //     switch (formula) {
//               //       case "flat":
//               //         total = amt;
//               //         c["amt_formula"] = "$amt";
//               //         break;
//               //
//               //       case "per_qty":
//               //         total = amt * qty;
//               //         c["amt_formula"] = "$amt × $qty";
//               //         break;
//               //
//               //       case "per_weight":
//               //         total = amt * weight;
//               //         c["amt_formula"] = "$amt × $weight";
//               //         break;
//               //
//               //       case "per_qty_weight":
//               //         total = amt * qty * weight;
//               //         c["amt_formula"] = "$amt × $qty × $weight";
//               //         break;
//               //
//               //       default:
//               //         total = amt;
//               //         c["amt_formula"] = "$amt";
//               //     }
//               //
//               //     c["total_amt"] = total.toStringAsFixed(2);
//               //   }
//               // }
//
//               void calculateCharges() {
//                 for (var c in charges) {
//                   double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//                   double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//                   double weight = double.tryParse(c["weight"]?.toString() ?? "1") ?? 1;
//
//                   String amtFormula = c["amt_formula_type"] ?? "flat";
//                   String wtFormula = c["wt_formula"] ?? "flat";
//
//                   double totalAmt = 0;
//                   double totalWeight = 0;
//
//                   /// 🔥 TOTAL WEIGHT CALCULATION
//                   switch (wtFormula) {
//                     case "flat":
//                       totalWeight = weight;
//                       break;
//
//                     case "per_qty":
//                       totalWeight = weight * qty;
//                       break;
//
//                     case "per_weight":
//                       totalWeight = weight; // 🔥 simple weight
//                       break;
//
//                     default:
//                       totalWeight = weight;
//                   }
//
//
//                   c["total_weight"] = totalWeight.toStringAsFixed(2);
//
//                   /// 🔥 TOTAL AMOUNT CALCULATION
//                   switch (amtFormula) {
//                     case "flat":
//                       totalAmt = amt;
//                       c["amt_formula"] = "$amt";
//                       break;
//
//                     case "per_qty":
//                       totalAmt = amt * qty;
//                       c["amt_formula"] = "$amt × $qty";
//                       break;
//
//                     case "per_weight":
//                       totalAmt = amt * totalWeight; // 🔥 USE TOTAL WEIGHT
//                       c["amt_formula"] = "$amt × $totalWeight";
//                       break;
//
//                     case "per_qty_weight":
//                       totalAmt = amt * qty * weight;
//                       c["amt_formula"] = "$amt × $qty × $weight";
//                       break;
//
//                     default:
//                       totalAmt = amt;
//                       c["amt_formula"] = "$amt";
//                   }
//
//                   c["total_amt"] = totalAmt.toStringAsFixed(2);
//                 }
//               }
//
//
//
//
//               calculateCharges();
//
//               /// ✅ 👉 AHI ADD KARVU (IMPORTANT)
//               double total = charges.fold(
//                 0,
//                     (sum, c) {
//                   if (c["is_selected"] == true) {
//                     return sum + (double.tryParse(c["total_amt"] ?? "0") ?? 0);
//                   }
//                   return sum;
//                 },
//               );
//
//               return SizedBox(
//                 width: double.infinity,
//                 child: Container(
//                   padding: const EdgeInsets.all(14),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//
//                       /// 🔝 HEADER
//                       const Text(
//                         "Other Charges",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                         ),
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       /// 🔹 TABLE
//                       SingleChildScrollView(
//                         scrollDirection: Axis.horizontal,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//
//                             /// HEADER ROW
//                             Container(
//                               padding:
//                               const EdgeInsets.symmetric(vertical: 8),
//                               decoration: BoxDecoration(
//                                 gradient: const LinearGradient(
//                                   colors: [
//                                     Color(0xffE6C58A),
//                                     Color(0xffC8A96A),
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                               child: Row(
//                                 children: const [
//                                   SizedBox(width: 100, child: Padding(
//                                     padding: EdgeInsets.symmetric(horizontal: 6),
//                                     child: Text("Charge",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, ),),
//                                   )),
//                                   SizedBox(width: 80, child: Center(child: Text("Amt",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 70, child: Center(child: Text("Qty",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 90, child: Center(child: Text("Weight",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 110, child: Center(child: Text("Wt Formula",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 110, child: Center(child: Text("Total weight",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 110, child: Center(child: Text("Amt Formula",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 110, child: Center(child: Text("Total Amt",style: TextStyle( fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, )))),
//                                   SizedBox(width: 40),
//                                 ],
//                               ),
//                             ),
//
//                             const SizedBox(height: 8),
//
//                             /// LIST
//                             SizedBox(
//                               height: 180,
//                               width: 850,
//                               child: ListView.builder(
//                                 itemCount: charges.length,
//                                 itemBuilder: (context, index) {
//                                   var c = charges[index];
//
//                                   return Container(
//                                     margin:
//                                     const EdgeInsets.only(bottom: 6),
//                                     padding:
//                                     const EdgeInsets.symmetric(vertical: 6),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius:
//                                       BorderRadius.circular(6),
//                                       border: Border.all(
//                                           color: Colors.grey.shade200),
//                                     ),
//                                     child: Row(
//                                       children: [
//
//                                         /// Charge
//                                         SizedBox(
//                                           width: 100,
//                                           child: Padding(
//                                             padding: const EdgeInsets.symmetric(horizontal: 6),
//                                             child: Text(c["charge"],style: TextStyle( fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black, )),
//                                           ),
//                                         ),
//
//                                         /// Amount
//                                         SizedBox(
//                                           width: 80,
//                                           child: TextFormField(
//                                             initialValue: c["amount"],
//                                             style: TextStyle( fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black, ),
//                                             onChanged: (v) {
//                                               c["amount"] = v;
//                                               setStateDialog(() {});
//                                             },
//                                             keyboardType: TextInputType.number,
//                                             textAlign: TextAlign.center,
//                                             decoration: const InputDecoration(
//                                               isDense: true,
//                                               border: OutlineInputBorder(),
//                                             ),
//                                           ),
//                                         ),
//
//                                         const SizedBox(width: 6),
//
//                                         /// Qty
//                                         SizedBox(
//                                           width: 70,
//                                           child: TextFormField(
//                                             initialValue: c["qty"],
//                                             style: TextStyle( fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black, ),
//                                             onChanged: (v) {
//                                               c["qty"] = v;
//                                               setStateDialog(() {});
//                                             },
//                                             keyboardType: TextInputType.number,
//                                             textAlign: TextAlign.center,
//                                             decoration: const InputDecoration(
//                                               isDense: true,
//                                               border: OutlineInputBorder(),
//                                             ),
//                                           ),
//                                         ),
//
//                                         const SizedBox(width: 6),
//
//                                         /// 🔥 WEIGHT
//                                         SizedBox(
//                                           width: 90,
//                                           child: TextFormField(
//                                             initialValue: c["weight"],
//                                             style: TextStyle( fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black, ),
//                                             onChanged: (v) {
//                                               c["weight"] = v;
//                                               setStateDialog(() {});
//                                             },
//                                             keyboardType: TextInputType.number,
//                                             textAlign: TextAlign.center,
//                                             decoration: const InputDecoration(
//                                               isDense: true,
//                                               border: OutlineInputBorder(),
//                                             ),
//                                           ),
//                                         ),
//
//                                         const SizedBox(width: 6),
//
//                                         /// 🔥 WT FORMULA DROPDOWN
//                                         SizedBox(
//                                           width: 100,
//                                           child: DropdownButtonFormField<String>(
//                                             value: c["wt_formula"],
//                                             dropdownColor: Colors.white,
//                                             style: const TextStyle(
//                                               fontSize: 13,
//                                               //fontWeight: FontWeight.bold,
//                                               color: Colors.black,
//                                             ),
//
//                                             decoration: InputDecoration(
//                                               isDense: true,
//                                               contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
//
//                                               filled: true,
//                                               fillColor: Colors.white,
//
//                                               /// 🔥 DEFAULT BORDER
//                                               border: OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(6),
//                                                 borderSide: const BorderSide(color: Colors.black, width: 1),
//                                               ),
//
//                                               /// 🔥 ENABLED BORDER
//                                               enabledBorder: OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(6),
//                                                 borderSide: const BorderSide(color: Colors.black, width: 1),
//                                               ),
//
//                                               /// 🔥 FOCUSED BORDER
//                                               focusedBorder: OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(6),
//                                                 borderSide: const BorderSide(color: Colors.black, width: 1.5),
//                                               ),
//                                             ),
//
//                                             items: const [
//                                               DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                               DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                               DropdownMenuItem(value: "per_weight", child: Text("Per Wt")), // 🔥 NEW
//                                             ],
//
//
//                                             onChanged: (v) {
//                                               c["wt_formula"] = v;
//                                               setStateDialog(() {});
//                                             },
//                                           ),
//                                         ),
//
//                                         /// Total weight
//                                         SizedBox(
//                                           width: 110,
//                                           child: Text(
//                                             c["total_weight"] ?? "0",
//                                             textAlign: TextAlign.center,
//                                             style: TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, ),
//                                           ),
//                                         ),
//
//                                         const SizedBox(width: 6),
//                                         /// Amt Formula
//                                         SizedBox(
//                                           width: 100,
//                                           child: DropdownButtonFormField<String>(
//                                             value: c["amt_formula_type"] ?? "flat",
//
//                                             dropdownColor: Colors.white,
//                                             isExpanded: true,
//
//                                             style: const TextStyle(
//                                               fontSize: 13,
//                                               //fontWeight: FontWeight.bold,
//                                               color: Colors.black,
//                                             ),
//
//                                             decoration: InputDecoration(
//                                               isDense: true,
//                                               contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
//                                               filled: true,
//                                               fillColor: Colors.white,
//
//                                               border: OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(6),
//                                                 borderSide: const BorderSide(color: Colors.black),
//                                               ),
//                                               enabledBorder: OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(6),
//                                                 borderSide: const BorderSide(color: Colors.black),
//                                               ),
//                                               focusedBorder: OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(6),
//                                                 borderSide: const BorderSide(color: Colors.black, width: 1.5),
//                                               ),
//                                             ),
//
//                                             items: const [
//                                               DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                               DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                               DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                               DropdownMenuItem(value: "per_qty_weight", child: Text("Qty × Wt")),
//                                             ],
//
//                                             onChanged: (v) {
//                                               c["amt_formula_type"] = v;
//                                               setStateDialog(() {});
//                                             },
//                                           ),
//                                         ),
//
//                                         SizedBox(
//                                           width: 110,
//                                           child: Text(
//                                             c["total_amt"] ?? "0",
//                                             textAlign: TextAlign.center,
//                                             style: TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, ),
//                                           ),
//                                         ),
//
//
//                                         /// Checkbox
//                                         SizedBox(
//                                           width: 40,
//                                           child: Checkbox(
//                                             value: c["is_selected"],
//                                             onChanged: (val) {
//                                               c["is_selected"] = val;
//
//                                               calculateCharges(); // 🔥 optional but safe
//                                               setStateDialog(() {});
//                                             },
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       const SizedBox(height: 10),
//
//                       /// TOTAL
//                       Row(
//                         children: [
//                           const Text("Total", style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black)),
//                           const Spacer(),
//                           Text(total.toStringAsFixed(2),
//                               style: const TextStyle(fontWeight: FontWeight.bold,color: Colors.black)),
//                         ],
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       /// APPLY
//                       InkWell(
//                         onTap: () {
//                           double selectedTotal = 0;
//
//                           for (var c in charges) {
//                             if (c["is_selected"] == true) {
//                               selectedTotal += double.tryParse(c["total_amt"]) ?? 0;
//                             }
//                           }
//
//                           item["other_amount"] =
//                               selectedTotal.toStringAsFixed(2);
//
//                           updateController(item, "other_amount");
//                           calculateItem(item);
//                           updateFinalItems(); // 🔥 ADD THIS
//                           /// 🔥 CLOSE KEYBOARD
//                           FocusManager.instance.primaryFocus?.unfocus();
//
//                           Navigator.pop(context);
//
//                           setState(() {});
//                         },
//                         child: Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                           decoration: BoxDecoration(
//                             gradient: const LinearGradient(
//                               colors: [
//                                 Color(0xffE6C58A),
//                                 Color(0xffC8A96A),
//                               ],
//                             ),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: const Center(
//                             child: Text("Apply",
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black)),
//                           ),
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
//
//   void updateFinalItems() {
//     List<Map<String, dynamic>> updatedList = [];
//
//     /// 🔹 Manual Items
//     for (var item in items) {
//       if (item["id"] != null) {
//         updatedList.add(buildItemData(item, "manual"));
//       }
//     }
//
//     /// 🔹 Approval Items
//     for (var item in approvalAddedItems) {
//       if (item["itemset_id"] != null &&
//           item["approval_item_id"] != null) {
//
//         /// 🔥 Duplicate avoid (same itemset_id + approval_id)
//         bool alreadyExists = updatedList.any((e) =>
//         e["itemset_id"] == item["itemset_id"] &&
//             e["approval_item_id"] == item["approval_item_id"]);
//
//         if (!alreadyExists) {
//           updatedList.add(buildItemData(item, "approval"));
//         }
//       }
//     }
//
//     /// 🔹 Scanner Items (🔥 CONDITION ADD)
//     for (var item in cartItems) {
//       if (item["itemset_id"] != null) {
//
//         bool alreadyExists = updatedList.any((e) =>
//         e["itemset_id"] == item["itemset_id"]);
//
//         if (!alreadyExists) {
//
//           /// 🔥 SAME AS preparedScanItems
//           updatedList.add(buildItemData(item, "Scan"));
//         }
//       }
//     }
//
//     /// 🔥 IMPORTANT CHANGE
//     setState(() {
//       finalItems = updatedList;
//       uniqueItems = List.from(updatedList); // 🔥 summary mate
//     });
//
//     print("🔥 LIVE FINAL ITEMS: $finalItems");
//   }
//
//
//   Map<String, dynamic> buildItemData(Map item, String source) {
//     double gross = getValue(item, "gross_weight");
//     double other = getValue(item, "other_weight");
//     double net = gross - other;
//
//     double metalRate = getValue(item, "metal_rate");
//     double labourRate = getValue(item, "labour_rate");
//     double otherAmount = getValue(item, "other_amount");
//
//     double metalAmount = net * metalRate;
//     double labourAmount = net * labourRate;
//     /// 🔥 FIX HERE
//     double totalAmount;
//
//     if (source == "Scan") {
//       /// 👉 API amount use કર
//       totalAmount = double.tryParse(item["amount"]?.toString() ?? "0") ?? 0;
//     } else {
//       totalAmount = metalAmount + labourAmount + otherAmount;
//     }
//
//
//     return {
//       "source": source,
//       "itemset_id": item["itemset_id"] ?? item["id"],
//       "approval_item_id": item["approval_item_id"],
//       "gross_weight": gross,
//       "other_weight": other,
//       "net_weight": net,
//       "metal_rate": metalRate,
//       "labour_rate": labourRate,
//       "other_amount": otherAmount,
//
//       "metal_amount": metalAmount,
//       "labour_amount": labourAmount,
//       "total_amount": totalAmount,
//     };
//   }
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
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xffFAF7F2),
//         border: Border(top: BorderSide(color: Colors.grey.shade300)),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//
//             _summaryBox("Items", "${uniqueItems.length}"),
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
//             _summaryBox("Labour Rate", totals["labourRate"]!.toStringAsFixed(2)),
//             _summaryBox("Labour Amt", totals["labour"]!.toStringAsFixed(2)),
//
//             _summaryBox("Other Amt", totals["otherAmt"]!.toStringAsFixed(2)),
//             _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
//
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
//
//       metalRate += double.tryParse(item["metal_rate"]?.toString() ?? "0") ?? 0;
//
//       /// 🔥 IMPORTANT (ONLY SUM)
//       metal += double.tryParse(item["metal_amount"]?.toString() ?? "0") ?? 0;
//
//       labourRate += double.tryParse(item["labour_rate"]?.toString() ?? "0") ?? 0;
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
//
//
//
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
//           Text(title,
//               style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
//     ).animate(
//       CurvedAnimation(
//         parent: controller,
//         curve: Curves.easeInOut,
//       ),
//     );
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
//                 )
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
//
//
//
//

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Dashboard/HomeScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/ItemProvider.dart';
// import '../Extra/PermissionDeniedWidget.dart';
// import '../Extra/PremiumSearchableDropdown.dart';
// import 'SellScreen.dart';
//
// class SellList extends StatefulWidget {
//   const SellList({super.key});
//
//   @override
//   State<SellList> createState() => _SellListState();
// }
//
// class _SellListState extends State<SellList> {
//   TextEditingController searchController = TextEditingController();
//   TextEditingController fromDateController = TextEditingController();
//   TextEditingController toDateController = TextEditingController();
//   List userlist = [];
//   List<Map<String, dynamic>> allItems = [];
//   String? selectedItem;
//   List<Map<String, dynamic>> tableRows = [];
//   Timer? _huidTimer;
//   int apiRowCount = 0;
//   List customerlist = [];
//   String? selectedUser;
//   String? selectedCompanyId;
//   String? selectedUserId;
//   DateTime? birthDate;
//   DateTime? anniversaryDate;
//   List cartItems = [];
//   List allUsers = []; // 🔥 original data store
//   Future<void> _selectDate(TextEditingController controller) async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2030),
//     );
//
//     if (picked != null) {
//       controller.text =
//       "${picked.day}-${picked.month}-${picked.year}";
//     }
//   }
//   void applyDateFilter() {
//     List result = List.from(allUsers);
//
//     // 📅 Date filter
//     if (fromDateController.text.isNotEmpty &&
//         toDateController.text.isNotEmpty) {
//       final fromDate = _convertToDate(fromDateController.text);
//       final toDate = _convertToDate(toDateController.text);
//
//       final startDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
//       final endDate =
//       DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
//
//       result = result.where((user) {
//         final rawDate = user["modified_at"];
//         if (rawDate == null) return false;
//
//         final d = DateTime.parse(rawDate.toString()).toLocal();
//         return d.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
//             d.isBefore(endDate.add(const Duration(seconds: 1)));
//       }).toList();
//     }
//
//     // 👤 Customer filter
//     if (selectedUserId != null && selectedUserId!.isNotEmpty) {
//       result = result.where((sale) {
//         final customerId = sale["customer"]?["id"]?.toString() ??
//             sale["customer_id"]?.toString();
//         return customerId == selectedUserId;
//       }).toList();
//     }
//
//     setState(() {
//       userlist = result;
//     });
//   }
//   DateTime _convertToDate(String input) {
//     final parts = input.split("-");
//     return DateTime(
//       int.parse(parts[2]), // year
//       int.parse(parts[1]), // month
//       int.parse(parts[0]), // day
//     );
//   }
//
//   List<String> userPermissions = [];   // 🔥 ADD
//
//   Future<void> loadPermissions() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     // 🔥 Full prefs debug
//     Set<String> keys = prefs.getKeys();
//     print("🔥 All SharedPreferences Keys: $keys");
//
//     List<String> perms = prefs.getStringList("user_permissions") ?? [];
//     print("🔥 user_permissions value: $perms");
//
//     setState(() {
//       userPermissions = perms;
//     });
//   }
//   /// 🔥 Permission check helper
//   bool hasPermission(String permissionName) {
//   //  print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
//     return userPermissions.contains(permissionName);
//   }
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//
//     loadPermissions();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
//     });
//     DateTime today = DateTime.now();
//     DateTime sevenDaysAgo = today.subtract(const Duration(days: 7));
//
//     String formatDate(DateTime date) {
//       return "${date.day.toString().padLeft(2, '0')}-"
//           "${date.month.toString().padLeft(2, '0')}-"
//           "${date.year}";
//     }
//
//     fromDateController.text = formatDate(sevenDaysAgo);
//     toDateController.text = formatDate(today);
//
//     String from = DateFormat("yyyy-MM-dd").format(
//       DateFormat("dd-MM-yyyy").parse(fromDateController.text),
//     );
//
//     String to = DateFormat("yyyy-MM-dd").format(
//       DateFormat("dd-MM-yyyy").parse(toDateController.text),
//     );
//     getSaleDetails(
//       fromDate: from,
//       toDate: to,
//     );
//
//   }
//
//
//
//   Future<void> getSaleDetails({
//     String? fromDate,
//     String? toDate,
//   }) async {
//
//     String url = ApiConstants.sale_list;
//
//     if (fromDate != null &&
//         toDate != null &&
//         fromDate.isNotEmpty &&
//         toDate.isNotEmpty) {
//
//       url += "?from_date=$fromDate&to_date=$toDate";
//     }
//
//     final response = await ApiHelper().getRequest(url);
//
//     // final response =
//     // await ApiHelper().getRequest(ApiConstants.sale_list);
//
//     if (response != null && response.statusCode == 200) {
//
//       final data = response.data;
//
//       // ✅ success check
//       final List categories = data['data'];
//       AppMessage.success(context, data["message"] ?? "Data Loaded Successfully");
//       setState(() {
//
//         tableRows.clear();
//         userlist = categories;
//         allItems = List.from(categories); // 🔥 must for filter
//         allUsers = allItems; // 🔥 store original
//
//       });
//       applyDateFilter();
//     } else {
//
//       print("API Failed");
//
//     }
//   }
//
//
//
//   @override
//   Widget build(BuildContext context) {
//
//     if(!(
//         hasPermission("sale-view") ||
//             hasPermission("sale-manage")
//     )){
//       return Scaffold(
//         body: PermissionDeniedWidget(
//           onBack: (){
//             Navigator.pop(context);
//           },
//         ),
//       );
//     }
//
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//     final isMobile = width < 600;
//
//     return PopScope(
//       canPop: false,
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//
//         Navigator.pop(context,true);
//       },
//       child: Scaffold(
//         resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
//         backgroundColor: AppColors.white,
//         body: Stack(
//           children: [
//
//
//
//             /// ✅ Main Content
//             Column(
//               children: [
//                 /// IMPORTANT: top padding space leave karvu (AppBar mate)
//                 SizedBox(
//                   height: MediaQuery.of(context).padding.top + 40,
//                 ),
//                 /// 🔥 FILTER SECTION (NEW)
//                 filterWidget(),
//
//                 Container(
//                   margin: const EdgeInsets.only(top: 10),
//                   width: double.infinity,
//                   height: 2,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         AppColors.primaryDark.withOpacity(0.1),
//                         AppColors.primaryDark,
//                         AppColors.secondaryDark.withOpacity(0.4),
//                         AppColors.primaryDark.withOpacity(0.1),
//                       ],
//                     ),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//
//
//                 /// 🔥 Dynamic Bottom Section
//
//                 Expanded(
//                   child: userlist.isEmpty
//                       ? Center(
//                     child: Text(
//                       "No Data Found",
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey,
//                       ),
//                     ),
//                   )
//                       : ListView.builder(
//                     padding: const EdgeInsets.all(10),
//                     itemCount: userlist.length,
//                     itemBuilder: (context, index) {
//                       final item = userlist[index];
//                       return buildCard(item, index);
//                     },
//                   ),
//                 ),
//
//                 if (hasPermission("sale-create"))
//                 /// Bottom Button
//                 InkWell(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const Sellscreen(),
//                       ),
//                     );
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
//                           "+ Create Sale",
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
//
//
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
//
//                     /// ✅ CENTER TITLE
//                     const Text(
//                       "Sale Estimate List",
//                       style: TextStyle(
//                         color: Colors.black,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     /// ✅ LEFT BACK ICON
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: InkWell(
//                         onTap: () {
//                           Navigator.pop(context,true);
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//                           decoration: BoxDecoration(
//                             color:AppColors.primaryDark,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.grey.shade300),
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
//                     /// RIGHT NOTIFICATION ICON
//                     // Align(
//                     //   alignment: Alignment.centerRight,
//                     //
//                     //   child: Container(
//                     //     padding: EdgeInsets.all(isMobile ? 6 : 8),
//                     //
//                     //     decoration: BoxDecoration(
//                     //       color: Colors.white,
//                     //
//                     //       borderRadius: BorderRadius.circular(8),
//                     //
//                     //       boxShadow: [
//                     //         BoxShadow(
//                     //           color: AppColors.shadow,
//                     //
//                     //           blurRadius: 20,
//                     //
//                     //           offset: const Offset(5, 10),
//                     //         ),
//                     //       ],
//                     //     ),
//                     //
//                     //     child: Stack(
//                     //       clipBehavior: Clip.none,
//                     //
//                     //       children: [
//                     //         Icon(
//                     //           Icons.notifications_none,
//                     //
//                     //           size: isMobile ? 22 : 24,
//                     //
//                     //           color: Colors.red,
//                     //         ),
//                     //
//                     //         Positioned(
//                     //           right: -2,
//                     //
//                     //           top: -2,
//                     //
//                     //           child: Container(
//                     //             height: 8,
//                     //
//                     //             width: 8,
//                     //
//                     //             decoration: const BoxDecoration(
//                     //               color: Colors.red,
//                     //
//                     //               shape: BoxShape.circle,
//                     //             ),
//                     //           ),
//                     //         ),
//                     //       ],
//                     //     ),
//                     //   ),
//                     // ),
//                   ],
//                 ),
//               ),
//             )
//           ],
//         ),
//         //bottomNavigationBar: _buildSaveButton(),
//
//       ),
//     );
//   }
//
//   /// ✅ Header Section
//   Widget topHeaderSectionGlass(double width) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(20),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.05),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(
//               color: Colors.white.withOpacity(0.1),
//               width: 1,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 10,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//
//               /// Top Row
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       const CircleAvatar(
//                         radius: 25,
//                         backgroundImage: AssetImage("assets/static/img.png"),
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         "OrnaSphere",
//                         style: TextStyle(
//                           color: AppColors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Row(
//                     children: [
//                       GestureDetector(
//                         onTap: () {},
//                         child: Icon(Icons.notifications_none,
//                             color: AppColors.white, size: 26),
//                       ),
//                       const SizedBox(width: 15),
//                       const CircleAvatar(
//                         radius: 16,
//                         backgroundImage:
//                         NetworkImage("https://i.pravatar.cc/150?img=3"),
//                       )
//                     ],
//                   )
//                 ],
//               ),
//
//               const SizedBox(height: 5),
//
//               /// Bottom Right Buttons
//               Align(
//                 alignment: Alignment.bottomRight,
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//
//
//
//                     const SizedBox(width: 10),
//
//                     /// Approve Button
//                     InkWell(
//                       onTap: () async {
//
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => Sellscreen(),
//                           ),
//                         );
//
//                       },borderRadius: BorderRadius.circular(10),
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(10),
//                           gradient: const LinearGradient(
//                             colors: [
//                               Color(0xFF00C853),
//                               Color(0xFF64DD17),
//                             ],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.green.withOpacity(0.5),
//                               blurRadius: 12,
//                               offset: const Offset(0, 4),
//                             )
//                           ],
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: const [
//                             Icon(Icons.check_circle, color: Colors.white, size: 18),
//                             SizedBox(width: 6),
//                             Text(
//                               "Create Sale",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 15,
//                                 letterSpacing: 0.5,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//
//
//   int? expandedSaleId;
//   Widget buildCard(Map<String, dynamic> item, int index) {
//     final size = MediaQuery.of(context).size;
//     final bool isTablet = size.width >= 600;
//
//     // =========================================================
//     // UNIQUE ID
//     // =========================================================
//     final int id =
//         int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
//
//     final bool isExpanded = expandedSaleId == id;
//
//     // =========================================================
//     // DATA
//     // =========================================================
//     final String voucherNo =
//         item["voucher_no"]?.toString() ?? "-";
//
//     final String customerName =
//         item["customer"]?["name"]?.toString() ?? "-";
//
//     final String metal =
//         item["metal"]?.toString() ?? "-";
//
//     final String modifiedAt =
//         item["modified_at"]?.toString() ?? "";
//
//     final String mobile =
//         item["customer"]?["mobile_no"]?.toString() ?? "-";
//
//     final String email =
//         item["customer"]?["email"]?.toString() ?? "-";
//
//     final String totalAmount =
//         item["net_total"]?.toString() ?? "-";
//
//     final String receivedAmount =
//         item["received_amount"]?.toString() ?? "-";
//
//     final String pendingAmount =
//         item["pending_amount"]?.toString() ?? "-";
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//
//       decoration: BoxDecoration(
//         color: AppColors.cardBackground,
//         borderRadius: BorderRadius.circular(5),
//
//         border: Border.all(
//           color: isExpanded
//               ? AppColors.primaryDark.withOpacity(0.45)
//               : AppColors.border,
//         ),
//
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(5),
//
//         child: Column(
//           children: [
//
//             // =====================================================
//             // HEADER - ALWAYS VISIBLE
//             // =====================================================
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isTablet ? 14 : 10,
//                 vertical: isTablet ? 12 : 10,
//               ),
//
//               child: Row(
//                 children: [
//
//                   // =================================================
//                   // INDEX
//                   // =================================================
//                   Container(
//                     width: 27,
//                     height: 27,
//                     alignment: Alignment.center,
//
//                     decoration: BoxDecoration(
//                       color: AppColors.gradientBlue,
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//
//                     child: Text(
//                       "${index + 1}",
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 11,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//
//                   const SizedBox(width: 8),
//
//                   // =================================================
//                   // VOUCHER NO + CUSTOMER
//                   // =================================================
//                   Expanded(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//
//                         // VOUCHER NO
//                         Text(
//                           voucherNo,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontSize: 14,
//                             color: Colors.black87,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//
//                         const SizedBox(height: 3),
//
//                         // CUSTOMER NAME
//                         Row(
//                           children: [
//                             Icon(
//                               Icons.person_outline_rounded,
//                               size: 13,
//                               color: Colors.grey.shade600,
//                             ),
//
//                             const SizedBox(width: 4),
//
//                             Expanded(
//                               child: Text(
//                                 customerName,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey.shade600,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   const SizedBox(width: 5),
//
//                   // =================================================
//                   // METAL STATUS
//                   // =================================================
//                   statusChip(metal),
//
//                   SizedBox(
//                     width: isTablet ? 8 : 5,
//                   ),
//
//                   // =================================================
//                   // EDIT
//                   // =================================================
//                   if (hasPermission("sale-edit") ||
//                       hasPermission("sale-manage")) ...[
//                     premiumIconBtn(
//                       Icons.edit_rounded,
//                       AppColors.gradientBlue,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) =>
//                                 Sellscreen(userData: item),
//                           ),
//                         );
//                       },
//                     ),
//
//                     SizedBox(
//                       width: isTablet ? 8 : 5,
//                     ),
//                   ],
//
//                   // =================================================
//                   // VIEW
//                   // =================================================
//                   // if (hasPermission("sale-edit") ||
//                   //     hasPermission("sale-manage")) ...[
//                   //   premiumIconBtn(
//                   //     Icons.visibility_rounded,
//                   //     AppColors.gradientBlue,
//                   //     onTap: () {
//                   //       getApprovalDetails(id);
//                   //
//                   //       debugPrint(
//                   //         "VIEW SALE ID => $id",
//                   //       );
//                   //     },
//                   //   ),
//                   //
//                   //   SizedBox(
//                   //     width: isTablet ? 8 : 5,
//                   //   ),
//                   // ],
//
//                   if (hasPermission("sale-delete")) ...[
//                     premiumIconBtn(
//                       Icons.delete_outline_rounded,
//                       Colors.red,
//                       onTap: () {
//                         _showDeleteDialog(id);
//                       },
//                     ),
//
//                     SizedBox(
//                       width: isTablet ? 8 : 5,
//                     ),
//                   ],
//
//                   // =================================================
//                   // PDF
//                   // =================================================
//                   pdfBtn(() {
//                     final String pdfUrl =
//                         item["pdf_url"]?.toString() ?? "";
//
//                     if (pdfUrl.isNotEmpty) {
//                       openPdfUrl(pdfUrl);
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text(
//                             "PDF not available",
//                           ),
//                         ),
//                       );
//                     }
//                   }),
//
//                   SizedBox(
//                     width: isTablet ? 8 : 5,
//                   ),
//
//                   // =================================================
//                   // EXPAND BUTTON
//                   // =================================================
//                   InkWell(
//                     onTap: () {
//                       setState(() {
//                         if (expandedSaleId == id) {
//                           // Same card click -> close
//                           expandedSaleId = null;
//                         } else {
//                           // New card open
//                           // Previous automatically close
//                           expandedSaleId = id;
//                         }
//                       });
//                     },
//
//                     borderRadius: BorderRadius.circular(20),
//
//                     child: AnimatedRotation(
//                       turns: isExpanded ? 0.5 : 0,
//
//                       duration: const Duration(
//                         milliseconds: 250,
//                       ),
//
//                       child: Container(
//                         width: 30,
//                         height: 30,
//                         alignment: Alignment.center,
//
//                         decoration: BoxDecoration(
//                           color: AppColors.primaryDark
//                               .withOpacity(0.08),
//                           shape: BoxShape.circle,
//                         ),
//
//                         child: const Icon(
//                           Icons.keyboard_arrow_down_rounded,
//                           size: 22,
//                           color: AppColors.primaryDark,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             // =====================================================
//             // EXPANDED SECTION
//             // =====================================================
//             AnimatedCrossFade(
//               duration: const Duration(
//                 milliseconds: 250,
//               ),
//
//               firstChild: const SizedBox(
//                 width: double.infinity,
//                 height: 0,
//               ),
//
//               secondChild: Container(
//                 width: double.infinity,
//
//                 padding: const EdgeInsets.fromLTRB(
//                   10,
//                   0,
//                   10,
//                   10,
//                 ),
//
//                 child: Column(
//                   children: [
//
//                     // =================================================
//                     // DIVIDER
//                     // =================================================
//                     Divider(
//                       height: 1,
//                       color: AppColors.border,
//                     ),
//
//                     const SizedBox(height: 10),
//
//                     // =================================================
//                     // ERP DETAILS
//                     // =================================================
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 6,
//                       ),
//
//                       decoration: BoxDecoration(
//                         color: AppColors.background,
//
//                         border: Border.all(
//                           color: AppColors.border,
//                           width: 1.2,
//                         ),
//
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//
//                       child: Column(
//                         children: [
//
//                           // ===========================================
//                           // DATE / MOBILE
//                           // ===========================================
//                           _erpRow(
//                             "Date",
//                             modifiedAt.isNotEmpty
//                                 ? formatApiDate(modifiedAt)
//                                 : "-",
//
//                             "Mobile",
//                             mobile,
//                           ),
//
//                           Divider(
//                             height: 1,
//                             color: AppColors.border,
//                           ),
//
//                           // ===========================================
//                           // TOTAL AMOUNT / EMAIL
//                           // ===========================================
//                           _erpRow(
//                             "Total Amt",
//                             totalAmount,
//
//                             "Email",
//                             email,
//                           ),
//
//                           Divider(
//                             height: 1,
//                             color: AppColors.border,
//                           ),
//
//                           // ===========================================
//                           // RECEIVED / PENDING
//                           // ===========================================
//                           _erpRow(
//                             "Received Amt",
//                             receivedAmount,
//
//                             "Pending Amt",
//                             pendingAmount,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               crossFadeState: isExpanded
//                   ? CrossFadeState.showSecond
//                   : CrossFadeState.showFirst,
//             ),
//           ],
//         ),
//       ),
//     );
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
//                     overflow: TextOverflow.ellipsis,
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
//
//   Widget premiumIconBtn(IconData icon, Color color, {required VoidCallback onTap}) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(5),
//       child: Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.12),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Icon(icon, color: color, size: 20),
//       ),
//     );
//   }
//
//
//   /// 🔹 PDF Button
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
//         child: Row(
//           children: const [
//             Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
//             SizedBox(width: 0),
//             Text("",
//                 style: TextStyle(
//                     color: Colors.white, fontWeight: FontWeight.w500)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// 🔹 Status Chip
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
//         return const SizedBox.shrink(); // 👈 Unknown hide
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [startColor, endColor],
//         ),
//         borderRadius: BorderRadius.circular(5),
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
//               color: Colors.white,
//               fontWeight: FontWeight.w600,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> openPdf(int id) async {
//
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.Sale_pdf,
//       id,
//       responseType: ResponseType.bytes,
//     );
//
//     if (response != null && response.statusCode == 200) {
//
//       final dir = await getTemporaryDirectory();
//
//       final file = File("${dir.path}/return_$id.pdf");
//
//       await file.writeAsBytes(response.data);
//
//       OpenFile.open(file.path);
//
//     } else {
//
//       print("PDF Download Failed");
//
//     }
//
//   }
//
//
//
//   /// Header Cell
//   Widget _buildHeaderCell(String title) {
//     return Expanded(
//       child: Container(
//         height: 55,
//         alignment: Alignment.center,
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [
//               Color(0xff2B3050), // dark brown
//               Color(0xff1b1411),
//               Color(0xff3A3F63),// deep dark
//             ],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//           border: Border(
//             right: BorderSide(
//               color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//               width: 1.2,
//             ),
//             left: BorderSide(
//               color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//               width: 1.2,
//             ),
//             top: BorderSide(
//               color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//               width: 1.2,
//             ),
//             bottom: BorderSide(
//               color: Color(0xffC9A44A).withOpacity(0.6), // gold bottom line
//               width: 1.5,
//             ),
//           ),
//         ),
//         child: Text(
//           title,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Color(0xffE6C36A), // gold text
//             fontSize: 13,
//             fontWeight: FontWeight.w700,
//             letterSpacing: 0.5,
//           ),
//         ),
//       ),
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
//   Future<void> loadItemDetails(String itemId) async {
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.label_item_list,
//       {"item_id": itemId},
//     );
//
//     if (response!.statusCode == 200 && response.data["data"] != null) {
//
//       final List data = response.data["data"];
//
//       setState(() {
//         tableRows.clear();
//
//         for (var row in data) {
//           tableRows.add({
//             "gross": TextEditingController(text: row["gross_weight"] ?? ""),
//             "other": TextEditingController(text: row["other"] ?? ""),
//             "net": TextEditingController(text: row["net_weight"] ?? ""),
//             "labourRate": TextEditingController(
//                 text: row["sale_labour_rate"]?.toString() ?? ""),
//             "labourAmount": TextEditingController(
//                 text: row["sale_labour_amount"]?.toString() ?? ""),
//             "purity": TextEditingController(
//                 text: row["outward_purity"]?.toString() ?? ""),
//             "size": TextEditingController(text: row["size"] ?? ""),
//             "huid": TextEditingController(text: row["HUID"] ?? ""),
//           });
//         }
//         apiRowCount = data.length; // ⭐ important
//         /// 🔥 Extra 3 Empty Rows
//         for (int i = 0; i < 3; i++) {
//           tableRows.add({
//             "gross": TextEditingController(),
//             "other": TextEditingController(),
//             "net": TextEditingController(),
//             "labourRate": TextEditingController(),
//             "labourAmount": TextEditingController(),
//             "purity": TextEditingController(),
//             "size": TextEditingController(),
//             "huid": TextEditingController(),
//           });
//         }
//       });
//     }
//   }
//
//   Widget _buildDateField(
//       BuildContext context,
//       String label,
//       DateTime? selectedDate,
//       Function(DateTime) onDateSelected,
//       ) {
//     final screenHeight = MediaQuery.of(context).size.height;
//     final screenWidth = MediaQuery.of(context).size.width;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label),
//         SizedBox(height: screenHeight * 0.01),
//
//         GestureDetector(
//           onTap: () async {
//             DateTime initialDate = selectedDate ?? DateTime.now();
//
//             final pickedDate = await showDatePicker(
//               context: context,
//               initialDate: initialDate,
//               firstDate: DateTime(1900),
//               lastDate: DateTime(2100),
//             );
//
//             if (pickedDate != null) {
//               onDateSelected(pickedDate);
//             }
//           },
//           child: Container(
//             height: screenHeight * 0.055,
//             padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
//             alignment: Alignment.centerLeft,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   selectedDate == null
//                       ? "Select Date"
//                       : "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}",
//                 ),
//                 const Icon(Icons.calendar_today, size: 18,color: Colors.amberAccent,),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//
//   Future<List<Map<String,String>>?> openApprovePopup(BuildContext context) async {
//
//     List<Map<String, String>> tableRows = [];
//     TextEditingController labelController = TextEditingController();
//     String? popupSelectedUser; // 👈 add this
//     bool showScanner = false;
//     bool showLabelField = false;
//
//     return showDialog<List<Map<String,String>>>(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.4),
//       builder: (context) {
//
//         return StatefulBuilder(
//           builder: (context, setState) {
//
//             return Dialog(
//               insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
//               backgroundColor: Colors.transparent,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//                   child: Container(
//                     width: double.infinity,
//                     height: showScanner || showLabelField?700:500,
//                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.08),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(
//                         color: Colors.white.withOpacity(0.2),
//                       ),
//                     ),
//
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//
//                         /// Title
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//
//                             const Text(
//                               "Sale Estimate",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//
//                             Row(
//                               children: [
//
//                                 /// Edit Icon
//                                 IconButton(
//                                   onPressed: () {
//                                     print("Edit Clicked");
//                                     setState(() {
//                                       showLabelField = true;
//                                       showScanner = false;
//                                     });
//                                   },
//                                   icon: const Icon(Icons.edit, color: Colors.white),
//                                 ),
//
//                                 /// Scan Icon
//                                 IconButton(
//                                   onPressed: () {
//                                     setState(() {
//                                       showScanner = true;
//                                       showLabelField = false;
//                                     });
//                                     print("Scan Clicked");
//                                   },
//                                   icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
//                                 ),
//
//                                 /// Close Icon
//                                 IconButton(
//                                   onPressed: (){
//                                     Navigator.pop(context);
//                                   },
//                                   icon: const Icon(Icons.close, color: Colors.white),
//                                 ),
//
//                               ],
//                             )
//
//                           ],
//                         ),
//
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//
//                             const Text("Select Party",
//                                 style: TextStyle(color: Colors.white70)),
//
//                             const SizedBox(height: 8),
//
//                             Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 12),
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(color: Colors.white24),
//                                 color: Colors.white.withOpacity(0.05),
//                               ),
//                               child: DropdownButtonHideUnderline(
//                                 child: DropdownButton<String>(
//                                   isExpanded: true,
//                                   dropdownColor: Colors.black,
//                                   hint: const Text(
//                                     "Select Customer",
//                                     style: TextStyle(color: Colors.white70),
//                                   ),
//                                   value: popupSelectedUser,
//                                   items: customerlist.map<DropdownMenuItem<String>>((user) {
//                                     return DropdownMenuItem<String>(
//                                       value: user["id"].toString(),
//                                       child: Text(
//                                         user["name"] ?? "",
//                                         style: const TextStyle(color: Colors.white),
//                                       ),
//                                     );
//                                   }).toList(),
//                                   onChanged: (val) {
//                                     setState(() {
//                                       popupSelectedUser = val;
//                                       showScanner = false;
//                                       showLabelField = false;
//                                       final selectedData = customerlist.firstWhere(
//                                             (user) => user["id"].toString() == val,
//                                       );
//                                       selectedCompanyId =
//                                           selectedData["company_id"].toString();
//
//                                       print("Selected Company ID: $selectedCompanyId");
//                                     });
//                                   },
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//
//
//                         Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//
//                             /// Title
//
//                             /// Customer Dropdown
//
//                             if (popupSelectedUser != null) ...[
//
//                               const SizedBox(height: 15),
//
//                               /// Label TextField
//                               if (showLabelField) ...[
//
//
//                                 TextField(
//                                   controller: labelController,
//                                   style: const TextStyle(color: Colors.white),
//                                   decoration: InputDecoration(
//                                     labelText: "Enter Label",
//                                     labelStyle: const TextStyle(color: Colors.white70),
//                                     //filled: true,
//                                     //fillColor: Colors.white.withOpacity(0.05),
//                                     border: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(10),
//                                     ),
//                                   ),
//
//                                   onSubmitted: (value) {
//
//                                     if (value.trim().isEmpty) return;
//
//                                     setState(() {
//
//                                       tableRows.add({
//                                         //"label": value.trim(),
//                                         "gross": "10.0",
//                                         "other": "2.5",
//                                         "net": "7.5",
//                                         "size": "10",
//                                         "huid": "001",
//                                       });
//
//                                     });
//
//                                     labelController.clear();
//                                   },
//                                 ),
//
//                               ],
//
//                               const SizedBox(height: 20),
//
//
//
//
//
//                               /// Table
//                               /// Table/Grid
//                               SizedBox(
//                                 height: 220,
//                                 child: Column(
//                                   children: [
//
//                                     /// Header
//                                     Container(
//                                       decoration: BoxDecoration(
//                                         border: Border.all(color: Colors.white24),
//                                       ),
//                                       child: Row(
//                                         children: [
//                                           _buildHeaderCell("Gross\nWeight"),
//                                           _buildHeaderCell("Other"),
//                                           _buildHeaderCell("Net\nWeight"),
//                                           _buildHeaderCell("Size"),
//                                           _buildHeaderCell("HUID"),
//                                         ],
//                                       ),
//                                     ),
//
//                                     /// Rows
//                                     Expanded(
//                                       child: SingleChildScrollView(
//                                         child: Table(
//                                           border: TableBorder.all(color: Colors.white24),
//                                           children: tableRows.asMap().entries.map((entry) {
//
//                                             int index = entry.key;
//                                             var row = entry.value;
//
//                                             return TableRow(
//                                               children: [
//
//                                                 /// Label
//                                                 // Padding(
//                                                 //   padding: const EdgeInsets.all(6),
//                                                 //   child: Text(
//                                                 //     row["label"]!,
//                                                 //     style: const TextStyle(color: Colors.white),
//                                                 //     textAlign: TextAlign.center,
//                                                 //   ),
//                                                 // ),
//
//                                                 _buildTableCell1(row["gross"]!, (val){ row["gross"] = val; }),
//                                                 _buildTableCell1(row["other"]!, (val){ row["other"] = val; }),
//                                                 _buildTableCell1(row["net"]!, (val){ row["net"] = val; }),
//                                                 // _buildTableCell1(row["labourRate"]!, (val){ row["labourRate"] = val; }),
//                                                 // _buildTableCell1(row["labourAmount"]!, (val){ row["labourAmount"] = val; }),
//                                                 _buildTableCell1(row["size"]!, (val){ row["size"] = val; }),
//                                                 _buildTableCell1(row["huid"]!, (val){ row["huid"] = val; }),
//
//                                               ],
//                                             );
//
//
//                                           }).toList(),
//                                         ),
//                                       ),
//                                     ),
//
//                                   ],
//                                 ),
//                               ),
//
//                               const SizedBox(height: 15),
//
//                               /// Submit Button
//                               Container(
//                                 width: double.infinity,
//                                 decoration: BoxDecoration(
//                                   gradient: const LinearGradient(
//                                     colors: [
//                                       Color(0xFF00C853),
//                                       Color(0xFF64DD17),
//                                     ],
//                                   ),
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                                 child: TextButton(
//                                   onPressed: (){
//                                     Navigator.pop(context, tableRows); // 🔥 return data
//                                     print(tableRows);
//                                   },
//                                   child: const Text(
//                                     "Submit",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                               )
//
//                             ]
//
//                           ],
//                         )
//
//
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             );
//
//           },
//         );
//
//       },
//     );
//   }
//
//   Widget _buildTableCell1(String value, Function(String) onChanged) {
//
//     return Container(
//       height: 40,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(0),
//         gradient: LinearGradient(
//           colors: [
//             Colors.white.withOpacity(0.10),
//             Colors.white.withOpacity(0.05),
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         border: Border(
//           right: BorderSide(
//             color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//             width: 0.8,
//           ),
//           left: BorderSide(
//             color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//             width: 0.8,
//           ),
//           bottom: BorderSide(
//             color: Color(0xffC9A44A).withOpacity(0.6), // gold bottom line
//             width: 0.8,
//           ),
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(0),
//         child: TextFormField(
//           initialValue: value,
//           keyboardType: TextInputType.number,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//           ),
//           decoration: const InputDecoration(
//             contentPadding: EdgeInsets.symmetric(horizontal: 0),
//             border: InputBorder.none,
//           ),
//           onChanged: onChanged,
//         ),
//       ),
//     );
//
//   }
//
//   Future<void> openPdfUrl(String url) async {
//     final Uri uri = Uri.parse(url);
//
//     print(url);
//
//     if (!await launchUrl(uri)) {
//       throw Exception('Could not launch $uri');
//     }
//   }
//
//   Widget filterWidget() {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
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
//
//           /// 🔍 SEARCH FIELD
//           // TextField(
//           //   controller: searchController,
//           //   style: const TextStyle(color: Colors.black),
//           //   onChanged: (value) {
//           //     searchCustomer(value); // 🔥 LIVE SEARCH
//           //   },
//           //   decoration: InputDecoration(
//           //     hintText: "Search Customer",
//           //     hintStyle: TextStyle(color: Colors.grey.shade600),
//           //     prefixIcon: Icon(Icons.search, color:AppColors.primaryDark),
//           //     filled: true,
//           //     fillColor: Colors.white,
//           //     contentPadding: const EdgeInsets.symmetric(vertical: 0),
//           //     border: OutlineInputBorder(
//           //         borderRadius: BorderRadius.circular(8),
//           //         borderSide: BorderSide(color: AppColors.border)
//           //     ),
//           //
//           //     enabledBorder: OutlineInputBorder(
//           //       borderRadius: BorderRadius.circular(8),
//           //       borderSide: BorderSide(color:AppColors.border),
//           //     ),
//           //
//           //     focusedBorder: OutlineInputBorder(
//           //       borderRadius: BorderRadius.circular(8),
//           //       borderSide: BorderSide(color: AppColors.border),
//           //     ),
//           //   ),
//           // ),
//           Container(
//             padding: EdgeInsets.zero,
//             decoration: BoxDecoration(
//               color: AppColors.background,
//               border: Border.all(color: AppColors.border),
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Consumer<ItemProvider>(
//               builder: (context, provider, child) {
//                 final List<Map<String, dynamic>> customers = provider.customers
//                     .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
//                     .toList();
//
//                 Map<String, dynamic>? selectedCustomer;
//
//                 if (selectedItem != null) {
//                   try {
//                     selectedCustomer = customers.firstWhere(
//                           (e) => e["id"]?.toString() == selectedItem.toString(),
//                     );
//                   } catch (_) {
//                     selectedCustomer = null;
//                   }
//                 }
//
//                 return Stack(
//                   alignment: Alignment.centerRight,
//                   children: [
//                     PremiumSearchableDropdown<Map<String, dynamic>>(
//                       label: "",
//                       hint: "Select Customer",
//                       items: customers,
//                       value: selectedCustomer,
//                       prefixIcon: Icons.person_outline_rounded,
//                       dropdownMaxHeight: 350,
//                       itemLabel: (customer) => customer["name"]?.toString() ?? "",
//                       searchText: (customer) {
//                         final name = customer["name"]?.toString() ?? "";
//                         final mobile = customer["mobile"]?.toString() ??
//                             customer["mobile_no"]?.toString() ??
//                             customer["phone"]?.toString() ??
//                             "";
//                         final code = customer["code"]?.toString() ??
//                             customer["customer_code"]?.toString() ??
//                             "";
//                         return "$name $mobile $code";
//                       },
//                       onChanged: (customer) => _setCustomerFilter(customer),
//                     ),
//
//                     /// ❌ CLEAR — dropdown ની અંદર, arrow ની ડાબી બાજુ
//                     if (selectedCustomer != null)
//                       Positioned(
//                         right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
//                         top: 0,
//                         bottom: 0,
//                         child: Center(
//                           child: InkWell(
//                             borderRadius: BorderRadius.circular(20),
//                             onTap: () {
//                               FocusManager.instance.primaryFocus?.unfocus();
//                               _setCustomerFilter(null);
//                             },
//                             child: Container(
//                               width: 20,
//                               height: 20,
//                               alignment: Alignment.center,
//                               decoration: BoxDecoration(
//                                 color: Colors.red.shade50,
//                                 shape: BoxShape.circle,
//                                 border: Border.all(color: Colors.red.shade200),
//                               ),
//                               child: Icon(
//                                 Icons.close_rounded,
//                                 size: 13,
//                                 color: Colors.red.shade700,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                   ],
//                 );
//               },
//             ),
//           ),
//
//           const SizedBox(height: 5),
//
//           /// 📅 DATE ROW
//           Row(
//             children: [
//               Expanded(
//                 child: InkWell(
//                   onTap: () => _selectDate(fromDateController),
//                   child: IgnorePointer(
//                     child: TextField(
//                       controller: fromDateController,
//                       style: const TextStyle(color: Colors.black),
//                       decoration: InputDecoration(
//                         hintText: "From Date",
//                         hintStyle: TextStyle(color: Colors.grey.shade600),
//                         suffixIcon: const Icon(Icons.calendar_today, size: 18,color: AppColors.primaryDark,),
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide(color: AppColors.border)
//                         ),
//
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color:AppColors.border),
//                         ),
//
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: AppColors.border),
//                         ),
//
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(width: 8),
//
//               Expanded(
//                 child: InkWell(
//                   onTap: () => _selectDate(toDateController),
//                   child: IgnorePointer(
//                     child: TextField(
//                       controller: toDateController,
//                       style: const TextStyle(color: Colors.black),
//                       decoration: InputDecoration(
//                         hintText: "To Date",
//                         hintStyle: TextStyle(color: Colors.grey.shade600),
//                         suffixIcon: const Icon(Icons.calendar_today, size: 18,color: AppColors.primaryDark,),
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide(color: AppColors.border)
//                         ),
//
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color:AppColors.border),
//                         ),
//
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: AppColors.border),
//                         ),
//                       ),
//                     ),
//                   ),
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
//                     applyDateFilter(); // 🔥 CALL HERE
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
//               Expanded(
//                 child: pdfBtn1(() {
//
//                   openApprovalPdf(
//                     fromDateController.text,
//                     toDateController.text,
//                   );
//
//                   print("PDF Click");
//                 }),
//               ),
//             ],
//           )
//         ],
//       ),
//     );
//   }
//
//   String formatApiDate(String input) {
//     try {
//       DateTime date = DateTime.parse(input);
//
//       return "${date.day.toString().padLeft(2, '0')}-"
//           "${date.month.toString().padLeft(2, '0')}-"
//           "${date.year}";
//     } catch (e) {
//       return "";
//     }
//   }
//
//   Future<void> getApprovalDetails(dynamic id) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.sale_item_update,
//       id,
//       responseType: ResponseType.bytes,
//     );
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//       /// 🔥 BYTES → STRING → JSON
//       String jsonString = utf8.decode(response.data);
//       final data = jsonDecode(jsonString);
//
//       final item = data["data"] is List ? data["data"][0] : data["data"];
//
//       showApprovalDialog(item);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
//     }
//
//
//   }
//
//
//
//
//   void showApprovalDialog(Map<String, dynamic> item) {
//     String val(dynamic v) {
//       if (v == null || v.toString().trim().isEmpty) {
//         return "-";
//       }
//       return v.toString();
//     }
//
//     final List items =
//     item["sale_items"] is List ? item["sale_items"] : [];
//
//     final int saleId =
//         int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
//
//     showDialog(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.55),
//       builder: (dialogContext) {
//         final Size size = MediaQuery.of(dialogContext).size;
//         final bool isTablet = size.width >= 600;
//
//         return Dialog(
//           elevation: 0,
//           backgroundColor: Colors.transparent,
//           insetPadding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 50 : 14,
//             vertical: 24,
//           ),
//           child: Container(
//             width: isTablet ? 720 : double.infinity,
//             constraints: BoxConstraints(
//               maxHeight: size.height * 0.88,
//             ),
//             decoration: BoxDecoration(
//               color: AppColors.background,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                 color: AppColors.border,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.22),
//                   blurRadius: 30,
//                   offset: const Offset(0, 12),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // ==========================================================
//                   // PREMIUM BLUE HEADER
//                   // ==========================================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.fromLTRB(
//                       14,
//                       13,
//                       10,
//                       13,
//                     ),
//                     decoration: const BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark,
//                           AppColors.gradientBlue,
//                         ],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         // HEADER ICON
//                         Container(
//                           width: 42,
//                           height: 42,
//                           alignment: Alignment.center,
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.14),
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.18),
//                             ),
//                           ),
//                           child: const Icon(
//                             Icons.receipt_long_rounded,
//                             color: Colors.white,
//                             size: 21,
//                           ),
//                         ),
//
//                         const SizedBox(width: 11),
//
//                         // TITLE
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 "Sale Details",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 17,
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ),
//                               const SizedBox(height: 3),
//                               Text(
//                                 val(item["voucher_no"]),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.78),
//                                   fontSize: 11,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         // PDF BUTTON
//                         Material(
//                           color: Colors.transparent,
//                           child: InkWell(
//                             onTap: () {
//                               if (saleId > 0) {
//                                 openPdf(saleId);
//                               }
//                             },
//                             borderRadius: BorderRadius.circular(9),
//                             child: Container(
//                               width: 38,
//                               height: 38,
//                               alignment: Alignment.center,
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.12),
//                                 borderRadius: BorderRadius.circular(9),
//                                 border: Border.all(
//                                   color: Colors.white.withOpacity(0.15),
//                                 ),
//                               ),
//                               child: const Icon(
//                                 Icons.picture_as_pdf_rounded,
//                                 color: Colors.white,
//                                 size: 19,
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(width: 7),
//
//                         // CLOSE BUTTON
//                         Material(
//                           color: Colors.transparent,
//                           child: InkWell(
//                             onTap: () {
//                               Navigator.pop(dialogContext);
//                             },
//                             borderRadius: BorderRadius.circular(9),
//                             child: Container(
//                               width: 38,
//                               height: 38,
//                               alignment: Alignment.center,
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.12),
//                                 borderRadius: BorderRadius.circular(9),
//                                 border: Border.all(
//                                   color: Colors.white.withOpacity(0.12),
//                                 ),
//                               ),
//                               child: const Icon(
//                                 Icons.close_rounded,
//                                 color: Colors.white,
//                                 size: 21,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // ==========================================================
//                   // BODY
//                   // ==========================================================
//                   Flexible(
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.all(14),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // ==================================================
//                           // CUSTOMER HERO CARD
//                           // ==================================================
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(13),
//                             decoration: BoxDecoration(
//                               color: AppColors.cardBackground,
//                               borderRadius: BorderRadius.circular(11),
//                               border: Border.all(
//                                 color: AppColors.border,
//                               ),
//                               boxShadow: const [
//                                 BoxShadow(
//                                   color: AppColors.shadow,
//                                   blurRadius: 8,
//                                   offset: Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: Row(
//                               children: [
//                                 // CUSTOMER ICON
//                                 Container(
//                                   width: 43,
//                                   height: 43,
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     color: AppColors.iconBg,
//                                     borderRadius: BorderRadius.circular(11),
//                                   ),
//                                   child: const Icon(
//                                     Icons.person_outline_rounded,
//                                     color: AppColors.primaryDark,
//                                     size: 21,
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 11),
//
//                                 // CUSTOMER NAME
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         val(item["customer"]?["name"]),
//                                         maxLines: 1,
//                                         overflow: TextOverflow.ellipsis,
//                                         style: const TextStyle(
//                                           color: AppColors.textPrimary,
//                                           fontSize: 15,
//                                           fontWeight: FontWeight.w700,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 3),
//                                       const Text(
//                                         "Customer",
//                                         style: TextStyle(
//                                           color: AppColors.textSecondary,
//                                           fontSize: 10,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 8),
//
//                                 // VOUCHER BADGE
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 10,
//                                     vertical: 6,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: AppColors.iconBg,
//                                     borderRadius: BorderRadius.circular(7),
//                                     border: Border.all(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       const Icon(
//                                         Icons.receipt_outlined,
//                                         color: AppColors.primaryDark,
//                                         size: 13,
//                                       ),
//                                       const SizedBox(width: 5),
//                                       Text(
//                                         val(item["voucher_no"]),
//                                         style: const TextStyle(
//                                           color: AppColors.primaryDark,
//                                           fontSize: 10.5,
//                                           fontWeight: FontWeight.w700,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//
//                           const SizedBox(height: 14),
//
//                           // ==================================================
//                           // SALE SUMMARY TITLE
//                           // ==================================================
//                           _premiumSectionTitle(
//                             icon: Icons.analytics_outlined,
//                             title: "Sale Summary",
//                           ),
//
//                           const SizedBox(height: 8),
//
//                           // ==================================================
//                           // SALE SUMMARY CARD
//                           // ==================================================
//                           Container(
//                             width: double.infinity,
//                             decoration: BoxDecoration(
//                               color: AppColors.cardBackground,
//                               borderRadius: BorderRadius.circular(10),
//                               border: Border.all(
//                                 color: AppColors.border,
//                               ),
//                               boxShadow: const [
//                                 BoxShadow(
//                                   color: AppColors.shadow,
//                                   blurRadius: 6,
//                                   offset: Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               children: [
//                                 _blueInfoRow(
//                                   leftIcon: Icons.calendar_month_outlined,
//                                   leftTitle: "Date",
//                                   leftValue: item["sale_date"] != null
//                                       ? formatApiDate(
//                                     val(item["sale_date"]),
//                                   )
//                                       : "-",
//                                   rightIcon: Icons.scale_outlined,
//                                   rightTitle: "Gross Wt",
//                                   rightValue: val(
//                                     item["gross_weight"],
//                                   ),
//                                 ),
//
//                                 const Divider(
//                                   height: 1,
//                                   thickness: 1,
//                                   color: AppColors.border,
//                                 ),
//
//                                 _blueInfoRow(
//                                   leftIcon:
//                                   Icons.monitor_weight_outlined,
//                                   leftTitle: "Net Wt",
//                                   leftValue: val(
//                                     item["net_weight"],
//                                   ),
//                                   rightIcon:
//                                   Icons.currency_rupee_rounded,
//                                   rightTitle: "Amount",
//                                   rightValue:
//                                   "₹ ${val(item["net_total"])}",
//                                 ),
//                               ],
//                             ),
//                           ),
//
//                           const SizedBox(height: 16),
//
//                           // ==================================================
//                           // ITEMS SECTION HEADER
//                           // ==================================================
//                           Row(
//                             children: [
//                               _premiumSectionTitle(
//                                 icon: Icons.inventory_2_outlined,
//                                 title: "Sale Items",
//                               ),
//
//                               const Spacer(),
//
//                               Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 9,
//                                   vertical: 5,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.iconBg,
//                                   borderRadius: BorderRadius.circular(20),
//                                   border: Border.all(
//                                     color: AppColors.border,
//                                   ),
//                                 ),
//                                 child: Text(
//                                   "${items.length} "
//                                       "${items.length == 1 ? "Item" : "Items"}",
//                                   style: const TextStyle(
//                                     color: AppColors.primaryDark,
//                                     fontSize: 10,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//
//                           const SizedBox(height: 8),
//
//                           // ==================================================
//                           // EMPTY STATE
//                           // ==================================================
//                           if (items.isEmpty)
//                             Container(
//                               width: double.infinity,
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 32,
//                                 horizontal: 15,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: AppColors.cardBackground,
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: AppColors.border,
//                                 ),
//                               ),
//                               child: const Column(
//                                 children: [
//                                   Icon(
//                                     Icons.inventory_2_outlined,
//                                     color: AppColors.textLight,
//                                     size: 32,
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     "No sale items found",
//                                     style: TextStyle(
//                                       color: AppColors.textSecondary,
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//
//                           // ==================================================
//                           // ITEM CARDS
//                           // ==================================================
//                           ...List.generate(
//                             items.length,
//                                 (index) {
//                               final Map<String, dynamic> data =
//                               Map<String, dynamic>.from(
//                                 items[index] as Map,
//                               );
//
//                               final dynamic itemSet =
//                               data["itemset"];
//
//                               final dynamic itemData =
//                               itemSet is Map
//                                   ? itemSet["item"]
//                                   : null;
//
//                               return Container(
//                                 width: double.infinity,
//                                 margin: const EdgeInsets.only(
//                                   bottom: 9,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.cardBackground,
//                                   borderRadius:
//                                   BorderRadius.circular(10),
//                                   border: Border.all(
//                                     color: AppColors.border,
//                                   ),
//                                   boxShadow: const [
//                                     BoxShadow(
//                                       color: AppColors.shadow,
//                                       blurRadius: 6,
//                                       offset: Offset(0, 2),
//                                     ),
//                                   ],
//                                 ),
//                                 child: Column(
//                                   children: [
//                                     // ==========================================
//                                     // ITEM HEADER
//                                     // ==========================================
//                                     Container(
//                                       padding:
//                                       const EdgeInsets.symmetric(
//                                         horizontal: 10,
//                                         vertical: 9,
//                                       ),
//                                       decoration: const BoxDecoration(
//                                         color: AppColors.iconBg,
//                                         borderRadius: BorderRadius.only(
//                                           topLeft:
//                                           Radius.circular(9),
//                                           topRight:
//                                           Radius.circular(9),
//                                         ),
//                                       ),
//                                       child: Row(
//                                         children: [
//                                           // ITEM NUMBER
//                                           Container(
//                                             width: 27,
//                                             height: 27,
//                                             alignment:
//                                             Alignment.center,
//                                             decoration: BoxDecoration(
//                                               gradient:
//                                               const LinearGradient(
//                                                 colors: [
//                                                   AppColors.primaryDark,
//                                                   AppColors.gradientBlue,
//                                                 ],
//                                                 begin:
//                                                 Alignment.topLeft,
//                                                 end: Alignment
//                                                     .bottomRight,
//                                               ),
//                                               borderRadius:
//                                               BorderRadius.circular(
//                                                 6,
//                                               ),
//                                               boxShadow: const [
//                                                 BoxShadow(
//                                                   color:
//                                                   AppColors.shadow,
//                                                   blurRadius: 5,
//                                                   offset:
//                                                   Offset(0, 2),
//                                                 ),
//                                               ],
//                                             ),
//                                             child: Text(
//                                               "${index + 1}",
//                                               style:
//                                               const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 10,
//                                                 fontWeight:
//                                                 FontWeight.w700,
//                                               ),
//                                             ),
//                                           ),
//
//                                           const SizedBox(width: 8),
//
//                                           // ITEM NAME
//                                           Expanded(
//                                             child: Text(
//                                               val(data["item_name"]),
//                                               maxLines: 1,
//                                               overflow:
//                                               TextOverflow.ellipsis,
//                                               style:
//                                               const TextStyle(
//                                                 color: AppColors
//                                                     .textPrimary,
//                                                 fontSize: 13,
//                                                 fontWeight:
//                                                 FontWeight.w700,
//                                               ),
//                                             ),
//                                           ),
//
//                                           const SizedBox(width: 8),
//
//                                           // ITEM CODE
//                                           Container(
//                                             padding:
//                                             const EdgeInsets.symmetric(
//                                               horizontal: 8,
//                                               vertical: 4,
//                                             ),
//                                             decoration: BoxDecoration(
//                                               color: Colors.white,
//                                               borderRadius:
//                                               BorderRadius.circular(
//                                                 6,
//                                               ),
//                                               border: Border.all(
//                                                 color:
//                                                 AppColors.border,
//                                               ),
//                                             ),
//                                             child: Text(
//                                               val(
//                                                 itemData is Map
//                                                     ? itemData[
//                                                 "item_code"]
//                                                     : null,
//                                               ),
//                                               style:
//                                               const TextStyle(
//                                                 color: AppColors
//                                                     .primaryDark,
//                                                 fontSize: 10,
//                                                 fontWeight:
//                                                 FontWeight.w700,
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//
//                                     const Divider(
//                                       height: 1,
//                                       thickness: 1,
//                                       color: AppColors.border,
//                                     ),
//
//                                     // ==========================================
//                                     // WEIGHT DETAILS
//                                     // ==========================================
//                                     _blueInfoRow(
//                                       leftIcon:
//                                       Icons.scale_outlined,
//                                       leftTitle: "Gross Wt",
//                                       leftValue: val(
//                                         itemSet is Map
//                                             ? itemSet[
//                                         "gross_weight"]
//                                             : null,
//                                       ),
//                                       rightIcon:
//                                       Icons.remove_circle_outline,
//                                       rightTitle: "Less Wt",
//                                       rightValue: val(
//                                         itemSet is Map
//                                             ? itemSet["other"]
//                                             : null,
//                                       ),
//                                     ),
//
//                                     const Divider(
//                                       height: 1,
//                                       thickness: 1,
//                                       color: AppColors.border,
//                                     ),
//
//                                     _blueInfoRow(
//                                       leftIcon: Icons
//                                           .monitor_weight_outlined,
//                                       leftTitle: "Net Wt",
//                                       leftValue: val(
//                                         itemSet is Map
//                                             ? itemSet[
//                                         "net_weight"]
//                                             : null,
//                                       ),
//                                       rightIcon:
//                                       Icons.add_box_outlined,
//                                       rightTitle: "Other",
//                                       rightValue: val(
//                                         itemSet is Map
//                                             ? itemSet[
//                                         "sale_other"]
//                                             : null,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             },
//                           ),
//
//                           const SizedBox(height: 3),
//                         ],
//                       ),
//                     ),
//                   ),
//
//                   // ==========================================================
//                   // BOTTOM BAR
//                   // ==========================================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.fromLTRB(
//                       14,
//                       10,
//                       14,
//                       14,
//                     ),
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       border: Border(
//                         top: BorderSide(
//                           color: AppColors.border,
//                         ),
//                       ),
//                     ),
//                     child: SizedBox(
//                       width: double.infinity,
//                       height: 44,
//                       child: Material(
//                         color: Colors.transparent,
//                         child: InkWell(
//                           onTap: () {
//                             Navigator.pop(dialogContext);
//                           },
//                           borderRadius: BorderRadius.circular(8),
//                           child: Ink(
//                             decoration: BoxDecoration(
//                               gradient: const LinearGradient(
//                                 colors: [
//                                   AppColors.primaryDark,
//                                   AppColors.gradientBlue,
//                                 ],
//                                 begin: Alignment.centerLeft,
//                                 end: Alignment.centerRight,
//                               ),
//                               borderRadius:
//                               BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: AppColors.primaryDark
//                                       .withOpacity(0.22),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 3),
//                                 ),
//                               ],
//                             ),
//                             child: const Row(
//                               mainAxisAlignment:
//                               MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.check_circle_outline_rounded,
//                                   color: Colors.white,
//                                   size: 17,
//                                 ),
//                                 SizedBox(width: 7),
//                                 Text(
//                                   "Close",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
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
//   Widget pdfBtn1(VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(5),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [Color(0xffE57373), Color(0xffD32F2F)],
//           ),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: const [
//             Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
//             SizedBox(width: 4),
//             Text("PDF",
//                 style: TextStyle(
//                     color: Colors.white, fontWeight: FontWeight.w500)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> openApprovalPdf(
//       String fromDate,
//       String toDate,
//       ) async {
//
//     final fromDateApi = formatDate(fromDate);
//     final toDateApi = formatDate(toDate);
//     final response = await ApiHelper().getpdfapprovalreturnRequest(
//       "${ApiConstants.baseUrl}sales/export/listpdf"
//           "?from_date=$fromDateApi"
//           "&to_date=$toDateApi",
//       responseType: ResponseType.bytes,
//     );
//
//
//
//
//
//     if (response != null && response.statusCode == 200) {
//
//       final dir = await getTemporaryDirectory();
//
//       final file = File(
//         "${dir.path}/approval_report.pdf",
//       );
//
//       await file.writeAsBytes(response.data);
//
//       await OpenFile.open(file.path);
//
//     } else {
//
//       print("PDF Download Failed");
//
//     }
//   }
//
//   String formatDate(String date) {
//     final parts = date.split('-');
//
//     return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
//   }
//
//   @override
//   void dispose() {
//     /// Cancel timer
//     _huidTimer?.cancel();
//
//     /// Dispose controllers
//     searchController.dispose();
//     fromDateController.dispose();
//     toDateController.dispose();
//
//     super.dispose();
//   }
//
//   Widget _premiumSectionTitle({
//     required IconData icon,
//     required String title,
//   }) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 27,
//           height: 27,
//           alignment: Alignment.center,
//           decoration: BoxDecoration(
//             color: const Color(0xffD7B56D).withOpacity(0.12),
//             borderRadius: BorderRadius.circular(6),
//           ),
//           child: Icon(
//             icon,
//             size: 15,
//             color: const Color(0xff987437),
//           ),
//         ),
//         const SizedBox(width: 7),
//         Text(
//           title,
//           style: const TextStyle(
//             color: Color(0xff292929),
//             fontSize: 13,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _blueInfoRow({
//     required IconData leftIcon,
//     required String leftTitle,
//     required String leftValue,
//     required IconData rightIcon,
//     required String rightTitle,
//     required String rightValue,
//   }) {
//     Widget infoCell({
//       required IconData icon,
//       required String title,
//       required String value,
//     }) {
//       return Expanded(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(
//             horizontal: 10,
//             vertical: 10,
//           ),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Container(
//                 width: 30,
//                 height: 30,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: AppColors.iconBg,
//                   borderRadius: BorderRadius.circular(7),
//                 ),
//                 child: Icon(
//                   icon,
//                   color: AppColors.primaryDark,
//                   size: 15,
//                 ),
//               ),
//
//               const SizedBox(width: 8),
//
//               Expanded(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment:
//                   CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: AppColors.textSecondary,
//                         fontSize: 9.5,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//
//                     const SizedBox(height: 3),
//
//                     Text(
//                       value,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: AppColors.textPrimary,
//                         fontSize: 11.5,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return IntrinsicHeight(
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           infoCell(
//             icon: leftIcon,
//             title: leftTitle,
//             value: leftValue,
//           ),
//
//           Container(
//             width: 1,
//             margin: const EdgeInsets.symmetric(
//               vertical: 8,
//             ),
//             color: AppColors.border,
//           ),
//
//           infoCell(
//             icon: rightIcon,
//             title: rightTitle,
//             value: rightValue,
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showDeleteDialog(dynamic id) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           title: const Text(
//             "Delete Voucher",
//             style: TextStyle(
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           content: const Text(
//             "Are you sure you want to delete this voucher?",
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(dialogContext);
//               },
//               child: const Text("Cancel"),
//             ),
//
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 foregroundColor: Colors.white,
//               ),
//               onPressed: () async {
//                 Navigator.pop(dialogContext);
//
//                 // Confirm pachi GET API
//                 await deleteSale(id);
//               },
//               child: const Text("Delete"),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<void> deleteSale(dynamic id) async {
//     try {
//       print("DELETE SALE API => /sales/$id");
//
//       final response = await ApiHelper().deleteRequest(
//         "/sales/$id",
//       );
//
//       print("DELETE SALE RESPONSE => ${response!.data}");
//
//       if (response!.data["success"] == true) {
//         // success
//         print("SALE DELETED SUCCESSFULLY");
//
//         // list refresh
//         await getSaleDetails();
//       }
//     } catch (e) {
//       print("DELETE SALE ERROR => $e");
//     }
//   }
//
//   void searchCustomer(String value) {
//     if (value.trim().isEmpty) {
//       setState(() {
//         userlist = List.from(allUsers);
//       });
//       return;
//     }
//
//     final String query = value.trim().toLowerCase();
//
//     List filtered = allUsers.where((item) {
//       final String customerName =
//           item["customer"]?["name"]?.toString().toLowerCase() ?? "";
//
//       final String voucherNo =
//           item["voucher_no"]?.toString().toLowerCase() ?? "";
//
//       final String mobile =
//           item["customer"]?["mobile_no"]?.toString().toLowerCase() ?? "";
//
//       return customerName.contains(query) ||
//           voucherNo.contains(query) ||
//           mobile.contains(query);
//     }).toList();
//
//     setState(() {
//       userlist = filtered;
//     });
//   }
//
//   /// 🔥 Customer select / clear → filter ફરી લગાવો
//   void _setCustomerFilter(Map<String, dynamic>? customer) {
//     setState(() {
//       selectedItem = customer?["id"]?.toString();
//       selectedCompanyId = customer?["company_id"]?.toString();
//       selectedUserId = customer?["id"]?.toString();
//
//       /// Customer clear થાય ત્યારે cart પણ ખાલી
//       if (customer == null) cartItems = [];
//     });
//
//     /// customer હોય → list filter, null → બધું દેખાશે
//     applyDateFilter();
//   }
// }
//
//
//


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'SellScreen.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class SellList extends StatefulWidget {
  const SellList({super.key});

  @override
  State<SellList> createState() => _SellListState();
}

class _SellListState extends State<SellList> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  List userlist = [];
  List<Map<String, dynamic>> allItems = [];
  String? selectedItem;
  List<Map<String, dynamic>> tableRows = [];
  Timer? _huidTimer;
  int apiRowCount = 0;
  List customerlist = [];
  String? selectedUser;
  String? selectedCompanyId;
  String? selectedUserId;
  DateTime? birthDate;
  DateTime? anniversaryDate;
  List cartItems = [];
  List allUsers = []; // 🔥 original data store

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        // ✅ hammesha dd-MM-yyyy (01-05-2026)
        controller.text = DateFormat("dd-MM-yyyy").format(picked);
      });
    }
  }

  void applyDateFilter() {
    List result = List.from(allUsers);

    // 📅 Date filter
    if (fromDateController.text.isNotEmpty &&
        toDateController.text.isNotEmpty) {
      final fromDate = _convertToDate(fromDateController.text);
      final toDate = _convertToDate(toDateController.text);

      final startDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final endDate =
      DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

      result = result.where((user) {
        final rawDate = user["modified_at"];
        if (rawDate == null) return false;

        final DateTime? parsed = DateTime.tryParse(rawDate.toString());
        if (parsed == null) return false;
        final d = parsed.toLocal();
        return d.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            d.isBefore(endDate.add(const Duration(seconds: 1)));
      }).toList();
    }

    // 👤 Customer filter
    if (selectedUserId != null && selectedUserId!.isNotEmpty) {
      result = result.where((sale) {
        final customerId = sale["customer"]?["id"]?.toString() ??
            sale["customer_id"]?.toString();
        return customerId == selectedUserId;
      }).toList();
    }

    setState(() {
      userlist = result;
    });
  }

  DateTime _convertToDate(String input) {
    try {
      return DateFormat("d-M-yyyy").parse(input.trim());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// From / To date (dd-MM-yyyy → yyyy-MM-dd), khotu ke khali hoy to null
  ({String? from, String? to}) _apiRange() {
    String? conv(String s) {
      try {
        if (s.trim().isEmpty) return null;
        return DateFormat("yyyy-MM-dd")
            .format(DateFormat("d-M-yyyy").parse(s.trim()));
      } catch (_) {
        return null;
      }
    }

    return (from: conv(fromDateController.text), to: conv(toDateController.text));
  }

  /// ✅ Create / Edit / Delete pachhi — same date range thi refresh
  Future<void> _refreshList() async {
    final r = _apiRange();
    await getSaleDetails(fromDate: r.from, toDate: r.to);
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (Sale Summary jevu j)
  // ============================================================

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe?
  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// management_branches[]=1&management_branches[]=2
  String get _branchQuery => appliedCompanyIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// sale_list?management_branches[]=1&management_branches[]=2 (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// sale → branch name (company_id / branch / company_name)
  String _branchOf(Map user) {
    final int? id = int.tryParse("${user["company_id"] ?? ""}");
    if (id != null) {
      for (final c in branchCompanies) {
        if (c.id == id) return c.name;
      }
    }
    final dynamic b = user["branch"] ?? user["branch_name"] ?? user["company"];
    if (b is Map && b["name"] != null) return b["name"].toString();
    final String t = (b ?? user["company_name"] ?? "").toString().trim();
    return t.isEmpty || t == "null" ? "" : t;
  }

  /// Main company nu id (branch list mathi)
  int? get _mainCompanyId {
    for (final c in branchCompanies) {
      if (c.isMain) return c.id;
    }
    return null;
  }

  /// ✅ Aa sale main company no chhe? (fakt eno j edit / delete)
  /// Branch list j na hoy (branch user) to potano j data → true
  bool _isMainData(Map user) {
    final int? mainId = _mainCompanyId;
    if (mainId == null) return true;

    final int? id = int.tryParse("${user["company_id"] ?? ""}");
    if (id != null) return id == mainId;

    // company_id na aave to branch na naam thi
    final String br = _branchOf(user).trim().toLowerCase();
    if (br.isEmpty) return true;
    for (final c in branchCompanies) {
      if (c.name.trim().toLowerCase() == br) return c.isMain;
    }
    return true;
  }

  List<String> userPermissions = [];

  Future<void> loadPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> perms = prefs.getStringList("user_permissions") ?? [];

    setState(() {
      userPermissions = perms;
    });
  }

  /// 🔥 Permission check helper
  bool hasPermission(String permissionName) {
    return userPermissions.contains(permissionName);
  }

  @override
  void initState() {
    super.initState();

    loadPermissions();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
    });
    DateTime today = DateTime.now();
    DateTime sevenDaysAgo = today.subtract(const Duration(days: 7));

    String formatDate(DateTime date) {
      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    }

    fromDateController.text = formatDate(sevenDaysAgo);
    toDateController.text = formatDate(today);

    String from = DateFormat("yyyy-MM-dd").format(
      DateFormat("dd-MM-yyyy").parse(fromDateController.text),
    );

    String to = DateFormat("yyyy-MM-dd").format(
      DateFormat("dd-MM-yyyy").parse(toDateController.text),
    );
    getSaleDetails(
      fromDate: from,
      toDate: to,
    );
    _loadBranches();
  }

  Future<void> getSaleDetails({
    String? fromDate,
    String? toDate,
  }) async {
    String url = ApiConstants.sale_list;

    if (fromDate != null &&
        toDate != null &&
        fromDate.isNotEmpty &&
        toDate.isNotEmpty) {
      url += "?from_date=$fromDate&to_date=$toDate";
    }

    // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
    url = _br(url);
    debugPrint("📋 SALE LIST URL => $url");

    final response = await ApiHelper().getRequest(url);

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final List categories = data['data'] ?? [];
      AppMessage.success(
          context, data["message"] ?? "Data Loaded Successfully");
      setState(() {
        tableRows.clear();
        userlist = categories;
        allItems = List<Map<String, dynamic>>.from(
          categories.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        allUsers = allItems; // 🔥 store original
      });
      applyDateFilter();
    } else {
      setState(() {
        userlist = [];
        allItems = [];
        allUsers = [];
      });
      debugPrint("API Failed");
      AppMessage.error(context, "Failed to load data");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("sale-view") || hasPermission("sale-manage"))) {
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 600;

    final bool canCreate = hasPermission("sale-create");

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ✅ Main Content
            Column(
              children: [
                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 40,
                ),

                // 🔥 Branch Reports tab sauthi upar
                _buildBranchCard(),

                /// 🔥 FILTER SECTION
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

                /// 🔥 LIST
                Expanded(
                  child: userlist.isEmpty
                      ? const Center(
                    child: Text(
                      "No Data Found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: userlist.length,
                    itemBuilder: (context, index) {
                      final item = userlist[index];
                      return buildCard(item, index);
                    },
                  ),
                ),

                /// =====================================================
                /// 🔥 LIST SUMMARY BAR
                /// Filter pachhi dekhati sales no total
                /// =====================================================
                if (userlist.isNotEmpty)
                  SafeArea(
                    top: false,
                    bottom: !canCreate,
                    child: _listSummaryBar(userlist),
                  ),

                if (canCreate)
                /// Bottom Button
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Sellscreen(),
                        ),
                      );

                      // ✅ Create pachhi list refresh
                      if (!mounted) return;
                      if (result == true) await _refreshList();
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                            "+ Create Sale",
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    /// ✅ CENTER TITLE
                    const Text(
                      "Sale Estimate List",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        onTap: () {
                          Navigator.pop(context, true);
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(5),
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

                    /// ✅ RIGHT — EXCEL + PDF
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _exportBtn(
                            icon: Icons.table_chart_rounded,
                            color: const Color(0xff16A34A),
                            tooltip: "Excel",
                            busy: _exporting == "excel",
                            onTap: () => _export("excel"),
                            isMobile: isMobile,
                          ),
                          const SizedBox(width: 8),
                          _exportBtn(
                            icon: Icons.picture_as_pdf_rounded,
                            color: const Color(0xffDC2626),
                            tooltip: "PDF",
                            busy: _exporting == "pdf",
                            onTap: () => _export("pdf"),
                            isMobile: isMobile,
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
      ),
    );
  }

  // ============================================================
  // 🔥 LIST SUMMARY BAR
  //
  // Gross Wt | Less Wt | Net Wt | Fine Wt | Other Amt | Total Amt
  //
  // Less  = other_weight hoy to e, nahi to Gross - Net
  // Total = net_total
  // ============================================================
  double _num(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString().replaceAll(",", "")) ?? 0;
  }

  Widget _listSummaryBar(List sales) {
    double gross = 0;
    double less = 0;
    double net = 0;
    double fine = 0;
    double otherAmt = 0;
    double total = 0;

    for (final s in sales) {
      if (s is! Map) continue;

      final double g = _num(s["gross_weight"]);
      final double n = _num(s["net_weight"]);

      gross += g;
      net += n;

      /// other_weight / less_weight hoy to e, nahi to Gross - Net
      final dynamic lessRaw = s["other_weight"] ?? s["less_weight"];
      less += lessRaw != null ? _num(lessRaw) : (g - n);

      fine += _num(s["fine_weight"]);
      otherAmt += _num(s["other_amount"]);
      total += _num(s["net_total"] ?? s["total_amount"]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _summaryBox("Gross Wt", gross.toStringAsFixed(3)),
            _summaryBox("Less Wt", less.toStringAsFixed(3)),
            _summaryBox("Net Wt", net.toStringAsFixed(3)),
            _summaryBox("Fine Wt", fine.toStringAsFixed(3)),
            _summaryBox("Other Amt", otherAmt.toStringAsFixed(2)),
            _summaryBox(
              "Total Amt",
              total.toStringAsFixed(2),
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Ek box — horizontal list ma (ochhama ochhi 92 width)
  Widget _summaryBox(String title, String value, {bool highlight = false}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gradientBlue.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? AppColors.gradientBlue : Colors.grey.shade300,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.primaryDark : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Header Section
  Widget topHeaderSectionGlass(double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundImage: AssetImage("assets/static/img.png"),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "OrnaSphere",
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: Icon(Icons.notifications_none,
                            color: AppColors.white, size: 26),
                      ),
                      const SizedBox(width: 15),
                      const CircleAvatar(
                        radius: 16,
                        backgroundImage:
                        NetworkImage("https://i.pravatar.cc/150?img=3"),
                      )
                    ],
                  )
                ],
              ),

              const SizedBox(height: 5),

              /// Bottom Right Buttons
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Sellscreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00C853),
                              Color(0xFF64DD17),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Create Sale",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  int? expandedSaleId;

  Widget buildCard(Map<String, dynamic> item, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    // UNIQUE ID
    final int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedSaleId == id;

    // DATA
    final String voucherNo = item["voucher_no"]?.toString() ?? "-";
    final String customerName = item["customer"]?["name"]?.toString() ?? "-";
    final String metal = item["metal"]?.toString() ?? "-";
    final String modifiedAt = item["modified_at"]?.toString() ?? "";
    final String mobile = item["customer"]?["mobile_no"]?.toString() ?? "-";
    final String email = item["customer"]?["email"]?.toString() ?? "-";
    final String totalAmount = item["net_total"]?.toString() ?? "-";
    final String receivedAmount = item["received_amount"]?.toString() ?? "-";
    final String pendingAmount = item["pending_amount"]?.toString() ?? "-";

    /// 🔐 Main company sivay ni branch no data → edit / delete nahi
    final bool canModify = _isMainData(item);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isExpanded
              ? AppColors.primaryDark.withOpacity(0.45)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Column(
          children: [
            // HEADER - ALWAYS VISIBLE
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 10,
                vertical: isTablet ? 12 : 10,
              ),
              child: Row(
                children: [
                  // INDEX
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gradientBlue,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // VOUCHER NO + CUSTOMER
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voucherNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        /// 🏢 BRANCH (branch mode)
                        if (_branchMode && _branchOf(item).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.primaryDark.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.store_mall_directory_rounded,
                                    size: 11, color: AppColors.primaryDark),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _branchOf(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 5),

                  // METAL STATUS
                  statusChip(metal),

                  SizedBox(width: isTablet ? 8 : 5),

                  // EDIT
                  if (canModify &&
                      (hasPermission("sale-edit") ||
                          hasPermission("sale-manage"))) ...[
                    premiumIconBtn(
                      Icons.edit_rounded,
                      AppColors.gradientBlue,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Sellscreen(userData: item),
                          ),
                        );

                        // ✅ Update pachhi list refresh
                        if (!mounted) return;
                        if (result == true) await _refreshList();
                      },
                    ),
                    SizedBox(width: isTablet ? 8 : 5),
                  ],

                  // DELETE
                  if (canModify && hasPermission("sale-delete")) ...[
                    premiumIconBtn(
                      Icons.delete_outline_rounded,
                      Colors.red,
                      onTap: () {
                        _showDeleteDialog(id);
                      },
                    ),
                    SizedBox(width: isTablet ? 8 : 5),
                  ],

                  // PDF
                  pdfBtn(() {
                    final String pdfUrl = item["pdf_url"]?.toString() ?? "";

                    if (pdfUrl.isNotEmpty) {
                      openPdfUrl(pdfUrl);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("PDF not available"),
                        ),
                      );
                    }
                  }),

                  SizedBox(width: isTablet ? 8 : 5),

                  // EXPAND BUTTON
                  InkWell(
                    onTap: () {
                      setState(() {
                        expandedSaleId = expandedSaleId == id ? null : id;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // EXPANDED SECTION
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              firstChild: const SizedBox(
                width: double.infinity,
                height: 0,
              ),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          _erpRow(
                            "Date",
                            modifiedAt.isNotEmpty
                                ? formatApiDate(modifiedAt)
                                : "-",
                            "Mobile",
                            mobile,
                          ),
                          Divider(height: 1, color: AppColors.border),
                          _erpRow(
                            "Total Amt",
                            totalAmount,
                            "Email",
                            email,
                          ),
                          Divider(height: 1, color: AppColors.border),
                          _erpRow(
                            "Received Amt",
                            receivedAmount,
                            "Pending Amt",
                            pendingAmount,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ),
      ),
    );
  }

  Widget _erpRow(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          /// Left Field
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

          /// Right Field
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

  Widget premiumIconBtn(IconData icon, Color color,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  /// 🔹 PDF Button
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
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  /// 🔹 Status Chip
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
        return const SizedBox.shrink(); // 👈 Unknown hide
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
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
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openPdf(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.Sale_pdf,
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/return_$id.pdf");

      await file.writeAsBytes(response.data);

      OpenFile.open(file.path);
    } else {
      debugPrint("PDF Download Failed");
    }
  }

  /// Header Cell
  Widget _buildHeaderCell(String title) {
    return Expanded(
      child: Container(
        height: 55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff2B3050),
              Color(0xff1b1411),
              Color(0xff3A3F63),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            right: BorderSide(
              color: const Color(0xffC9A44A).withOpacity(0.6),
              width: 1.2,
            ),
            left: BorderSide(
              color: const Color(0xffC9A44A).withOpacity(0.6),
              width: 1.2,
            ),
            top: BorderSide(
              color: const Color(0xffC9A44A).withOpacity(0.6),
              width: 1.2,
            ),
            bottom: BorderSide(
              color: const Color(0xffC9A44A).withOpacity(0.6),
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xffE6C36A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void calculateNetWeight(int index) {
    double gross = double.tryParse(tableRows[index]["gross"]!.text) ?? 0;

    double other = double.tryParse(tableRows[index]["other"]!.text) ?? 0;

    double net = gross - other;

    tableRows[index]["net"]!.text = net.toStringAsFixed(3);
  }

  Future<void> loadItemDetails(String itemId) async {
    final response = await ApiHelper().postRequest(
      ApiConstants.label_item_list,
      {"item_id": itemId},
    );

    if (response != null &&
        response.statusCode == 200 &&
        response.data["data"] != null) {
      final List data = response.data["data"];

      setState(() {
        tableRows.clear();

        for (var row in data) {
          tableRows.add({
            "gross": TextEditingController(text: row["gross_weight"] ?? ""),
            "other": TextEditingController(text: row["other"] ?? ""),
            "net": TextEditingController(text: row["net_weight"] ?? ""),
            "labourRate": TextEditingController(
                text: row["sale_labour_rate"]?.toString() ?? ""),
            "labourAmount": TextEditingController(
                text: row["sale_labour_amount"]?.toString() ?? ""),
            "purity": TextEditingController(
                text: row["outward_purity"]?.toString() ?? ""),
            "size": TextEditingController(text: row["size"] ?? ""),
            "huid": TextEditingController(text: row["HUID"] ?? ""),
          });
        }
        apiRowCount = data.length;

        /// 🔥 Extra 3 Empty Rows
        for (int i = 0; i < 3; i++) {
          tableRows.add({
            "gross": TextEditingController(),
            "other": TextEditingController(),
            "net": TextEditingController(),
            "labourRate": TextEditingController(),
            "labourAmount": TextEditingController(),
            "purity": TextEditingController(),
            "size": TextEditingController(),
            "huid": TextEditingController(),
          });
        }
      });
    }
  }

  Widget _buildDateField(
      BuildContext context,
      String label,
      DateTime? selectedDate,
      Function(DateTime) onDateSelected,
      ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: screenHeight * 0.01),
        GestureDetector(
          onTap: () async {
            DateTime initialDate = selectedDate ?? DateTime.now();

            final pickedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );

            if (pickedDate != null) {
              onDateSelected(pickedDate);
            }
          },
          child: Container(
            height: screenHeight * 0.055,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate == null
                      ? "Select Date"
                      : "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}",
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.amberAccent,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, String>>?> openApprovePopup(
      BuildContext context) async {
    List<Map<String, String>> tableRows = [];
    TextEditingController labelController = TextEditingController();
    String? popupSelectedUser;
    bool showScanner = false;
    bool showLabelField = false;

    return showDialog<List<Map<String, String>>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    height: showScanner || showLabelField ? 700 : 500,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Sale Estimate",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      showLabelField = true;
                                      showScanner = false;
                                    });
                                  },
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      showScanner = true;
                                      showLabelField = false;
                                    });
                                  },
                                  icon: const Icon(Icons.qr_code_scanner,
                                      color: Colors.white),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                ),
                              ],
                            )
                          ],
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Select Party",
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: Colors.black,
                                  hint: const Text(
                                    "Select Customer",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  value: popupSelectedUser,
                                  items: customerlist
                                      .map<DropdownMenuItem<String>>((user) {
                                    return DropdownMenuItem<String>(
                                      value: user["id"].toString(),
                                      child: Text(
                                        user["name"] ?? "",
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      popupSelectedUser = val;
                                      showScanner = false;
                                      showLabelField = false;
                                      final selectedData =
                                      customerlist.firstWhere(
                                            (user) => user["id"].toString() == val,
                                      );
                                      selectedCompanyId =
                                          selectedData["company_id"]
                                              .toString();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (popupSelectedUser != null) ...[
                              const SizedBox(height: 15),

                              /// Label TextField
                              if (showLabelField) ...[
                                TextField(
                                  controller: labelController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Enter Label",
                                    labelStyle: const TextStyle(
                                        color: Colors.white70),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onSubmitted: (value) {
                                    if (value.trim().isEmpty) return;

                                    setState(() {
                                      tableRows.add({
                                        "gross": "10.0",
                                        "other": "2.5",
                                        "net": "7.5",
                                        "size": "10",
                                        "huid": "001",
                                      });
                                    });

                                    labelController.clear();
                                  },
                                ),
                              ],

                              const SizedBox(height: 20),

                              /// Table/Grid
                              SizedBox(
                                height: 220,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        border:
                                        Border.all(color: Colors.white24),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildHeaderCell("Gross\nWeight"),
                                          _buildHeaderCell("Other"),
                                          _buildHeaderCell("Net\nWeight"),
                                          _buildHeaderCell("Size"),
                                          _buildHeaderCell("HUID"),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Table(
                                          border: TableBorder.all(
                                              color: Colors.white24),
                                          children: tableRows.map((row) {
                                            return TableRow(
                                              children: [
                                                _buildTableCell1(row["gross"]!,
                                                        (val) {
                                                      row["gross"] = val;
                                                    }),
                                                _buildTableCell1(row["other"]!,
                                                        (val) {
                                                      row["other"] = val;
                                                    }),
                                                _buildTableCell1(row["net"]!,
                                                        (val) {
                                                      row["net"] = val;
                                                    }),
                                                _buildTableCell1(row["size"]!,
                                                        (val) {
                                                      row["size"] = val;
                                                    }),
                                                _buildTableCell1(row["huid"]!,
                                                        (val) {
                                                      row["huid"] = val;
                                                    }),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),

                              /// Submit Button
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00C853),
                                      Color(0xFF64DD17),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, tableRows);
                                  },
                                  child: const Text(
                                    "Submit",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            ]
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTableCell1(String value, Function(String) onChanged) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          right: BorderSide(
            color: const Color(0xffC9A44A).withOpacity(0.6),
            width: 0.8,
          ),
          left: BorderSide(
            color: const Color(0xffC9A44A).withOpacity(0.6),
            width: 0.8,
          ),
          bottom: BorderSide(
            color: const Color(0xffC9A44A).withOpacity(0.6),
            width: 0.8,
          ),
        ),
      ),
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 0),
          border: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> openPdfUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $uri');
    }
  }

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
          /// 👤 CUSTOMER
          Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final List<Map<String, dynamic>> customers = provider
                    .customers
                    .map<Map<String, dynamic>>(
                        (e) => Map<String, dynamic>.from(e))
                    .toList();

                Map<String, dynamic>? selectedCustomer;

                if (selectedItem != null) {
                  for (final e in customers) {
                    if (e["id"]?.toString() == selectedItem.toString()) {
                      selectedCustomer = e;
                      break;
                    }
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
                      itemLabel: (customer) =>
                      customer["name"]?.toString() ?? "",
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
                      onChanged: (customer) => _setCustomerFilter(customer),
                    ),

                    /// ❌ CLEAR
                    if (selectedCustomer != null)
                      Positioned(
                        right: 40,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _setCustomerFilter(null);
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

          const SizedBox(height: 5),

          /// 📅 DATE ROW
          Row(
            children: [
              Expanded(child: _dateInput(fromDateController, "From Date")),
              const SizedBox(width: 8),
              Expanded(child: _dateInput(toDateController, "To Date")),
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
                    applyDateFilter();
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

              Expanded(
                child: pdfBtn1(() {
                  openApprovalPdf(
                    fromDateController.text,
                    toDateController.text,
                  );
                }),
              ),
            ],
          )
        ],
      ),
    );
  }

  /// 📅 Date field (From / To — banne same design)
  Widget _dateInput(TextEditingController controller, String hint) {
    return InkWell(
      onTap: () => _selectDate(controller),
      child: IgnorePointer(
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            suffixIcon: const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.primaryDark,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }

  String formatApiDate(String input) {
    try {
      DateTime date = DateTime.parse(input);

      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    } catch (e) {
      return "";
    }
  }

  Future<void> getApprovalDetails(dynamic id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequestWithId(
      ApiConstants.sale_item_update,
      id,
      responseType: ResponseType.bytes,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (response != null && response.statusCode == 200) {
      /// 🔥 BYTES → STRING → JSON
      String jsonString = utf8.decode(response.data);
      final data = jsonDecode(jsonString);

      final item = data["data"] is List ? data["data"][0] : data["data"];

      showApprovalDialog(item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load details")));
    }
  }

  void showApprovalDialog(Map<String, dynamic> item) {
    String val(dynamic v) {
      if (v == null || v.toString().trim().isEmpty) {
        return "-";
      }
      return v.toString();
    }

    final List items = item["sale_items"] is List ? item["sale_items"] : [];

    final int saleId = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;
        final bool isTablet = size.width >= 600;

        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 50 : 14,
            vertical: 24,
          ),
          child: Container(
            width: isTablet ? 720 : double.infinity,
            constraints: BoxConstraints(maxHeight: size.height * 0.88),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.gradientBlue,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Sale Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                val(item["voucher_no"]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _dialogHeaderBtn(
                          icon: Icons.picture_as_pdf_rounded,
                          onTap: () {
                            if (saleId > 0) openPdf(saleId);
                          },
                        ),
                        const SizedBox(width: 7),
                        _dialogHeaderBtn(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),

                  // BODY
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CUSTOMER HERO CARD
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: AppColors.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 43,
                                  height: 43,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.iconBg,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.primaryDark,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        val(item["customer"]?["name"]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        "Customer",
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.iconBg,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.receipt_outlined,
                                        color: AppColors.primaryDark,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        val(item["voucher_no"]),
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          _premiumSectionTitle(
                            icon: Icons.analytics_outlined,
                            title: "Sale Summary",
                          ),

                          const SizedBox(height: 8),

                          // SALE SUMMARY CARD
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _blueInfoRow(
                                  leftIcon: Icons.calendar_month_outlined,
                                  leftTitle: "Date",
                                  leftValue: item["sale_date"] != null
                                      ? formatApiDate(val(item["sale_date"]))
                                      : "-",
                                  rightIcon: Icons.scale_outlined,
                                  rightTitle: "Gross Wt",
                                  rightValue: val(item["gross_weight"]),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.border,
                                ),
                                _blueInfoRow(
                                  leftIcon: Icons.monitor_weight_outlined,
                                  leftTitle: "Net Wt",
                                  leftValue: val(item["net_weight"]),
                                  rightIcon: Icons.currency_rupee_rounded,
                                  rightTitle: "Amount",
                                  rightValue: "₹ ${val(item["net_total"])}",
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ITEMS SECTION HEADER
                          Row(
                            children: [
                              _premiumSectionTitle(
                                icon: Icons.inventory_2_outlined,
                                title: "Sale Items",
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  "${items.length} "
                                      "${items.length == 1 ? "Item" : "Items"}",
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // EMPTY STATE
                          if (items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                                horizontal: 15,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: AppColors.textLight,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "No sale items found",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ITEM CARDS
                          ...List.generate(items.length, (index) {
                            final Map<String, dynamic> data =
                            Map<String, dynamic>.from(items[index] as Map);

                            final dynamic itemSet = data["itemset"];
                            final dynamic itemData =
                            itemSet is Map ? itemSet["item"] : null;

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 9),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // ITEM HEADER
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 9,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.iconBg,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(9),
                                        topRight: Radius.circular(9),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 27,
                                          height: 27,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                AppColors.primaryDark,
                                                AppColors.gradientBlue,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                            BorderRadius.circular(6),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: AppColors.shadow,
                                                blurRadius: 5,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            "${index + 1}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            val(data["item_name"]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                            BorderRadius.circular(6),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: Text(
                                            val(itemData is Map
                                                ? itemData["item_code"]
                                                : null),
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

                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),

                                  // WEIGHT DETAILS
                                  _blueInfoRow(
                                    leftIcon: Icons.scale_outlined,
                                    leftTitle: "Gross Wt",
                                    leftValue: val(itemSet is Map
                                        ? itemSet["gross_weight"]
                                        : null),
                                    rightIcon: Icons.remove_circle_outline,
                                    rightTitle: "Less Wt",
                                    rightValue: val(
                                        itemSet is Map ? itemSet["other"] : null),
                                  ),

                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),

                                  _blueInfoRow(
                                    leftIcon: Icons.monitor_weight_outlined,
                                    leftTitle: "Net Wt",
                                    leftValue: val(itemSet is Map
                                        ? itemSet["net_weight"]
                                        : null),
                                    rightIcon: Icons.add_box_outlined,
                                    rightTitle: "Other",
                                    rightValue: val(itemSet is Map
                                        ? itemSet["sale_other"]
                                        : null),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 3),
                        ],
                      ),
                    ),
                  ),

                  // BOTTOM BAR
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(dialogContext),
                          borderRadius: BorderRadius.circular(8),
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
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  AppColors.primaryDark.withOpacity(0.22),
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
                                  size: 17,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  "Close",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
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
          ),
        );
      },
    );
  }

  /// Dialog header na nana white buttons (PDF / Close)
  Widget _dialogHeaderBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget pdfBtn1(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              "PDF",
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openApprovalPdf(String fromDate, String toDate) async {
    if (fromDate.trim().isEmpty || toDate.trim().isEmpty) {
      AppMessage.error(context, "Please select From and To date");
      return;
    }

    final fromDateApi = formatDate(fromDate);
    final toDateApi = formatDate(toDate);

    // 🔥 Branch mode → &management_branches[]=1&management_branches[]=2
    final String url = _br(
      "${ApiConstants.baseUrl}sales/export/listpdf"
          "?from_date=$fromDateApi"
          "&to_date=$toDateApi",
    );
    debugPrint("📤 SALE LIST PDF URL => $url");

    final response = await ApiHelper().getpdfapprovalreturnRequest(
      url,
      responseType: ResponseType.bytes,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/approval_report.pdf");

      await file.writeAsBytes(response.data);

      await OpenFile.open(file.path);
    } else {
      debugPrint("PDF Download Failed");
    }
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// sale_list?from_date=..&to_date=..&management_branches[]=1&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.sale_list;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // List ma je date + branch chhe e j export ma pan
      final r = _apiRange();
      String base = _exportUrl;
      if (r.from != null && r.to != null) {
        base += "?from_date=${r.from}&to_date=${r.to}";
      }
      base = _br(base);
      final String url = "$base${base.contains('?') ? '&' : '?'}export=$type";
      debugPrint("📤 EXPORT $type URL => $url");

      final response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        AppMessage.error(
          context,
          _exportError(response?.data) ??
              "Failed to download ${type == 'pdf' ? 'PDF' : 'Excel'}",
        );
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // Bytes ni jagya e JSON error aave to
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        AppMessage.error(
          context,
          _exportError(raw) ?? "No file received from server",
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final String stamp =
          "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}";
      final String ext = type == "pdf" ? "pdf" : "xlsx";
      final file = File("${dir.path}/Sale_List_$stamp.$ext");
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      AppMessage.success(
          context, "${type == 'pdf' ? 'PDF' : 'Excel'} downloaded");
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ EXPORT $type ERROR => $e");
      if (mounted) AppMessage.error(context, "Download failed");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  /// JSON (bytes / map / string) mathi message
  String? _exportError(dynamic data) {
    try {
      dynamic d = data;
      if (d is List<int>) d = utf8.decode(d);
      if (d is String) d = jsonDecode(d);
      if (d is Map && d["message"] != null) return d["message"].toString();
    } catch (_) {}
    return null;
  }

  Widget _exportBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool busy,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _exporting != null ? null : onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          // Loader fakt ApiHelper nu j (button ma spinner nahi)
          child: Opacity(
            opacity: busy ? 0.5 : 1,
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
        ),
      ),
    );
  }


  /// "05-10-2026" → "2026-10-05"
  String formatDate(String date) {
    final parts = date.split('-');

    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _huidTimer?.cancel();

    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();

    super.dispose();
  }

  Widget _premiumSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xffD7B56D).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 15,
            color: const Color(0xff987437),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff292929),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _blueInfoRow({
    required IconData leftIcon,
    required String leftTitle,
    required String leftValue,
    required IconData rightIcon,
    required String rightTitle,
    required String rightValue,
  }) {
    Widget infoCell({
      required IconData icon,
      required String title,
      required String value,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          infoCell(icon: leftIcon, title: leftTitle, value: leftValue),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.border,
          ),
          infoCell(icon: rightIcon, title: rightTitle, value: rightValue),
        ],
      ),
    );
  }

  void _showDeleteDialog(dynamic id) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            "Delete Voucher",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            "Are you sure you want to delete this voucher?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await deleteSale(id);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteSale(dynamic id) async {
    try {
      final response = await ApiHelper().deleteRequest("/sales/$id");

      if (response != null && response.data?["success"] == true) {
        /// 🔥 Same date range thi list refresh (summary pan update thase)
        // ✅ Date khali hoy to pan crash nahi
        await _refreshList();
      }
    } catch (e) {
      debugPrint("DELETE SALE ERROR => $e");
    }
  }

  void searchCustomer(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        userlist = List.from(allUsers);
      });
      return;
    }

    final String query = value.trim().toLowerCase();

    List filtered = allUsers.where((item) {
      final String customerName =
          item["customer"]?["name"]?.toString().toLowerCase() ?? "";

      final String voucherNo =
          item["voucher_no"]?.toString().toLowerCase() ?? "";

      final String mobile =
          item["customer"]?["mobile_no"]?.toString().toLowerCase() ?? "";

      return customerName.contains(query) ||
          voucherNo.contains(query) ||
          mobile.contains(query);
    }).toList();

    setState(() {
      userlist = filtered;
    });
  }

  /// 🔥 Customer select / clear → filter ફરી લગાવો
  void _setCustomerFilter(Map<String, dynamic>? customer) {
    setState(() {
      selectedItem = customer?["id"]?.toString();
      selectedCompanyId = customer?["company_id"]?.toString();
      selectedUserId = customer?["id"]?.toString();

      if (customer == null) cartItems = [];
    });

    applyDateFilter();
  }

  /// =========================================================
  /// 🔥 LOAD BRANCHES (Sale Summary jevu j)
  /// =========================================================

  Future<void> _loadBranches() async {
    setState(() => branchesLoading = true);

    try {
      // 🔐 Fakt main company admin ne j Branch Reports dekhay
      final bool isAdmin = await BranchAccess.isMainCompanyAdmin();
      if (!isAdmin) {
        if (mounted) setState(() => canViewBranches = false);
        return;
      }

      final overview = await BranchApi.fetchOverview();

      if (!mounted) return;

      final List<Company> list = [
        if (overview.mainCompany != null) overview.mainCompany!,
        ...overview.branches,
      ];

      setState(() {
        branchCompanies = list;

        // Main company + ek branch hoy tyare j tab dekhay
        canViewBranches = list.length > 1;

        // Default: main company select
        selectedCompanyIds = {
          if (overview.mainCompany != null) overview.mainCompany!.id,
        };
      });
    } catch (e) {
      // Branch access nathi (branch user / staff) → tab nahi dekhay
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// From / To date (dd-MM-yyyy → yyyy-MM-dd), khotu hoy to null

  /// Sale list farithi (branch mujab)
  Future<void> _reloadSales() async {
    setState(() => expandedSaleId = null);
    await _refreshList();
  }

  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }

    setState(() {
      appliedCompanyIds = selectedCompanyIds.toList();
      branchReportLoading = true;
    });

    try {
      await _reloadSales();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadSales();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab) — Sale Summary jevu j
  // ============================================================

  Widget _buildBranchCard() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.all(14),
        decoration: _branchCardDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Loading branches...",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList =
    branchCompanies.where((c) => selectedCompanyIds.contains(c.id)).toList();

    final bool appliedDiffers = appliedCompanyIds.toSet().length !=
        selectedCompanyIds.length ||
        !appliedCompanyIds.toSet().containsAll(selectedCompanyIds);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: _branchCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- HEADER (tap = expand) ----------------
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Branch Reports",
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedCompanyIds.length}/${branchCompanies.length}",
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: branchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- BODY ----------------
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !branchExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Multi select box
                  InkWell(
                    onTap: _openBranchPicker,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                                : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in selectedList)
                                  _branchChip(c),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Select one or more branches to see their sales.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _viewReportButton(highlight: appliedDiffers),

                  // Branch report chalu hoy tyare info + clear
                  if (_branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff16A34A).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xff16A34A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xff16A34A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing sales of "
                                  "${appliedCompanyIds.length} "
                                  "${appliedCompanyIds.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff166534),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: clearBranchReport,
                            style: TextButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xffD32F2F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChip(Company c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.isMain ? Icons.verified_rounded : c.type.icon,
            size: 13,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _companyLabel(c),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => setState(() => selectedCompanyIds.remove(c.id)),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewReportButton({required bool highlight}) {
    return InkWell(
      onTap: branchReportLoading ? null : viewBranchReport,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff22C55E), Color(0xff16A34A)],
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color:
              const Color(0xff16A34A).withOpacity(highlight ? 0.35 : 0.15),
              blurRadius: highlight ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: branchReportLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_rounded, size: 17, color: Colors.white),
              SizedBox(width: 6),
              Text(
                "View",
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
    );
  }

  /// 🔥 Multi-select bottom sheet
  Future<void> _openBranchPicker() async {
    final Set<int> temp = {...selectedCompanyIds};

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final bool allSelected = temp.length == branchCompanies.length;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Select Branches",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff172033),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                if (allSelected) {
                                  temp.clear();
                                } else {
                                  temp.addAll(branchCompanies.map((c) => c.id));
                                }
                              });
                            },
                            child: Text(
                              allSelected ? "Clear All" : "Select All",
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: branchCompanies.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, i) {
                          final c = branchCompanies[i];
                          final bool checked = temp.contains(c.id);

                          return InkWell(
                            onTap: () => setSheet(() {
                              checked ? temp.remove(c.id) : temp.add(c.id);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      c.isMain
                                          ? Icons.verified_rounded
                                          : c.type.icon,
                                      size: 17,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _companyLabel(c),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff172033),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            c.isMain ? "Main" : c.type.label,
                                            if (c.city != null) c.city!,
                                            if (!c.active) "Inactive",
                                          ].join(" • "),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.active
                                                ? Colors.grey.shade600
                                                : Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? AppColors.gradientBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: checked
                                            ? AppColors.gradientBlue
                                            : Colors.grey.shade400,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: checked
                                        ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => Navigator.pop(sheetContext, temp),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Text(
                                    "Done (${temp.length})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
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
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => selectedCompanyIds = result);
    }
  }

  BoxDecoration _branchCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

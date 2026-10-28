// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Dashboard/HomeScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/ItemProvider.dart';
// import '../Extra/PermissionDeniedWidget.dart';
// import '../Extra/PremiumSearchableDropdown.dart';
//
// class ReciveReturnPurchase extends StatefulWidget {
//   const ReciveReturnPurchase({super.key});
//
//   @override
//   State<ReciveReturnPurchase> createState() => _ReciveReturnPurchasetState();
// }
//
// class _ReciveReturnPurchasetState extends State<ReciveReturnPurchase> {
//   TextEditingController searchController = TextEditingController();
//   TextEditingController fromDateController = TextEditingController();
//   TextEditingController fromDatebalanceController = TextEditingController();
//   TextEditingController toDateController = TextEditingController();
//   TextEditingController amountController = TextEditingController();
//   TextEditingController remarksController = TextEditingController();
//   TextEditingController metalController = TextEditingController();
//   TextEditingController amount1Controller = TextEditingController();
//   TextEditingController fineController = TextEditingController();
//   TextEditingController remarkdialogController = TextEditingController();
//   final TextEditingController metalWeightController = TextEditingController();
//
//   final TextEditingController rupeesController = TextEditingController();
//   final TextEditingController fineWeightController =
//   TextEditingController();
//   String? selectedMetalType = "Silver";
//   List userlist = [];
//   List<Map<String, dynamic>> items = [];
//   List searchResults = [];
//   bool isLoading = false;
//   Map<String, bool> expandedMap = {};
//   Map<String, dynamic>? summaryTotals;
//   String customerName = "";
//   String customerCity = "";
//
//   double cashBalance = 0.0;
//   double goldBalance = 0.0;
//   double silverBalance = 0.0;
//   double otherBalance = 0.0;
//   List<Map<String, dynamic>> ledgerList = [];
//   String? Code;
//
//   Future<void> _selectDate(TextEditingController controller) async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2030),
//     );
//
//     if (picked != null) {
//       controller.text = "${picked.day}-${picked.month}-${picked.year}";
//     }
//   }
//
//   String? selectedItem;
//   List allUsers = []; // 🔥 original data store
//
//   String? selectedCity;
//   void searchUser(String value) {
//     if (value.isEmpty) {
//       setState(() {
//         userlist = allUsers; // reset
//       });
//       return;
//     }
//
//     List filteredList = allUsers.where((user) {
//       final name = user["name"]?.toString().toLowerCase() ?? "";
//       final role = user["role"]?.toString().toLowerCase() ?? "";
//
//       return name.contains(value.toLowerCase()) ||
//           role.contains(value.toLowerCase());
//     }).toList();
//
//     setState(() {
//       userlist = filteredList;
//     });
//   }
//
//   /// 🔥 CHECKBOX VARIABLES
//   bool useParty = false;
//   bool useCity = false;
//
//   /// 🔥 VARIABLES ADD KARO
//   bool useWeight = false;
//   bool useAmount = false;
//
//   TextEditingController weightFromController = TextEditingController();
//   TextEditingController weightToController = TextEditingController();
//
//   TextEditingController amountFromController = TextEditingController();
//   TextEditingController amountToController = TextEditingController();
//   void applyDateFilter() {
//     if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
//       setState(() {
//         userlist = allUsers;
//       });
//       return;
//     }
//
//     DateTime fromDate = _convertToDate(fromDateController.text);
//     DateTime toDate = _convertToDate(toDateController.text);
//
//     List filtered = allUsers.where((user) {
//       if (user["created_at"] == null) return false;
//
//       DateTime userDate = DateTime.parse(user["created_at"]);
//
//       return userDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
//           userDate.isBefore(toDate.add(const Duration(days: 1)));
//     }).toList();
//
//     setState(() {
//       userlist = filtered;
//     });
//   }
//
//     String selectedEntryType = "receive_amount";
//   String selectedEntryType1 = "Rupees to Metal";
//   String? selectedPaymentMode;
//   String? selectedconversationtype;
//   String? selectedmetaltype;
//
//   List<String> userPermissions = []; // 🔥 ADD
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
//
//   /// 🔥 Permission check helper
//   bool hasPermission(String permissionName) {
//     //print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
//     return userPermissions.contains(permissionName);
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     loadPermissions();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).refreshreturnCustomers();
//     });
//
//     //Salesumryreport();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!(hasPermission("sale-advance-view") ||
//         hasPermission("sale-advance-manage"))) {
//       return Scaffold(
//         body: PermissionDeniedWidget(
//           onBack: () {
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
//         resizeToAvoidBottomInset: false, // ⭐ IMPORTANT FIX
//         backgroundColor: AppColors.white,
//         body: Stack(
//           children: [
//             /// 🔥 MAIN CONTENT
//             Column(
//               children: [
//                 /// IMPORTANT: top padding space leave karvu (AppBar mate)
//                 SizedBox(height: MediaQuery.of(context).padding.top + 40),
//
//                 Expanded(
//                   child: SingleChildScrollView(
//                     physics: const BouncingScrollPhysics(),
//                     child: Column(
//                       children: [
//                         filterWidget(),
//
//                         Container(
//                           margin: const EdgeInsets.only(top: 10),
//                           width: double.infinity,
//                           height: 2,
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 AppColors.primaryDark.withOpacity(0.1),
//                                 AppColors.primaryDark,
//                                 AppColors.secondaryDark.withOpacity(0.4),
//                                 AppColors.primaryDark.withOpacity(0.1),
//                               ],
//                             ),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                         ),
//
//                         selectedItem == null
//                             ? const Center(child: Text("No Data Added"))
//                             : ListView.builder(
//                                 padding: const EdgeInsets.all(10),
//                                 shrinkWrap: true, // ✅ IMPORTANT
//                                 physics:
//                                     const NeverScrollableScrollPhysics(), // ✅ IMPORTANT
//                                 itemCount: userlist.length,
//                                 itemBuilder: (context, index) {
//                                   return buildUserCard(
//                                     userlist[index],
//                                     index,
//                                     userlist.length,
//                                   );
//                                 },
//                               ),
//
//                         /// 🔥 BOTTOM SUMMARY
//                         buildSummaryRow(),
//                         // SizedBox(height: height * 0.05),
//                         // 🔥 Save button જેટલી height નું space
//                         const SizedBox(height: 80),
//                       ],
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
//                       "Receive / Return / Purchase",
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
//                             color: AppColors.primaryDark,
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
//                     Align(
//                       alignment: Alignment.centerRight,
//
//                       child:SizedBox(
//                         width: 40,
//                         child: InkWell(
//                           onTap: () {
//                             if (selectedItem == null) {
//                               _showCustomerRequiredMessage();
//                               return;
//                             }
//
//                             openPdf(
//                               int.parse(selectedItem.toString()),
//                             );
//                           },
//                           borderRadius: BorderRadius.circular(7),
//                           child: Container(
//                             height: 35,
//                             decoration: BoxDecoration(
//                               color: const Color(0xffD32F2F),
//                               borderRadius: BorderRadius.circular(7),
//                             ),
//                             child: const Row(
//                               mainAxisAlignment:
//                               MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.picture_as_pdf_outlined,
//                                   color: Colors.white,
//                                   size: 18,
//                                 ),
//                               ],
//                             ),
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
//   Widget buildUserCard(Map user, int index, int totalCount) {
//     final size = MediaQuery.of(context).size;
//     final isTablet = size.width >= 600;
//
//     return Container(
//       margin: const EdgeInsets.symmetric(
//         horizontal: 0,
//         vertical: 6,
//       ),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: AppColors.border,
//           width: 1,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//
//           /// =========================================================
//           /// TOP HEADER
//           /// =========================================================
//           Container(
//             height: 38,
//             padding: const EdgeInsets.symmetric(
//               horizontal: 10,
//             ),
//             decoration: BoxDecoration(
//               color: AppColors.primaryDark.withOpacity(0.4),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(5),
//                 topRight: Radius.circular(5),
//               ),
//             ),
//             child: Row(
//               children: [
//
//                 /// INDEX BADGE
//                 Container(
//                   width: 26,
//                   height: 26,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: AppColors.primaryDark,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     "${totalCount - index}",
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 11,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 /// ENTRY TYPE
//                 Expanded(
//                   child: Row(
//                     children: [
//                       const Icon(
//                         Icons.receipt_long_outlined,
//                         size: 15,
//                         color: AppColors.primaryDark,
//                       ),
//
//                       const SizedBox(width: 5),
//
//                       Flexible(
//                         child: Text(
//                           _formatLedgerEntryType(
//                             user["entry_type"]?.toString() ?? "-",
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: Colors.black,
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 /// PAYMENT CHIP
//                 if ((user["payment_mode"]?.toString() ?? "").isNotEmpty)
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(5),
//                       border: Border.all(
//                         color: AppColors.primaryDark.withOpacity(0.15),
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(
//                           Icons.payments_outlined,
//                           size: 12,
//                           color: AppColors.primaryDark,
//                         ),
//                         const SizedBox(width: 4),
//                         Text(
//                           user["payment_mode"]?.toString() ?? "-",
//                           style: const TextStyle(
//                             color: AppColors.primaryDark,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           /// =========================================================
//           /// HORIZONTAL DATA
//           /// =========================================================
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             physics: const BouncingScrollPhysics(),
//             child: Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isTablet ? 14 : 10,
//                 vertical: 10,
//               ),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//
//                   _viewField(
//                     "Date & Time",
//                     user["entry_date"]?.toString() ?? "-",
//                     icon: Icons.calendar_month_outlined,
//                     width: 165,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Entry Type",
//                     _formatLedgerEntryType(
//                       user["entry_type"]?.toString() ?? "-",
//                     ),
//                     icon: Icons.swap_horiz_rounded,
//                     width: 150,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Mode",
//                     user["payment_mode"]?.toString() ?? "-",
//                     icon: Icons.account_balance_wallet_outlined,
//                     width: 120,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Cash In",
//                     user["cash_in"]?.toString() ?? "0.00",
//                     icon: Icons.south_west_rounded,
//                     width: 125,
//                     highlight: true,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Cash Out",
//                     user["cash_out"]?.toString() ?? "0.00",
//                     icon: Icons.north_east_rounded,
//                     width: 125,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Metal Type",
//                     _capitalizeLedgerText(
//                       user["metal_type"]?.toString() ?? "-",
//                     ),
//                     icon: Icons.diamond_outlined,
//                     width: 125,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Metal In",
//                     user["metal_in"]?.toString() ?? "0.000",
//                     icon: Icons.arrow_downward_rounded,
//                     width: 125,
//                     highlight: true,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Metal Out",
//                     user["metal_out"]?.toString() ?? "0.000",
//                     icon: Icons.arrow_upward_rounded,
//                     width: 125,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Rate",
//                     user["rate"]?.toString() ?? "0.000",
//                     icon: Icons.currency_rupee_rounded,
//                     width: 125,
//                   ),
//
//                   _premiumVerticalDivider(),
//
//                   _viewField(
//                     "Remarks",
//                     user["remarks"]?.toString() ?? "-",
//                     icon: Icons.notes_rounded,
//                     width: 190,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Widget _viewField(String title, String value, {double width = 140}) {
//   //   return Container(
//   //     width: width,
//   //     margin: const EdgeInsets.only(right: 8, top: 10),
//   //     child: Column(
//   //       crossAxisAlignment: CrossAxisAlignment.start,
//   //       children: [
//   //         Text(
//   //           title,
//   //           style: const TextStyle(
//   //             fontSize: 11,
//   //             color: Colors.black54,
//   //             fontWeight: FontWeight.w600,
//   //           ),
//   //         ),
//   //
//   //         const SizedBox(height: 4),
//   //
//   //         Container(
//   //           width: double.infinity,
//   //           padding: const EdgeInsets.all(8),
//   //           decoration: BoxDecoration(
//   //             color: Colors.white,
//   //             borderRadius: BorderRadius.circular(6),
//   //             border: Border.all(color: Colors.grey.shade300),
//   //           ),
//   //           child: SizedBox(
//   //             width: 150,
//   //             child: Text(
//   //               value,
//   //               style: const TextStyle(
//   //                 overflow: TextOverflow.ellipsis,
//   //                 color: Colors.black,
//   //                 fontSize: 13,
//   //               ),
//   //             ),
//   //           ),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//
//   Future<void> Salesumryreport() async {
//     final response = await ApiHelper().getRequest(
//       ApiConstants.OutStanding_amount_report,
//     );
//
//     print("user API URL: ${ApiConstants.OutStanding_amount_report}");
//     print("users Raw Response: ${response.toString()}");
//
//     if (response!.statusCode == 200) {
//       final data = response.data;
//
//       // ✅ success check
//       final List categories = data['data'];
//
//       setState(() {
//         userlist = categories;
//         allUsers = categories; // 🔥 store original
//         summaryTotals = data["summary"]; // 🔥 IMPORTANT
//       });
//
//       print("✅ Total user: ${userlist.length}");
//       searchController.clear();
//       searchResults.clear();
//     } else {
//       setState(() {
//         userlist = [];
//       });
//       print("❌ userlist API failed");
//     }
//   }
//
//   Widget filterWidget() {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: AppColors.cardBackground,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: AppColors.border,
//           width: 1,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // =========================================================
//           // TITLE
//           // =========================================================
//
//           // Row(
//           //   children: [
//           //     Container(
//           //       width: 34,
//           //       height: 34,
//           //       decoration: BoxDecoration(
//           //         color: AppColors.primaryDark.withOpacity(0.10),
//           //         borderRadius: BorderRadius.circular(8),
//           //       ),
//           //       child: const Icon(
//           //         Icons.account_balance_wallet_outlined,
//           //         size: 19,
//           //         color: AppColors.primaryDark,
//           //       ),
//           //     ),
//           //
//           //     const SizedBox(width: 10),
//           //
//           //     const Expanded(
//           //       child: Column(
//           //         crossAxisAlignment: CrossAxisAlignment.start,
//           //         children: [
//           //           Text(
//           //             "Receive / Return Entry",
//           //             style: TextStyle(
//           //               color: Colors.black,
//           //               fontSize: 15,
//           //               fontWeight: FontWeight.w700,
//           //             ),
//           //           ),
//           //           SizedBox(height: 2),
//           //           Text(
//           //             "Select customer and enter transaction details",
//           //             style: TextStyle(
//           //               color: Colors.black54,
//           //               fontSize: 11,
//           //             ),
//           //           ),
//           //         ],
//           //       ),
//           //     ),
//           //   ],
//           // ),
//           //
//           // const SizedBox(height: 14),
//
//           // =========================================================
//           // CUSTOMER SEARCHABLE DROPDOWN
//           // =========================================================
//
//           Consumer<ItemProvider>(
//             builder: (context, provider, child) {
//               final customers = provider.customers_return;
//
//               Map? selectedCustomer;
//
//               if (selectedItem != null) {
//                 try {
//                   selectedCustomer = customers.firstWhere(
//                         (item) => item["id"]?.toString() == selectedItem.toString(),
//                   );
//                 } catch (_) {
//                   selectedCustomer = null;
//                 }
//               }
//
//               return Stack(
//                 alignment: Alignment.centerRight,
//                 children: [
//                   PremiumSearchableDropdown<Map>(
//                     label: "",
//                     hint: "Search & Select Customer",
//                     items: List<Map>.from(customers),
//                     value: selectedCustomer,
//                     prefixIcon: Icons.person_outline,
//
//                     itemLabel: (item) => item["name"]?.toString() ?? "-",
//
//                     searchText: (item) {
//                       return [
//                         item["name"]?.toString() ?? "",
//                         item["mobile_no"]?.toString() ?? "",
//                         item["mobile"]?.toString() ?? "",
//                         item["email"]?.toString() ?? "",
//                         item["id"]?.toString() ?? "",
//                       ].join(" ");
//                     },
//
//                     onChanged: (selectedData) => _setCustomer(selectedData),
//                   ),
//
//                   /// ❌ CLEAR — dropdown ની અંદર, arrow ની ડાબી બાજુ
//                   if (selectedCustomer != null)
//                     Positioned(
//                       right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
//                       top: 0,
//                       bottom: 0,
//                       child: Center(
//                         child: InkWell(
//                           borderRadius: BorderRadius.circular(20),
//                           onTap: () {
//                             FocusManager.instance.primaryFocus?.unfocus();
//                             _setCustomer(null);
//                           },
//                           child: Container(
//                             width: 20,
//                             height: 20,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               color: Colors.red.shade50,
//                               shape: BoxShape.circle,
//                               border: Border.all(color: Colors.red.shade200),
//                             ),
//                             child: Icon(
//                               Icons.close_rounded,
//                               size: 13,
//                               color: Colors.red.shade700,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               );
//             },
//           ),
//
//           // =========================================================
//           // CUSTOMER INFO
//           // =========================================================
//
//           // if (selectedItem != null) ...[
//           //   const SizedBox(height: 10),
//           //
//           //   Container(
//           //     width: double.infinity,
//           //     padding: const EdgeInsets.symmetric(
//           //       horizontal: 12,
//           //       vertical: 9,
//           //     ),
//           //     decoration: BoxDecoration(
//           //       color: AppColors.primaryDark.withOpacity(0.06),
//           //       borderRadius: BorderRadius.circular(7),
//           //       border: Border.all(
//           //         color:
//           //         AppColors.primaryDark.withOpacity(0.12),
//           //       ),
//           //     ),
//           //     child: Row(
//           //       children: [
//           //         const Icon(
//           //           Icons.person_outline,
//           //           size: 17,
//           //           color: AppColors.primaryDark,
//           //         ),
//           //
//           //         const SizedBox(width: 7),
//           //
//           //         Expanded(
//           //           child: Text(
//           //             customerName.isEmpty
//           //                 ? "Selected Customer"
//           //                 : customerName,
//           //             overflow: TextOverflow.ellipsis,
//           //             style: const TextStyle(
//           //               color: Colors.black,
//           //               fontSize: 12,
//           //               fontWeight: FontWeight.w600,
//           //             ),
//           //           ),
//           //         ),
//           //
//           //         if (customerCity.isNotEmpty) ...[
//           //           const SizedBox(width: 8),
//           //
//           //           const Icon(
//           //             Icons.location_on_outlined,
//           //             size: 15,
//           //             color: Colors.black54,
//           //           ),
//           //
//           //           const SizedBox(width: 3),
//           //
//           //           Flexible(
//           //             child: Text(
//           //               customerCity,
//           //               overflow: TextOverflow.ellipsis,
//           //               style: const TextStyle(
//           //                 color: Colors.black54,
//           //                 fontSize: 11,
//           //               ),
//           //             ),
//           //           ),
//           //         ],
//           //       ],
//           //     ),
//           //   ),
//           // ],
//           //
//            const SizedBox(height: 12),
//
//           // =========================================================
//           // DATE + PAYMENT
//           // =========================================================
//
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // DATE
//               Expanded(
//                 child: InkWell(
//                   onTap: () =>
//                       _selectDate(fromDateController),
//                   borderRadius: BorderRadius.circular(8),
//                   child: IgnorePointer(
//                     child: TextFormField(
//                       controller: fromDateController,
//                       style: const TextStyle(
//                         color: Colors.black,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w500,
//                       ),
//                       decoration: _premiumInputDecoration(
//                         hint: "Entry Date",
//                         icon:
//                         Icons.calendar_month_outlined,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(width: 8),
//
//               // PAYMENT MODE
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: selectedPaymentMode,
//                   isExpanded: true,
//                   dropdownColor: Colors.white,
//                   icon: const Icon(
//                     Icons.keyboard_arrow_down_rounded,
//                     color: Colors.black54,
//                   ),
//                   hint: const Text(
//                     "Payment Mode",
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                       color: Colors.black54,
//                       fontSize: 12,
//                     ),
//                   ),
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontSize: 13,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   decoration: _premiumInputDecoration(
//                     hint: "",
//                     icon: Icons.payments_outlined,
//                   ),
//                   items: const [
//                     DropdownMenuItem(
//                       value: "Cash",
//                       child: Text("Cash"),
//                     ),
//                     DropdownMenuItem(
//                       value: "Online",
//                       child: Text("Online"),
//                     ),
//                     DropdownMenuItem(
//                       value: "UPI",
//                       child: Text("UPI"),
//                     ),
//                     DropdownMenuItem(
//                       value: "Bank",
//                       child: Text("Bank"),
//                     ),
//                     DropdownMenuItem(
//                       value: "Other",
//                       child: Text("Other"),
//                     ),
//                   ],
//                   onChanged: (value) {
//                     setState(() {
//                       selectedPaymentMode = value;
//                     });
//                   },
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 12),
//
//           // =========================================================
//           // ENTRY TYPE
//           // =========================================================
//
//           DropdownButtonFormField<String>(
//             value: selectedEntryType,
//             isExpanded: true,
//             dropdownColor: Colors.white,
//             icon: const Icon(
//               Icons.keyboard_arrow_down_rounded,
//               color: Colors.black54,
//             ),
//             style: const TextStyle(
//               color: Colors.black,
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//             decoration: _premiumInputDecoration(
//               hint: "Entry Type",
//               icon: Icons.swap_vert_rounded,
//             ),
//             items: const [
//               DropdownMenuItem(
//                 value: "receive_amount",
//                 child: Text("Receive Amount"),
//               ),
//               DropdownMenuItem(
//                 value: "receive_fine_metal",
//                 child: Text("Receive Fine Metal"),
//               ),
//             ],
//             onChanged: (value) {
//               if (value == null) return;
//
//               setState(() {
//                 selectedEntryType = value;
//
//                 if (value == "receive_amount") {
//                   selectedMetalType = "silver";
//                   fineWeightController.clear();
//                 } else if (value == "receive_metal") {
//                   selectedMetalType = "silver";
//                   amountController.clear();
//                 }
//               });
//
//               print("Entry Type => $selectedEntryType");
//               print("Metal Type => $selectedMetalType");
//             },
//           ),
//
//           // =========================================================
//           // CUSTOMER SELECTED -> BALANCE
//           // =========================================================
//
//           if (selectedItem != null) ...[
//             const SizedBox(height: 14),
//
//             Row(
//               children: [
//                 const Text(
//                   "Current Balance",
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 Expanded(
//                   child: Container(
//                     height: 1,
//                     color: AppColors.border,
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 9),
//
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 final List<Widget> cards = [];
//
//                 void addCard({
//                   required String title,
//                   required double value,
//                   required IconData icon,
//                 }) {
//                   cards.add(
//                     SizedBox(
//                       width: 145,
//                       child: _premiumBalanceCard(
//                         title: title,
//                         value: value,
//                         icon: icon,
//                       ),
//                     ),
//                   );
//                 }
//
//                 addCard(
//                   title: "Cash Credit",
//                   value: cashBalance,
//                   icon: Icons.currency_rupee,
//                 );
//
//                 if (goldBalance != 0) {
//                   addCard(
//                     title: "Gold Balance",
//                     value: goldBalance,
//                     icon: Icons.diamond_outlined,
//                   );
//                 }
//
//                 if (silverBalance != 0) {
//                   addCard(
//                     title: "Silver Balance",
//                     value: silverBalance,
//                     icon: Icons.circle_outlined,
//                   );
//                 }
//
//                 if (otherBalance != 0) {
//                   addCard(
//                     title: "Other Balance",
//                     value: otherBalance,
//                     icon: Icons
//                         .account_balance_wallet_outlined,
//                   );
//                 }
//
//                 return SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: List.generate(
//                       cards.length,
//                           (index) => Padding(
//                         padding: EdgeInsets.only(
//                           right:
//                           index == cards.length - 1
//                               ? 0
//                               : 8,
//                         ),
//                         child: cards[index],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//
//           const SizedBox(height: 14),
//
//           // =========================================================
//           // RECEIVE AMOUNT
//           // SHOW ONLY FOR RECEIVE AMOUNT
//           // =========================================================
//
//           if (selectedEntryType == "receive_amount") ...[
//             TextFormField(
//               controller: amountController,
//               keyboardType:
//               const TextInputType.numberWithOptions(
//                 decimal: true,
//               ),
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//               onChanged: (value) {
//                 if (value.trim().isNotEmpty) {
//                   selectedEntryType = "receive_amount";
//                 }
//               },
//               decoration: _premiumInputDecoration(
//                 hint: "Enter Amount",
//                 icon: Icons.currency_rupee_rounded,
//               ),
//             ),
//           ],
//
//           // =========================================================
//           // RECEIVE FINE METAL
//           // METAL TYPE + FINE WEIGHT
//           // =========================================================
//
//           if (selectedEntryType ==
//               "receive_fine_metal") ...[
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // =====================================================
//                 // METAL TYPE
//                 // =====================================================
//
//                 Expanded(
//                   child: DropdownButtonFormField<String>(
//                     value: selectedMetalType,
//                     isExpanded: true,
//                     dropdownColor: Colors.white,
//                     icon: const Icon(
//                       Icons.keyboard_arrow_down_rounded,
//                       color: Colors.black54,
//                     ),
//                     style: const TextStyle(
//                       color: Colors.black,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w500,
//                     ),
//                     decoration: _premiumInputDecoration(
//                       hint: "Metal Type",
//                       icon: Icons.diamond_outlined,
//                     ),
//                     items: const [
//                       DropdownMenuItem(
//                         value: "Gold",
//                         child: Text("Gold"),
//                       ),
//                       DropdownMenuItem(
//                         value: "Silver",
//                         child: Text("Silver"),
//                       ),
//                       DropdownMenuItem(
//                         value: "Other",
//                         child: Text("Other"),
//                       ),
//                     ],
//                     onChanged: (value) {
//                       setState(() {
//                         selectedMetalType = value;
//                       });
//
//                       print(
//                         "Metal Type => $selectedMetalType",
//                       );
//                     },
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 // =====================================================
//                 // FINE WEIGHT
//                 // =====================================================
//
//                 Expanded(
//                   child: TextFormField(
//                     controller: fineWeightController,
//                     keyboardType:
//                     const TextInputType.numberWithOptions(
//                       decimal: true,
//                     ),
//                     style: const TextStyle(
//                       color: Colors.black,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                     ),
//                     decoration: _premiumInputDecoration(
//                       hint: "Fine Weight",
//                       icon: Icons.scale_outlined,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//
//           const SizedBox(height: 14),
//
//           // =========================================================
//           // REMARKS
//           // =========================================================
//
//           TextFormField(
//             controller: remarksController,
//             style: const TextStyle(
//               color: Colors.black,
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//             decoration: _premiumInputDecoration(
//               hint: "Enter Remarks",
//               icon: Icons.notes_rounded,
//             ),
//           ),
//
//           const SizedBox(height: 14),
//
//           // =========================================================
//           // ACTION BUTTONS
//           // =========================================================
//
//           Row(
//             children: [
//               // SAVE ENTRY
//               Expanded(
//                 child: _premiumActionButton(
//                   title: "Save Entry",
//                   icon: Icons.save_outlined,
//                   onTap: () async {
//                     FocusManager.instance.primaryFocus
//                         ?.unfocus();
//
//                     if (selectedItem == null) {
//                       _showCustomerRequiredMessage();
//                       return;
//                     }
//
//                     // ==============================================
//                     // VALIDATION
//                     // ==============================================
//
//                     if (selectedEntryType ==
//                         "receive_amount") {
//                       if (amountController.text
//                           .trim()
//                           .isEmpty) {
//                         AppMessage.error(
//                           context,
//                           "Please enter amount.",
//                         );
//                         return;
//                       }
//                     }
//
//                     if (selectedEntryType ==
//                         "receive_fine_metal") {
//                       if (selectedMetalType == null ||
//                           selectedMetalType!.isEmpty) {
//                         AppMessage.error(
//                           context,
//                           "Please select metal type.",
//                         );
//                         return;
//                       }
//
//                       if (fineWeightController.text
//                           .trim()
//                           .isEmpty) {
//                         AppMessage.error(
//                           context,
//                           "Please enter fine weight.",
//                         );
//                         return;
//                       }
//                     }
//
//                     await saveEntry(mode: "main");   // 🔥 FIX
//                   },
//                 ),
//               ),
//
//               const SizedBox(width: 8),
//
//               // BALANCE CONVERSION
//               Expanded(
//                 child: _premiumActionButton(
//                   title: "Conversion",
//                   icon: Icons.swap_horiz_rounded,
//                   onTap: () {
//                     if (selectedItem == null) {
//                       _showCustomerRequiredMessage();
//                       return;
//                     }
//
//                     showBalanceConversionDialog();
//                   },
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 8),
//
//           // =========================================================
//           // PDF
//           // =========================================================
//           //
//           // SizedBox(
//           //   width: double.infinity,
//           //   child: InkWell(
//           //     onTap: () {
//           //       if (selectedItem == null) {
//           //         _showCustomerRequiredMessage();
//           //         return;
//           //       }
//           //
//           //       openPdf(
//           //         int.parse(selectedItem.toString()),
//           //       );
//           //     },
//           //     borderRadius: BorderRadius.circular(7),
//           //     child: Container(
//           //       height: 42,
//           //       decoration: BoxDecoration(
//           //         color: const Color(0xffD32F2F),
//           //         borderRadius: BorderRadius.circular(7),
//           //       ),
//           //       child: const Row(
//           //         mainAxisAlignment:
//           //         MainAxisAlignment.center,
//           //         children: [
//           //           Icon(
//           //             Icons.picture_as_pdf_outlined,
//           //             color: Colors.white,
//           //             size: 18,
//           //           ),
//           //           SizedBox(width: 6),
//           //           Text(
//           //             "View Ledger PDF",
//           //             style: TextStyle(
//           //               color: Colors.white,
//           //               fontSize: 13,
//           //               fontWeight: FontWeight.w600,
//           //             ),
//           //           ),
//           //         ],
//           //       ),
//           //     ),
//           //   ),
//           // ),
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
//   String formatDate(String date) {
//     try {
//       final parts = date.split(" ")[0].split("-"); // 🔥 space par split
//       return "${parts[2]}-${parts[1]}-${parts[0]}"; // dd-MM-yyyy
//     } catch (e) {
//       return "-";
//     }
//   }
//
//   DateTime _convertToDate(String input) {
//     final parts = input.split("-");
//     return DateTime(
//       int.parse(parts[2]), // year
//       int.parse(parts[1]), // month
//       int.parse(parts[0]), // day
//     );
//   }
//
//   Future<void> searchItemsApi(String keyword) async {
//     if (keyword.isEmpty) {
//       setState(() {
//         items = [];
//       });
//       return;
//     }
//
//     final response = await ApiHelper().getRequest(
//       "${ApiConstants.Barcode_report}/suggest?q=$keyword",
//     );
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//
//       setState(() {
//         searchResults = response.data["data"];
//       });
//     } else {
//       print("Search API Failed");
//     }
//   }
//
//   /// 🔹 PDF Button
//   Widget pdfBtn(VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(5),
//       child: Container(
//         margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
//         padding: const EdgeInsets.all(9),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [Color(0xffE57373), Color(0xffD32F2F), Color(0xffE57373)],
//           ),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: const [
//             Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
//             SizedBox(width: 4),
//             Text(
//               "PDF",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.w500,
//                 fontSize: 16,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget excelBtn(VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(10),
//       child: Container(
//         margin: const EdgeInsets.fromLTRB(0, 0, 20, 0),
//         padding: const EdgeInsets.all(7),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [
//               Color(0xff66BB6A), // light green
//               Color(0xff2E7D32), // dark green
//               Color(0xff66BB6A), // light green
//             ],
//           ),
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: const [
//             Icon(Icons.table_chart, color: Colors.white, size: 18),
//             SizedBox(width: 4),
//             Text(
//               "Excel",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.w500,
//                 fontSize: 16,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String apiDate(String value) {
//     if (value.isEmpty) return "";
//
//     final parts = value.split("-");
//
//     return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
//   }
//
//   Future<void> openPdf(int id) async {
//     final response = await ApiHelper().getRequestWithId(
//       "${ApiConstants.sales_advance_ledger_pdf}"
//       "?customer_id=$id"
//       "&direct=1"
//       "&mode=inline",
//       id,
//       responseType: ResponseType.bytes,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       final dir = await getTemporaryDirectory();
//
//       final file = File("${dir.path}/return_$id.pdf");
//
//       await file.writeAsBytes(response.data);
//
//       OpenFile.open(file.path);
//     } else {
//       print("PDF Download Failed");
//     }
//   }
//
//   Future<void> openexel(String Code) async {
//     try {
//       bool isDefaultReport = !useParty && !useCity && !useWeight && !useAmount;
//       String url =
//           "${ApiConstants.OutStanding_amount_report_excel}?"
//           "use_default_report=${isDefaultReport ? 1 : 0}"
//           "&use_date=1"
//           "&from_date=${apiDate(fromDateController.text)}"
//           "&to_date=${apiDate(toDateController.text)}"
//           "&use_party=${useParty ? 1 : 0}"
//           "&customer_id=${useParty ? selectedItem ?? "" : ""}"
//           "&use_city=${useCity ? 1 : 0}"
//           "&city=${useCity ? selectedCity ?? "" : ""}"
//           "&use_mode=0"
//           "&payment_mode="
//           "&use_weight=${useWeight ? 1 : 0}"
//           "&weight_from=${useWeight ? weightFromController.text : ""}"
//           "&weight_to=${useWeight ? weightToController.text : ""}"
//           "&use_amount=${useAmount ? 1 : 0}"
//           "&amount_from=${useAmount ? amountFromController.text : ""}"
//           "&amount_to=${useAmount ? amountToController.text : ""}";
//       final response = await ApiHelper().getPdfRequest(url);
//
//       if (response != null && response.statusCode == 200) {
//         final dir = await getTemporaryDirectory();
//         final file = File("${dir.path}/sales_summary.pdf");
//
//         /// 🔥 IMPORTANT: ensure List<int>
//         final bytes = List<int>.from(response.data);
//
//         await file.writeAsBytes(bytes);
//
//         await OpenFile.open(file.path);
//       } else {
//         print("PDF Download Failed: ${response?.statusCode}");
//       }
//     } catch (e) {
//       print("Error: $e");
//     }
//   }
//
//   Widget buildSummaryRow() {
//     if (summaryTotals == null) {
//       return const SizedBox(); // or loader
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xffFAF7F2),
//         border: Border(
//           top: BorderSide(color: Colors.grey),
//           bottom: BorderSide(color: Colors.grey),
//         ),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//             _summaryBox("Voucher", summaryTotals!["voucher_count"].toString()),
//
//             _summaryBox(
//               "Gross",
//               double.parse(
//                 summaryTotals!["gross_weight"].toString(),
//               ).toStringAsFixed(2),
//             ),
//
//             _summaryBox("Net", summaryTotals!["net_weight"].toString()),
//
//             _summaryBox("Amount IN", summaryTotals!["amount_in"].toString()),
//
//             _summaryBox("Amount Out", summaryTotals!["amount_out"].toString()),
//
//             _summaryBox(
//               "Pending Amt",
//               summaryTotals!["pending_amount"].toString(),
//             ),
//
//             _summaryBox("Total", summaryTotals!["total_amount"].toString()),
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
//   Widget _balanceBox({required String title, required String amount}) {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: AppColors.primaryDark.withOpacity(0.4),
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
//     try {
//       /// ==========================
//       /// 1️⃣ SUMMARY API
//       /// ==========================
//       final response = await ApiHelper().getRequest(
//         "${ApiConstants.advance_ledger_summary}?customer_id=$customerId",
//       );
//
//       if (response != null && response.statusCode == 200) {
//         final json = response.data;
//
//         if (json["success"] == true) {
//           final data = json["data"];
//
//           final customer = data["customer"];
//           final balance = data["balance"];
//           final metalBalance = balance["metal_balance"];
//
//           setState(() {
//             customerName = customer["name"] ?? "";
//             customerCity = customer["city"] ?? "";
//
//             cashBalance =
//                 double.tryParse(balance["cash_balance"].toString()) ?? 0.0;
//
//             goldBalance =
//                 double.tryParse(metalBalance["gold"].toString()) ?? 0.0;
//
//             silverBalance =
//                 double.tryParse(metalBalance["silver"].toString()) ?? 0.0;
//
//             otherBalance =
//                 double.tryParse(metalBalance["other"].toString()) ?? 0.0;
//           });
//
//           /// ==========================
//           /// 2️⃣ ENTRIES API
//           /// ==========================
//
//           final ledgerResponse = await ApiHelper().getRequest(
//             "${ApiConstants.sales_advance_ledger_entries}?customer_id=$customerId&per_page=50",
//           );
//
//           if (ledgerResponse != null && ledgerResponse.statusCode == 200) {
//             final ledgerJson = ledgerResponse.data;
//
//             if (ledgerJson["success"] == true) {
//               setState(() {
//                 userlist = List<Map<String, dynamic>>.from(
//                   ledgerJson["data"] ?? [],
//                 );
//               });
//
//               print("Ledger Records = ${userlist.length}");
//             }
//           }
//         }
//       }
//     } catch (e) {
//       print("Error => $e");
//     }
//
//     Navigator.pop(context);
//   }
//
//   Future<void> saveEntry({required String mode}) async {
//     Map<String, dynamic> body = {};
//
//     // ============================================================
//     // MODE: "main" -> Save Entry button (Receive Amount / Receive Fine Metal)
//     // ============================================================
//     if (mode == "main") {
//       if (selectedEntryType == "receive_amount") {
//         body = {
//           "entry_date": fromDateController.text,
//           "customer_id": int.parse(selectedItem.toString()),
//           "entry_type": "receive_amount",
//           "payment_mode": selectedPaymentMode,
//           "amount": double.tryParse(amountController.text) ?? 0,
//           "remarks": remarksController.text,
//         };
//       } else if (selectedEntryType == "receive_fine_metal") {
//         body = {
//           "entry_date": fromDateController.text,
//           "customer_id": int.parse(selectedItem.toString()),
//           "entry_type": "receive_metal",
//           "metal_type": selectedMetalType.toString().toLowerCase(),
//           "rate": double.tryParse(metalController.text) ?? 0,
//           "amount": double.tryParse(amount1Controller.text) ?? 0,
//           "fine_weight": double.tryParse(fineWeightController.text) ?? 0,
//           "remarks": remarkdialogController.text,
//         };
//       }
//     }
//
//     // ============================================================
//     // MODE: "conversion" -> Convert & Save button (Balance Conversion dialog)
//     // ============================================================
//     else if (mode == "conversion") {
//       if (selectedEntryType1 == "Rupees to Metal") {
//         body = {
//           "entry_date": fromDatebalanceController.text,
//           "customer_id": int.parse(selectedItem.toString()),
//           "entry_type": "convert_to_metal",
//           "metal_type": (selectedmetaltype ?? "silver").toLowerCase(),
//           "rate": double.tryParse(metalController.text) ?? 0,
//           "amount": double.tryParse(amount1Controller.text) ?? 0,
//           "fine_weight": double.tryParse(fineController.text) ?? 0,
//           "remarks": remarkdialogController.text,
//         };
//       } else if (selectedEntryType1 == "Metal to Rupees") {
//         body = {
//           "entry_date": fromDatebalanceController.text,
//           "customer_id": int.parse(selectedItem.toString()),
//           "entry_type": "convert_to_rupees",
//           "metal_type": (selectedmetaltype ?? "silver").toLowerCase(),
//           "rate": double.tryParse(metalController.text) ?? 0,
//           "amount": double.tryParse(rupeesController.text) ?? 0,
//           "fine_weight": double.tryParse(metalWeightController.text) ?? 0,
//           "remarks": remarkdialogController.text,
//         };
//       }
//     }
//
//     if (body.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please fill required fields"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     print(body);
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.sales_advance_ledger_entries,
//       body,
//     );
//
//     if (response != null &&
//         (response.statusCode == 200 || response.statusCode == 201)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Entry Saved Successfully"),
//           backgroundColor: Colors.green,
//         ),
//       );
//
//       /// Refresh Balance + Ledger
//       await getApprovalDetails(int.parse(selectedItem.toString()));
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Failed to Save Entry"),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void showBalanceConversionDialog() {
//
//     fromDatebalanceController.clear();
//     metalController.clear();
//     amount1Controller.clear();
//     fineController.clear();
//     metalWeightController.clear();
//     rupeesController.clear();
//     remarkdialogController.clear();
//
//     /// 🔥 FIX: Dialog khule tyare default reset karo
//     selectedEntryType1 = "Rupees to Metal";
//     selectedmetaltype = "silver";
//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, dialogSetState) {
//             return Dialog(
//               backgroundColor: AppColors.background,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               insetPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 24,
//               ), // 🔥 FIX
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
//                             "Balance Conversion",
//                             style: TextStyle(
//                               color: Colors.black,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const Spacer(),
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
//                       const SizedBox(height: 16),
//
//                       Row(
//                         children: [
//                           Expanded(
//                             child: InkWell(
//                               onTap: () =>
//                                   _selectDate(fromDatebalanceController),
//                               child: IgnorePointer(
//                                 child: TextField(
//                                   controller: fromDatebalanceController,
//                                   style: const TextStyle(color: Colors.black),
//                                   decoration: InputDecoration(
//                                     hintText: "From Date",
//                                     hintStyle: TextStyle(
//                                       color: Colors.grey.shade600,
//                                     ),
//                                     suffixIcon: const Icon(
//                                       Icons.calendar_today,
//                                       size: 18,
//                                       color: AppColors.primaryDark,
//                                     ),
//                                     filled: true,
//                                     fillColor: Colors.white,
//                                     contentPadding: const EdgeInsets.symmetric(
//                                       vertical: 0,
//                                       horizontal: 8,
//                                     ),
//                                     border: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(5),
//                                       borderSide: BorderSide(
//                                         color: AppColors.border,
//                                       ),
//                                     ),
//
//                                     enabledBorder: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(5),
//                                       borderSide: BorderSide(
//                                         color: AppColors.border,
//                                       ),
//                                     ),
//
//                                     focusedBorder: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(5),
//                                       borderSide: BorderSide(
//                                         color: AppColors.border,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//
//                           const SizedBox(width: 8),
//
//                           Expanded(
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(5),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.05),
//                                     blurRadius: 5,
//                                     offset: const Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               child: DropdownButtonFormField<String>(
//                                 isExpanded: true,
//                                 value: selectedEntryType1,
//                                 hint: const Text(
//                                   "Conversion Type",
//                                   style: TextStyle(
//                                     color: Colors.black54,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 dropdownColor: Colors.white,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 12,
//                                 ),
//                                 decoration: InputDecoration(
//                                   labelText: "",
//                                   filled: true,
//                                   fillColor: Colors.white,
//
//                                   contentPadding: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 12,
//                                   ),
//
//                                   border: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                     borderSide: BorderSide(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//
//                                   enabledBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                     borderSide: BorderSide(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//
//                                   focusedBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                     borderSide: BorderSide(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//                                 ),
//
//                                 items: const [
//                                   DropdownMenuItem(
//                                     value: "Rupees to Metal",
//                                     child: Text(
//                                       "Rupees to Metal",
//                                       style: TextStyle(
//                                         color: Colors.black54,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                   DropdownMenuItem(
//                                     value: "Metal to Rupees",
//                                     child: Text("Metal to Rupees"),
//                                   ),
//                                 ],
//
//                                 onChanged: (value) {
//                                   dialogSetState(() {
//                                     selectedEntryType1 = value!;
//                                     //selectedEntryType = selectedEntryType1;
//                                   });
//
//                                   print(selectedEntryType);
//                                 },
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(10),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.05),
//                                     blurRadius: 5,
//                                     offset: const Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               child: DropdownButtonFormField<String>(
//                                 isExpanded: true,
//
//                                 hint: const Text(
//                                   "Metal Type",
//                                   style: TextStyle(
//                                     color: Colors.black54,
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                                 dropdownColor: Colors.white,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 14,
//                                 ),
//                                 decoration: InputDecoration(
//                                   labelText: "",
//                                   filled: true,
//                                   fillColor: Colors.white,
//
//                                   contentPadding: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 12,
//                                   ),
//
//                                   border: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                     borderSide: BorderSide(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//
//                                   enabledBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                     borderSide: BorderSide(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//
//                                   focusedBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(5),
//                                     borderSide: BorderSide(
//                                       color: AppColors.border,
//                                     ),
//                                   ),
//                                 ),
//
//                                 items: const [
//                                   DropdownMenuItem(
//                                     value: "gold",
//                                     child: Text("Gold"),
//                                   ),
//                                   DropdownMenuItem(
//                                     value: "silver",
//                                     child: Text("Silver"),
//                                   ),
//                                   DropdownMenuItem(
//                                     value: "other",
//                                     child: Text("Other"),
//                                   ),
//                                 ],
//
//                                 onChanged: (value) {
//                                   setState(() {
//                                     selectedmetaltype = value;
//                                   });
//
//                                   print(selectedmetaltype);
//                                 },
//                               ),
//                             ),
//                           ),
//
//                           const SizedBox(width: 8),
//
//                           Expanded(
//                             child: TextFormField(
//                               controller: metalController,
//                               keyboardType: TextInputType.number,
//                               onChanged: (value) {
//                                 calculateFineWeight(); // 🔥 કેલ્ક્યુલેશન કોલ કરો
//                               },
//                               style: const TextStyle(
//                                 color: Colors.black,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               decoration: InputDecoration(
//                                 hintText: "Enter Metal Rate",
//                                 hintStyle: TextStyle(
//                                   color: Colors.grey.shade600,
//                                 ),
//
//                                 filled: true,
//                                 fillColor: Colors.white,
//
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 12,
//                                 ),
//
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(5),
//                                   borderSide: BorderSide(
//                                     color: AppColors.border,
//                                   ),
//                                 ),
//
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(5),
//                                   borderSide: BorderSide(
//                                     color: AppColors.border,
//                                   ),
//                                 ),
//
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(5),
//                                   borderSide: BorderSide(
//                                     color: AppColors.border,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 4),
//                       selectedEntryType1.toString() == "Rupees to Metal"
//                           ? Row(
//                               children: [
//                                 Expanded(
//                                   child: TextFormField(
//                                     controller: amount1Controller,
//                                     keyboardType: TextInputType.number,
//                                     onChanged: (value) {
//                                       calculateFineWeight(); // 🔥 કેલ્ક્યુલેશન કોલ કરો
//                                     },
//                                     style: const TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                     decoration: InputDecoration(
//                                       hintText: "Enter Amount Advance",
//                                       hintStyle: TextStyle(
//                                         color: Colors.grey.shade600,
//                                       ),
//
//                                       filled: true,
//                                       fillColor: Colors.white,
//
//                                       contentPadding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 12,
//                                           ),
//
//                                       border: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//
//                                       enabledBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//
//                                       focusedBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 8),
//
//                                 Expanded(
//                                   child: TextFormField(
//                                     controller: fineController,
//                                     keyboardType: TextInputType.number,
//                                     readOnly: true, // 🔥 યુઝર ફેરફાર ના કર
//                                     style: const TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                     decoration: InputDecoration(
//                                       hintText: "Enter Fine Weight",
//                                       hintStyle: TextStyle(
//                                         color: Colors.grey.shade600,
//                                       ),
//
//                                       filled: true,
//                                       fillColor: Colors.white,
//
//                                       contentPadding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 12,
//                                           ),
//
//                                       border: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//
//                                       enabledBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//
//                                       focusedBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             )
//                           : Row(
//                               children: [
//                                 Expanded(
//                                   child: TextFormField(
//                                     controller: metalWeightController,
//                                     keyboardType: TextInputType.number,
//                                     onChanged: (value) {
//                                       calculateRupees(); // 🔥 કેલ્ક્યુલેશન કોલ કરો
//                                     },
//                                     style: const TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                     decoration: InputDecoration(
//                                       hintText: "Enter Metal Weight",
//                                       hintStyle: TextStyle(
//                                         color: Colors.grey.shade600,
//                                       ),
//
//                                       filled: true,
//                                       fillColor: Colors.white,
//
//                                       contentPadding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 12,
//                                           ),
//
//                                       border: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//
//                                       enabledBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//
//                                       focusedBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(5),
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//
//                                 const SizedBox(width: 8),
//
//                                 Expanded(
//                                   child: TextFormField(
//                                     controller: rupeesController,
//                                     keyboardType: TextInputType.number,
//                                     readOnly: true, // 🔥 યુઝર ફેરફાર ના કર
//                                     style: const TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                     decoration: InputDecoration(
//                                       hintText: "Rupees ( Auto )",
//                                       hintStyle: TextStyle(
//                                         color: Colors.grey.shade600,
//                                       ),
//
//                                       filled: true,
//                                       fillColor: Colors.white,
//
//                                       contentPadding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 14,
//                                           ),
//
//                                       border: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//
//                                       enabledBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                         borderSide: BorderSide(
//                                           color: Colors.grey.shade300,
//                                         ),
//                                       ),
//
//                                       focusedBorder: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                         borderSide: const BorderSide(
//                                           color: Color(0xffE6C58A),
//                                           width: 1.5,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: TextFormField(
//                               controller: remarkdialogController,
//                               //keyboardType: TextInputType.number,
//                               style: const TextStyle(
//                                 color: Colors.black,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               decoration: InputDecoration(
//                                 hintText: "Enter Remarks",
//                                 hintStyle: TextStyle(
//                                   color: Colors.grey.shade600,
//                                 ),
//
//                                 filled: true,
//                                 fillColor: Colors.white,
//
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 14,
//                                 ),
//
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
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
//                                   borderSide: const BorderSide(
//                                     color: Color(0xffE6C58A),
//                                     width: 1.5,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 10),
//                       InkWell(
//                         onTap: () async {
//                           //selectedEntryType = selectedEntryType1;
//
//                           Navigator.pop(context);
//                           await saveEntry(mode: "conversion");   // 🔥 FIX
//                         },
//                         child: Center(
//                           child: Container(
//                             width: 150,
//                             height: 40,
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 6,
//                             ),
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   AppColors.primaryDark.withOpacity(0.7),
//                                   AppColors.border.withOpacity(0.7),
//                                   AppColors.secondaryDark.withOpacity(0.7),
//                                 ],
//                               ),
//                               borderRadius: BorderRadius.circular(5),
//                             ),
//                             child: Center(
//                               child: const Text(
//                                 "Convert & Save",
//                                 style: TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w500,
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
//   void calculateFineWeight() {
//     double rate = double.tryParse(metalController.text) ?? 0;
//     double amount = double.tryParse(amount1Controller.text) ?? 0;
//
//     if (rate > 0 && amount > 0) {
//       double fine = amount / rate;
//       // .toStringAsFixed(3) વજન માટે યોગ્ય રહેશે
//       fineController.text = fine.toStringAsFixed(3);
//     } else {
//       fineController.text = "";
//     }
//   }
//
//   void calculateRupees() {
//     double rate = double.tryParse(metalController.text) ?? 0;
//     double weight = double.tryParse(metalWeightController.text) ?? 0;
//
//     if (rate > 0 && weight > 0) {
//       double totalRupees = rate * weight;
//       // Rupees બતાવવા માટે આપણે amount1Controller નો ઉપયોગ કરીશું
//       rupeesController.text = totalRupees.toStringAsFixed(2);
//     } else {
//       rupeesController.text = "0.00";
//     }
//   }
//
//   InputDecoration _premiumInputDecoration({
//     required String hint,
//     required IconData icon,
//   }) {
//     return InputDecoration(
//       hintText: hint,
//       hintStyle: const TextStyle(
//         color: Colors.black45,
//         fontSize: 12,
//         fontWeight: FontWeight.w400,
//       ),
//
//       prefixIcon: Icon(
//         icon,
//         size: 18,
//         color: AppColors.primaryDark,
//       ),
//
//       prefixIconConstraints: const BoxConstraints(
//         minWidth: 40,
//         minHeight: 40,
//       ),
//
//       filled: true,
//       fillColor: Colors.white,
//
//       isDense: true,
//
//       contentPadding: const EdgeInsets.symmetric(
//         horizontal: 10,
//         vertical: 13,
//       ),
//
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(
//           color: AppColors.border,
//         ),
//       ),
//
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(
//           color: AppColors.border,
//         ),
//       ),
//
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: const BorderSide(
//           color: AppColors.primaryDark,
//           width: 1.2,
//         ),
//       ),
//     );
//   }
//
//   Widget _premiumBalanceCard({
//     required String title,
//     required double value,
//     required IconData icon,
//   }) {
//     return Container(
//       height: 72,
//       padding: const EdgeInsets.symmetric(
//         horizontal: 11,
//         vertical: 9,
//       ),
//       decoration: BoxDecoration(
//         color: AppColors.primaryDark.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: AppColors.primaryDark.withOpacity(0.16),
//         ),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 34,
//             height: 34,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(7),
//             ),
//             child: Icon(
//               icon,
//               size: 18,
//               color: AppColors.primaryDark,
//             ),
//           ),
//
//           const SizedBox(width: 8),
//
//           Expanded(
//             child: Column(
//               mainAxisAlignment:
//               MainAxisAlignment.center,
//               crossAxisAlignment:
//               CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Colors.black54,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//
//                 const SizedBox(height: 3),
//
//                 Text(
//                   value.toStringAsFixed(2),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
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
//   Widget _premiumActionButton({
//     required String title,
//     required IconData icon,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(7),
//       child: Container(
//         height: 43,
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [
//               AppColors.primaryDark.withOpacity(0.85),
//               AppColors.secondaryDark.withOpacity(0.85),
//             ],
//           ),
//           borderRadius: BorderRadius.circular(7),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               color: Colors.white,
//               size: 17,
//             ),
//
//             const SizedBox(width: 6),
//
//             Flexible(
//               child: Text(
//                 title,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showCustomerRequiredMessage() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text(
//           "Please Select Customer First",
//         ),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
//
//   String _formatLedgerEntryType(String value) {
//     if (value.isEmpty || value == "-") {
//       return "-";
//     }
//
//     return value
//         .replaceAll("_", " ")
//         .split(" ")
//         .map((word) {
//       if (word.isEmpty) return "";
//
//       return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
//     })
//         .join(" ");
//   }
//
//   String _capitalizeLedgerText(String value) {
//     if (value.isEmpty || value == "-") {
//       return "-";
//     }
//
//     return value[0].toUpperCase() +
//         value.substring(1).toLowerCase();
//   }
//
//   Widget _premiumVerticalDivider() {
//     return Container(
//       width: 1,
//       height: 48,
//       margin: const EdgeInsets.symmetric(
//         horizontal: 5,
//         vertical: 4,
//       ),
//       color: AppColors.border.withOpacity(0.7),
//     );
//   }
//
//   Widget _viewField(
//       String title,
//       String value, {
//         double width = 140,
//         IconData? icon,
//         bool highlight = false,
//       }) {
//     return Container(
//       width: width,
//       margin: const EdgeInsets.symmetric(horizontal: 3),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//
//           /// TITLE
//           Padding(
//             padding: const EdgeInsets.only(left: 2),
//             child: Row(
//               children: [
//                 if (icon != null) ...[
//                   Icon(
//                     icon,
//                     size: 13,
//                     color: AppColors.primaryDark,
//                   ),
//                   const SizedBox(width: 5),
//                 ],
//
//                 Expanded(
//                   child: Text(
//                     title,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 10,
//                       color: Colors.black54,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 6),
//
//           /// VALUE BOX
//           Container(
//             height: 38,
//             width: double.infinity,
//             padding: const EdgeInsets.symmetric(
//               horizontal: 10,
//             ),
//             alignment: Alignment.centerLeft,
//             decoration: BoxDecoration(
//               color: highlight
//                   ? AppColors.primaryDark.withOpacity(0.06)
//                   : const Color(0xffFAFAFA),
//               borderRadius: BorderRadius.circular(7),
//               border: Border.all(
//                 color: highlight
//                     ? AppColors.primaryDark.withOpacity(0.18)
//                     : AppColors.border,
//               ),
//             ),
//             child: Text(
//               value.isEmpty ? "-" : value,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 color: Colors.black87,
//                 fontSize: 12,
//                 fontWeight:
//                 highlight ? FontWeight.w700 : FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// 🔥 Customer select / clear
//   Future<void> _setCustomer(Map? customer) async {
//     /// ❌ CLEAR
//     if (customer == null) {
//       setState(() {
//         selectedItem = null;
//
//         customerName = "";
//         customerCity = "";
//
//         cashBalance = 0;
//         goldBalance = 0;
//         silverBalance = 0;
//         otherBalance = 0;
//
//         userlist.clear();
//       });
//       return;
//     }
//
//     final int? customerId = int.tryParse(customer["id"]?.toString() ?? "");
//     if (customerId == null) return;
//
//     setState(() {
//       selectedItem = customerId.toString();
//       customerName = customer["name"]?.toString() ?? "";
//       customerCity = customer["city"]?.toString() ?? "";
//     });
//
//     debugPrint("Selected Customer => ${customer["name"]} ($customerId)");
//
//     await getApprovalDetails(customerId);
//   }
// }


import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PermissionDeniedWidget.dart';
import '../Extra/PremiumSearchableDropdown.dart';

class ReciveReturnPurchase extends StatefulWidget {
  const ReciveReturnPurchase({super.key});

  @override
  State<ReciveReturnPurchase> createState() => _ReciveReturnPurchasetState();
}

class _ReciveReturnPurchasetState extends State<ReciveReturnPurchase> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController fromDatebalanceController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController remarksController = TextEditingController();
  TextEditingController metalController = TextEditingController();
  TextEditingController amount1Controller = TextEditingController();
  TextEditingController fineController = TextEditingController();
  TextEditingController remarkdialogController = TextEditingController();
  final TextEditingController metalWeightController = TextEditingController();

  final TextEditingController rupeesController = TextEditingController();
  final TextEditingController fineWeightController = TextEditingController();
  String? selectedMetalType = "Silver";
  List userlist = [];
  List<Map<String, dynamic>> items = [];
  List searchResults = [];
  bool isLoading = false;
  Map<String, bool> expandedMap = {};
  Map<String, dynamic>? summaryTotals;
  String customerName = "";
  String customerCity = "";

  double cashBalance = 0.0;
  double goldBalance = 0.0;
  double silverBalance = 0.0;
  double otherBalance = 0.0;
  List<Map<String, dynamic>> ledgerList = [];
  String? Code;

  /// 🔥 NEW: Item rows (Sale screen jevu - "+" thi navi row, Item Name dropdown)
  final List<Map<String, dynamic>> entryItems = [];
  final Map<String, TextEditingController> itemControllers = {};

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text = "${picked.day}-${picked.month}-${picked.year}";
    }
  }

  String? selectedItem;
  List allUsers = []; // 🔥 original data store

  String? selectedCity;
  void searchUser(String value) {
    if (value.isEmpty) {
      setState(() {
        userlist = allUsers; // reset
      });
      return;
    }

    List filteredList = allUsers.where((user) {
      final name = user["name"]?.toString().toLowerCase() ?? "";
      final role = user["role"]?.toString().toLowerCase() ?? "";

      return name.contains(value.toLowerCase()) ||
          role.contains(value.toLowerCase());
    }).toList();

    setState(() {
      userlist = filteredList;
    });
  }

  /// 🔥 CHECKBOX VARIABLES
  bool useParty = false;
  bool useCity = false;

  /// 🔥 VARIABLES ADD KARO
  bool useWeight = false;
  bool useAmount = false;

  TextEditingController weightFromController = TextEditingController();
  TextEditingController weightToController = TextEditingController();

  TextEditingController amountFromController = TextEditingController();
  TextEditingController amountToController = TextEditingController();
  void applyDateFilter() {
    if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
      setState(() {
        userlist = allUsers;
      });
      return;
    }

    DateTime fromDate = _convertToDate(fromDateController.text);
    DateTime toDate = _convertToDate(toDateController.text);

    List filtered = allUsers.where((user) {
      if (user["created_at"] == null) return false;

      DateTime userDate = DateTime.parse(user["created_at"]);

      return userDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(toDate.add(const Duration(days: 1)));
    }).toList();

    setState(() {
      userlist = filtered;
    });
  }

  String selectedEntryType = "receive_amount";
  String selectedEntryType1 = "Rupees to Metal";
  String? selectedPaymentMode;
  String? selectedconversationtype;
  String? selectedmetaltype;

  List<String> userPermissions = []; // 🔥 ADD

  Future<void> loadPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Set<String> keys = prefs.getKeys();
    print("🔥 All SharedPreferences Keys: $keys");

    List<String> perms = prefs.getStringList("user_permissions") ?? [];
    print("🔥 user_permissions value: $perms");

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
      Provider.of<ItemProvider>(context, listen: false).refreshreturnCustomers();
      Provider.of<ItemProvider>(context, listen: false).refreshItems(); // 🔥 Item master list
    });
  }

  /// 🔥 NEW: controllers dispose
  @override
  void dispose() {
    for (final c in itemControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 🔥 NEW: Item rows reset
  void _resetItemRows() {
    for (final c in itemControllers.values) {
      c.dispose();
    }
    itemControllers.clear();
    entryItems.clear();
  }

  /// 🔥 NEW: item select thayeli rows j save ma jay
  List<Map<String, dynamic>> get _filledItemRows =>
      entryItems.where((r) => r["item_id"] != null).toList();

  @override
  Widget build(BuildContext context) {
    if (!(hasPermission("sale-advance-view") ||
        hasPermission("sale-advance-manage"))) {
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
            /// 🔥 MAIN CONTENT
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

                        selectedItem == null
                            ? const Center(child: Text("No Data Added"))
                            : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: userlist.length,
                          itemBuilder: (context, index) {
                            return buildUserCard(
                              userlist[index],
                              index,
                              userlist.length,
                            );
                          },
                        ),

                        /// 🔥 BOTTOM SUMMARY
                        buildSummaryRow(),
                        const SizedBox(height: 80),
                      ],
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
                    const Text(
                      "Receive / Return / Purchase",
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
                          Navigator.pop(context, true);
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

                    /// RIGHT PDF ICON
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 40,
                        child: InkWell(
                          onTap: () {
                            if (selectedItem == null) {
                              _showCustomerRequiredMessage();
                              return;
                            }

                            openPdf(int.parse(selectedItem.toString()));
                          },
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: const Color(0xffD32F2F),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
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

  Widget buildUserCard(Map user, int index, int totalCount) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          /// TOP HEADER
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.4),
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
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(6),
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
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 15,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _formatLedgerEntryType(
                            user["entry_type"]?.toString() ?? "-",
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if ((user["payment_mode"]?.toString() ?? "").isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.primaryDark.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 12,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user["payment_mode"]?.toString() ?? "-",
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          /// HORIZONTAL DATA
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 10,
                vertical: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _viewField(
                    "Date & Time",
                    user["entry_date"]?.toString() ?? "-",
                    icon: Icons.calendar_month_outlined,
                    width: 165,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Entry Type",
                    _formatLedgerEntryType(
                      user["entry_type"]?.toString() ?? "-",
                    ),
                    icon: Icons.swap_horiz_rounded,
                    width: 150,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Mode",
                    user["payment_mode"]?.toString() ?? "-",
                    icon: Icons.account_balance_wallet_outlined,
                    width: 120,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Cash In",
                    user["cash_in"]?.toString() ?? "0.00",
                    icon: Icons.south_west_rounded,
                    width: 125,
                    highlight: true,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Cash Out",
                    user["cash_out"]?.toString() ?? "0.00",
                    icon: Icons.north_east_rounded,
                    width: 125,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Metal Type",
                    _capitalizeLedgerText(
                      user["metal_type"]?.toString() ?? "-",
                    ),
                    icon: Icons.diamond_outlined,
                    width: 125,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Metal In",
                    user["metal_in"]?.toString() ?? "0.000",
                    icon: Icons.arrow_downward_rounded,
                    width: 125,
                    highlight: true,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Metal Out",
                    user["metal_out"]?.toString() ?? "0.000",
                    icon: Icons.arrow_upward_rounded,
                    width: 125,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Rate",
                    user["rate"]?.toString() ?? "0.000",
                    icon: Icons.currency_rupee_rounded,
                    width: 125,
                  ),
                  _premiumVerticalDivider(),
                  _viewField(
                    "Remarks",
                    user["remarks"]?.toString() ?? "-",
                    icon: Icons.notes_rounded,
                    width: 190,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> Salesumryreport() async {
    final response = await ApiHelper().getRequest(
      ApiConstants.OutStanding_amount_report,
    );

    print("user API URL: ${ApiConstants.OutStanding_amount_report}");
    print("users Raw Response: ${response.toString()}");

    if (response!.statusCode == 200) {
      final data = response.data;
      final List categories = data['data'];

      setState(() {
        userlist = categories;
        allUsers = categories;
        summaryTotals = data["summary"];
      });

      print("✅ Total user: ${userlist.length}");
      searchController.clear();
      searchResults.clear();
    } else {
      setState(() {
        userlist = [];
      });
      print("❌ userlist API failed");
    }
  }

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================
          // CUSTOMER SEARCHABLE DROPDOWN
          // =========================================================
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              final customers = provider.customers_return;

              Map? selectedCustomer;

              if (selectedItem != null) {
                try {
                  selectedCustomer = customers.firstWhere(
                        (item) => item["id"]?.toString() == selectedItem.toString(),
                  );
                } catch (_) {
                  selectedCustomer = null;
                }
              }

              return Stack(
                alignment: Alignment.centerRight,
                children: [
                  PremiumSearchableDropdown<Map>(
                    label: "",
                    hint: "Search & Select Customer",
                    items: List<Map>.from(customers),
                    value: selectedCustomer,
                    prefixIcon: Icons.person_outline,
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
                    onChanged: (selectedData) => _setCustomer(selectedData),
                  ),

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
                            _setCustomer(null);
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

          const SizedBox(height: 12),

          // =========================================================
          // DATE + PAYMENT
          // =========================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(fromDateController),
                  borderRadius: BorderRadius.circular(8),
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: fromDateController,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _premiumInputDecoration(
                        hint: "Entry Date",
                        icon: Icons.calendar_month_outlined,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedPaymentMode,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black54,
                  ),
                  hint: const Text(
                    "Payment Mode",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _premiumInputDecoration(
                    hint: "",
                    icon: Icons.payments_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(value: "Cash", child: Text("Cash")),
                    DropdownMenuItem(value: "Online", child: Text("Online")),
                    DropdownMenuItem(value: "UPI", child: Text("UPI")),
                    DropdownMenuItem(value: "Bank", child: Text("Bank")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedPaymentMode = value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // =========================================================
          // ENTRY TYPE
          // =========================================================
          DropdownButtonFormField<String>(
            value: selectedEntryType,
            isExpanded: true,
            dropdownColor: Colors.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black54,
            ),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: _premiumInputDecoration(
              hint: "Entry Type",
              icon: Icons.swap_vert_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: "receive_amount",
                child: Text("Receive Amount"),
              ),
              DropdownMenuItem(
                value: "receive_fine_metal",
                child: Text("Receive Fine Metal"),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedEntryType = value;

                // 🔥 FIX: dropdown values "Gold/Silver/Other" chhe,
                // lowercase "silver" aapta crash thato hato
                if (value == "receive_amount") {
                  selectedMetalType = "Silver";
                  fineWeightController.clear();
                } else if (value == "receive_fine_metal") {
                  selectedMetalType = "Silver";
                  amountController.clear();
                }
              });

              print("Entry Type => $selectedEntryType");
              print("Metal Type => $selectedMetalType");
            },
          ),

          // =========================================================
          // CUSTOMER SELECTED -> BALANCE
          // =========================================================
          if (selectedItem != null) ...[
            const SizedBox(height: 14),

            Row(
              children: [
                const Text(
                  "Current Balance",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(height: 1, color: AppColors.border),
                ),
              ],
            ),

            const SizedBox(height: 9),

            LayoutBuilder(
              builder: (context, constraints) {
                final List<Widget> cards = [];

                void addCard({
                  required String title,
                  required double value,
                  required IconData icon,
                }) {
                  cards.add(
                    SizedBox(
                      width: 145,
                      child: _premiumBalanceCard(
                        title: title,
                        value: value,
                        icon: icon,
                      ),
                    ),
                  );
                }

                addCard(
                  title: "Cash Credit",
                  value: cashBalance,
                  icon: Icons.currency_rupee,
                );

                if (goldBalance != 0) {
                  addCard(
                    title: "Gold Balance",
                    value: goldBalance,
                    icon: Icons.diamond_outlined,
                  );
                }

                if (silverBalance != 0) {
                  addCard(
                    title: "Silver Balance",
                    value: silverBalance,
                    icon: Icons.circle_outlined,
                  );
                }

                if (otherBalance != 0) {
                  addCard(
                    title: "Other Balance",
                    value: otherBalance,
                    icon: Icons.account_balance_wallet_outlined,
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      cards.length,
                          (index) => Padding(
                        padding: EdgeInsets.only(
                          right: index == cards.length - 1 ? 0 : 8,
                        ),
                        child: cards[index],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 14),

          // =========================================================
          // RECEIVE AMOUNT
          // =========================================================
          if (selectedEntryType == "receive_amount") ...[
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: _premiumInputDecoration(
                hint: "Enter Amount",
                icon: Icons.currency_rupee_rounded,
              ),
            ),
          ],

          // =========================================================
          // RECEIVE FINE METAL
          // =========================================================
          if (selectedEntryType == "receive_fine_metal") ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMetalType,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black54,
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _premiumInputDecoration(
                      hint: "Metal Type",
                      icon: Icons.diamond_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: "Gold", child: Text("Gold")),
                      DropdownMenuItem(value: "Silver", child: Text("Silver")),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedMetalType = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextFormField(
                    controller: fineWeightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _premiumInputDecoration(
                      hint: "Fine Weight",
                      icon: Icons.scale_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // =========================================================
          // 🔥 NEW: ITEMS (Sale screen jevu - "+" thi row, Item dropdown)
          // =========================================================
          const SizedBox(height: 14),

          _buildItemsSection(),

          const SizedBox(height: 14),

          // =========================================================
          // REMARKS
          // =========================================================
          TextFormField(
            controller: remarksController,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: _premiumInputDecoration(
              hint: "Enter Remarks",
              icon: Icons.notes_rounded,
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================
          // ACTION BUTTONS
          // =========================================================
          Row(
            children: [
              Expanded(
                child: _premiumActionButton(
                  title: "Save Entry",
                  icon: Icons.save_outlined,
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    if (selectedItem == null) {
                      _showCustomerRequiredMessage();
                      return;
                    }

                    if (selectedEntryType == "receive_amount") {
                      if (amountController.text.trim().isEmpty) {
                        AppMessage.error(context, "Please enter amount.");
                        return;
                      }
                    }

                    if (selectedEntryType == "receive_fine_metal") {
                      if (selectedMetalType == null ||
                          selectedMetalType!.isEmpty) {
                        AppMessage.error(context, "Please select metal type.");
                        return;
                      }

                      if (fineWeightController.text.trim().isEmpty) {
                        AppMessage.error(context, "Please enter fine weight.");
                        return;
                      }
                    }

                    await saveEntry(mode: "main");
                  },
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _premiumActionButton(
                  title: "Conversion",
                  icon: Icons.swap_horiz_rounded,
                  onTap: () {
                    if (selectedItem == null) {
                      _showCustomerRequiredMessage();
                      return;
                    }

                    showBalanceConversionDialog();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
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

  String formatDate(String date) {
    try {
      final parts = date.split(" ")[0].split("-");
      return "${parts[2]}-${parts[1]}-${parts[0]}";
    } catch (e) {
      return "-";
    }
  }

  DateTime _convertToDate(String input) {
    final parts = input.split("-");
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  Future<void> searchItemsApi(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        items = [];
      });
      return;
    }

    final response = await ApiHelper().getRequest(
      "${ApiConstants.Barcode_report}/suggest?q=$keyword",
    );

    if (response != null && response.statusCode == 200) {
      setState(() {
        searchResults = response.data["data"];
      });
    } else {
      print("Search API Failed");
    }
  }

  /// 🔹 PDF Button
  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F), Color(0xffE57373)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text(
              "PDF",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget excelBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 20, 0),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff66BB6A), Color(0xff2E7D32), Color(0xff66BB6A)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              "Excel",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String apiDate(String value) {
    if (value.isEmpty) return "";

    final parts = value.split("-");

    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  Future<void> openPdf(int id) async {
    final response = await ApiHelper().getRequestWithId(
      "${ApiConstants.sales_advance_ledger_pdf}"
          "?customer_id=$id"
          "&direct=1"
          "&mode=inline",
      id,
      responseType: ResponseType.bytes,
    );

    if (response != null && response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/return_$id.pdf");
      await file.writeAsBytes(response.data);
      OpenFile.open(file.path);
    } else {
      print("PDF Download Failed");
    }
  }

  Future<void> openexel(String Code) async {
    try {
      bool isDefaultReport = !useParty && !useCity && !useWeight && !useAmount;
      String url =
          "${ApiConstants.OutStanding_amount_report_excel}?"
          "use_default_report=${isDefaultReport ? 1 : 0}"
          "&use_date=1"
          "&from_date=${apiDate(fromDateController.text)}"
          "&to_date=${apiDate(toDateController.text)}"
          "&use_party=${useParty ? 1 : 0}"
          "&customer_id=${useParty ? selectedItem ?? "" : ""}"
          "&use_city=${useCity ? 1 : 0}"
          "&city=${useCity ? selectedCity ?? "" : ""}"
          "&use_mode=0"
          "&payment_mode="
          "&use_weight=${useWeight ? 1 : 0}"
          "&weight_from=${useWeight ? weightFromController.text : ""}"
          "&weight_to=${useWeight ? weightToController.text : ""}"
          "&use_amount=${useAmount ? 1 : 0}"
          "&amount_from=${useAmount ? amountFromController.text : ""}"
          "&amount_to=${useAmount ? amountToController.text : ""}";
      final response = await ApiHelper().getPdfRequest(url);

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/sales_summary.pdf");
        final bytes = List<int>.from(response.data);
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      } else {
        print("PDF Download Failed: ${response?.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Widget buildSummaryRow() {
    if (summaryTotals == null) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xffFAF7F2),
        border: Border(
          top: BorderSide(color: Colors.grey),
          bottom: BorderSide(color: Colors.grey),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryBox("Voucher", summaryTotals!["voucher_count"].toString()),
            _summaryBox(
              "Gross",
              double.parse(
                summaryTotals!["gross_weight"].toString(),
              ).toStringAsFixed(2),
            ),
            _summaryBox("Net", summaryTotals!["net_weight"].toString()),
            _summaryBox("Amount IN", summaryTotals!["amount_in"].toString()),
            _summaryBox("Amount Out", summaryTotals!["amount_out"].toString()),
            _summaryBox(
              "Pending Amt",
              summaryTotals!["pending_amount"].toString(),
            ),
            _summaryBox("Total", summaryTotals!["total_amount"].toString()),
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

  Widget _balanceBox({required String title, required String amount}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.4),
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

    try {
      /// 1️⃣ SUMMARY API
      final response = await ApiHelper().getRequest(
        "${ApiConstants.advance_ledger_summary}?customer_id=$customerId",
      );

      if (response != null && response.statusCode == 200) {
        final json = response.data;

        if (json["success"] == true) {
          final data = json["data"];

          final customer = data["customer"];
          final balance = data["balance"];
          final metalBalance = balance["metal_balance"];

          setState(() {
            customerName = customer["name"] ?? "";
            customerCity = customer["city"] ?? "";

            cashBalance =
                double.tryParse(balance["cash_balance"].toString()) ?? 0.0;
            goldBalance =
                double.tryParse(metalBalance["gold"].toString()) ?? 0.0;
            silverBalance =
                double.tryParse(metalBalance["silver"].toString()) ?? 0.0;
            otherBalance =
                double.tryParse(metalBalance["other"].toString()) ?? 0.0;
          });

          /// 2️⃣ ENTRIES API
          final ledgerResponse = await ApiHelper().getRequest(
            "${ApiConstants.sales_advance_ledger_entries}?customer_id=$customerId&per_page=50",
          );

          if (ledgerResponse != null && ledgerResponse.statusCode == 200) {
            final ledgerJson = ledgerResponse.data;

            if (ledgerJson["success"] == true) {
              setState(() {
                userlist = List<Map<String, dynamic>>.from(
                  ledgerJson["data"] ?? [],
                );
              });

              print("Ledger Records = ${userlist.length}");
            }
          }
        }
      }
    } catch (e) {
      print("Error => $e");
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> saveEntry({required String mode}) async {
    Map<String, dynamic> body = {};

    // ============================================================
    // MODE: "main" -> Save Entry button
    // ============================================================
    if (mode == "main") {
      if (selectedEntryType == "receive_amount") {
        body = {
          "entry_date": fromDateController.text,
          "customer_id": int.parse(selectedItem.toString()),
          "entry_type": "receive_amount",
          "payment_mode": selectedPaymentMode,
          "amount": double.tryParse(amountController.text) ?? 0,
          "remarks": remarksController.text,
        };
      } else if (selectedEntryType == "receive_fine_metal") {
        body = {
          "entry_date": fromDateController.text,
          "customer_id": int.parse(selectedItem.toString()),
          "entry_type": "receive_metal",
          "payment_mode": selectedPaymentMode,
          "metal_type": selectedMetalType.toString().toLowerCase(),
          "rate": double.tryParse(metalController.text) ?? 0,
          "amount": 0,
          "fine_weight": double.tryParse(fineWeightController.text) ?? 0,
          "remarks": remarksController.text,
        };
      }
    }

    // ============================================================
    // MODE: "conversion" -> Convert & Save button
    // ============================================================
    else if (mode == "conversion") {
      if (selectedEntryType1 == "Rupees to Metal") {
        body = {
          "entry_date": fromDatebalanceController.text,
          "customer_id": int.parse(selectedItem.toString()),
          "entry_type": "convert_to_metal",
          "metal_type": (selectedmetaltype ?? "silver").toLowerCase(),
          "rate": double.tryParse(metalController.text) ?? 0,
          "amount": double.tryParse(amount1Controller.text) ?? 0,
          "fine_weight": double.tryParse(fineController.text) ?? 0,
          "remarks": remarkdialogController.text,
        };
      } else if (selectedEntryType1 == "Metal to Rupees") {
        body = {
          "entry_date": fromDatebalanceController.text,
          "customer_id": int.parse(selectedItem.toString()),
          "entry_type": "convert_to_rupees",
          "metal_type": (selectedmetaltype ?? "silver").toLowerCase(),
          "rate": double.tryParse(metalController.text) ?? 0,
          "amount": double.tryParse(rupeesController.text) ?? 0,
          "fine_weight": double.tryParse(metalWeightController.text) ?? 0,
          "remarks": remarkdialogController.text,
        };
      }
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print(body);

    final response = await ApiHelper().postRequest(
      ApiConstants.sales_advance_ledger_entries,
      body,
    );

    if (!mounted) return;

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Entry Saved Successfully"),
          backgroundColor: Colors.green,
        ),
      );

      if (mode == "main") {
        setState(() {
          amountController.clear();
          fineWeightController.clear();
          remarksController.clear();
        });
      }

      /// Refresh Balance + Ledger
      await getApprovalDetails(int.parse(selectedItem.toString()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to Save Entry"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showBalanceConversionDialog() {
    fromDatebalanceController.clear();
    metalController.clear();
    amount1Controller.clear();
    fineController.clear();
    metalWeightController.clear();
    rupeesController.clear();
    remarkdialogController.clear();

    selectedEntryType1 = "Rupees to Metal";
    selectedmetaltype = "silver";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              backgroundColor: AppColors.background,
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// HEADER
                      Row(
                        children: [
                          const Text(
                            "Balance Conversion",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
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

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  _selectDate(fromDatebalanceController),
                              child: IgnorePointer(
                                child: TextField(
                                  controller: fromDatebalanceController,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: _dialogDecoration(
                                    "From Date",
                                    suffix: const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: AppColors.primaryDark,
                                    ),
                                    vertical: 0,
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedEntryType1,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              decoration: _dialogDecoration(""),
                              items: const [
                                DropdownMenuItem(
                                  value: "Rupees to Metal",
                                  child: Text("Rupees to Metal"),
                                ),
                                DropdownMenuItem(
                                  value: "Metal to Rupees",
                                  child: Text("Metal to Rupees"),
                                ),
                              ],
                              onChanged: (value) {
                                dialogSetState(() {
                                  selectedEntryType1 = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedmetaltype,
                              hint: const Text(
                                "Metal Type",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: _dialogDecoration(""),
                              items: const [
                                DropdownMenuItem(
                                  value: "gold",
                                  child: Text("Gold"),
                                ),
                                DropdownMenuItem(
                                  value: "silver",
                                  child: Text("Silver"),
                                ),
                                DropdownMenuItem(
                                  value: "other",
                                  child: Text("Other"),
                                ),
                              ],
                              onChanged: (value) {
                                dialogSetState(() {
                                  selectedmetaltype = value;
                                });
                              },
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: TextFormField(
                              controller: metalController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                calculateFineWeight();
                                calculateRupees();
                              },
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _dialogDecoration("Enter Metal Rate"),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      selectedEntryType1 == "Rupees to Metal"
                          ? Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: amount1Controller,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                calculateFineWeight();
                              },
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _dialogDecoration(
                                "Enter Amount Advance",
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: fineController,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _dialogDecoration(
                                "Fine Weight (Auto)",
                              ),
                            ),
                          ),
                        ],
                      )
                          : Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: metalWeightController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                calculateRupees();
                              },
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _dialogDecoration(
                                "Enter Metal Weight",
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: rupeesController,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _dialogDecoration(
                                "Rupees ( Auto )",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: remarkdialogController,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _dialogDecoration("Enter Remarks"),
                      ),

                      const SizedBox(height: 10),

                      InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await saveEntry(mode: "conversion");
                        },
                        child: Center(
                          child: Container(
                            width: 150,
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                              child: Text(
                                "Convert & Save",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
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
      },
    );
  }

  /// Dialog na badha input mate common decoration
  InputDecoration _dialogDecoration(
      String hint, {
        Widget? suffix,
        double vertical = 12,
        double horizontal = 12,
      }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(color: AppColors.border),
    );
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }

  void calculateFineWeight() {
    double rate = double.tryParse(metalController.text) ?? 0;
    double amount = double.tryParse(amount1Controller.text) ?? 0;

    if (rate > 0 && amount > 0) {
      double fine = amount / rate;
      fineController.text = fine.toStringAsFixed(3);
    } else {
      fineController.text = "";
    }
  }

  void calculateRupees() {
    double rate = double.tryParse(metalController.text) ?? 0;
    double weight = double.tryParse(metalWeightController.text) ?? 0;

    if (rate > 0 && weight > 0) {
      double totalRupees = rate * weight;
      rupeesController.text = totalRupees.toStringAsFixed(2);
    } else {
      rupeesController.text = "0.00";
    }
  }

  InputDecoration _premiumInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black45,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primaryDark),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
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
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.2),
      ),
    );
  }

  Widget _premiumBalanceCard({
    required String title,
    required double value,
    required IconData icon,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.toStringAsFixed(2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 43,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark.withOpacity(0.85),
              AppColors.secondaryDark.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please Select Customer First"),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatLedgerEntryType(String value) {
    if (value.isEmpty || value == "-") {
      return "-";
    }

    return value
        .replaceAll("_", " ")
        .split(" ")
        .map((word) {
      if (word.isEmpty) return "";
      return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
    })
        .join(" ");
  }

  String _capitalizeLedgerText(String value) {
    if (value.isEmpty || value == "-") {
      return "-";
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Widget _premiumVerticalDivider() {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      color: AppColors.border.withOpacity(0.7),
    );
  }

  Widget _viewField(
      String title,
      String value, {
        double width = 140,
        IconData? icon,
        bool highlight = false,
      }) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: AppColors.primaryDark),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 38,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: highlight
                  ? AppColors.primaryDark.withOpacity(0.06)
                  : const Color(0xffFAFAFA),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: highlight
                    ? AppColors.primaryDark.withOpacity(0.18)
                    : AppColors.border,
              ),
            ),
            child: Text(
              value.isEmpty ? "-" : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 🔥 ITEM ROWS — Sale screen jevu j (Item Name dropdown + search sheet)
  // ===================================================================

  TextEditingController _ctrl(Map item, String key) {
    final String k = "${item["row_id"]}_$key";
    return itemControllers.putIfAbsent(
      k,
          () => TextEditingController(text: item[key]?.toString() ?? ""),
    );
  }

  double _num(Map item, String key) {
    final String text = _ctrl(item, key).text.trim();
    return double.tryParse(text.isEmpty ? (item[key]?.toString() ?? "0") : text) ?? 0;
  }

  Map<String, dynamic> _createBlankItemRow() {
    return {
      "row_id": "row_${DateTime.now().microsecondsSinceEpoch}",
      "item_id": null,
      "item_name": "",
      "metal": "",
      "qty": "1",
      "gross_weight": "0",
      "other_weight": "0",
      "net_weight": "0",
      "purity": "0",
      "waste": "0",
      "net_purity": "0",
      "fine_weight": "0",
      "metal_rate": "0",
      "metal_amount": "0",
      "labour_rate": "0",
      "labour_amount": "0",
      "other_amount": "0",
      "total_amount": "0",
      "remarks": "",
      "manual_metal": true,
      "manual_labour": true,
    };
  }

  void _addItemRow() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      entryItems.insert(0, _createBlankItemRow()); // navi row upar
    });
  }

  void _removeItemRow(Map<String, dynamic> item) {
    setState(() {
      final String prefix = "${item["row_id"]}_";
      final keys =
      itemControllers.keys.where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        itemControllers.remove(k)?.dispose();
      }
      entryItems.remove(item);
    });
  }

  /// Sale na calculateItem() jevu j
  void _calcItem(Map<String, dynamic> item) {
    final double gross = _num(item, "gross_weight");
    final double other = _num(item, "other_weight");
    final double net = gross - other;
    final double purity = _num(item, "purity");
    final double waste = _num(item, "waste");
    final double netPurity = purity + waste;
    final double fine = net * (netPurity / 100);
    final double metalRate = _num(item, "metal_rate");
    final double labourRate = _num(item, "labour_rate");
    final double otherAmount = _num(item, "other_amount");

    final double metalAmount =
    (item["manual_metal"] ?? true) ? fine * metalRate : 0;
    final double labourAmount =
    (item["manual_labour"] ?? true) ? net * labourRate : 0;
    final double total = metalAmount + labourAmount + otherAmount;

    item["net_weight"] = net.toStringAsFixed(3);
    item["net_purity"] = netPurity.toStringAsFixed(2);
    item["fine_weight"] = fine.toStringAsFixed(3);
    item["metal_amount"] = metalAmount.toStringAsFixed(2);
    item["labour_amount"] = labourAmount.toStringAsFixed(2);
    item["total_amount"] = total.toStringAsFixed(2);

    for (final k in [
      "net_weight",
      "net_purity",
      "fine_weight",
      "metal_amount",
      "labour_amount",
      "total_amount",
    ]) {
      final c = _ctrl(item, k);
      if (c.text != item[k]) c.text = item[k];
    }
  }

  bool _isEditableKey(String key) => const [
    "qty",
    "gross_weight",
    "other_weight",
    "purity",
    "waste",
    "metal_rate",
    "labour_rate",
    "other_amount",
    "remarks",
  ].contains(key);

  /// 🔥 API format mujab ek item
  Map<String, dynamic> _itemToJson(Map<String, dynamic> item) {
    double r3(double v) => double.parse(v.toStringAsFixed(3));
    double r2(double v) => double.parse(v.toStringAsFixed(2));

    return {
      "product_id": int.tryParse(item["item_id"]?.toString() ?? ""),
      "gross_weight": r3(_num(item, "gross_weight")),
      "other_weight": r3(_num(item, "other_weight")),
      "net_weight": r3(_num(item, "net_weight")),
      "purity": r2(_num(item, "purity")),
      "waste_percent": r2(_num(item, "waste")),
      "net_purity": r2(_num(item, "net_purity")),
      "fine_weight": r3(_num(item, "fine_weight")),
      "metal_rate": r2(_num(item, "metal_rate")),
      "labour_rate": r2(_num(item, "labour_rate")),
    };
  }

  /// "2026-10-12" format (date khali hoy to aaj ni date)
  String _itemsEntryDate() {
    final String text = fromDateController.text.trim();
    if (text.isNotEmpty) {
      try {
        return apiDate(text);
      } catch (_) {}
    }
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  bool _isSavingItems = false;

  // ===================================================================
  // 🔥 SAVE ITEMS — Save Entry vali j API, items vala body sathe
  // ===================================================================
  Future<void> saveItems() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isSavingItems) return;

    if (selectedItem == null) {
      _showCustomerRequiredMessage();
      return;
    }

    if (entryItems.any((r) => r["item_id"] == null)) {
      AppMessage.error(context, "Please select item in all rows.");
      return;
    }

    final filled = _filledItemRows;

    if (filled.isEmpty) {
      AppMessage.error(context, "Please add at least one item.");
      return;
    }

    if (filled.any((r) => _num(r, "gross_weight") <= 0)) {
      AppMessage.error(context, "Please enter gross weight in all items.");
      return;
    }

    final Map<String, dynamic> body = {
      "entry_date": _itemsEntryDate(),
      "customer_id": int.parse(selectedItem.toString()),
      "remarks": remarksController.text.trim(),
      "items": filled.map(_itemToJson).toList(),
    };

    debugPrint("📤 SAVE ITEMS BODY => $body");

    setState(() => _isSavingItems = true);

    final response = await ApiHelper().postRequest(
      ApiConstants.sales_advance_ledger_entries,
      body,
    );

    if (!mounted) return;

    setState(() => _isSavingItems = false);

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      AppMessage.success(
        context,
        response.data is Map
            ? (response.data["message"]?.toString() ?? "Items Saved Successfully")
            : "Items Saved Successfully",
      );

      final bool hadItems = filled.isNotEmpty;

      _resetItemRows();
      remarksController.clear();

      if (hadItems) {
        /// 🔥 Items save thaya → Receive Return page par pachha jao
        Navigator.pop(context, true);
      } else {
        /// Items nathi → page par j raho, balance + ledger refresh
        setState(() {});
        await getApprovalDetails(int.parse(selectedItem.toString()));
      }
    } else {
      final String msg = (response?.data is Map
          ? response?.data["message"]?.toString()
          : null) ??
          "Failed to Save Items";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  /// "All" — pehli row ni value badhi rows ma
  void _applyToAllItems(Map<String, dynamic> source, String key) {
    FocusManager.instance.primaryFocus?.unfocus();
    final String value =
    _ctrl(source, key).text.trim().isEmpty ? "0" : _ctrl(source, key).text.trim();

    for (final item in entryItems) {
      _ctrl(item, key).text = value;
      item[key] = value;
      if (key == "metal_rate") item["manual_metal"] = true;
      if (key == "labour_rate") item["manual_labour"] = true;
      _calcItem(item);
    }
    setState(() {});

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text("Applied to all ${entryItems.length} items"),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // -------------------------------------------------------------------
  // SECTION: header + "+" + cards + totals
  // -------------------------------------------------------------------
  Widget _buildItemsSection() {
    double gross = 0, net = 0, fine = 0, total = 0;
    for (final r in entryItems) {
      gross += _num(r, "gross_weight");
      net += _num(r, "net_weight");
      fine += _num(r, "fine_weight");
      total += _num(r, "total_amount");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Items",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: AppColors.border)),
            const SizedBox(width: 8),

            /// ➕ ADD ITEM (Sale jevu)
            InkWell(
              onTap: _addItemRow,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryDark.withOpacity(0.25),
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (entryItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              "Tap + to add item",
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          )
        else ...[
          ...List.generate(
            entryItems.length,
                (i) => _itemCard(entryItems[i], i, entryItems.length),
          ),

          /// TOTALS
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _summaryBox("Items", "${entryItems.length}"),
                  _summaryBox("Gross", gross.toStringAsFixed(3)),
                  _summaryBox("Net", net.toStringAsFixed(3)),
                  _summaryBox("Fine", fine.toStringAsFixed(3)),
                  _summaryBox("Total", total.toStringAsFixed(2)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// 💾 SAVE ITEMS
          SizedBox(
            width: double.infinity,
            child: _isSavingItems
                ? Container(
              height: 43,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : _premiumActionButton(
              title: "Save Items",
              icon: Icons.inventory_2_outlined,
              onTap: saveItems,
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------
  // CARD (Sale na approvalItemCard jevu)
  // -------------------------------------------------------------------
  Widget _itemCard(Map<String, dynamic> item, int index, int totalCount) {
    final String itemName = item["item_name"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
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
                    color: AppColors.primaryDark,
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
                        itemName.isEmpty ? "Select Item" : itemName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: itemName.isEmpty
                              ? Colors.black38
                              : Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                /// DELETE
                InkWell(
                  onTap: () => _removeItemRow(item),
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

          /// FIELDS (horizontal)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _itemDropdown(item),
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

  // -------------------------------------------------------------------
  // ITEM NAME DROPDOWN → search bottom sheet (Sale na _labourDropdown jevu)
  // -------------------------------------------------------------------
  Widget _itemDropdown(Map<String, dynamic> item) {
    final provider = Provider.of<ItemProvider>(context, listen: false);

    final List<Map<String, dynamic>> allItems = provider.items
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    return _miniDropdownBox(
      title: "Item Name",
      width: 155,
      text: item["item_name"]?.toString() ?? "",
      hint: "Select Item",
      onTap: () async {
        final Map<String, dynamic>? selected = await _openSearchSheet(
          title: "Item",
          icon: Icons.category_outlined,
          items: allItems,
          selectedId: item["item_id"]?.toString(),
          labelOf: (d) => d["item_name"]?.toString() ?? "-",
          subtitleOf: (d) {
            final code = d["item_code"]?.toString() ?? "";
            return (code.isEmpty || code == "null") ? "" : "Code: $code";
          },
          searchOf: (d) => [
            d["item_name"]?.toString() ?? "",
            d["item_code"]?.toString() ?? "",
            d["metal"]?.toString() ?? "",
            d["id"]?.toString() ?? "",
          ].join(" "),
        );

        if (selected == null || !mounted) return;

        final String outwardCarat =
            selected["outward_carat"]?.toString() ?? "0";
        final String labourRate = selected["labour_rate"]?.toString() ?? "0";

        setState(() {
          item["item_id"] = selected["id"];
          item["item_name"] = selected["item_name"]?.toString() ?? "";
          item["item_code"] = selected["item_code"];
          item["metal"] = selected["metal"];
          item["purity"] = outwardCarat;
          item["labour_rate"] = labourRate;
          item["selected_item_data"] = selected;

          _ctrl(item, "purity").text = outwardCarat;
          _ctrl(item, "labour_rate").text = labourRate;

          _calcItem(item);
        });
      },
    );
  }

  // -------------------------------------------------------------------
  // MINI FIELD (Sale na _miniField jevu)
  // -------------------------------------------------------------------
  Widget _miniField(
      String title,
      Map<String, dynamic> item,
      String key,
      int index,
      ) {
    final bool isRemarks = key == "remarks";
    final bool isMetalRate = key == "metal_rate";
    final bool isLabourRate = key == "labour_rate";
    final bool editable = _isEditableKey(key);
    final controller = _ctrl(item, key);

    final bool showAll = index == 0 &&
        entryItems.length > 1 &&
        const ["metal_rate", "labour_rate", "purity", "waste", "other_amount"]
            .contains(key);

    return Container(
      width: isRemarks ? 140 : 105,
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
                if (showAll)
                  InkWell(
                    onTap: () => _applyToAllItems(item, key),
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
                  readOnly: !editable,
                  canRequestFocus: editable,
                  showCursor: editable,
                  keyboardType: isRemarks
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: editable ? Colors.black : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () {
                    if (isRemarks || !editable) return;
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
                    if (!isRemarks && controller.text.isEmpty) {
                      controller.text = "0";
                    }
                    FocusScope.of(context).unfocus();
                  },
                  onChanged: (val) {
                    item[key] = val;
                    _calcItem(item);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: 8,
                      right: (isMetalRate || isLabourRate) ? 30 : 8,
                      top: 9,
                      bottom: 9,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),

                /// METAL / LABOUR RATE CHECKBOX (Sale jevu)
                if (isMetalRate || isLabourRate)
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
                          value: (double.tryParse(controller.text.isEmpty
                              ? "0"
                              : controller.text) ??
                              0) >
                              0,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                if ((double.tryParse(controller.text.isEmpty
                                    ? "0"
                                    : controller.text) ??
                                    0) ==
                                    0) {
                                  if (isMetalRate) {
                                    controller.text = "1";
                                  } else {
                                    controller.clear();
                                  }
                                }
                              } else {
                                controller.text = "0.00";
                              }
                              item[key] = controller.text;
                              _calcItem(item);
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

  // -------------------------------------------------------------------
  // DROPDOWN BOX (border sathe) — Sale mathi
  // -------------------------------------------------------------------
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

  // -------------------------------------------------------------------
  // PREMIUM SEARCH BOTTOM SHEET — Sale mathi
  // -------------------------------------------------------------------
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
                                                overflow: TextOverflow
                                                    .ellipsis,
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

  /// 🔥 Customer select / clear
  Future<void> _setCustomer(Map? customer) async {
    if (customer == null) {
      setState(() {
        selectedItem = null;
        customerName = "";
        customerCity = "";
        cashBalance = 0;
        goldBalance = 0;
        silverBalance = 0;
        otherBalance = 0;
        userlist.clear();
        _resetItemRows(); // 🔥 NEW
      });
      return;
    }

    final int? customerId = int.tryParse(customer["id"]?.toString() ?? "");
    if (customerId == null) return;

    setState(() {
      selectedItem = customerId.toString();
      customerName = customer["name"]?.toString() ?? "";
      customerCity = customer["city"]?.toString() ?? "";
    });

    debugPrint("Selected Customer => ${customer["name"]} ($customerId)");

    await getApprovalDetails(customerId);
  }
}
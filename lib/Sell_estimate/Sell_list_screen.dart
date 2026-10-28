// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/ItemProvider.dart';
//
// class SellListScreen extends StatefulWidget {
//   const SellListScreen({super.key});
//
//   @override
//   State<SellListScreen> createState() => _SellListScreenState();
// }
//
// class _SellListScreenState extends State<SellListScreen> {
//   TextEditingController searchController = TextEditingController();
//   TextEditingController fromDateController = TextEditingController();
//   TextEditingController toDateController = TextEditingController();
//   List userlist = [];
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
//   List<Map<String, dynamic>> allItems = [];
//   List<Map<String, dynamic>> items = [];
//   List cartItems = [];
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
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     category();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).loadItems();
//     });
//     getSaleDetails();
//
//   }
//
//   Future<void> category() async {
//     final response =
//     await ApiHelper().getRequest(ApiConstants.customerlist);
//
//     print("user API URL: ${ApiConstants.customerlist}");
//     print("users Raw Response: ${response.toString()}");
//
//     if (response!.statusCode == 200) {
//       final data = response.data;
//
//       setState(() {
//         customerlist = data['data'];
//       });
//     } else {
//       setState(() {
//         customerlist = [];
//       });
//     }
//   }
//
//   Future<void> getSaleDetails() async {
//
//     final response =
//     await ApiHelper().getRequest(ApiConstants.return_list);
//
//     if (response != null && response.statusCode == 200) {
//
//       final data = response.data;
//
//       // ✅ success check
//       final List categories = data['data'];
//
//       setState(() {
//
//         tableRows.clear();
//         userlist = categories;
//         allItems = List.from(categories); // 🔥 must for filter
//
//
//       });
//
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
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//
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
//             /// ✅ Main Content
//             Column(
//               children: [
//                 SizedBox(
//                   height: MediaQuery.of(context).padding.top + 30,
//                 ),
//                 /// 🔥 FILTER SECTION (NEW)
//                 filterWidget(),
//
//                 Container(
//                   margin: const EdgeInsets.only(top: 10, bottom: 0),
//                   child: Image.asset(
//                     "assets/static/divider.png",
//                     fit: BoxFit.fill,
//                     width: double.infinity,
//                     height: 25,
//                   ),
//                 ),
//
//                 Expanded(
//                   child: ListView.builder(
//                     padding: const EdgeInsets.only(left: 10,right: 10, top: 0),
//                     itemCount: userlist.length,
//                     itemBuilder: (context, index) {
//                       final item = userlist[index];
//                       return buildCard(item, index);
//                     },
//                   ),
//                 ),
//                 /// 🔥 Dynamic Bottom Section
//                 // Expanded(
//                 //   child: _buildRecentScansList(height),
//                 // ),
//                 /// Bottom Button
//                 InkWell(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const SellReturnScreen(),
//                       ),
//                     );
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
//                           Color(0xffE6C58A)
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(15),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         "+ Create Return",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//
//               ],
//             ),
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
//                       "Sell Return List",
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
//             )
//           ],
//         ),
//       ),
//       //bottomNavigationBar: _buildSaveButton(),
//
//     );
//   }
//
//
//
//
//
//   Future<void> openPdf(int id) async {
//
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.return_pdf,
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
//
//
//
//   Widget _buildSaveButton() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(20),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
//           child: Container(
//             height: 60,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.08), // glass transparency
//               borderRadius: BorderRadius.circular(20),
//               // border: Border.all(
//               //   color: Colors.white.withOpacity(0.2),
//               //   width: 1,
//               // ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.3),
//                   blurRadius: 15,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: InkWell(
//               borderRadius: BorderRadius.circular(20),
//               onTap: () async {
//                 //await savefinalizeBulkItems();
//               },
//               child: const Center(
//                 child: Text(
//                   "Save",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 1,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
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
//
//   Widget _buildTableCell(
//       TextEditingController controller,
//       String field,
//       int index,
//       ) {
//     return Container(
//       height: 50,
//       margin: const EdgeInsets.all(0),
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
//             width: 1.2,
//           ),
//           left: BorderSide(
//             color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//             width: 1.5,
//           ),
//           bottom: BorderSide(
//             color: Color(0xffC9A44A).withOpacity(0.6), // gold bottom line
//             width: 1.5,
//           ),
//         ),
//       ),
//       child: Center(
//         child: TextField(
//           controller: controller,
//           readOnly: field == "net",
//           keyboardType: TextInputType.number,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//           ),
//           onChanged: (value) {
//
//             // 🔥 Net weight auto calculate
//             if (field == "gross" || field == "other") {
//               calculateNetWeight(index);
//             }
//
//             // 🔥 HUID API call after 1 second
//             if (field == "huid") {
//
//               if (_huidTimer != null) {
//                 _huidTimer!.cancel();
//               }
//
//               _huidTimer = Timer(const Duration(seconds: 1), () {
//                 //saveBulkItems();
//               });
//             }
//
//           },
//           decoration: const InputDecoration(
//             contentPadding: EdgeInsets.symmetric(horizontal: 8),
//             border: InputBorder.none,
//           ),
//           cursorColor: Colors.white,
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
//                         // const SizedBox(height: 15),
//                         //
//                         // /// Label TextField
//                         // TextField(
//                         //   controller: labelController,
//                         //   style: const TextStyle(color: Colors.white),
//                         //   decoration: InputDecoration(
//                         //     labelText: "Enter Label",
//                         //     labelStyle: const TextStyle(color: Colors.white70),
//                         //     //filled: true,
//                         //     //fillColor: Colors.white.withOpacity(0.05),
//                         //     border: OutlineInputBorder(
//                         //       borderRadius: BorderRadius.circular(10),
//                         //     ),
//                         //   ),
//                         //
//                         //   onSubmitted: (value) {
//                         //
//                         //     if (value.trim().isEmpty) return;
//                         //
//                         //     setState(() {
//                         //
//                         //       tableRows.add({
//                         //         //"label": value.trim(),
//                         //         "gross": "10.0",
//                         //         "other": "2.5",
//                         //         "net": "7.5",
//                         //         "labourRate": "0",
//                         //         "labourAmount": "0",
//                         //         "size": "10",
//                         //         "huid": "001",
//                         //       });
//                         //
//                         //     });
//                         //
//                         //     labelController.clear();
//                         //   },
//                         // ),
//                         //
//                         // const SizedBox(height: 20),
//                         //
//                         // /// Scanner Box
//                         // const SizedBox(height: 10),
//                         //
//                         // _buildScannerSection(),
//                         //
//                         // const SizedBox(height: 20),
//                         //
//                         // /// Table/Grid
//                         // SizedBox(
//                         //   height: 220,
//                         //   child: Column(
//                         //     children: [
//                         //
//                         //       /// Header
//                         //       Container(
//                         //         decoration: BoxDecoration(
//                         //           border: Border.all(color: Colors.white24),
//                         //         ),
//                         //         child: Row(
//                         //           children: [
//                         //             _buildHeaderCell("Gross\nWeight"),
//                         //             _buildHeaderCell("Other"),
//                         //             _buildHeaderCell("Net\nWeight"),
//                         //             _buildHeaderCell("Labour\nRate"),
//                         //             _buildHeaderCell("Labour\nAmount"),
//                         //             _buildHeaderCell("Size"),
//                         //             _buildHeaderCell("HUID"),
//                         //           ],
//                         //         ),
//                         //       ),
//                         //
//                         //       /// Rows
//                         //       Expanded(
//                         //         child: SingleChildScrollView(
//                         //           child: Table(
//                         //             border: TableBorder.all(color: Colors.white24),
//                         //             children: tableRows.asMap().entries.map((entry) {
//                         //
//                         //               int index = entry.key;
//                         //               var row = entry.value;
//                         //
//                         //               return TableRow(
//                         //                 children: [
//                         //
//                         //                   /// Label
//                         //                   // Padding(
//                         //                   //   padding: const EdgeInsets.all(6),
//                         //                   //   child: Text(
//                         //                   //     row["label"]!,
//                         //                   //     style: const TextStyle(color: Colors.white),
//                         //                   //     textAlign: TextAlign.center,
//                         //                   //   ),
//                         //                   // ),
//                         //
//                         //                   _buildTableCell1(row["gross"]!, (val){ row["gross"] = val; }),
//                         //                   _buildTableCell1(row["other"]!, (val){ row["other"] = val; }),
//                         //                   _buildTableCell1(row["net"]!, (val){ row["net"] = val; }),
//                         //                   _buildTableCell1(row["labourRate"]!, (val){ row["labourRate"] = val; }),
//                         //                   _buildTableCell1(row["labourAmount"]!, (val){ row["labourAmount"] = val; }),
//                         //                   _buildTableCell1(row["size"]!, (val){ row["size"] = val; }),
//                         //                   _buildTableCell1(row["huid"]!, (val){ row["huid"] = val; }),
//                         //
//                         //                 ],
//                         //               );
//                         //
//                         //
//                         //             }).toList(),
//                         //           ),
//                         //         ),
//                         //       ),
//                         //
//                         //     ],
//                         //   ),
//                         // ),
//                         //
//                         // const SizedBox(height: 15),
//                         //
//                         // /// Submit Button
//                         // Container(
//                         //   width: double.infinity,
//                         //   decoration: BoxDecoration(
//                         //     gradient: const LinearGradient(
//                         //       colors: [
//                         //         Color(0xFF00C853),
//                         //         Color(0xFF64DD17),
//                         //       ],
//                         //     ),
//                         //     borderRadius: BorderRadius.circular(10),
//                         //   ),
//                         //   child: TextButton(
//                         //     onPressed: (){
//                         //       Navigator.pop(context, tableRows); // 🔥 return data
//                         //       print(tableRows);
//                         //     },
//                         //     child: const Text(
//                         //       "Submit",
//                         //       style: TextStyle(
//                         //         color: Colors.white,
//                         //         fontWeight: FontWeight.bold,
//                         //       ),
//                         //     ),
//                         //   ),
//                         // ),
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
//                               /// Scanner
//                               if (showScanner) ...[
//
//
//                                 //_buildScannerSection(),
//
//                               ],
//
//                               const SizedBox(height: 20),
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
//           )
//         ],
//       ),
//       child: Column(
//         children: [
//
//           /// 🔍 SEARCH FIELD
//           TextField(
//             controller: searchController,
//             style: const TextStyle(color: Colors.black),
//             onChanged: (value) {
//               searchUser(value); // 🔥 LIVE SEARCH
//             },
//             decoration: InputDecoration(
//               hintText: "Search Customer",
//               hintStyle: TextStyle(color: Colors.grey.shade600),
//               prefixIcon: const Icon(Icons.search, color: Colors.black54),
//               filled: true,
//               fillColor: Colors.white,
//               contentPadding: const EdgeInsets.symmetric(vertical: 0),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide(color: Colors.grey.shade300),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide(color: Colors.grey.shade300),
//               ),
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
//                         suffixIcon: const Icon(Icons.calendar_today, size: 18),
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide(color: Colors.black)
//                         ),
//
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: Colors.grey.shade300),
//                         ),
//
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: Colors.blue),
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
//                         suffixIcon: const Icon(Icons.calendar_today, size: 18),
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: Colors.grey.shade300),
//                         ),
//
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide(color: Colors.blue),
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
//                     //applyLocalFilter();
//                     print("Apply Filter");
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xffE6C58A), Color(0xffC8A96A)],
//                       ),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Center(
//                       child: Text(
//                         "Show",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
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
//                     searchController.clear();
//                     fromDateController.clear();
//                     toDateController.clear();
//                     setState(() {
//                       //userlist = List.from(allItems); // 🔥 reset list
//                     });
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade200,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.grey.shade300),
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
//   Widget buildCard(Map<String, dynamic> item, int index) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Color(0xffFAF7F2).withOpacity(0.9),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//
//           /// 🔝 TOP ROW
//           Row(
//             children: [
//               statusChip(item["metal"].toString()),
//               const Spacer(),
//               /// ⚙️ ACTIONS
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//
//                   premiumIconBtn(Icons.visibility, Colors.blue, onTap: () {
//                     getApprovalDetails(item["id"]); // 🔥 id pass karo
//                     print("View Item");
//                   }),
//
//
//                   const SizedBox(width: 8),
//
//                   pdfBtn(() {
//                     //openPdf(item["id"]);
//                     int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
//
//
//                     openPdf(id);
//
//                   }),
//
//                   const SizedBox(width: 8),
//
//                   // premiumIconBtn(Icons.delete, Colors.red, onTap: () {
//                   //   setState(() {
//                   //     items.removeAt(index);
//                   //   });
//                   // }),
//                 ],
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 8),
//
//           /// 🧾 TITLE
//           Row(
//             children: [
//               Text(
//                 item["voucher_no"] ?? "",
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color: Colors.black, // ✅ FIX
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 item["customer_name"]?.toString() ?? "",
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color: Colors.black, // ✅ FIX
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           /// 🔥 ERP GRID (MAIN FIX)
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               border: Border.all(color: Colors.grey.shade200,width: 1.5),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Column(
//               children: [
//
//                 /// Row 1
//                 _erpRow("Date", item["return_date"].toString(),
//                     "R_total", item["return_total"]?.toString() ?? "-"),
//
//                 Divider(height: 1, color: Colors.grey.shade200),
//
//
//                 /// Row 2
//                 _erpRow(
//                   "Type",
//                   item["source_type"]?.toString() ?? "-",
//                       "",
//                   "",
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 10),
//
//           /// Divider
//         //  Divider(color: Colors.grey.shade300, height: 1),
//
//           const SizedBox(height: 6),
//
//
//         ],
//       ),
//     );
//
//
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
//   void searchUser(String value) {
//     if (value.isEmpty) {
//       setState(() {
//         userlist = allItems;
//       });
//       return;
//     }
//
//     List filteredList = allItems.where((user) {
//
//       final name = user["voucher_no"]?.toString().toLowerCase() ?? "";
//       final customer = user["customer_name"]?.toString().toLowerCase() ?? "";
//       final source = user["source_type"]?.toString().toLowerCase() ?? "";
//
//       return name.contains(value.toLowerCase()) ||
//           customer.contains(value.toLowerCase()) ||
//           source.contains(value.toLowerCase());
//
//     }).toList();
//
//     setState(() {
//       userlist = filteredList;
//     });
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
//       ApiConstants.returns_vouchar,
//       id,
//     );
//
//     Navigator.pop(context);
//
//     if (response != null && response.statusCode == 200) {
//
//       /// ✅ DIRECT JSON (NO utf8.decode)
//       final data = response.data;
//
//       final item = data["data"] is List
//           ? data["data"][0]
//           : data["data"];
//
//       showApprovalDialog(item);
//
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to load details")),
//       );
//     }
//   }
//
//
//   void showApprovalDialog(Map<String, dynamic> item) {
//     String val(dynamic v) => v == null ? "-" : v.toString();
//
//     var items = item["items"] ?? [];
//     var data = item["data"] ?? [];
//     showDialog(
//       context: context,
//       builder: (context) {
//         return Dialog(
//           backgroundColor: const Color(0xffFAF7F2),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           insetPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 24,
//           ), // 🔥 FIX
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.92,
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// 🔝 HEADER
//                   Row(
//                     children: [
//                       const Text(
//                         "Return Details",
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const Spacer(),
//
//                       pdfBtn(() {
//                         openPdf(item["id"]);
//                       }),
//
//                       const SizedBox(width: 8),
//
//                       InkWell(
//                         onTap: () => Navigator.pop(context),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.black,
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: const Text(
//                             "Back",
//                             style: TextStyle(color: Colors.white),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 16),
//
//                   Container(
//                     padding: const EdgeInsets.symmetric(vertical: 6),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       border: Border.all(
//                         color: Colors.grey.shade200,
//                         width: 1.5,
//                       ),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Column(
//                       children: [
//                         /// Row 1
//                         _erpRow(
//                           "Customer",
//                           val(item["customer"]?["name"]),
//                           "Vouchar",
//                           val(item["return_voucher_no"]),
//                         ),
//
//                         Divider(height: 1.5, color: Colors.grey.shade200),
//
//                         /// Row 2
//                         _erpRow(
//                           "Date",
//                           (val(item["return_date"])
//                           ),
//                           "Remarks",
//                           val(item["remarks"]), // ✅ BEST),
//                         ),
//
//                         Divider(height: 1.0, color: Colors.grey.shade200),
//
//                         /// Row 3
//                         _erpRow(
//                           "Amount",
//                           val(item["return_total"]),
//                           "",
//                           val(item[""]),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   /// 🔹 TOP INFO (3x3 GRID)
//                   const SizedBox(height: 12),
//
//                   Container(
//                     height: 110,
//                     child: ListView.builder(
//                       scrollDirection: Axis.vertical,
//                       itemCount: items.length,
//                       itemBuilder: (context, index) {
//                         final data = items[index];
//
//                         final saleItem = data['sale_item'] ?? {};
//                         final itemset = saleItem['itemset'] ?? {};
//                         final itemData = itemset['item'] ?? {};
//
//                         return Container(
//                           width: 220,
//                           margin: const EdgeInsets.only(right: 8),
//                           padding: const EdgeInsets.symmetric(
//                             vertical: 6,
//                             horizontal: 8,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             border: Border.all(
//                               color: Colors.grey.shade200,
//                               width: 1.5,
//                             ),
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: Column(
//                             children: [
//                               /// Row 1
//                               /// Row 1
//                               _erpRow(
//                                 "Item",
//                                 val(itemData['item_name']),
//                                 "Code",
//                                 val(itemData['item_code']),
//                               ),
//
//
//
//                               Divider(height: 1.0, color: Colors.grey.shade200),
//
//                               /// Row 2
//                               _erpRow(
//                                 "Gross Wt",
//                                 val(itemset['gross_weight']),
//                                 "Less Wt",
//                                 val(itemset['other']),
//                               ),
//
//                               Divider(height: 1.0, color: Colors.grey.shade200),
//
//                               /// Row 2
//                               _erpRow(
//                                 "Net Wt",
//                                 val(itemset['net_weight']),
//                                 "Other",
//                                 val(itemset['sale_other']),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//
//                   const SizedBox(height: 12),
//                   InkWell(
//                     onTap: () => Navigator.pop(context),
//                     child: Center(
//                       child: Container(
//                         width: 100,
//                         height: 40,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 6,
//                         ),
//                         decoration: BoxDecoration(
//                           gradient: const LinearGradient(
//                             colors: [Color(0xffC8A96A), Color(0xffE6C58A)],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           ),
//                           borderRadius: BorderRadius.circular(6),
//                         ),
//                         child: Center(
//                           child: const Text(
//                             "Close",
//                             style: TextStyle(
//                               color: Colors.black,
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
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
//
//
//
//
//
// }
//
//
//

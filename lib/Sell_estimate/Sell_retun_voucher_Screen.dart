// import 'dart:async';
// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
// import 'package:provider/provider.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/ItemProvider.dart';
//
// class SellRetunVoucherScreen extends StatefulWidget {
//   String id;
//   SellRetunVoucherScreen(this.id,{super.key});
//
//   @override
//   State<SellRetunVoucherScreen> createState() => _SellRetunVoucherScreenState();
// }
//
// class _SellRetunVoucherScreenState extends State<SellRetunVoucherScreen> {
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
//   List cartItems = [];
//   String customerName = "";
//   String saleDate = "";
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
//     print(widget.id.toString());
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
//     // final response =
//     // await ApiHelper().getRequest(ApiConstants.return_sale);
//
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.return_sale,
//       int.parse(widget.id),
//       //responseType: ResponseType.bytes,
//     );
//     if (response != null && response.statusCode == 200) {
//
//       final data = response.data["data"];
//       final List saleItems = data["sale_items"];
//
//       setState(() {
//
//         /// 🔥 Customer & Date
//         customerName = data["customer"]?["name"] ?? "";
//         saleDate = data["sale_date"] ?? "";
//         tableRows.clear();
//
//         for (var row in saleItems) {
//
//           final itemSet = row["item_set"];
//           final item = itemSet["item"];
//
//           tableRows.add({
//
//             "id": row["id"], // 🔥 ADD THIS
//             "item": TextEditingController(
//                 text: item["item_name"] ?? ""),
//
//             "gross": TextEditingController(
//                 text: itemSet["gross_weight"] ?? ""),
//
//             "net": TextEditingController(
//                 text: itemSet["net_weight"] ?? ""),
//
//             "total": TextEditingController(
//                 text: row["total_amount"] ?? ""),
//
//             "checked": false, // 🔥 checkbox state
//
//           });
//
//         }
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
//
//   @override
//   Widget build(BuildContext context) {
//
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//
//     return Scaffold(
//       body: SafeArea(
//         child: Stack(
//           children: [
//
//             /// ✅ Background Image
//             Positioned.fill(
//               child: Image.asset(
//                 "assets/static/img_1.png",
//                 fit: BoxFit.cover,
//               ),
//             ),
//
//             /// ✅ Dark Overlay
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(0.25),
//               ),
//             ),
//
//             /// ✅ Main Content
//             Column(
//               children: [
//                 topHeaderSectionGlass(width),
//                 SizedBox(height: height * 0.02),
//
//                 /// 🔥 Dynamic Bottom Section
//                 Expanded(
//                   child: _buildRecentScansList(height),
//                 ),
//
//
//               ],
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: _buildSaveButton(),
//
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
//
//
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   bool isProcessing = false;
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
//           onDetect: (barcodeCapture) async {
//
//             if (isProcessing) return;
//
//             final List<Barcode> barcodes = barcodeCapture.barcodes;
//
//             for (final barcode in barcodes) {
//
//               final String? code = barcode.rawValue;
//
//               if (code != null) {
//
//                 isProcessing = true;
//
//                 print("Scanned Code: $code");
//
//                 //await scanApiCall(code);
//
//                 Future.delayed(const Duration(seconds: 2), () {
//                   isProcessing = false;
//                 });
//
//               }
//
//             }
//
//           },
//         ),
//       ),
//     );
//   }
//
//   /// ✅ Recent Scan List
//   Widget _buildRecentScansList(double height) {
//     return ClipRRect(
//       borderRadius: const BorderRadius.only(
//         topLeft: Radius.circular(30),
//         topRight: Radius.circular(30),
//       ),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
//         child: Container(
//           padding: const EdgeInsets.symmetric(
//               horizontal: 10, vertical: 25),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.06), // glass transparency
//             borderRadius: const BorderRadius.only(
//               topLeft: Radius.circular(20),
//               topRight: Radius.circular(20),
//             ),
//             // border: Border.all(
//             //   color: Colors.white.withOpacity(0.15),
//             //   width: 1.5,
//             // ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.4),
//                 blurRadius: 25,
//                 offset: const Offset(0, -10),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//
//               Text(
//                 "Sales Return Voucher",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: height * 0.015,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//
//               SizedBox(height: height * 0.01),
//               Text(
//                 "Customer : $customerName",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: height * 0.015,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//
//               SizedBox(height: height * 0.01),
//
//               Text(
//                 "Date : $saleDate",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: height * 0.015,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//
//               SizedBox(height: height * 0.02),
//               // /// Carat & Purity Row
//               // Row(
//               //   children: [
//               //     Expanded(
//               //       child: _buildTextField("Carat"),
//               //     ),
//               //     const SizedBox(width: 12),
//               //     Expanded(
//               //       child: _buildTextField("Purity"),
//               //     ),
//               //   ],
//               // ),
//               //
//               // const SizedBox(height: 25),
//
//               Expanded(
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal, // 🔥 horizontal scroll
//                   child: SizedBox(
//                     width: 700, // 🔥 total table width
//                     child: Column(
//                       children: [
//
//                         /// Header
//                         Container(
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.white24),
//                           ),
//                           child: Row(
//                             children: [
//                               _buildHeaderCell("Item"),
//                               _buildHeaderCell("Gross"),
//                               _buildHeaderCell("Net"),
//                               _buildHeaderCell("Total"),
//                               _buildHeaderCell("Action"),
//                             ],
//                           ),
//                         ),
//
//                         /// Table Rows
//                         Expanded(
//                           child: SingleChildScrollView(
//                             child: Table(
//                               border: TableBorder.all(color: Colors.white24),
//                               children: [
//                                 ...tableRows.asMap().entries.map((entry) {
//
//                                   int index = entry.key;
//                                   var row = entry.value;
//
//                                   return TableRow(
//                                     children: [
//
//                                       _buildTableCell(tableRows[index]["item"]!, "item", index),
//
//                                       _buildTableCell(tableRows[index]["gross"]!, "gross", index),
//
//                                       _buildTableCell(tableRows[index]["net"]!, "net", index),
//
//                                       _buildTableCell(tableRows[index]["total"]!, "total", index),
//
//                                       /// 🔥 Checkbox Action
//                                       Container(
//                                         height: 50,
//                                         decoration: BoxDecoration(
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               Colors.white.withOpacity(0.10),
//                                               Colors.white.withOpacity(0.05),
//                                             ],
//                                             begin: Alignment.topLeft,
//                                             end: Alignment.bottomRight,
//                                           ),
//                                           border: Border(
//                                             right: BorderSide(
//                                               color: Color(0xffC9A44A).withOpacity(0.6),
//                                               width: 1.5,
//                                             ),
//                                             bottom: BorderSide(
//                                               color: Color(0xffC9A44A).withOpacity(0.6),
//                                               width: 1.5,
//                                             ),
//                                           ),
//                                         ),
//                                         alignment: Alignment.center,
//                                         child: Checkbox(
//                                           value: tableRows[index]["checked"] ?? false,
//                                           activeColor: Colors.green,
//                                           onChanged: (value) {
//
//                                             setState(() {
//                                               tableRows[index]["checked"] = value;
//                                             });
//
//                                           },
//                                         ),
//                                       ),
//
//                                     ],
//                                   );
//
//
//
//                                 }).toList(),
//                               ],
//                             ),
//                           ),
//                         )
//
//                       ],
//                     ),
//                   ),
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
//                 await savefinalizeBulkItems();
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
//   Future<void> savefinalizeBulkItems() async {
//
//     List<int> selectedIds = tableRows
//         .where((row) => row["checked"] == true)
//         .map<int>((row) => row["id"])
//         .toList();
//
//     Map<String, dynamic> body = {
//       "sale_id": int.parse(widget.id),
//       //"ids": selectedIds
//     };
//
//     print("📤 REQUEST BODY: $body");
//
//     final response = await ApiHelper().postRequest1(
//       ApiConstants.return_Store,
//       body,
//     );
//
//     if (response != null && response.statusCode == 200) {
//
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => SellListScreen(),
//         ),
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Store Sucesfully")),
//       );
//
//     } else {
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to Save Data")),
//       );
//
//     }
//   }
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
// }
//
//
//

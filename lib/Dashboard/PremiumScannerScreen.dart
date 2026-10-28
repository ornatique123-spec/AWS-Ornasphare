// import 'dart:ui';
//
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
//
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Extra/AppColors.dart';
//
// class PremiumScannerScreen extends StatefulWidget {
//   const PremiumScannerScreen({super.key});
//
//   @override
//   State<PremiumScannerScreen> createState() => _PremiumScannerScreenState();
// }
//
// class _PremiumScannerScreenState extends State<PremiumScannerScreen> {
//
//   String? selectedItem;
//   List cartItems = [];
//   List<String> itemList = [
//     "Gold Ring",
//     "Gold Chain",
//     "Gold Pendant",
//     "Gold Bracelet"
//   ];
//   List customerlist = [];
//   String? selectedUser;
//   String? selectedCompanyId;
//   @override
//   void initState() {
//     super.initState();
//     category();
//   }
//
//   Future<void> category() async {
//
//     final response =
//     await ApiHelper().getRequest(ApiConstants.customerlist);
//
//     print("user API URL: ${ApiConstants.customerlist}");
//     print("users Raw Response: ${response.toString()}");
//
//     if (response!.statusCode == 200) {
//
//       final data = response.data;
//
//       setState(() {
//         customerlist = data['data'];
//       });
//
//     } else {
//
//       setState(() {
//         customerlist = [];
//       });
//
//     }
//   }
//
//   Future<void> scanApiCall(String code) async {
//
//     Map<String, dynamic> body = {
//       "qr_code": code,
//       "company_id":selectedCompanyId
//     };
//
//     print("📤 API URL: ${ApiConstants.sales_add_to_cart}");
//     print("📤 Request Body: $body");
//
//     final response = await ApiHelper().postRequest(
//         ApiConstants.sales_add_to_cart,
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
//           setState(() {
//             getCartItems();
//           });
//
//         }else{
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(response.data['message'].toString()),
//               backgroundColor: Colors.green,
//               duration: const Duration(seconds: 2),
//             ),
//           );
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
//
//     final response =
//     await ApiHelper().getRequest(ApiConstants.sales_cart_items);
//
//     print("Cart API URL: https://ornasphere.com/api/sales/cart-items");
//     print("Cart Raw Response: ${response.toString()}");
//
//     if (response != null && response.statusCode == 200) {
//
//       final resData = response.data["data"];
//
//       setState(() {
//         cartItems = resData;
//       });
//
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
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//
//     final scannerSize = screenWidth * 0.65;
//     final bottomHeight = screenHeight * 0.42;
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
//             /// ✅ Optional Dark Overlay
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(0.25),
//               ),
//             ),
//
//             /// ✅ Main Content
//             Column(
//               children: [
//
//                 topHeaderSectionGlass(),
//
//                 const SizedBox(height: 10),
//
//                 /// 🔽 Dropdown
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.white24),
//                       color: Colors.white.withOpacity(0.05),
//                     ),
//                     child: DropdownButtonHideUnderline(
//                       child: DropdownButton<String>(
//                         isExpanded: true,
//                         dropdownColor: Colors.black,
//                         hint: const Text(
//                           "Select Customer",
//                           style: TextStyle(color: Colors.white70),
//                         ),
//                         value: selectedUser,
//                         items: customerlist.map<DropdownMenuItem<String>>((user) {
//                           return DropdownMenuItem<String>(
//                             value: user["id"].toString(),
//                             child: Text(
//                               user["name"] ?? "",
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                           );
//                         }).toList(),
//                         onChanged: (val) {
//                           setState(() {
//                             selectedUser = val;
//
//                             final selectedData = customerlist.firstWhere(
//                                   (user) => user["id"].toString() == val,
//                             );
//
//                             selectedCompanyId = selectedData["company_id"].toString();
//
//                             print("Selected Company ID: $selectedCompanyId");
//                           });
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//
//
//                 const SizedBox(height: 10),
//
//                 _buildScannerSection(),
//
//
//
//                 const SizedBox(height: 20),
//
//                 Expanded(
//                   child: _buildRecentScansList(),
//                 ),
//
//               ],
//             )
//
//           ],
//         ),
//       ),
//       bottomNavigationBar: _buildSaveButton(),
//     );
//   }
//
//
//   // 1. App Header
//   Widget topHeaderSectionGlass() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(20),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.05), // Glass transparency
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
//               /// Top Row (Avatar + Notification)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       CircleAvatar(
//                         radius: 25,
//                         backgroundImage: AssetImage("assets/static/img.png"),
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         "OrnaSphere",
//                         style: TextStyle(
//                             color: AppColors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600),
//                       ),
//                     ],
//                   ),
//                   Row(
//                     children: const [
//                       Icon(Icons.notifications_none,
//                           color: AppColors.white, size: 26),
//                       SizedBox(width: 15),
//                       CircleAvatar(
//                         radius: 16,
//                         backgroundImage:
//                         NetworkImage("https://i.pravatar.cc/150?img=3"),
//                       )
//                     ],
//                   )
//                 ],
//               ),
//               const SizedBox(height: 1),
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // 2. Scanner Section with Custom Frame
//   bool isProcessing = false;
//
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
//                 await scanApiCall(code);
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
//
//
//
//
//
//
//
//   // 3. Recent Scans Bottom Sheet Look List
//   Widget _buildRecentScansList() {
//     double height = MediaQuery.of(context).size.height * 0.5;
//
//     if (MediaQuery.of(context).size.width > 600) {
//       height = 350;
//     }
//     return ClipRRect(
//       borderRadius: const BorderRadius.only(
//         topLeft: Radius.circular(30),
//         topRight: Radius.circular(30),
//       ),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
//         child: Container(
//           height: height,
//           padding: EdgeInsets.symmetric(
//             horizontal: MediaQuery.of(context).size.width * 0.06,
//             vertical: 15,
//           ),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.06), // glass transparency
//             borderRadius: const BorderRadius.only(
//               topLeft: Radius.circular(40),
//               topRight: Radius.circular(40),
//             ),
//             border: Border.all(
//               color: Colors.white.withOpacity(0.15),
//               width: 1,
//             ),
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
//               const Text(
//                 "Recent Scans",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Expanded(
//                 child: ListView.builder(
//
//                   itemCount: cartItems.length,
//                   itemBuilder: (context, index) {
//
//                     final item = cartItems[index];
//                     final itemset = item["itemset"];
//
//                     return _buildItemTable(
//                       "Item ${itemset["item_id"]}",
//                       itemset["barcode"] ?? "",
//                       "₹ ---",
//                       //Colors.blue,
//                       "${itemset["gross_weight"]}g",
//                       "${itemset["other"]}g",
//                       "${itemset["net_weight"]}g",
//                       itemset["size"] ?? "",
//                     );
//
//                   },
//                 ),
//               )
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   // Widget _buildItemCard(
//   //     String title,
//   //     String id,
//   //     String price,
//   //     Color iconColor,
//   //     String gross,
//   //     String less,
//   //     String net,
//   //     String purity,
//   //     ) {
//   //
//   //   double screenWidth = MediaQuery.of(context).size.width;
//   //
//   //   double imageSize = screenWidth * 0.18;
//   //
//   //   if (screenWidth > 600) {
//   //     imageSize = 90;
//   //   }
//   //
//   //   return Container(
//   //     margin: const EdgeInsets.only(bottom: 5),
//   //     padding: EdgeInsets.all(screenWidth * 0.025),
//   //     decoration: BoxDecoration(
//   //       color: Colors.white.withOpacity(0.05),
//   //       borderRadius: BorderRadius.circular(18),
//   //       border: Border.all(color: Colors.white10),
//   //     ),
//   //     child: Row(
//   //       crossAxisAlignment: CrossAxisAlignment.start,
//   //       children: [
//   //
//   //         /// Product Image
//   //         ClipRRect(
//   //           borderRadius: BorderRadius.circular(12),
//   //           child: Image.network(
//   //             "https://images.unsplash.com/photo-1605100804763-247f67b3557e",
//   //             height: imageSize,
//   //             width: imageSize,
//   //             fit: BoxFit.cover,
//   //           ),
//   //         ),
//   //
//   //         const SizedBox(width: 12),
//   //
//   //         /// Main Content
//   //         Expanded(
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //
//   //               /// Title + Action Buttons
//   //               Row(
//   //                 crossAxisAlignment: CrossAxisAlignment.start,
//   //                 children: [
//   //
//   //                   /// Title
//   //                   Expanded(
//   //                     child: Text(
//   //                       title,
//   //                       maxLines: 2,
//   //                       overflow: TextOverflow.ellipsis,
//   //                       style: const TextStyle(
//   //                         color: Colors.white,
//   //                         fontWeight: FontWeight.bold,
//   //                         fontSize: 15,
//   //                       ),
//   //                     ),
//   //                   ),
//   //
//   //                   const SizedBox(width: 6),
//   //
//   //                   /// Buttons
//   //                   Row(
//   //                     mainAxisSize: MainAxisSize.min,
//   //                     children: [
//   //                       _actionButton(Icons.edit, Colors.amber),
//   //                       const SizedBox(width: 6),
//   //                       _actionButton(Icons.delete, Colors.red),
//   //                     ],
//   //                   ),
//   //                 ],
//   //               ),
//   //
//   //               const SizedBox(height: 2),
//   //
//   //               /// ID
//   //               Text(
//   //                 "ID: $id",
//   //                 style: const TextStyle(
//   //                   color: Colors.white38,
//   //                   fontSize: 12,
//   //                 ),
//   //               ),
//   //
//   //               const SizedBox(height: 8),
//   //
//   //               /// Gross / Less
//   //               Row(
//   //                 children: [
//   //                   Expanded(child: _buildSmallText("Gross: $gross")),
//   //                   const SizedBox(width: 6),
//   //                   Container(
//   //                     height: 14,
//   //                     width: 1,
//   //                     color: Colors.white24,
//   //                   ),
//   //                   const SizedBox(width: 6),
//   //                   Expanded(child: _buildSmallText("Less: $less")),
//   //                 ],
//   //               ),
//   //
//   //               const SizedBox(height: 4),
//   //
//   //               /// Net / Purity
//   //               Row(
//   //                 children: [
//   //                   Expanded(child: _buildSmallText("Net: $net")),
//   //                   const SizedBox(width: 6),
//   //                   Container(
//   //                     height: 14,
//   //                     width: 1,
//   //                     color: Colors.white24,
//   //                   ),
//   //                   const SizedBox(width: 6),
//   //                   Expanded(child: _buildSmallText("Purity: $purity")),
//   //                 ],
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//
//   Widget _buildItemTable(
//       String title,
//       String id,
//       String price,
//       String gross,
//       String less,
//       String net,
//       String purity,
//       ) {
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Table(
//         border: TableBorder.all(color: Colors.white24),
//         columnWidths: const {
//           0: FixedColumnWidth(100),
//           1: FixedColumnWidth(80),
//           2: FixedColumnWidth(80),
//           3: FixedColumnWidth(80),
//           4: FixedColumnWidth(80),
//           5: FixedColumnWidth(60),
//         },
//         children: [
//
//           /// HEADER
//           TableRow(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Color(0xff2B3050), // dark brown
//                   Color(0xff1b1411),
//                   Color(0xff3A3F63),// deep dark
//                 ],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//               border: Border(
//                 right: BorderSide(
//                   color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//                   width: 1.2,
//                 ),
//                 left: BorderSide(
//                   color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//                   width: 1.2,
//                 ),
//                 top: BorderSide(
//                   color: Color(0xffC9A44A).withOpacity(0.6), // gold divider
//                   width: 1.2,
//                 ),
//                 bottom: BorderSide(
//                   color: Color(0xffC9A44A).withOpacity(0.6), // gold bottom line
//                   width: 1.5,
//                 ),
//               ),
//             ),
//             children: [
//               SizedBox(
//                 height: 40,
//                 child: Center(
//                   child: Text(
//                     "Item",
//                     style: TextStyle(
//                       color: Color(0xffE6C36A),
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(
//                 height: 40,
//                 child: Padding(
//                   padding: EdgeInsets.all(8),
//                   child: Center(
//                     child: Text("Gross",
//                         style: TextStyle( color: Color(0xffE6C36A),fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//               ),
//               SizedBox(
//                 height: 40,
//                 child: Padding(
//                   padding: EdgeInsets.all(8),
//                   child: Text("Less",
//                       style: TextStyle( color: Color(0xffE6C36A),fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               SizedBox(
//                 height: 40,
//                 child: Padding(
//                   padding: EdgeInsets.all(8),
//                   child: Text("Net",
//                       style: TextStyle( color: Color(0xffE6C36A),fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               SizedBox(
//                 height: 40,
//                 child: Padding(
//                   padding: EdgeInsets.all(8),
//                   child: Text("Size",
//                       style: TextStyle( color: Color(0xffE6C36A),fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               SizedBox(
//                 height: 40,
//                 child: Padding(
//                   padding: EdgeInsets.all(8),
//                   child: Text("Action",
//                       style: TextStyle( color: Color(0xffE6C36A),fontWeight: FontWeight.bold)),
//                 ),
//               ),
//             ],
//           ),
//
//           /// DATA ROW
//           TableRow(
//             children: [
//
//               _tableValue(title),
//               _tableValue(gross),
//               _tableValue(less),
//               _tableValue(net),
//               _tableValue(purity),
//
//               Padding(
//                 padding: const EdgeInsets.all(0),
//                 child: IconButton(
//                   icon: const Icon(Icons.delete, color: Colors.red, size: 20),
//                   onPressed: () {
//                     //deleteItemApi(id);
//                   },
//                 ),
//               ),
//
//             ],
//           ),
//
//         ],
//       ),
//     );
//   }
//
//
//
//
//   Widget _tableValue(String value) {
//     return Padding(
//       padding: const EdgeInsets.all(8),
//       child: Text(
//         value,
//         textAlign: TextAlign.center,
//         style: const TextStyle(color: Colors.white),
//       ),
//     );
//   }
//
//
//
//   Widget _buildSmallText(String text) {
//     return Text(
//       text,
//       style: const TextStyle(
//         color: Colors.white70,
//         fontSize: 12,
//       ),
//     );
//   }
//
//   Widget _actionButton(IconData icon, Color color) {
//     return InkWell(
//       onTap: () {},
//       borderRadius: BorderRadius.circular(30),
//       child: Container(
//         height: 34,
//         width: 34,
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.15),
//           shape: BoxShape.circle,
//         ),
//         child: Icon(
//           icon,
//           color: color,
//           size: 18,
//         ),
//       ),
//     );
//   }
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
//   Future<void> savefinalizeBulkItems() async {
//     if (selectedCompanyId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please select Customer")),
//       );
//       return;
//     }
//
//     Map<String, dynamic> body = {
//       "company_id": int.parse(selectedCompanyId!),
//       "customer_id": "22",
//     };
//
//     print("📤 REQUEST BODY: $body");
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.sales_confirm_sale,
//       body,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Saved successfully")),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to Save Data")),
//       );
//     }
//   }
//
//
//
// }
//
// // સ્કેનરના ચાર ખૂણા દોરવા માટે
// class ScannerFramePainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.blueAccent
//       ..strokeWidth = 4
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//
//     double len = 30; // ખૂણાની લંબાઈ
//
//     // Top Left
//     canvas.drawPath(Path()..moveTo(0, len)..lineTo(0, 0)..lineTo(len, 0), paint);
//     // Top Right
//     canvas.drawPath(Path()..moveTo(size.width - len, 0)..lineTo(size.width, 0)..lineTo(size.width, len), paint);
//     // Bottom Left
//     canvas.drawPath(Path()..moveTo(0, size.height - len)..lineTo(0, size.height)..lineTo(len, size.height), paint);
//     // Bottom Right
//     canvas.drawPath(Path()..moveTo(size.width - len, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - len), paint);
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
//
// // સ્કેનિંગ લાઇન એનિમેશન
// class ScanningAnimationLine extends StatefulWidget {
//   const ScanningAnimationLine({super.key});
//
//   @override
//   State<ScanningAnimationLine> createState() => _ScanningAnimationLineState();
// }
//
// class _ScanningAnimationLineState extends State<ScanningAnimationLine> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, child) {
//         return Positioned(
//           top: 40 + (_controller.value * 140),
//           child: Container(
//             width: 200,
//             height: 2,
//             decoration: BoxDecoration(
//               boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
//               gradient: const LinearGradient(colors: [Colors.transparent, Colors.blueAccent, Colors.transparent]),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
// }
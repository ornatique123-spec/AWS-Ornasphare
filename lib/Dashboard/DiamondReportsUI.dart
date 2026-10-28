// import 'dart:ui';
//
// import 'package:flutter/material.dart';
// import 'package:pecifician_sysytem/Dashboard/InventoryScreen.dart';
//
// import '../Extra/AppColors.dart';
// import 'HomeScreen.dart';
//
// class DiamondReportsFullUI extends StatefulWidget {
//   const DiamondReportsFullUI({super.key});
//
//   @override
//   State<DiamondReportsFullUI> createState() => _DiamondReportsFullUIState();
// }
//
// class _DiamondReportsFullUIState extends State<DiamondReportsFullUI> {
//   int selectedIndex = 1;
//   int _selectedIndex = 0;
//   int selectedTab = 0;
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF020617),
//       bottomNavigationBar: customBottomNav(),
//       body: Stack(
//         children: [
//           /// ✅ Background Image
//           Positioned.fill(
//             child: Image.asset(
//               "assets/static/img_1.png",
//               fit: BoxFit.cover,
//             ),
//           ),
//
//           /// ✅ Dark Overlay
//           Positioned.fill(
//             child: Container(
//               color: Colors.black.withOpacity(0.25),
//             ),
//           ),
//
//           /// ✅ Main Content
//           Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.symmetric(horizontal: 0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const SizedBox(height: 0),
//                       topHeaderSection(),
//                       const SizedBox(height: 25),
//                       _buildTopTabs(),
//                       const SizedBox(height: 20),
//                       // Padding(
//                       //   padding: const EdgeInsets.only(left: 20.0,right: 20),
//                       //   child: _buildDateRangePicker(),
//                       // ),
//                       // const SizedBox(height: 20),
//                       Padding(
//                         padding: const EdgeInsets.only(left: 20.0,right: 20),
//                         child: _buildMainSalesCard(),
//                       ),
//                       const SizedBox(height: 15),
//                       Padding(
//                         padding: const EdgeInsets.only(left: 20.0,right: 20),
//                         child: _buildInventoryValueCard(),
//                       ),
//                       const SizedBox(height: 15),
//                       Padding(
//                         padding: const EdgeInsets.only(left: 20.0,right: 20),
//                         child: _buildBottomGrid(),
//                       ),
//                       const SizedBox(height: 20),
//                     ],
//                   ),
//                 ),
//               ),
//               // _buildBottomNavBar(),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // 1️⃣ App Bar
//   Widget _buildAppBar() {
//     return const Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Row(
//           children: [
//             CircleAvatar(
//               radius: 18,
//               backgroundColor: Colors.blueAccent,
//               child: Icon(Icons.diamond, color: Colors.white, size: 20),
//             ),
//             SizedBox(width: 12),
//             Text(
//               "Reports",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//         Icon(Icons.settings_outlined, color: Colors.white70, size: 28),
//       ],
//     );
//   }
//
//   // 2️⃣ Top Navigation Tabs
//
//   Widget _buildTopTabs() {
//     List<String> tabs = ["Daily", "Monthly", "Yearly", "Partly", "New"];
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 10),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(15),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//           child: Container(
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05), // Glass background
//               borderRadius: BorderRadius.circular(15),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.1),
//               ),
//             ),
//             child: Row(
//               children: List.generate(tabs.length, (index) {
//                 bool isSelected = selectedTab == index;
//
//                 return Expanded(
//                   child: GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         selectedTab = index;
//                       });
//                     },
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 250),
//                       padding: const EdgeInsets.symmetric(vertical: 10),
//                       decoration: BoxDecoration(
//                         color: isSelected
//                             ? Colors.white.withOpacity(0.15)
//                             : Colors.transparent,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Center(
//                         child: Text(
//                           tabs[index],
//                           style: TextStyle(
//                             color:
//                             isSelected ? Colors.white : Colors.white54,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   Widget topHeaderSection() {
//     return ClipRRect(
//       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(15, 50, 15, 40),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.06), // Glass effect
//             borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
//             border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
//               /// Top Row: Logo + Profile + Notifications
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
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Row(
//                     children: const [
//                       Icon(Icons.notifications_none, color: Colors.white, size: 26),
//                       SizedBox(width: 15),
//                       CircleAvatar(
//                         radius: 16,
//                         backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=3"),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//
//               const SizedBox(height: 15),
//
//               /// Glass Search Bar
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                   child: Container(
//                     height: 50,
//                     padding: const EdgeInsets.symmetric(horizontal: 15),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.08),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: Colors.white.withOpacity(0.2),
//                         width: 1,
//                       ),
//                     ),
//                     child: const Row(
//                       children: [
//                         Icon(Icons.search, color: Colors.white70),
//                         SizedBox(width: 10),
//                         Text(
//                           "Search Product...",
//                           style: TextStyle(color: Colors.white70, fontSize: 14),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // 3️⃣ Date Range Picker
//   Widget _buildDateRangePicker() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.white10),
//       ),
//       child: const Row(
//         children: [
//           Icon(Icons.person_outline, color: Colors.white54, size: 20),
//           SizedBox(width: 8),
//           Text(
//             "+ Dec 1, 2023 - Dec 31, 2023",
//             style: TextStyle(color: Colors.white70, fontSize: 13),
//           ),
//           Spacer(),
//           Icon(Icons.menu, color: Colors.white54, size: 20),
//         ],
//       ),
//     );
//   }
//
//   // 4️⃣ Main Sales Card
//   Widget _buildMainSalesCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: _glassDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Top Row: Title and Total Amount
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text("Sales",
//                   style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
//               Row(
//                 children: [
//                   const Icon(Icons.show_chart, color: Colors.white70, size: 16),
//                   const SizedBox(width: 4),
//                   const Text("₹ 16,67,000",
//                       style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//
//           // Main Content Row: Left Labels + Bars
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               // Left Side Labels (Retail, Realit)
//               const Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text("Retail", style: TextStyle(color: Colors.white38, fontSize: 11)),
//                   SizedBox(height: 25),
//                   Text("Realit", style: TextStyle(color: Colors.white38, fontSize: 11)),
//                   SizedBox(height: 10),
//                 ],
//               ),
//               const SizedBox(width: 10),
//
//               // Bars with Labels on Top
//               Expanded(
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     _buildBarWithLabel(40, [const Color(0xFF3B487A), const Color(0xFF566BB1)], ""),
//                     _buildBarWithLabel(55, [const Color(0xFF5C3B7A), const Color(0xFF8B5CB1)], ""),
//                     _buildBarWithLabel(45, [const Color(0xFF7A643B), const Color(0xFFB19356)], "1K"),
//                     _buildBarWithLabel(85, [const Color(0xFF3B7A7A), const Color(0xFF56B1B1)], ""),
//                     _buildBarWithLabel(65, [const Color(0xFF3B5B7A), const Color(0xFF5685B1)], ""),
//                     _buildBarWithLabel(75, [const Color(0xFF3B6B7A), const Color(0xFF56A1B1)], ""),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           const Divider(color: Colors.white10, thickness: 1),
//
//           // Bottom Inventory Details
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _buildInventoryDetail(Icons.grid_view, "Inventory", "Stock 6,000"),
//               _buildInventoryDetail(Icons.stars, "Bulk ₹ 5,30,000", "Stock 82,000"),
//             ],
//           )
//         ],
//       ),
//     );
//   }
//
// // Helper: Bar with Label on top
//   Widget _buildBarWithLabel(double height, List<Color> colors, String label) {
//     return Column(
//       children: [
//         if (label.isNotEmpty)
//           Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
//         const SizedBox(height: 4),
//         Container(
//           height: height,
//           width: 22,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: colors,
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//             ),
//             borderRadius: BorderRadius.circular(4),
//           ),
//         ),
//       ],
//     );
//   }
//
// // Helper: Bottom Inventory Info
//   Widget _buildInventoryDetail(IconData icon, String title, String subtitle) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, color: Colors.orangeAccent, size: 14),
//             const SizedBox(width: 4),
//             Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
//           ],
//         ),
//         Padding(
//           padding: const EdgeInsets.only(left: 18),
//           child: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildBar(double height, List<Color> colors) {
//     return Container(
//       height: height,
//       width: 22,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: colors,
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//         borderRadius: BorderRadius.circular(4),
//       ),
//     );
//   }
//
//   // 5️⃣ Inventory Value Card
//   Widget _buildInventoryValueCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: _glassDecoration(),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // Left Side: Text Details
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text("Inventory Value",
//                   style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5)),
//               const SizedBox(height: 8),
//               const Text(
//                 "₹ 10,46,000",
//                 style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 1),
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 children: [
//                   Container(
//                     width: 10,
//                     height: 10,
//                     decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
//                   ),
//                   const SizedBox(width: 6),
//                   const Text("Stock 66,000",
//                       style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w500)),
//                 ],
//               ),
//               const SizedBox(height: 4),
//               const Text("Total Orders",
//                   style: TextStyle(color: Colors.white38, fontSize: 12)),
//             ],
//           ),
//
//           // Right Side: Multi-color Circular Progress
//           Stack(
//             alignment: Alignment.center,
//             children: [
//               SizedBox(
//                 height: 80,
//                 width: 80,
//                 child: CustomPaint(
//                   painter: MultiColorCircularPainter(),
//                 ),
//               ),
//               Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: const [
//                   Text("80%",
//                       style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ],
//           )
//         ],
//       ),
//     );
//   }
//
//   // 6️⃣ Bottom Grid Stats
//   Widget _buildBottomGrid() {
//     return Row(
//       children: [
//         Expanded(child: _buildSmallBox("525,158", "Total Products", Icons.layers_outlined)),
//         const SizedBox(width: 15),
//         Expanded(child: _buildSmallBox("2,081", "Total Orders", Icons.star_border)),
//       ],
//     );
//   }
//
//   Widget _buildSmallBox(String val, String title, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: _glassDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
//               Icon(icon, color: Colors.white24, size: 18),
//             ],
//           ),
//           const SizedBox(height: 4),
//           Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
//         ],
//       ),
//     );
//   }
//
//   // 7️⃣ Bottom Navigation Bar
//   Widget _buildBottomNavBar() {
//     return Container(
//       height: 70,
//       decoration: const BoxDecoration(
//         color: Color(0xFF0F172A),
//         border: Border(top: BorderSide(color: Colors.white10)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _navIcon(Icons.dashboard_outlined, "Summary", 0),
//           _navIcon(Icons.pie_chart_outline, "Sections", 1),
//           _navIcon(Icons.bar_chart_outlined, "More", 2),
//           _navIcon(Icons.inventory_2_outlined, "Spares", 3),
//           _navIcon(Icons.account_balance_wallet_outlined, "Manage", 4),
//         ],
//       ),
//     );
//   }
//
//   Widget customBottomNav() {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Container(
//         height: 85,
//         decoration: BoxDecoration(
//           color: AppColors.primaryDark,
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(20),
//             topRight: Radius.circular(20),
//             bottomLeft: Radius.circular(60),
//             bottomRight: Radius.circular(60),
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.4),
//               blurRadius: 20,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(15),
//             topRight: Radius.circular(15),
//           ),
//           child: BottomNavigationBar(
//             backgroundColor: AppColors.primaryDark,
//             currentIndex: selectedIndex,
//             onTap: (index) {
//               if (index == 0) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const HomeScreen(),
//                   ),
//                 );
//               }else if (index == 1) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const InventoryScreen(),
//                   ),
//                 );
//               }
//             },
//             type: BottomNavigationBarType.fixed,
//             selectedItemColor: Colors.white,
//             unselectedItemColor: Colors.white54,
//             selectedLabelStyle: const TextStyle(
//               fontWeight: FontWeight.w600,
//             ),
//             showUnselectedLabels: true,
//             elevation: 0,
//             items: const [
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.dashboard),
//                   label: "Dashboard"),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.inventory),
//                   label: "Inventory"),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.receipt_long),
//                   label: "Orders"),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.more_horiz),
//                   label: "More"),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _navIcon(IconData icon, String label, int index) {
//     bool isSel = _selectedIndex == index;
//     return GestureDetector(
//       onTap: () => setState(() => _selectedIndex = index),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, color: isSel ? Colors.white : Colors.white38, size: 22),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: TextStyle(
//               color: isSel ? Colors.white : Colors.white38,
//               fontSize: 10,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // 🔹 Glass Card Decoration
//   BoxDecoration _glassDecoration() {
//     return BoxDecoration(
//       borderRadius: BorderRadius.circular(18),
//
//       // Glass base color
//       color: Colors.white.withOpacity(0.06),
//
//       // Soft border
//       border: Border.all(
//         color: Colors.white.withOpacity(0.15),
//         width: 1,
//       ),
//
//       // Depth shadow
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.25),
//           blurRadius: 5,
//           offset: const Offset(0, 8),
//         ),
//       ],
//
//       // // Optional subtle gradient highlight
//       // gradient: LinearGradient(
//       //   begin: Alignment.topLeft,
//       //   end: Alignment.bottomRight,
//       //   colors: [
//       //     Colors.white.withOpacity(0.10),
//       //     Colors.white.withOpacity(0.02),
//       //   ],
//       // ),
//     );
//   }
//
// }
//
// // તમારી ઈમેજ મુજબ 3 અલગ અલગ કલરના પ્રોગ્રેસ બાર માટે Custom Painter
// class MultiColorCircularPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     double strokeWidth = 10;
//     Rect rect = Offset.zero & size;
//     Paint backgroundPaint = Paint()
//       ..color = Colors.white.withOpacity(0.1)
//       ..strokeWidth = strokeWidth
//       ..style = PaintingStyle.stroke;
//
//     // આખું બેકગ્રાઉન્ડ સર્કલ
//     canvas.drawCircle(size.center(Offset.zero), size.width / 2, backgroundPaint);
//
//     // વાદળી ભાગ (Blue section)
//     Paint bluePaint = Paint()
//       ..color = const Color(0xFF3B82F6).withOpacity(0.5)
//       ..strokeWidth = strokeWidth
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//     canvas.drawArc(rect, -1.5, 2.5, false, bluePaint);
//
//     // પીળો/ગોલ્ડન ભાગ (Golden section)
//     Paint goldPaint = Paint()
//       ..color = const Color(0xFFFBBF24)
//       ..strokeWidth = strokeWidth
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//     canvas.drawArc(rect, 1.1, 1.8, false, goldPaint);
//
//     // વ્હાઇટ/લાઈટ ભાગ (White section)
//     Paint whitePaint = Paint()
//       ..color = Colors.white
//       ..strokeWidth = strokeWidth
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//     canvas.drawArc(rect, 2.9, 0.5, false, whitePaint);
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => false;
// }

// import 'dart:ui';
//
// import 'package:flutter/material.dart';
// import 'package:pecifician_sysytem/Dashboard/HomeScreen.dart';
//
// import '../Extra/AppColors.dart';
// import 'DiamondReportsUI.dart';
//
// class InventoryScreen extends StatefulWidget {
//   const InventoryScreen({super.key});
//
//   @override
//   State<InventoryScreen> createState() => _InventoryScreenState();
// }
//
// class _InventoryScreenState extends State<InventoryScreen>{
//   int selectedTab = 0;
//   int selectedIndex = 1;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBody: true,
//       bottomNavigationBar: customBottomNav(),
//       body: Stack(
//         children: [
//
//           /// ✅ Background Image
//           Positioned.fill(
//             child: Image.asset(
//               "assets/static/img_1.png",
//               fit: BoxFit.cover,
//             ),
//           ),
//
//           /// ✅ Optional Dark Overlay
//           Positioned.fill(
//             child: Container(
//               color: Colors.black.withOpacity(0.25),
//             ),
//           ),
//
//           /// ✅ Main Content
//           Column(
//             children: [
//               topHeaderSectionGlass(),
//
//               /// Inventory Title
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text(
//                       "Inventory",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 28,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 15),
//
//               /// Product List
//               Expanded(
//                 child: ListView(
//                   padding: const EdgeInsets.symmetric(horizontal: 10),
//                   children: const [
//                     ProductCard(
//                       name: "Solitaire Ring",
//                       stock: "IN STOCK",
//                       color: Colors.green,
//                     ),
//                     ProductCard(
//                       name: "Gold Earrings",
//                       stock: "LOW STOCK",
//                       color: Colors.orange,
//                     ),
//                     ProductCard(
//                       name: "Diamond Necklace",
//                       stock: "OUT STOCK",
//                       color: Colors.red,
//                     ),
//                     ProductCard(
//                       name: "Ruby Ring",
//                       stock: "OUT STOCK",
//                       color: Colors.red,
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   Widget topHeaderSectionGlass() {
//     return ClipRRect(
//       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
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
//               /// Top Row (Avatar + Notifications)
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
//                       Icon(Icons.notifications_none,
//                           color: Colors.white, size: 26),
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
//
//               const SizedBox(height: 20),
//
//               /// Glass Search Bar
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 10),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: BackdropFilter(
//                     filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                     child: Container(
//                       height: 50,
//                       padding: const EdgeInsets.symmetric(horizontal: 15),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.08),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: Colors.white.withOpacity(0.2),
//                           width: 1,
//                         ),
//                       ),
//                       child: const Row(
//                         children: [
//                           Icon(Icons.search, color: Colors.white70),
//                           SizedBox(width: 10),
//                           Text(
//                             "Search Product...",
//                             style: TextStyle(color: Colors.white70),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               /// Stock Tabs in Glass Style
//               stockTabsGlass(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget stockTabsGlass() {
//     List<String> tabs = ["All", "In Stock", "Low Stock", "Out of Stock"];
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 0),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(12),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//           child: Container(
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.white.withOpacity(0.1)),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Center(
//                         child: Text(
//                           tabs[index],
//                           style: TextStyle(
//                             color: isSelected ? Colors.white : Colors.white70,
//                             fontWeight: FontWeight.w600,
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
//               }else if (index == 2) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => const DiamondReportsFullUI(),
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
// }
//
//
// class ProductCard extends StatelessWidget {
//   final String name;
//   final String stock;
//   final Color color;
//
//   const ProductCard({
//     super.key,
//     required this.name,
//     required this.stock,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 15),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(16),
//               gradient: LinearGradient(
//                 colors: [
//                   Colors.white.withOpacity(0.08),
//                   Colors.white.withOpacity(0.03),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.15),
//                 width: 1.2,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 20,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Image.asset(
//                   "assets/static/img_2.png",
//                   height: 50,
//                   fit: BoxFit.contain,
//                 ),
//                 const SizedBox(width: 15),
//
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         name,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 5),
//                       const Text(
//                         "SKU: ₹ 88,000",
//                         style: TextStyle(
//                           color: Colors.white70,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 8,
//                   ),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.25),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                       color: color.withOpacity(0.6),
//                     ),
//                   ),
//                   child: Text(
//                     stock,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter_colorpicker/flutter_colorpicker.dart';
//
// class GradientPickerPage extends StatefulWidget {
//   const GradientPickerPage({super.key});
//
//   @override
//   State<GradientPickerPage> createState() => _GradientPickerPageState();
// }
//
// class _GradientPickerPageState extends State<GradientPickerPage> {
//   Color color1 = const Color(0xFFD4AF37);
//   Color color2 = Colors.black;
//
//   bool selectFirst = true;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // backgroundColor: const Color(0xFF0B0B0B),
//       //
//       // appBar: AppBar(
//       //   backgroundColor: const Color(0xFF0B0B0B),
//       //   elevation: 0,
//       //   centerTitle: true,
//       //   title: const Text(
//       //     "Jewellery Designer",
//       //     style: TextStyle(
//       //       color: Color(0xFFD4AF37),
//       //       fontWeight: FontWeight.bold,
//       //       letterSpacing: 1.5,
//       //     ),
//       //   ),
//       // ),
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
//                 SizedBox(height: MediaQuery.of(context).padding.top + 40),
//
//                 /// 💎 PREMIUM SEGMENTED SWITCH
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Container(
//                     padding: const EdgeInsets.all(5),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF1A1A1A),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: const Color(0xFFD4AF37).withOpacity(0.25),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         /// PRIMARY
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: () {
//                               setState(() {
//                                 selectFirst = true;
//                               });
//                             },
//                             child: AnimatedContainer(
//                               duration: const Duration(milliseconds: 50),
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                               decoration: BoxDecoration(
//                                 gradient: selectFirst
//                                     ? const LinearGradient(
//                                   colors: [
//                                     Color(0xffE6C58A),
//                                     Color(0xffC8A96A),
//                                     Color(0xffE6C58A),
//                                   ],
//                                   begin: Alignment.topLeft,
//                                   end: Alignment.bottomRight,
//                                 )
//                                     : null,
//                                 color: selectFirst ? null : Colors.transparent,
//                                 borderRadius: BorderRadius.circular(10),
//                                 boxShadow: selectFirst
//                                     ? [
//                                   BoxShadow(
//                                     color: const Color(0xFFD4AF37).withOpacity(0.5),
//                                     blurRadius: 12,
//                                     offset: const Offset(0, 4),
//                                   )
//                                 ]
//                                     : [],
//                               ),
//                               child: Center(
//                                 child: Text(
//                                   "Primary",
//                                   style: TextStyle(
//                                     color: selectFirst ? Colors.black : Colors.white70,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(width: 6),
//
//                         /// SECONDARY
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: () {
//                               setState(() {
//                                 selectFirst = false;
//                               });
//                             },
//                             child: AnimatedContainer(
//                               duration: const Duration(milliseconds: 50),
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                               decoration: BoxDecoration(
//                                 gradient: !selectFirst
//                                     ? const LinearGradient(
//                                   colors: [
//                                     Color(0xffE6C58A),
//                                     Color(0xffC8A96A),
//                                     Color(0xffE6C58A),
//                                   ],
//                                   begin: Alignment.topLeft,
//                                   end: Alignment.bottomRight,
//                                 )
//                                     : null,
//                                 color: !selectFirst ? null : Colors.transparent,
//                                 borderRadius: BorderRadius.circular(10),
//                                 boxShadow: !selectFirst
//                                     ? [
//                                   BoxShadow(
//                                     color: const Color(0xFFD4AF37).withOpacity(0.5),
//                                     blurRadius: 12,
//                                     offset: const Offset(0, 4),
//                                   )
//                                 ]
//                                     : [],
//                               ),
//                               child: Center(
//                                 child: Text(
//                                   "Secondary",
//                                   style: TextStyle(
//                                     color: !selectFirst ? Colors.black : Colors.white70,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//
//                 /// 🌟 TOP PREVIEW SECTION
//                 Expanded(
//                   flex: 2,
//                   child: Padding(
//                     padding: const EdgeInsets.all(10),
//                     child: Container(
//                       width: double.infinity,
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(20),
//                         gradient: LinearGradient(
//                           colors: [color1, color2],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.6),
//                             blurRadius: 25,
//                             offset: const Offset(0, 15),
//                           )
//                         ],
//                       ),
//                       child: const Center(
//                         child: Text(
//                           "LUXURY PREVIEW",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 26,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 2,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//
//                 /// 🎨 COLOR PICKER SECTION (BOTTOM)
//                 Expanded(
//                   flex: 3,
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(16),
//                     // decoration: const BoxDecoration(
//                     //   color: Color(0xFF111111),
//                     //   borderRadius: BorderRadius.vertical(
//                     //     top: Radius.circular(30),
//                     //   ),
//                     // ),
//                     child: Column(
//                       children: [
//
//                         UltraPremiumColorPicker(
//                           selectedColor: selectFirst ? color1 : color2,
//                           onChanged: (color) {
//                             setState(() {
//                               if (selectFirst) {
//                                 color1 = color;
//                               } else {
//                                 color2 = color;
//                               }
//                             });
//                           },
//                         ),
//
//                       ],
//                     ),
//                   ),
//                 ),
//
//                 /// Bottom Button
//                 InkWell(
//                   onTap: () {
//                     // savefinalizeBulkItems();
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
//                         "Apply Theme",
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
//                       "App Theme Setting",
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
//
//     );
//   }
// }
//
//
//
// class UltraPremiumColorPicker extends StatefulWidget {
//   final Color selectedColor;
//   final Function(Color) onChanged;
//
//   const UltraPremiumColorPicker({
//     super.key,
//     required this.selectedColor,
//     required this.onChanged,
//   });
//
//   @override
//   State<UltraPremiumColorPicker> createState() =>
//       _UltraPremiumColorPickerState();
// }
//
// class _UltraPremiumColorPickerState extends State<UltraPremiumColorPicker> {
//   final List<Color> colors = [
//     Colors.red,
//     Colors.pink,
//     Colors.purple,
//     Colors.deepPurple,
//     Colors.blue,
//     Colors.lightBlue,
//     Colors.cyan,
//     Colors.teal,
//     Colors.green,
//     Colors.lightGreen,
//     Colors.lime,
//     Colors.yellow,
//     Colors.orange,
//     Colors.deepOrange,
//     const Color(0xFFD4AF37), // gold
//     Colors.white,
//     Colors.black,
//   ];
//
//   final List<Color> recentColors = [];
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(20),
//         color: const Color(0xFF121212),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.5),
//             blurRadius: 25,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// TITLE
//           const Text(
//             "Choose Color",
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 1,
//             ),
//           ),
//
//           const SizedBox(height: 15),
//
//           /// MAIN COLOR GRID
//           Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             children: colors.map((color) {
//               bool isSelected = widget.selectedColor == color;
//
//               return GestureDetector(
//                 onTap: () {
//                   widget.onChanged(color);
//
//                   setState(() {
//                     recentColors.remove(color);
//                     recentColors.insert(0, color);
//                   });
//                 },
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 250),
//                   height: isSelected ? 45 : 40,
//                   width: isSelected ? 45 : 40,
//                   decoration: BoxDecoration(
//                     color: color,
//                     shape: BoxShape.circle,
//                     border: Border.all(
//                       color: isSelected
//                           ? const Color(0xFFD4AF37)
//                           : Colors.white24,
//                       width: isSelected ? 3 : 1,
//                     ),
//                     boxShadow: isSelected
//                         ? [
//                       BoxShadow(
//                         color: color.withOpacity(0.6),
//                         blurRadius: 15,
//                         spreadRadius: 2,
//                       )
//                     ]
//                         : [],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//
//           const SizedBox(height: 20),
//
//           /// RECENT COLORS
//           if (recentColors.isNotEmpty) ...[
//             const Text(
//               "Recent",
//               style: TextStyle(
//                 color: Colors.white70,
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 10),
//             SizedBox(
//               height: 40,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: recentColors.length,
//                 itemBuilder: (context, index) {
//                   final color = recentColors[index];
//
//                   return GestureDetector(
//                     onTap: () => widget.onChanged(color),
//                     child: Container(
//                       margin: const EdgeInsets.only(right: 10),
//                       width: 35,
//                       decoration: BoxDecoration(
//                         color: color,
//                         shape: BoxShape.circle,
//                         border: Border.all(color: Colors.white24),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
//

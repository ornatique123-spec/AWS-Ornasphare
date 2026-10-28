// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:pecifician_sysytem/Bullion/BullionEntryScreen.dart';
// import 'package:pecifician_sysytem/Dashboard/HomeScreen.dart';
// import 'package:pecifician_sysytem/Extra/AppColors.dart';
// import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Jobwork_issue_Screen.dart';
// import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
// import 'package:pecifician_sysytem/Job%20Work/Production_Costs/ProductionCost.dart';
// import 'package:pecifician_sysytem/Reports/ApprovalSummaryScreen.dart';
// import 'package:pecifician_sysytem/Reports/BarcodeHistory.dart';
// import 'package:pecifician_sysytem/Reports/SaleSumryReport.dart';
// import 'package:pecifician_sysytem/Reports/StockPositionReport.dart';
// import 'package:pecifician_sysytem/Reports/WorkerLossReportScreen.dart';
// import 'package:pecifician_sysytem/Role%20&%20Permission/PermissionScreen.dart';
// import 'package:pecifician_sysytem/Role%20&%20Permission/RoleScreen.dart';
// import 'package:pecifician_sysytem/Splash/LoginScreen.dart';
// import 'package:pecifician_sysytem/Stock%20Gallary/StockGalleryScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Casting/CastingHeatingScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Casting_Recive/CastingReciveScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Casting_Sort/CastingSortScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
// import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Vacuum%20Process/ProcessScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Vouchar%20History/VoucharHistoryScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
// import 'package:provider/provider.dart';
// import 'dart:ui';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../AI Asistant/AskAI/AskAiScreen.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../GPT Ai/GptAskScreen.dart';
// import '../GST/GstSearchScreen.dart';
// import '../Item_Mangement/Item/ItemScreen.dart';
// import '../Item_Mangement/Label Print/Label_print_Screen.dart';
// import '../Item_Mangement/Label/LabelScreen.dart';
// import '../Item_Mangement/Label_Items/label_item_screen.dart';
// import '../Item_Mangement/Others/Othersscreen.dart';
// import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
// import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
// import '../Reports/ApprovalOutstandingReport.dart';
// import '../Reports/ApprovalReturnRegisterScreen.dart';
// import '../Reports/OutStandingAmount.dart';
// import '../Reports/PurchaseReciverSummary.dart';
// import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
// import '../Visiting Card/Visitingcard.dart';
// import 'BeadsizerScreen.dart';
// import 'NotificationProvider.dart';
//
//
//
// class GlobalDrawer extends StatefulWidget {
//   const GlobalDrawer({super.key});
//
//   @override
//   State<GlobalDrawer> createState() => _GlobalDrawerState();
// }
//
// class _GlobalDrawerState extends State<GlobalDrawer> {
//   bool isExpanded = false;
//
//   String name = "";
//   String email = "";
//   String companyName = "";
//   String phone = "";
//   String city = "";
//   String state = "";
//   String companyLogo = "";
//   List<String> userPermissions = [];   // 🔥 ADD
//   Future<void> loadUserData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     setState(() {
//       name = prefs.getString("name") ?? "";
//       email = prefs.getString("email") ?? "";
//       companyName = prefs.getString("companyName") ?? "";
//       phone = prefs.getString("phone") ?? "";
//       city = prefs.getString("city") ?? "";
//       state = prefs.getString("state") ?? "";
//       companyLogo = prefs.getString("companyLogo") ?? "";
//       userPermissions = prefs.getStringList("user_permissions") ?? [];   // 🔥 ADD
//
//     });
//   }
//
//   bool hasPermission(String permission) {
//     return userPermissions.contains(permission);
//   }
//
//   /// 🔥 Module ma koi pan permission (view/create/edit/delete/manage) hoy to true
//   bool hasModuleAccess(String prefix) {
//     return userPermissions.any((p) => p.startsWith("$prefix-"));
//   }
//
//   bool hasAnyModuleAccess(List<String> prefixes) {
//     return prefixes.any((prefix) => hasModuleAccess(prefix));
//   }
//
//   bool hasAnyPermission(List<String> prefixes) {
//     return prefixes.any((prefix) => hasPermission(prefix));
//   }
//
//   /// 🔥 LIGHT BLUE PALETTE — derived from AppColors.iconBlue so it stays
//   /// tied to the app theme, just softened for a cleaner, "properer" look.
//   Color _lighten(Color color, [double amount = .3]) {
//     final hsl = HSLColor.fromColor(color);
//     final lightened =
//     hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
//     return lightened.toColor();
//   }
//
//   Color get _blueSoft => _lighten(AppColors.iconBlue, 0.32); // pastel blue
//   Color get _blueSofter => _lighten(AppColors.iconBlue, 0.44); // near-white blue
//   Color get _blueBorder => _lighten(AppColors.iconBlue, 0.30);
//
//   @override
//   void initState() {
//     super.initState();
//     loadUserData();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//
//     return Drawer(
//       width: screenWidth * 0.75,
//       child: Container(
//         decoration: BoxDecoration(
//
//           /// ✅ Soft light-blue background
//           gradient: LinearGradient(
//             colors: [
//               _blueSofter,
//               AppColors.background.withOpacity(0.96),
//               _blueSoft.withOpacity(0.55),
//             ],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: ClipRRect(
//           child: Column(
//             children: [
//               SizedBox(height: screenHeight * 0.015),
//
//               /// PROFILE CARD
//               GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     isExpanded = !isExpanded;
//                   });
//                 },
//                 child: Container(
//                   margin: EdgeInsets.symmetric(
//                     horizontal: screenWidth * 0.03,
//                     vertical: screenHeight * 0.00,
//                   ),
//                   padding: EdgeInsets.all(screenWidth * 0.04),
//                   decoration: BoxDecoration(
//                     color: const Color(0xffFAF7F2).withOpacity(0.95),
//                     borderRadius:
//                     BorderRadius.circular(screenWidth * 0.035),
//                     border: Border.all(color: Colors.white54, width: 1.2),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.08),
//                         blurRadius: 10,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(3),
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               border: Border.all(color: Colors.white54, width: 1.2),
//                             ),
//                             child: CircleAvatar(
//                               radius: screenWidth * 0.07,
//                               backgroundColor: Colors.grey.shade200,
//                               backgroundImage: (companyLogo != null && companyLogo != "")
//                                   ? NetworkImage("$companyLogo")
//                                   : const AssetImage("assets/static/logo.png") as ImageProvider,
//                             ),
//                           ),
//                           SizedBox(width: screenWidth * 0.03),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   name.isNotEmpty ? name : "Loading...",
//                                   overflow: TextOverflow.ellipsis,
//                                   style: TextStyle(
//                                     color: Colors.black,
//                                     fontSize: screenWidth * 0.044,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 SizedBox(height: screenHeight * 0.005),
//                                 Text(
//                                   email.isNotEmpty ? email : "-",
//                                   overflow: TextOverflow.ellipsis,
//                                   style: TextStyle(
//                                     color: Colors.black54,
//                                     fontSize: screenWidth * 0.03,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           AnimatedRotation(
//                             turns: isExpanded ? 0.5 : 0,
//                             duration: const Duration(milliseconds: 250),
//                             child: Icon(
//                               Icons.keyboard_arrow_down_rounded,
//                               color: AppColors.iconBlue,
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       AnimatedCrossFade(
//                         firstChild: const SizedBox.shrink(),
//                         secondChild: Padding(
//                           padding: EdgeInsets.only(top: screenHeight * 0.015),
//                           child: Container(
//                             padding: const EdgeInsets.all(10),
//                             decoration: BoxDecoration(
//                               color: _blueSofter.withOpacity(0.5),
//                               borderRadius: BorderRadius.circular(10),
//                               border: Border.all(
//                                   color: _blueBorder.withOpacity(0.5)),
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 _profileInfoRow(FontAwesomeIcons.phone, "Phone", phone),
//                                 const SizedBox(height: 8),
//                                 _profileInfoRow(FontAwesomeIcons.city, "City", city),
//                                 const SizedBox(height: 8),
//                                 _profileInfoRow(FontAwesomeIcons.locationDot, "State", state),
//                               ],
//                             ),
//                           ),
//                         ),
//                         crossFadeState: isExpanded
//                             ? CrossFadeState.showSecond
//                             : CrossFadeState.showFirst,
//                         duration: const Duration(milliseconds: 300),
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//
//               SizedBox(height: screenHeight * 0.02),
//
//               /// MENU
//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//
//                     _drawerItem(FontAwesomeIcons.house, "Dashboard  ", onTap: () {
//                       Navigator.pop(context);
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) =>
//                           const HomeScreen(),
//                         ),
//                       );
//                     },),
//
//                     /// 🔥 ASK AI — voice stock assistant
//                     if (hasPermission("stock-gallery-view") || hasModuleAccess("report-sales-summary"))
//                       _askAiTile(),
//
//                     if (hasPermission("gst-search-view"))
//                       _drawerItem(FontAwesomeIcons.images, "GST Search",
//                         onTap: () {
//                           //Navigator.pop(context);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) =>
//                               const GstSearchScreen(),
//                             ),
//                           );
//                         },),
//
//                     if (hasPermission("bullion-view"))
//                       _drawerItem(FontAwesomeIcons.images, "Bullion Management",
//                         onTap: () {
//                          // Navigator.pop(context);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => const BullionEntryScreen(),
//                             ),
//                           );
//                         },),
//
//                     if (hasAnyModuleAccess(["item", "label-config", "item-set", "label-print", "other-charge"]))
//                     /// ITEM EXPANDABLE
//                       Consumer<NotificationProvider>(
//                         builder: (context, notification, child) {
//
//                           final itemManagementCount = notification.totalCountOf([
//                             "item",
//                             "label_config",
//                             "item_set",
//                             "other_charge",
//                           ]);
//
//                           return  _drawerExpandableItem(
//                             icon: FontAwesomeIcons.boxesStacked,
//                             title: "Item Management",
//                             count: itemManagementCount,
//                             children: [
//                               if (hasModuleAccess("item"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.boxOpen,
//                                       "Items List",
//                                       count: notification.moduleCount("item"),
//                                       onTap: () {
//                                         //Navigator.pop(context);
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Itemscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("label-config"))
//
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.tags,
//                                       "Label Config",
//                                       count: notification.moduleCount("label_config"),
//                                       onTap: () {
//                                        // Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Labelscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("item-set"))
//
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.tag,
//                                       "Label Items",
//                                       count: notification.moduleCount("item_set"),
//                                       onTap: () {
//                                        // Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const label_item_screen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("label-print"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.print,
//                                   "Label Printing",
//                                   onTap: () {
//                                     //Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             LabelPrintScreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("other-charge"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.coins,
//                                       "Other Charges",
//                                       count: notification.moduleCount("other_charge"),
//                                       onTap: () {
//                                        // Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Othersscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               SizedBox(height: 10,)
//                             ],
//                           );
//                         },
//                       ),
//
//
//
//                     if (hasAnyModuleAccess(["labour-formula", "production-cost", "production-step", "job-worker", "jobwork-issue"]))
//                     /// Job Worker EXPANDABLE
//                       Consumer<NotificationProvider>(
//                         builder: (context, notification, child) {
//
//                           final jobWorkCount = notification.totalCountOf([
//                             "labour_formula",
//                             "production_cost",
//                             "production_step",
//                             "job_worker",
//                             "jobwork_issue",
//                           ]);
//
//                           return _drawerExpandableItem(
//                             icon: FontAwesomeIcons.industry,
//                             title: "Job Work",
//                             count: jobWorkCount,
//                             children: [
//                               if (hasModuleAccess("labour-formula"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.calculator,
//                                   "Labour Formula",
//                                   count: notification.moduleCount("labour_formula"),
//                                   onTap: () {
//                                   //  Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const JobLabourformulaScreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               if (hasModuleAccess("production-cost"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.moneyBillWave,
//                                   "Production Cost",
//                                   count: notification.moduleCount("production_cost"),
//                                   onTap: () {
//                                   //  Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const Productioncost(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               if (hasModuleAccess("production-step"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.listOl,
//                                   "Production Step",
//                                   count: notification.moduleCount("production_step"),
//                                   onTap: () {
//                                  //   Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const Prooductionstepscreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               // if (hasModuleAccess("job-worker"))
//                               //   _drawerexpandItem(
//                               //     FontAwesomeIcons.userGear,
//                               //     "Job Worker",
//                               //     count: notification.moduleCount("job_worker"),
//                               //     onTap: () {
//                               //       Navigator.pop(context);
//                               //       Navigator.push(
//                               //         context,
//                               //         MaterialPageRoute(
//                               //           builder: (_) => const Jobworkerscreen(),
//                               //         ),
//                               //       );
//                               //     },
//                               //   ),
//
//                               if (hasModuleAccess("jobwork-issue"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.fileExport,
//                                   "Jobwork Issue",
//                                   count: notification.moduleCount("jobwork_issue"),
//                                   onTap: () {
//                                   //  Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const JobworkIssueScreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               if (hasModuleAccess("jobwork-receive"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.fileImport,
//                                   "Jobwork Receive",
//                                   count: notification.moduleCount("jobwork_receive"),
//                                   onTap: () {
//                                   //  Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const Jobworkreceivescreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               const SizedBox(height: 10),
//                             ],
//                           );
//                         },
//                       ),
//
//                     if (hasAnyModuleAccess(["report-sales-summary", "receiver-summary", "report-stock-position", "report-outstanding-amount", "report-barcode-history","report-worker-loss"]))
//                     /// Report EXPANDABLE
//                       _drawerExpandableItem(
//                         icon: FontAwesomeIcons.chartLine,
//                         title: "Report",
//                         children: [
//                           if (hasModuleAccess("report-sales-summary"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.receipt,
//                               "Sales Summary",
//                               onTap: () {
//                                // Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                     const Salesumryreport(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           if (hasModuleAccess("report-purchase-receiver-summary"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.dolly,
//                               "Purchase/Receiver Summary",
//                               onTap: () {
//                               //  Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                     const Purchasereciversummary(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           if (hasModuleAccess("report-stock-position"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.chartBar,
//                               "Stock Position",
//                               onTap: () {
//                               //  Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                         Stockpositionreport(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           if (hasModuleAccess("report-outstanding-amount"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.wallet,
//                               "Outstanding Amount",
//                               onTap: () async {
//                               //  Navigator.pop(context);
//                                 final result = await Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => Outstandingamount(),
//                                   ),
//                                 );
//
//                                 if (result == true) {
//                                   loadUserData(); // અથવા જે API call કરવી હોય
//                                   setState(() {});
//                                 }
//                               },
//                             ),
//                           if (hasModuleAccess("report-approval-outstanding"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.fileCircleCheck,
//                               "Approval Outstanding",
//                               onTap: () {
//                               //  Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                         Approvaloutstandingreport(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           if (hasModuleAccess("report-barcode-history"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.barcode,
//                               "Barcode History",
//                               onTap: () {
//                              //   Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                         Barcodehistory(),
//                                   ),
//                                 );
//                               },
//                             ),
//
//                           if (hasModuleAccess("report-worker-loss"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.barcode,
//                               "Worker Loss Report",
//                               onTap: () {
//                               //  Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                         WorkerLossReportScreen(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           if (hasModuleAccess("report-worker-loss"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.barcode,
//                               "Approval & Register",
//                               onTap: () {
//                               //  Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                         ApprovalReturnRegisterScreen(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           if (hasModuleAccess("report-worker-loss"))
//                             _drawerexpandItem(
//                               FontAwesomeIcons.barcode,
//                               "ApprovalSummary",
//                               onTap: () {
//                               //  Navigator.pop(context);
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) =>
//                                         ApprovalSummaryScreen(),
//                                   ),
//                                 );
//                               },
//                             ),
//                           SizedBox(height: 10,)
//                         ],
//                       ),
//
//                     if (hasAnyModuleAccess(["vacuum-buch", "vacuum-process", "vacuum-voucher", "casting-heating", "casting-metal-issue","casting-release","tree-cutting-issue","tree-cutting-receive","casting-sorting","voucher-history"]))
//                     /// ITEM EXPANDABLE
//                       Consumer<NotificationProvider>(
//                         builder: (context, notification, child) {
//
//                           final itemManagementCount = notification.totalCountOf([
//                             "vacuum_buch",
//                             "vacuum_process",
//                             "vacuum_voucher",
//                             "casting_heating",
//                             "casting_metal_issue",
//                             "casting_release",
//                             "tree_cutting_issue",
//                             "tree_cutting_receive",
//                             "casting_sorting",
//                             "voucher-history",
//                           ]);
//
//                           return _drawerExpandableItem(
//                             icon: FontAwesomeIcons.fire,
//                             title: "Casting",
//                             count: itemManagementCount,
//                             children: [
//                               if (hasModuleAccess("vacuum-buch"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.fireFlameCurved,
//                                       "Buch",
//                                       count: notification.moduleCount("vacuum_buch"),
//                                       onTap: () {
//                                      //   Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Buchscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("vacuum-process"))
//
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.gears,
//                                       "Process",
//                                       count: notification.moduleCount("vacuum_process"),
//                                       onTap: () {
//                                       //  Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Processscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("vacuum-voucher"))
//
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.fileLines,
//                                       "Vacuum Voucher",
//                                       count: notification.moduleCount("vacuum_voucher"),
//                                       onTap: () {
//                                       //  Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Voucherscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("casting-heating"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.temperatureHigh,
//                                   "Casting Heating",
//                                   count: notification.moduleCount("casting_heating"),
//                                   onTap: () {
//                                   //  Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             Castingheatingscreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("casting-metal-issue"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.hammer,
//                                       "Casting Metal",
//                                       count: notification.moduleCount("casting_metal_issue"),
//                                       onTap: () {
//                                      //   Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Castingmetalscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("casting-release"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.boxArchive,
//                                       "Casting Receive",
//                                       count: notification.moduleCount("casting_release"),
//                                       onTap: () {
//                                      //   Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Castingrecivescreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("tree-cutting-office"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.building,
//                                       "Tree Cutting Office",
//                                       count: notification.moduleCount("tree_cutting_office"),
//                                       onTap: () {
//                                      //   Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Treecuttingoffice(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//
//
//                               if (hasModuleAccess("tree-cutting-issue"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.scissors,
//                                       "Tree Cutting Issue",
//                                       count: notification.moduleCount("tree_cutting_issue"),
//                                       onTap: () {
//                                      //   Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Treecuttingissuescreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//
//
//
//                               if (hasModuleAccess("tree-cutting-receive"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.inbox,
//                                       "Tree Cutting Receive",
//                                       count: notification.moduleCount("tree_cutting_receive"),
//                                       onTap: () {
//                                       //  Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Treecuttingreceivescreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("casting-sorting"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.sitemap,
//                                       "Casting Sorting",
//                                       count: notification.moduleCount("casting_sorting"),
//                                       onTap: () {
//                                       //  Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const Castingsortscreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               if (hasModuleAccess("voucher-history"))
//                                 Consumer<NotificationProvider>(
//                                   builder: (context, notification, child) {
//                                     return _drawerexpandItem(
//                                       FontAwesomeIcons.clockRotateLeft,
//                                       "Vouchar History",
//                                       count: notification.moduleCount("voucher-history"),
//                                       onTap: () {
//                                       //  Navigator.pop(context);
//
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) => const VoucherProcessHistoryScreen(),
//                                           ),
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               SizedBox(height: 10,)
//                             ],
//                           );
//                         },
//                       ),
//                     if (hasAnyModuleAccess(["role", "permission"]))
//                     /// ROLE & PERMISSION EXPANDABLE
//                       Consumer<NotificationProvider>(
//                         builder: (context, notification, child) {
//
//                           final rolePermissionCount = notification.totalCountOf([
//                             "role",
//                             "permission",
//                           ]);
//
//                           return _drawerExpandableItem(
//                             icon: FontAwesomeIcons.userShield,
//                             title: "Role & Permission",
//                             count: rolePermissionCount,
//                             children: [
//                               if (hasModuleAccess("role"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.usersGear,
//                                   "Roles",
//                                   count: notification.moduleCount("role"),
//                                   onTap: () {
//                                  //   Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const Rolescreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               if (hasModuleAccess("permission"))
//                                 _drawerexpandItem(
//                                   FontAwesomeIcons.lock,
//                                   "Permissions",
//                                   count: notification.moduleCount("permission"),
//                                   onTap: () {
//                                   //  Navigator.pop(context);
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (_) => const Permissionscreen(),
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                               const SizedBox(height: 10),
//                             ],
//                           );
//                         },
//                       ),
//                     if (hasPermission("report-visiting-cards-view"))
//                       _drawerItem(FontAwesomeIcons.addressCard, "Visiting Card",
//                         onTap: () {
//                         //  Navigator.pop(context);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) =>
//                               const PremiumHomeUI(),
//                             ),
//                           );
//                         },),
//
//
//                     // if (hasPermission("report-visiting-cards-view"))
//                     // _drawerItem(FontAwesomeIcons.image, "Background Remover",
//                     //   onTap: () {
//                     //     Navigator.pop(context);
//                     //     Navigator.push(
//                     //       context,
//                     //       MaterialPageRoute(
//                     //         builder: (context) =>
//                     //         const MyImagesScreen(),
//                     //       ),
//                     //     );
//                     //   },),
//
//                     if (hasPermission("stock-gallery-view"))
//                       _drawerItem(FontAwesomeIcons.images, "Stock Gallary",
//                         onTap: () {
//                         //  Navigator.pop(context);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) =>
//                               const StockGalleryScreen(),
//                             ),
//                           );
//                         },),
//
//
//                     if (hasPermission("stock-gallery-view"))
//                       _drawerItem(FontAwesomeIcons.images, "Jewel Scale",
//                         onTap: () {
//                         //  Navigator.pop(context);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => const BeadSizerScreen(),
//                             ),
//                           );
//                         },),
//
//                     SizedBox(height: 10,),
//
//                     Divider(
//                       color: Colors.black26,
//                       thickness: 1.2,
//                       height: 30,
//                       indent: 20,
//                       endIndent: 20,
//                     ),
//                     _drawerItem(
//                       FontAwesomeIcons.rightFromBracket,
//                       "Logout",
//                       iconColor: const Color(0xff8B3A3A),
//                       onTap: confirmLogout,
//                     ),
//                   ],
//                 ),
//               ),
//
//               SizedBox(height: screenHeight * 0.02),
//               _buildPoweredByFooter(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// 🔥 ASK AI TILE — highlighted gradient row (voice assistant)
//   Widget _askAiTile() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () {
//             Navigator.pop(context);
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (_) => const AskAiScreen()),
//             );
//             //Navigator.push(context, MaterialPageRoute(builder: (_) => const GptAskScreen()));
//           },
//           child: Ink(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [AppColors.primaryDark, AppColors.secondaryDark],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: AppColors.primaryDark.withOpacity(0.25),
//                   blurRadius: 8,
//                   offset: const Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   height: 34,
//                   width: 34,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.18),
//                     borderRadius: BorderRadius.circular(9),
//                   ),
//                   child: const FaIcon(FontAwesomeIcons.wandMagicSparkles,
//                       size: 14, color: Colors.white),
//                 ),
//                 const SizedBox(width: 14),
//                 const Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Ask AI",
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                           letterSpacing: 0.2,
//                         ),
//                       ),
//                       Text(
//                         "Stock ane sales vishe boline puchho",
//                         style: TextStyle(color: Colors.white70, fontSize: 10.5),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// SMALL ROW USED IN THE EXPANDED PROFILE CARD
//   Widget _profileInfoRow(IconData icon, String label, String value) {
//     return Row(
//       children: [
//         FaIcon(icon, size: 12, color: AppColors.iconBlue),
//         const SizedBox(width: 8),
//         Text(
//           "$label: ",
//           style: const TextStyle(
//             color: Colors.black54,
//             fontSize: 12,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         Expanded(
//           child: Text(
//             value.isNotEmpty ? value : "-",
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(
//               color: Colors.black,
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   /// 🔥 SHARED ICON BADGE — soft light-blue chip, consistent across every row
//   Widget _iconBadge(IconData icon, {double size = 34}) {
//     return Container(
//       height: size,
//       width: size,
//       alignment: Alignment.center,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             _blueSofter,
//             _blueSoft,
//           ],
//         ),
//         borderRadius: BorderRadius.circular(9),
//         border: Border.all(color: _blueBorder.withOpacity(0.6), width: 0.8),
//       ),
//       child: FaIcon(icon, size: size * 0.42, color: AppColors.iconBlue),
//     );
//   }
//
//   /// 🔥 COUNT BADGE — consistent pill used in list rows
//   Widget _countPill(int count) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xffFF7A7A), Color(0xffD9534F)],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xffD9534F).withOpacity(0.35),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Text(
//         "$count",
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 11,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }
//
//   /// NORMAL ITEM
//   Widget _drawerItem(
//       IconData icon,
//       String title, {
//         VoidCallback? onTap,
//         Color iconColor = Colors.amberAccent,
//       }) {
//     return Padding(
//       padding:
//       const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           splashColor: AppColors.iconBlue.withOpacity(0.15),
//           onTap: onTap ?? () => Navigator.pop(context),
//           child: Container(
//             padding: const EdgeInsets.symmetric(
//                 horizontal: 12, vertical: 11),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: _blueBorder.withOpacity(0.7)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.04),
//                   blurRadius: 6,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 _iconBadge(icon),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Text(
//                     title,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: Colors.black87,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       letterSpacing: 0.2,
//                     ),
//                   ),
//                 ),
//                 Icon(
//                   Icons.chevron_right_rounded,
//                   size: 18,
//                   color: Colors.grey.shade400,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   /// SUB (EXPANDED) ITEM
//   Widget _drawerexpandItem(
//       IconData icon,
//       String title, {
//         VoidCallback? onTap,
//         Color iconColor = Colors.amberAccent,
//         int count = 0,
//       }) {
//     return Padding(
//       padding:
//       const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(10),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(10),
//           splashColor: AppColors.iconBlue.withOpacity(0.15),
//           onTap: onTap ?? () => Navigator.pop(context),
//           child: Container(
//             padding: const EdgeInsets.symmetric(
//                 horizontal: 10, vertical: 9),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: _blueBorder.withOpacity(0.6)),
//             ),
//             child: Row(
//               children: [
//                 _iconBadge(icon, size: 30),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     title,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: Colors.black87,
//                       fontSize: 12.5,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 5),
//                 if (count > 0) _countPill(count),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// EXPANDABLE ITEM
//   Widget _drawerExpandableItem({
//     required IconData icon,
//     required String title,
//     required List<Widget> children,
//     int count = 0,
//   }) {
//     return Padding(
//       padding:
//       const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: _blueBorder.withOpacity(0.7)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.04),
//                 blurRadius: 6,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Theme(
//             data: Theme.of(context)
//                 .copyWith(dividerColor: Colors.transparent),
//             child: ExpansionTile(
//               collapsedIconColor: AppColors.iconBlue,
//               iconColor: AppColors.iconBlue,
//               tilePadding: const EdgeInsets.symmetric(horizontal: 12),
//               leading: _iconBadge(icon),
//               title: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       title,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: Colors.black87,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                         letterSpacing: 0.2,
//                       ),
//                     ),
//                   ),
//
//                   if (count > 0) ...[
//                     _countPill(count),
//                     const SizedBox(width: 6),
//                   ],
//                 ],
//               ),
//
//               childrenPadding:
//               const EdgeInsets.only(left: 14, right: 12, bottom: 4),
//               children: children,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// FOOTER
//   Widget _buildPoweredByFooter() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 20),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.09),
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//       ),
//       child: Center(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(2),
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(color: Colors.white54, width: 1.2),
//               ),
//               child: CircleAvatar(
//                 radius: 20,
//                 backgroundColor: Colors.grey.shade200,
//                 backgroundImage: (companyLogo != null && companyLogo != "")
//                     ? NetworkImage("$companyLogo")
//                     : const AssetImage("assets/static/img.png") as ImageProvider,
//               ),
//             ),
//             const SizedBox(height: 6),
//             const Text(
//               "Powered by OrnaSphere",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//
//           ],
//         ),
//
//       ),
//     );
//   }
//
//   /// LOGOUT DIALOG
//
//
//
//   void confirmLogout() {
//     showGeneralDialog(
//       context: context,
//       barrierLabel: "Logout",
//       barrierDismissible: true,
//       barrierColor: Colors.black.withOpacity(0.35),
//       transitionDuration: const Duration(milliseconds: 320),
//       pageBuilder: (dialogContext, __, ___) {
//         final double screenWidth = MediaQuery.of(dialogContext).size.width;
//         final double cardWidth =
//         (screenWidth * 0.85).clamp(260.0, 380.0).toDouble();
//
//         return Stack(
//           children: [
//             /// ================= BLUR BACKGROUND + OUTSIDE TAP =================
//             Positioned.fill(
//               child: GestureDetector(
//                 onTap: () => Navigator.pop(dialogContext),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
//                   child: const ColoredBox(color: Colors.transparent),
//                 ),
//               ),
//             ),
//
//             /// ================= CARD =================
//             Center(
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   width: cardWidth,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(22),
//                     border: Border.all(color: AppColors.border),
//                     boxShadow: [
//                       BoxShadow(
//                         color: AppColors.primaryDark.withOpacity(0.18),
//                         blurRadius: 30,
//                         offset: const Offset(0, 12),
//                       ),
//                     ],
//                   ),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(22),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         /// ================= HEADER =================
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 AppColors.primaryDark.withOpacity(0.08),
//                                 Colors.white,
//                               ],
//                               begin: Alignment.topCenter,
//                               end: Alignment.bottomCenter,
//                             ),
//                           ),
//                           child: Column(
//                             children: [
//                               /// ICON WITH SOFT RING
//                               Container(
//                                 padding: const EdgeInsets.all(6),
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   border: Border.all(
//                                     color:
//                                     AppColors.primaryDark.withOpacity(0.12),
//                                     width: 6,
//                                   ),
//                                 ),
//                                 child: Container(
//                                   width: 64,
//                                   height: 64,
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     shape: BoxShape.circle,
//                                     gradient: LinearGradient(
//                                       colors: [
//                                         AppColors.primaryDark,
//                                         AppColors.secondaryDark,
//                                       ],
//                                       begin: Alignment.topLeft,
//                                       end: Alignment.bottomRight,
//                                     ),
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: AppColors.primaryDark
//                                             .withOpacity(0.35),
//                                         blurRadius: 16,
//                                         offset: const Offset(0, 6),
//                                       ),
//                                     ],
//                                   ),
//                                   child: const FaIcon(
//                                     FontAwesomeIcons.rightFromBracket,
//                                     size: 26,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                               ),
//
//                               const SizedBox(height: 16),
//
//                               const Text(
//                                 "Logout?",
//                                 style: TextStyle(
//                                   fontSize: 19,
//                                   fontWeight: FontWeight.w800,
//                                   color: Colors.black87,
//                                   letterSpacing: 0.2,
//                                 ),
//                               ),
//
//                               const SizedBox(height: 6),
//
//                               const Text(
//                                 "Are you sure you want to logout from your account?",
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   fontSize: 13.5,
//                                   height: 1.4,
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         Divider(height: 1, color: AppColors.border),
//
//                         /// ================= BUTTONS =================
//                         Padding(
//                           padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//                           child: Row(
//                             children: [
//                               /// CANCEL
//                               Expanded(
//                                 child: SizedBox(
//                                   height: 46,
//                                   child: OutlinedButton(
//                                     style: OutlinedButton.styleFrom(
//                                       foregroundColor: AppColors.primaryDark,
//                                       side: BorderSide(
//                                         color: AppColors.border,
//                                         width: 1.2,
//                                       ),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                     ),
//                                     onPressed: () =>
//                                         Navigator.pop(dialogContext),
//                                     child: const Text(
//                                       "Cancel",
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.w700,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//
//                               const SizedBox(width: 12),
//
//                               /// LOGOUT
//                               Expanded(
//                                 child: Container(
//                                   height: 46,
//                                   decoration: BoxDecoration(
//                                     gradient: LinearGradient(
//                                       colors: [
//                                         AppColors.primaryDark,
//                                         AppColors.secondaryDark,
//                                       ],
//                                     ),
//                                     borderRadius: BorderRadius.circular(12),
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: AppColors.primaryDark.withOpacity(0.30),
//                                         blurRadius: 10,
//                                         offset: const Offset(0, 4),
//                                       ),
//                                     ],
//                                   ),
//                                   child: Material(
//                                     color: Colors.transparent, // 🔥 ripple button ni upar j dekhay
//                                     child: InkWell(
//                                       borderRadius: BorderRadius.circular(12),
//                                       onTap: () {
//                                         /// 🔥 Pehla dialog band, pachhi logout
//                                         Navigator.pop(dialogContext);
//                                         logout(context);
//                                       },
//                                       child: const Row(
//                                         mainAxisAlignment: MainAxisAlignment.center,
//                                         children: [
//                                           FaIcon(
//                                             FontAwesomeIcons.rightFromBracket,
//                                             size: 14,
//                                             color: Colors.white,
//                                           ),
//                                           SizedBox(width: 8),
//                                           Text(
//                                             "Logout",
//                                             style: TextStyle(
//                                               color: Colors.white,
//                                               fontSize: 14,
//                                               fontWeight: FontWeight.w800,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//       transitionBuilder: (_, anim, __, child) {
//         final curved = CurvedAnimation(
//           parent: anim,
//           curve: Curves.easeOutBack,
//         );
//
//         return FadeTransition(
//           opacity: anim,
//           child: ScaleTransition(
//             scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
//             child: child,
//           ),
//         );
//       },
//     );
//   }
//
//
//
//
//   Future<void> logout(BuildContext context) async {
//     String message = "Logout failed";
//
//     try {
//       print("🔄 Logout API calling...");
//
//       final response = await ApiHelper().postRequest(
//         ApiConstants.logout,
//         null,
//       );
//
//       print("📡 Status Code: ${response?.statusCode}");
//       print("📦 Response: ${response?.data}");
//
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.clear();
//
//       /// 🔥 GET MESSAGE FROM API (MOST IMPORTANT PART)
//       if (response != null && response.data != null) {
//         message = response.data['message']?.toString() ?? message;
//       }
//
//       /// OPTIONAL STATUS BASED OVERRIDE
//       if (response?.statusCode == 200) {
//         message = response!.data['message'] ?? "Logout successful";
//       }
//       else if (response?.statusCode == 401) {
//         message = response!.data['message'] ?? "Session expired";
//       }
//       else if (response?.statusCode == 500) {
//         message = response!.data['message'] ?? "Server error";
//       }
//
//       print("🟡 FINAL MESSAGE: $message");
//
//     } catch (e) {
//       print("❌ Exception: $e");
//       message = "Something went wrong";
//     }
//
//     /// 🔥 NAVIGATE TO LOGIN ALWAYS
//     Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => LoginScreen()),
//           (route) => false,
//     );
//
//     /// OPTIONAL: show message after navigation (safe way)
//     Future.delayed(const Duration(milliseconds: 300), () {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message)),
//       );
//     });
//   }
// }

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pecifician_sysytem/Bullion/BullionEntryScreen.dart';
import 'package:pecifician_sysytem/Dashboard/HomeScreen.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Jobwork_issue_Screen.dart';
import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
import 'package:pecifician_sysytem/Job%20Work/Production_Costs/ProductionCost.dart';
import 'package:pecifician_sysytem/Reports/ApprovalSummaryScreen.dart';
import 'package:pecifician_sysytem/Reports/BarcodeHistory.dart';
import 'package:pecifician_sysytem/Reports/SaleSumryReport.dart';
import 'package:pecifician_sysytem/Reports/StockPositionReport.dart';
import 'package:pecifician_sysytem/Reports/WorkerLossReportScreen.dart';
import 'package:pecifician_sysytem/Role%20&%20Permission/PermissionScreen.dart';
import 'package:pecifician_sysytem/Role%20&%20Permission/RoleScreen.dart';
import 'package:pecifician_sysytem/Splash/LoginScreen.dart';
import 'package:pecifician_sysytem/Stock%20Gallary/StockGalleryScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Casting/CastingHeatingScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Casting_Recive/CastingReciveScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Casting_Sort/CastingSortScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
import 'package:pecifician_sysytem/Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Vacuum%20Process/ProcessScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Vouchar%20History/VoucharHistoryScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../AI Asistant/AskAI/AskAiScreen.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../GPT Ai/GptAskScreen.dart';
import '../GST/GstSearchScreen.dart';
import '../Item_Mangement/Item/ItemScreen.dart';
import '../Item_Mangement/Label Print/Label_print_Screen.dart';
import '../Item_Mangement/Label/LabelScreen.dart';
import '../Item_Mangement/Label_Items/label_item_screen.dart';
import '../Item_Mangement/Others/Othersscreen.dart';
import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
import '../Reports/ApprovalOutstandingReport.dart';
import '../Reports/ApprovalReturnRegisterScreen.dart';
import '../Reports/OutStandingAmount.dart';
import '../Reports/PurchaseReciverSummary.dart';
import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
import '../Visiting Card/Visitingcard.dart';
import 'BeadsizerScreen.dart';
import 'NotificationProvider.dart';



class GlobalDrawer extends StatefulWidget {
  const GlobalDrawer({super.key});

  @override
  State<GlobalDrawer> createState() => _GlobalDrawerState();
}

class _GlobalDrawerState extends State<GlobalDrawer> {
  bool isExpanded = false;

  String name = "";
  String email = "";
  String companyName = "";
  String phone = "";
  String city = "";
  String state = "";
  String companyLogo = "";
  List<String> userPermissions = [];   // 🔥 ADD
  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      name = prefs.getString("name") ?? "";
      email = prefs.getString("email") ?? "";
      companyName = prefs.getString("companyName") ?? "";
      phone = prefs.getString("phone") ?? "";
      city = prefs.getString("city") ?? "";
      state = prefs.getString("state") ?? "";
      companyLogo = prefs.getString("companyLogo") ?? "";
      userPermissions = prefs.getStringList("user_permissions") ?? [];   // 🔥 ADD

    });
  }

  // ============================================================
  // 🔔 NOTIFICATION COUNT — click → read API → screen → back = count saaf
  // ============================================================

  /// Click karela module — count turant 0 dekhay.
  /// static etle drawer farithi khule to pan yaad rahe; server count 0
  /// aavi jay pachhi set mathi nikli jay (navi notification aave to dekhay).
  static final Set<String> _readModules = {};

  /// Ek module no count (click karelo hoy to 0)
  int _mc(NotificationProvider n, String module) {
    final int c = n.moduleCount(module);
    if (!_readModules.contains(module)) return c;
    if (c == 0) _readModules.remove(module);
    return 0;
  }

  /// Group (Item Management, Job Work...) no total — click karela minus
  int _tc(NotificationProvider n, List<String> modules) =>
      modules.fold<int>(0, (sum, m) => sum + _mc(n, m));

  Future<bool> _readModule(String module) async {
    try {
      final response = await ApiHelper().postRequest(
        "${ApiConstants.baseUrl}notifications/read-module",
        {"module": module},
      );
      debugPrint("🔔 Read Module ($module): ${response?.data}");
      return response != null &&
          response.statusCode == 200 &&
          response.data is Map &&
          response.data["success"] == true;
    } catch (e) {
      debugPrint("❌ Read Module Error: $e");
      return false;
    }
  }

  /// 🔥 Count hoy to read API → screen open → back aave tyare count refresh
  Future<void> _openModule(String module, Widget screen) async {
    final NotificationProvider provider = context.read<NotificationProvider>();
    final bool hasCount = provider.moduleCount(module) > 0;

    Future<bool>? readFuture;
    if (hasCount) {
      setState(() => _readModules.add(module)); // badge turant hide
      readFuture = _readModule(module);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    if (readFuture != null) {
      final bool ok = await readFuture;
      if (!ok) _readModules.remove(module); // API fail → count paachho
    }
    if (!mounted) return;

    // Server mathi navo count (group total pan minus thai jay)
    provider.loadNotificationCount();
    setState(() {});
  }

  bool hasPermission(String permission) {
    return userPermissions.contains(permission);
  }

  /// 🔥 Module ma koi pan permission (view/create/edit/delete/manage) hoy to true
  bool hasModuleAccess(String prefix) {
    return userPermissions.any((p) => p.startsWith("$prefix-"));
  }

  bool hasAnyModuleAccess(List<String> prefixes) {
    return prefixes.any((prefix) => hasModuleAccess(prefix));
  }

  bool hasAnyPermission(List<String> prefixes) {
    return prefixes.any((prefix) => hasPermission(prefix));
  }

  /// 🔥 LIGHT BLUE PALETTE — derived from AppColors.iconBlue so it stays
  /// tied to the app theme, just softened for a cleaner, "properer" look.
  Color _lighten(Color color, [double amount = .3]) {
    final hsl = HSLColor.fromColor(color);
    final lightened =
    hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  Color get _blueSoft => _lighten(AppColors.iconBlue, 0.32); // pastel blue
  Color get _blueSofter => _lighten(AppColors.iconBlue, 0.44); // near-white blue
  Color get _blueBorder => _lighten(AppColors.iconBlue, 0.30);

  @override
  void initState() {
    super.initState();
    loadUserData();

    // 🔔 Drawer khule (dar vakhte navo bane) tyare notification summary API
    // → module wise count taaja
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().loadNotificationCount();
    });
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Drawer(
      width: screenWidth * 0.75,
      child: Container(
        decoration: BoxDecoration(

          /// ✅ Soft light-blue background
          gradient: LinearGradient(
            colors: [
              _blueSofter,
              AppColors.background.withOpacity(0.96),
              _blueSoft.withOpacity(0.55),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.015),

              /// PROFILE CARD
              GestureDetector(
                onTap: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.00,
                  ),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: const Color(0xffFAF7F2).withOpacity(0.95),
                    borderRadius:
                    BorderRadius.circular(screenWidth * 0.035),
                    border: Border.all(color: Colors.white54, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white54, width: 1.2),
                            ),
                            child: CircleAvatar(
                              radius: screenWidth * 0.07,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: (companyLogo != null && companyLogo != "")
                                  ? NetworkImage("$companyLogo")
                                  : const AssetImage("assets/static/logo.png") as ImageProvider,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isNotEmpty ? name : "Loading...",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: screenWidth * 0.044,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                Text(
                                  email.isNotEmpty ? email : "-",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.iconBlue,
                            ),
                          ),
                        ],
                      ),

                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: EdgeInsets.only(top: screenHeight * 0.015),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _blueSofter.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _blueBorder.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _profileInfoRow(FontAwesomeIcons.phone, "Phone", phone),
                                const SizedBox(height: 8),
                                _profileInfoRow(FontAwesomeIcons.city, "City", city),
                                const SizedBox(height: 8),
                                _profileInfoRow(FontAwesomeIcons.locationDot, "State", state),
                              ],
                            ),
                          ),
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      )
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              /// MENU
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [

                    _drawerItem(FontAwesomeIcons.house, "Dashboard  ", onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const HomeScreen(),
                        ),
                      );
                    },),

                    /// 🔥 ASK AI — voice stock assistant
                    if (hasPermission("stock-gallery-view") || hasModuleAccess("report-sales-summary"))
                      _askAiTile(),

                    if (hasPermission("gst-search-view"))
                      _drawerItem(FontAwesomeIcons.images, "GST Search",
                        onTap: () {
                          //Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const GstSearchScreen(),
                            ),
                          );
                        },),

                    if (hasPermission("bullion-view"))
                      _drawerItem(FontAwesomeIcons.images, "Bullion Management",
                        onTap: () {
                          // Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BullionEntryScreen(),
                            ),
                          );
                        },),

                    if (hasAnyModuleAccess(["item", "label-config", "item-set", "label-print", "other-charge"]))
                    /// ITEM EXPANDABLE
                      Consumer<NotificationProvider>(
                        builder: (context, notification, child) {

                          final itemManagementCount = _tc(notification, [
                            "item",
                            "label_config",
                            "item_set",
                            "other_charge",
                          ]);

                          return  _drawerExpandableItem(
                            icon: FontAwesomeIcons.boxesStacked,
                            title: "Item Management",
                            count: itemManagementCount,
                            children: [
                              if (hasModuleAccess("item"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.boxOpen,
                                      "Items List",
                                      count: _mc(notification, "item"),
                                      onTap: () => _openModule("item", const Itemscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("label-config"))

                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.tags,
                                      "Label Config",
                                      count: _mc(notification, "label_config"),
                                      onTap: () => _openModule("label_config", const Labelscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("item-set"))

                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.tag,
                                      "Label Items",
                                      count: _mc(notification, "item_set"),
                                      onTap: () => _openModule("item_set", const label_item_screen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("label-print"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.print,
                                  "Label Printing",
                                  onTap: () {
                                    //Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            LabelPrintScreen(),
                                      ),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("other-charge"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.coins,
                                      "Other Charges",
                                      count: _mc(notification, "other_charge"),
                                      onTap: () => _openModule("other_charge", const Othersscreen()),
                                    );
                                  },
                                ),
                              SizedBox(height: 10,)
                            ],
                          );
                        },
                      ),



                    if (hasAnyModuleAccess(["labour-formula", "production-cost", "production-step", "job-worker", "jobwork-issue"]))
                    /// Job Worker EXPANDABLE
                      Consumer<NotificationProvider>(
                        builder: (context, notification, child) {

                          final jobWorkCount = _tc(notification, [
                            "labour_formula",
                            "production_cost",
                            "production_step",
                            "job_worker",
                            "jobwork_issue",
                            "jobwork_receive",
                          ]);

                          return _drawerExpandableItem(
                            icon: FontAwesomeIcons.industry,
                            title: "Job Work",
                            count: jobWorkCount,
                            children: [
                              if (hasModuleAccess("labour-formula"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.calculator,
                                  "Labour Formula",
                                  count: _mc(notification, "labour_formula"),
                                  onTap: () => _openModule("labour_formula", const JobLabourformulaScreen()),
                                ),

                              if (hasModuleAccess("production-cost"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.moneyBillWave,
                                  "Production Cost",
                                  count: _mc(notification, "production_cost"),
                                  onTap: () => _openModule("production_cost", const Productioncost()),
                                ),

                              if (hasModuleAccess("production-step"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.listOl,
                                  "Production Step",
                                  count: _mc(notification, "production_step"),
                                  onTap: () => _openModule("production_step", const Prooductionstepscreen()),
                                ),

                              // if (hasModuleAccess("job-worker"))
                              //   _drawerexpandItem(
                              //     FontAwesomeIcons.userGear,
                              //     "Job Worker",
                              //     count: notification.moduleCount("job_worker"),
                              //     onTap: () {
                              //       Navigator.pop(context);
                              //       Navigator.push(
                              //         context,
                              //         MaterialPageRoute(
                              //           builder: (_) => const Jobworkerscreen(),
                              //         ),
                              //       );
                              //     },
                              //   ),

                              if (hasModuleAccess("jobwork-issue"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.fileExport,
                                  "Jobwork Issue",
                                  count: _mc(notification, "jobwork_issue"),
                                  onTap: () => _openModule("jobwork_issue", const JobworkIssueScreen()),
                                ),

                              if (hasModuleAccess("jobwork-receive"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.fileImport,
                                  "Jobwork Receive",
                                  count: _mc(notification, "jobwork_receive"),
                                  onTap: () => _openModule("jobwork_receive", const Jobworkreceivescreen()),
                                ),

                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),

                    if (hasAnyModuleAccess(["report-sales-summary", "receiver-summary", "report-stock-position", "report-outstanding-amount", "report-barcode-history","report-worker-loss"]))
                    /// Report EXPANDABLE
                      _drawerExpandableItem(
                        icon: FontAwesomeIcons.chartLine,
                        title: "Report",
                        children: [
                          if (hasModuleAccess("report-sales-summary"))
                            _drawerexpandItem(
                              FontAwesomeIcons.receipt,
                              "Sales Summary",
                              onTap: () {
                                // Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const Salesumryreport(),
                                  ),
                                );
                              },
                            ),
                          if (hasModuleAccess("report-purchase-receiver-summary"))
                            _drawerexpandItem(
                              FontAwesomeIcons.dolly,
                              "Purchase/Receiver Summary",
                              onTap: () {
                                //  Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const Purchasereciversummary(),
                                  ),
                                );
                              },
                            ),
                          if (hasModuleAccess("report-stock-position"))
                            _drawerexpandItem(
                              FontAwesomeIcons.chartBar,
                              "Stock Position",
                              onTap: () {
                                //  Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Stockpositionreport(),
                                  ),
                                );
                              },
                            ),
                          if (hasModuleAccess("report-outstanding-amount"))
                            _drawerexpandItem(
                              FontAwesomeIcons.wallet,
                              "Outstanding Amount",
                              onTap: () async {
                                //  Navigator.pop(context);
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Outstandingamount(),
                                  ),
                                );

                                if (result == true) {
                                  loadUserData(); // અથવા જે API call કરવી હોય
                                  setState(() {});
                                }
                              },
                            ),
                          if (hasModuleAccess("report-approval-outstanding"))
                            _drawerexpandItem(
                              FontAwesomeIcons.fileCircleCheck,
                              "Approval Outstanding",
                              onTap: () {
                                //  Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Approvaloutstandingreport(),
                                  ),
                                );
                              },
                            ),
                          if (hasModuleAccess("report-barcode-history"))
                            _drawerexpandItem(
                              FontAwesomeIcons.barcode,
                              "Barcode History",
                              onTap: () {
                                //   Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Barcodehistory(),
                                  ),
                                );
                              },
                            ),

                          if (hasModuleAccess("report-worker-loss"))
                            _drawerexpandItem(
                              FontAwesomeIcons.barcode,
                              "Worker Loss Report",
                              onTap: () {
                                //  Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WorkerLossReportScreen(),
                                  ),
                                );
                              },
                            ),
                          if (hasModuleAccess("report-worker-loss"))
                            _drawerexpandItem(
                              FontAwesomeIcons.barcode,
                              "Approval & Register",
                              onTap: () {
                                //  Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ApprovalReturnRegisterScreen(),
                                  ),
                                );
                              },
                            ),
                          if (hasModuleAccess("report-worker-loss"))
                            _drawerexpandItem(
                              FontAwesomeIcons.barcode,
                              "ApprovalSummary",
                              onTap: () {
                                //  Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ApprovalSummaryScreen(),
                                  ),
                                );
                              },
                            ),
                          SizedBox(height: 10,)
                        ],
                      ),

                    if (hasAnyModuleAccess(["vacuum-buch", "vacuum-process", "vacuum-voucher", "casting-heating", "casting-metal-issue","casting-release","tree-cutting-issue","tree-cutting-receive","casting-sorting","voucher-history"]))
                    /// ITEM EXPANDABLE
                      Consumer<NotificationProvider>(
                        builder: (context, notification, child) {

                          final itemManagementCount = _tc(notification, [
                            "vacuum_buch",
                            "vacuum_process",
                            "vacuum_voucher",
                            "casting_heating",
                            "casting_metal_issue",
                            "casting_release",
                            "tree_cutting_office",
                            "tree_cutting_issue",
                            "tree_cutting_receive",
                            "casting_sorting",
                            "voucher-history",
                          ]);

                          return _drawerExpandableItem(
                            icon: FontAwesomeIcons.fire,
                            title: "Casting",
                            count: itemManagementCount,
                            children: [
                              if (hasModuleAccess("vacuum-buch"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.fireFlameCurved,
                                      "Buch",
                                      count: _mc(notification, "vacuum_buch"),
                                      onTap: () => _openModule("vacuum_buch", const Buchscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("vacuum-process"))

                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.gears,
                                      "Process",
                                      count: _mc(notification, "vacuum_process"),
                                      onTap: () => _openModule("vacuum_process", const Processscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("vacuum-voucher"))

                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.fileLines,
                                      "Vacuum Voucher",
                                      count: _mc(notification, "vacuum_voucher"),
                                      onTap: () => _openModule("vacuum_voucher", const Voucherscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("casting-heating"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.temperatureHigh,
                                  "Casting Heating",
                                  count: _mc(notification, "casting_heating"),
                                  onTap: () => _openModule("casting_heating", Castingheatingscreen()),
                                ),
                              if (hasModuleAccess("casting-metal-issue"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.hammer,
                                      "Casting Metal",
                                      count: _mc(notification, "casting_metal_issue"),
                                      onTap: () => _openModule("casting_metal_issue", const Castingmetalscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("casting-release"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.boxArchive,
                                      "Casting Receive",
                                      count: _mc(notification, "casting_release"),
                                      onTap: () => _openModule("casting_release", const Castingrecivescreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("tree-cutting-office"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.building,
                                      "Tree Cutting Office",
                                      count: _mc(notification, "tree_cutting_office"),
                                      onTap: () => _openModule("tree_cutting_office", const Treecuttingoffice()),
                                    );
                                  },
                                ),


                              if (hasModuleAccess("tree-cutting-issue"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.scissors,
                                      "Tree Cutting Issue",
                                      count: _mc(notification, "tree_cutting_issue"),
                                      onTap: () => _openModule("tree_cutting_issue", const Treecuttingissuescreen()),
                                    );
                                  },
                                ),



                              if (hasModuleAccess("tree-cutting-receive"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.inbox,
                                      "Tree Cutting Receive",
                                      count: _mc(notification, "tree_cutting_receive"),
                                      onTap: () => _openModule("tree_cutting_receive", const Treecuttingreceivescreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("casting-sorting"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.sitemap,
                                      "Casting Sorting",
                                      count: _mc(notification, "casting_sorting"),
                                      onTap: () => _openModule("casting_sorting", const Castingsortscreen()),
                                    );
                                  },
                                ),
                              if (hasModuleAccess("voucher-history"))
                                Consumer<NotificationProvider>(
                                  builder: (context, notification, child) {
                                    return _drawerexpandItem(
                                      FontAwesomeIcons.clockRotateLeft,
                                      "Vouchar History",
                                      count: _mc(notification, "voucher-history"),
                                      onTap: () => _openModule("voucher-history", const VoucherProcessHistoryScreen()),
                                    );
                                  },
                                ),
                              SizedBox(height: 10,)
                            ],
                          );
                        },
                      ),
                    if (hasAnyModuleAccess(["role", "permission"]))
                    /// ROLE & PERMISSION EXPANDABLE
                      Consumer<NotificationProvider>(
                        builder: (context, notification, child) {

                          final rolePermissionCount = _tc(notification, [
                            "role",
                            "permission",
                          ]);

                          return _drawerExpandableItem(
                            icon: FontAwesomeIcons.userShield,
                            title: "Role & Permission",
                            count: rolePermissionCount,
                            children: [
                              if (hasModuleAccess("role"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.usersGear,
                                  "Roles",
                                  count: _mc(notification, "role"),
                                  onTap: () => _openModule("role", const Rolescreen()),
                                ),

                              if (hasModuleAccess("permission"))
                                _drawerexpandItem(
                                  FontAwesomeIcons.lock,
                                  "Permissions",
                                  count: _mc(notification, "permission"),
                                  onTap: () => _openModule("permission", const Permissionscreen()),
                                ),

                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                    if (hasPermission("report-visiting-cards-view"))
                      _drawerItem(FontAwesomeIcons.addressCard, "Visiting Card",
                        onTap: () {
                          //  Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const PremiumHomeUI(),
                            ),
                          );
                        },),


                    // if (hasPermission("report-visiting-cards-view"))
                    // _drawerItem(FontAwesomeIcons.image, "Background Remover",
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) =>
                    //         const MyImagesScreen(),
                    //       ),
                    //     );
                    //   },),

                    if (hasPermission("stock-gallery-view"))
                      _drawerItem(FontAwesomeIcons.images, "Stock Gallary",
                        onTap: () {
                          //  Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const StockGalleryScreen(),
                            ),
                          );
                        },),


                    if (hasPermission("stock-gallery-view"))
                      _drawerItem(FontAwesomeIcons.images, "Jewel Scale",
                        onTap: () {
                          //  Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BeadSizerScreen(),
                            ),
                          );
                        },),

                    SizedBox(height: 10,),

                    Divider(
                      color: Colors.black26,
                      thickness: 1.2,
                      height: 30,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _drawerItem(
                      FontAwesomeIcons.rightFromBracket,
                      "Logout",
                      iconColor: const Color(0xff8B3A3A),
                      onTap: confirmLogout,
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02),
              _buildPoweredByFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔥 ASK AI TILE — highlighted gradient row (voice assistant)
  Widget _askAiTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AskAiScreen()),
            );
            //Navigator.push(context, MaterialPageRoute(builder: (_) => const GptAskScreen()));
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.secondaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const FaIcon(FontAwesomeIcons.wandMagicSparkles,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ask AI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        "Stock ane sales vishe boline puchho",
                        style: TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// SMALL ROW USED IN THE EXPANDED PROFILE CARD
  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        FaIcon(icon, size: 12, color: AppColors.iconBlue),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : "-",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 🔥 SHARED ICON BADGE — soft light-blue chip, consistent across every row
  Widget _iconBadge(IconData icon, {double size = 34}) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blueSofter,
            _blueSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _blueBorder.withOpacity(0.6), width: 0.8),
      ),
      child: FaIcon(icon, size: size * 0.42, color: AppColors.iconBlue),
    );
  }

  /// 🔥 COUNT BADGE — consistent pill used in list rows
  Widget _countPill(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffFF7A7A), Color(0xffD9534F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffD9534F).withOpacity(0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "$count",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// NORMAL ITEM
  Widget _drawerItem(
      IconData icon,
      String title, {
        VoidCallback? onTap,
        Color iconColor = Colors.amberAccent,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.iconBlue.withOpacity(0.15),
          onTap: onTap ?? () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blueBorder.withOpacity(0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _iconBadge(icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// SUB (EXPANDED) ITEM
  Widget _drawerexpandItem(
      IconData icon,
      String title, {
        VoidCallback? onTap,
        Color iconColor = Colors.amberAccent,
        int count = 0,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          splashColor: AppColors.iconBlue.withOpacity(0.15),
          onTap: onTap ?? () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _blueBorder.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                _iconBadge(icon, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if (count > 0) _countPill(count),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// EXPANDABLE ITEM
  Widget _drawerExpandableItem({
    required IconData icon,
    required String title,
    required List<Widget> children,
    int count = 0,
  }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blueBorder.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              collapsedIconColor: AppColors.iconBlue,
              iconColor: AppColors.iconBlue,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: _iconBadge(icon),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  if (count > 0) ...[
                    _countPill(count),
                    const SizedBox(width: 6),
                  ],
                ],
              ),

              childrenPadding:
              const EdgeInsets.only(left: 14, right: 12, bottom: 4),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  /// FOOTER
  Widget _buildPoweredByFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.09),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.2),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (companyLogo != null && companyLogo != "")
                    ? NetworkImage("$companyLogo")
                    : const AssetImage("assets/static/img.png") as ImageProvider,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Powered by OrnaSphere",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

          ],
        ),

      ),
    );
  }

  /// LOGOUT DIALOG



  void confirmLogout() {
    showGeneralDialog(
      context: context,
      barrierLabel: "Logout",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, __, ___) {
        final double screenWidth = MediaQuery.of(dialogContext).size.width;
        final double cardWidth =
        (screenWidth * 0.85).clamp(260.0, 380.0).toDouble();

        return Stack(
          children: [
            /// ================= BLUR BACKGROUND + OUTSIDE TAP =================
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),

            /// ================= CARD =================
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// ================= HEADER =================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark.withOpacity(0.08),
                                Colors.white,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            children: [
                              /// ICON WITH SOFT RING
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                    AppColors.primaryDark.withOpacity(0.12),
                                    width: 6,
                                  ),
                                ),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.secondaryDark,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryDark
                                            .withOpacity(0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const FaIcon(
                                    FontAwesomeIcons.rightFromBracket,
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              const Text(
                                "Logout?",
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  letterSpacing: 0.2,
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                "Are you sure you want to logout from your account?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(height: 1, color: AppColors.border),

                        /// ================= BUTTONS =================
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Row(
                            children: [
                              /// CANCEL
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryDark,
                                      side: BorderSide(
                                        color: AppColors.border,
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              /// LOGOUT
                              Expanded(
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.secondaryDark,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryDark.withOpacity(0.30),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent, // 🔥 ripple button ni upar j dekhay
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        /// 🔥 Pehla dialog band, pachhi logout
                                        Navigator.pop(dialogContext);
                                        logout(context);
                                      },
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          FaIcon(
                                            FontAwesomeIcons.rightFromBracket,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "Logout",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }




  Future<void> logout(BuildContext context) async {
    String message = "Logout failed";

    try {
      print("🔄 Logout API calling...");

      final response = await ApiHelper().postRequest(
        ApiConstants.logout,
        null,
      );

      print("📡 Status Code: ${response?.statusCode}");
      print("📦 Response: ${response?.data}");

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      /// 🔥 GET MESSAGE FROM API (MOST IMPORTANT PART)
      if (response != null && response.data != null) {
        message = response.data['message']?.toString() ?? message;
      }

      /// OPTIONAL STATUS BASED OVERRIDE
      if (response?.statusCode == 200) {
        message = response!.data['message'] ?? "Logout successful";
      }
      else if (response?.statusCode == 401) {
        message = response!.data['message'] ?? "Session expired";
      }
      else if (response?.statusCode == 500) {
        message = response!.data['message'] ?? "Server error";
      }

      print("🟡 FINAL MESSAGE: $message");

    } catch (e) {
      print("❌ Exception: $e");
      message = "Something went wrong";
    }

    /// 🔥 NAVIGATE TO LOGIN ALWAYS
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
    );

    /// OPTIONAL: show message after navigation (safe way)
    Future.delayed(const Duration(milliseconds: 300), () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }
}
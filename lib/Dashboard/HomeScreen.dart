// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
// import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
// import 'package:pecifician_sysytem/Approval/Recive_return_purchase.dart';
// import 'package:pecifician_sysytem/Dashboard/DiamondReportsUI.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
// import 'package:pecifician_sysytem/QR%20Making/AddQrScreen.dart';
// import 'package:pecifician_sysytem/QR%20Making/QrListScreen.dart';
// import 'package:pecifician_sysytem/Reports/ApprovalReturnRegisterScreen.dart';
// import 'package:pecifician_sysytem/Reports/ApprovalSummaryScreen.dart';
// import 'package:pecifician_sysytem/Reports/OutStandingAmount.dart';
// import 'package:pecifician_sysytem/Reports/WorkerLossReportScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/SellScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CategoryScreen.dart';
// import 'package:pecifician_sysytem/User/CreateCustomer.dart';
// import 'package:pecifician_sysytem/User/OfficeAccessSettingsScreen.dart';
// import 'package:pecifician_sysytem/User/UserScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
// import 'package:pecifician_sysytem/Visiting%20Card/Visitingcard.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Approval/ApproveListScreen.dart';
// import '../Approval/ReceivevoucharScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/GlobalDrawer.dart';
// import '../Extra/NotificationProvider.dart';
// import '../Settings/LiveMetalRatesScreen.dart';
// import '../Settings/SettingsScreen.dart';
// import '../Item_Mangement/Item/ItemScreen.dart';
// import '../Item_Mangement/Label Print/Label_print_Screen.dart';
// import '../Item_Mangement/Label/LabelScreen.dart';
// import '../Item_Mangement/Label_Items/label_item_screen.dart';
// import '../Item_Mangement/Others/Othersscreen.dart';
// import '../Job Work/Job Work Issue/Jobwork_issue_Screen.dart';
// import '../Job Work/Job Worker/JobWorkerScreen.dart';
// import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
// import '../Job Work/Production_Costs/ProductionCost.dart';
// import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
// import '../Notification/NotificationScreen.dart';
// import '../Reports/ApprovalOutstandingReport.dart';
// import '../Reports/BarcodeHistory.dart';
// import '../Reports/PurchaseReciverSummary.dart';
// import '../Reports/SaleSumryReport.dart';
// import '../Reports/StockPositionReport.dart';
// import '../Role & Permission/PermissionScreen.dart';
// import '../Role & Permission/RoleScreen.dart';
// import '../User/CustomerScreen.dart';
// import '../Vacuum/Casting/CastingHeatingScreen.dart';
// import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
// import '../Vacuum/Casting_Recive/CastingReciveScreen.dart';
// import '../Vacuum/Casting_Sort/CastingSortScreen.dart';
// import '../Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
// import '../Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
// import '../Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
// import '../Vacuum/Vacuum Process/ProcessScreen.dart';
// import '../Vacuum/Vouchar History/VoucharHistoryScreen.dart';
// import 'InventoryScreen.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   int selectedIndex = 0;
//   List<String> sectionOrder = [];
//   List<String> userRoleNames = [];
//   List<String> userPermissions = []; // ✅ aa hovu joiye
//   List<Map<String, dynamic>> bottomItems = [
//     {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//
//     {"title": "More", "icon": Icons.more_horiz},
//   ];
//   List rates = [];
//   String source = "";
//   String updatedAt = "";
//   Timer? autoRefreshTimer;
//   String? activeSection;
//   Map<String, double> _previousRateValues = {};
//   Map<String, Color> _rateColors = {};
//   /// ============================================================
//   /// 🔥 PLAN ALERT POPUP GUARD
//   ///
//   /// Ek j session ma popup vaar-vaar na khule (dar vaar getCompanyProfile
//   /// call thay tyare) — matra jyare tak user e already dekhi na hoy.
//   /// Jo tame har vaar j dekhadvu hoy to aa flag hatavi shakay.
//   /// ============================================================
//   bool _planAlertShown = false;
//
//   Future<void> moveSectionToTopAndOpen(String sectionName) async {
//     // if (!mounted) return;
//
//     setState(() {
//       activeSection = sectionName;
//
//       /// Section top par
//       sectionOrder.remove(sectionName);
//       sectionOrder.insert(0, sectionName);
//
//       /// Badha close
//       for (final key in sectionOrder) {
//         expandedSections[key] = false;
//       }
//
//       /// Current section open
//       expandedSections[sectionName] = true;
//     });
//
//     /// Persist
//     await saveSectionOrder();
//     await saveExpandedSections();
//   }
//
//   /// ============================================================
//   /// 🔥 CHECK IF CURRENT USER IS ADMIN
//   ///
//   /// SharedPreferences ma save thayela "user_role_names" check kare che.
//   /// Fallback tarike current in-memory `userRoleNames` list vaparay che.
//   /// ============================================================
//   Future<bool> _isAdminRole() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     final List<String> savedRoles =
//         prefs.getStringList("user_role_names") ?? [];
//
//     final List<String> roles = savedRoles.isNotEmpty
//         ? savedRoles
//         : userRoleNames;
//
//     return roles.any(
//           (r) =>
//       r.toLowerCase().trim() == "admin" ||
//           r.toLowerCase().trim().contains("admin"),
//     );
//   }
//
//   Future<void> loadRates({bool silent = false}) async {
//     try {
//       /// ============================================
//       /// 🔥 ADMIN CHECK — Default lat/long use karva mate
//       /// ============================================
//       final bool isAdmin = await _isAdminRole();
//
//       String latitude = "";
//       String longitude = "";
//
//       if (isAdmin) {
//         /// ============================================
//         /// 🔥 ADMIN — Fixed default coordinates
//         /// ============================================
//         latitude = "23.0492348";
//         longitude = "72.5800721";
//
//         debugPrint("======================================");
//         debugPrint("🔥 ADMIN ROLE — Using default location");
//         debugPrint("Latitude  => $latitude");
//         debugPrint("Longitude => $longitude");
//         debugPrint("======================================");
//       } else {
//         /// ============================================
//         /// 1. LOCATION SERVICE CHECK
//         ///
//         /// 🔥 IMPORTANT: Service bandh hoy to pan
//         /// return NA karvanu — API call thavi j joie,
//         /// fakt lat/long empty rehse.
//         /// ============================================
//         try {
//           final bool serviceEnabled =
//           await Geolocator.isLocationServiceEnabled();
//
//           if (!serviceEnabled) {
//             debugPrint("⚠️ Location service disabled — proceeding without lat/long");
//
//             if (!silent && mounted) {
//               AppMessage.error(context, "Please enable location service.");
//             }
//           } else {
//             /// ============================================
//             /// 2. LOCATION PERMISSION CHECK
//             /// ============================================
//             LocationPermission permission = await Geolocator.checkPermission();
//
//             if (permission == LocationPermission.denied) {
//               permission = await Geolocator.requestPermission();
//             }
//
//             if (permission == LocationPermission.denied) {
//               debugPrint("⚠️ Location permission denied — proceeding without lat/long");
//
//               if (!silent && mounted) {
//                 AppMessage.error(context, "Location permission is required.");
//               }
//             } else if (permission == LocationPermission.deniedForever) {
//               debugPrint(
//                 "⚠️ Location permission permanently denied — proceeding without lat/long",
//               );
//
//               if (!silent && mounted) {
//                 AppMessage.error(
//                   context,
//                   "Location permission is permanently denied.",
//                 );
//               }
//             } else {
//               /// ============================================
//               /// 3. GET CURRENT LOCATION
//               /// ============================================
//               final Position position = await Geolocator.getCurrentPosition(
//                 locationSettings: const LocationSettings(
//                   accuracy: LocationAccuracy.high,
//                 ),
//               );
//
//               latitude = position.latitude.toString();
//               longitude = position.longitude.toString();
//
//               debugPrint("======================================");
//               debugPrint("📍 CURRENT LOCATION");
//               debugPrint("Latitude  => $latitude");
//               debugPrint("Longitude => $longitude");
//             }
//           }
//         } catch (e) {
//           /// 🔥 Location related koi pan error aave to pan
//           /// aagad vadho (API call j thavi joie)
//           debugPrint("❌ Location Error => $e — proceeding without lat/long");
//         }
//       }
//
//       /// ============================================
//       /// 4. GET DEVICE ID
//       /// ============================================
//       String deviceId = "";
//       String deviceName = "";
//
//       try {
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//           deviceId = androidInfo.id;
//           deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
//         } else if (Platform.isIOS) {
//           final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//           deviceId = iosInfo.identifierForVendor ?? "";
//           deviceName = iosInfo.name;
//         }
//       } catch (e) {
//         debugPrint("❌ Device ID Error => $e");
//         deviceId = "";
//       }
//
//       debugPrint("📱 Device ID => $deviceId");
//       debugPrint("======================================");
//
//       /// ============================================
//       /// 5. CREATE QUERY PARAMETERS
//       /// ============================================
//       final Map<String, dynamic> queryParameters = {
//         "latitude": latitude,
//         "longitude": longitude,
//         "device_id": deviceId,
//       };
//
//       debugPrint("📤 LIVE RATE QUERY => $queryParameters");
//
//       /// ============================================
//       /// 6. API CALL — Location hoy ke na hoy, always thavi joie
//       /// ============================================
//       final response = await ApiHelper().getRequestWithQuery(
//         ApiConstants.live_metal_rates,
//         queryParameters: queryParameters,
//         showLoading: false,
//       );
//
//       debugPrint("======================================");
//       debugPrint("📥 LIVE RATE RESPONSE");
//       debugPrint("Status => ${response?.statusCode}");
//       debugPrint("Data => ${response?.data}");
//       debugPrint("======================================");
//
//       if (response == null) {
//         if (!silent && mounted) {
//           AppMessage.error(context, "No response from server.");
//         }
//         return;
//       }
//
//       if (response.statusCode == 200 && response.data["success"] == true) {
//         final data = response.data;
//         if (!mounted) return;
//
//         setState(() {
//           final List newRates = data["data"] ?? [];
//
//           /// 🔥 Color compare karva mate rates update karta
//           /// PEHLA j call karvanu
//           _updateRateColors(newRates);
//
//           rates = newRates;
//
//           source = data["source"]?.toString() ?? "";
//
//           updatedAt = data["updated_at"]?.toString() ?? "";
//         });
//
//         await loadSelectedRate();
//         return;
//       }
//
//       String message = "Failed to load live rates";
//       final dynamic responseData = response.data;
//
//       if (responseData is Map && responseData["message"] != null) {
//         message = responseData["message"].toString();
//       }
//
//       debugPrint("❌ API MESSAGE => $message");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, message);
//       }
//     } catch (e) {
//       debugPrint("======================================");
//       debugPrint("❌ LOAD RATES ERROR => $e");
//       debugPrint("======================================");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, "Failed to load live rates");
//       }
//     }
//   }
//
//   Map<String, bool> expandedSections = {};
//   int? expandedIndex;
//   String getGreeting() {
//     final hour = DateTime.now().hour;
//
//     if (hour >= 5 && hour < 12) {
//       return "Good Morning 👋";
//     } else if (hour >= 12 && hour < 17) {
//       return "Good Afternoon ☀️";
//     } else if (hour >= 17 && hour < 21) {
//       return "Good Evening 🌇";
//     } else {
//       return "Good Night 🌙";
//     }
//   }
//
//   String selectedSymbol = "GOLD";
//   Map<String, dynamic>? selectedRate;
//   List<Map<String, dynamic>> allMenuItems = [
//     {
//       "title": "Person",
//       "icon": Icons.person_add,
//       "module": "customer",
//       "screen": const Customerscreen(),
//       "section": "Management",
//       "prefix": "person",
//     },
//     {
//       "title": "Users",
//       "icon": Icons.people,
//       "module": "user",
//       "screen": const Userscreen(),
//       "section": "Management",
//       "prefix": "user",
//     },
//     {
//       "title": "Category",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const Categoryscreen(),
//       "section": "Management",
//       "prefix": "category-person",
//     },
//     {
//       "title": "Office Access",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const OfficeAccessSettingsScreen(),
//       "section": "Management",
//       "prefix": "office-access",
//     },
//     {
//       "title": "Sales Estimate",
//       "icon": Icons.sell,
//       "module": "sale",
//       "screen": const SellList(),
//       "section": "Sales",
//       "prefix": "sale",
//     },
//     {
//       "title": "Sale on Approvals",
//       "icon": Icons.qr_code,
//       "module": "approval",
//       "screen": const InvoiceScreen(),
//       "section": "Sales",
//       "prefix": "approval", // ✅ "view" hatavi nakhyu
//     },
//     {
//       "title": "Approval Return",
//       "icon": Icons.sell,
//       "module": "approval_return",
//       "screen": const Approvalreturnscreen(),
//       "section": "Sales",
//       "prefix": "approval-return",
//     },
//     {
//       "title": "Rec-Ret-Purchase",
//       "icon": Icons.sell,
//       "module": "sale_advance",
//       "screen": const Receivevoucharscreen(),
//       "section": "Sales",
//       "prefix": "sale-advance",
//     },
//     // {
//     //   "title": "Reports",
//     //   "icon": Icons.bar_chart,
//     //   "screen": const DiamondReportsFullUI(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "reports",
//     // },
//     // {
//     //   "title": "Scanner",
//     //   "icon": Icons.qr_code_scanner,
//     //   "screen": const PremiumScannerScreen(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "scanner",
//     // },
//     {
//       "title": "Item List",
//       "icon": Icons.add_box,
//       "module": "item",
//       "screen": const Itemscreen(),
//       "section": "Item Management",
//       "prefix": "item",
//     },
//     {
//       "title": "Label Config",
//       "icon": Icons.production_quantity_limits,
//       "module": "label_config",
//       "screen": const Labelscreen(),
//       "section": "Item Management",
//       "prefix": "label-config",
//     },
//     {
//       "title": "Label Items",
//       "icon": Icons.label_important_outlined,
//       "module": "item_set",
//       "screen": const label_item_screen(),
//       "section": "Item Management",
//       "prefix": "item-set",
//     },
//     {
//       "title": "Label Printing",
//       "icon": Icons.print,
//       "screen": const LabelPrintScreen(),
//       "section": "Item Management",
//       "prefix": "label-print",
//     },
//     {
//       "title": "Other Charges",
//       "icon": Icons.settings_applications,
//       "module": "other_charge",
//       "screen": const Othersscreen(),
//       "section": "Item Management",
//       "prefix": "other-charge",
//     },
//     {
//       "title": "Labour Formula",
//       "icon": Icons.add_box,
//       "module": "labour_formula",
//       "screen": const JobLabourformulaScreen(),
//       "section": "JobWork Management",
//       "prefix": "labour-formula",
//     },
//     {
//       "title": "Production Cost",
//       "icon": Icons.production_quantity_limits,
//       "module": "production_cost",
//       "screen": const Productioncost(),
//       "section": "JobWork Management",
//       "prefix": "production-cost",
//     },
//     {
//       "title": "Production Step",
//       "icon": Icons.label_important_outlined,
//       "module": "production_step",
//       "screen": const Prooductionstepscreen(),
//       "section": "JobWork Management",
//       "prefix": "production-step",
//     },
//     // {
//     //   "title": "Job Worker",
//     //   "icon": Icons.print,
//     //   "module": "job_worker",
//     //   "screen": const Jobworkerscreen(),
//     //   "section": "JobWork Management",
//     //   "prefix": "job-worker",
//     // },
//     {
//       "title": "Jobwork Issue",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_issue",
//       "screen": const JobworkIssueScreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-issue",
//     },
//     {
//       "title": "Jobwork Receive",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_receive",
//       "screen": const Jobworkreceivescreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-receive",
//     },
//     {
//       "title": "Sales Summary",
//       "icon": Icons.add_box,
//       "screen": const Salesumryreport(),
//       "section": "Report Management",
//       "prefix": "report-sales-summary",
//     },
//     {
//       "title": "Receiver Summary",
//       "icon": Icons.production_quantity_limits,
//       "screen": const Purchasereciversummary(),
//       "section": "Report Management",
//       "prefix": "report-purchase-receiver-summary",
//     },
//     {
//       "title": "Stock Position",
//       "icon": Icons.label_important_outlined,
//       "screen": const Stockpositionreport(),
//       "section": "Report Management",
//       "prefix": "report-stock-position",
//     },
//     {
//       "title": "Approval Outstanding",
//       "icon": Icons.print,
//       "screen": const Approvaloutstandingreport(),
//       "section": "Report Management",
//       "prefix": "report-approval-outstanding",
//     },
//     {
//       "title": "Barcode History",
//       "icon": Icons.settings_applications,
//       "screen": const Barcodehistory(),
//       "section": "Report Management",
//       "prefix": "report-barcode-history",
//     },
//     {
//       "title": "Outstanding Amount",
//       "icon": Icons.settings_applications,
//       "screen": const Outstandingamount(),
//       "section": "Report Management",
//       "prefix": "report-outstanding-amount",
//     },
//     {
//       "title": "Worker Loss",
//       "icon": Icons.settings_applications,
//       "screen": const WorkerLossReportScreen(),
//       "section": "Report Management",
//       "prefix": "report-worker-loss",
//     },
//     {
//       "title": "Approval Summary",
//       "icon": Icons.settings_applications,
//       "screen": const ApprovalSummaryScreen(),
//       "section": "Report Management",
//       "prefix": "report-worker-loss",
//     },
//     {
//       "title": "Approval Register",
//       "icon": Icons.settings_applications,
//       "screen": const ApprovalReturnRegisterScreen(),
//       "section": "Report Management",
//       "prefix": "report-worker-loss",
//     },
//     {
//       "title": "Roles",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Rolescreen(),
//       "section": "Role Management",
//       "prefix": "role",
//     },
//     {
//       "title": "Permissions",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Permissionscreen(),
//       "section": "Role Management",
//       "prefix": "permission",
//     },
//     {
//       "title": "Buch",
//       "icon": Icons.settings,
//       "module": "vacuum_buch",
//       "screen": const Buchscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-buch",
//     },
//     {
//       "title": "Process",
//       "icon": Icons.settings,
//       "module": "vacuum_process",
//       "screen": const Processscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-process",
//     },
//     {
//       "title": "Vacuum Voucher",
//       "icon": Icons.settings,
//       "module": "vacuum_voucher",
//       "screen": const Voucherscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-voucher",
//     },
//     {
//       "title": "Casting Heating",
//       "icon": Icons.settings,
//       "module": "casting_heating",
//       "screen": const Castingheatingscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-heating",
//     },
//     {
//       "title": "Casting Metal",
//       "icon": Icons.settings,
//       "module": "casting_metal_issue",
//       "screen": const Castingmetalscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-metal-issue",
//     },
//     {
//       "title": "Casting Receive",
//       "icon": Icons.settings,
//       "module": "casting_release",
//       "screen": const Castingrecivescreen(),
//       "section": "Casting Management",
//       "prefix": "casting-release",
//     },
//     {
//       "title": "Tree Cutting Office",
//       "icon": Icons.settings,
//       "module": "tree_cutting_office",
//       "screen": const Treecuttingoffice(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-office",
//     },
//     {
//       "title": "Tree Cutting Issue",
//       "icon": Icons.settings,
//       "module": "tree_cutting_issue",
//       "screen": const Treecuttingissuescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-issue",
//     },
//     {
//       "title": "Tree Cutting Receive",
//       "icon": Icons.settings,
//       "module": "tree_cutting_receive",
//       "screen": const Treecuttingreceivescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-receive",
//     },
//     {
//       "title": "Casting Sorting",
//       "icon": Icons.settings,
//       "module": "casting_sorting",
//       "screen": const Castingsortscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-sorting",
//     },
//
//     {
//       "title": "Voucher History",
//       "icon": Icons.settings,
//       "module": "voucher-history",
//       "screen": const VoucherProcessHistoryScreen(),
//       "section": "Casting Management",
//       "prefix": "voucher-history",
//     },
//   ];
//
//   /// 🔥 DASHBOARD SELECTED ITEMS
//   List<Map<String, dynamic>> dashboardItems = [];
//   String name = "";
//   String email = "";
//   String companyName = "";
//   String State = "";
//   String City = "";
//   String Role = "";
//   String companyLogo = "";
//
//   Future<bool> readModule(String module) async {
//     try {
//       final response = await ApiHelper().postRequest(
//         "${ApiConstants.baseUrl}notifications/read-module",
//         {"module": module},
//       );
//
//       print("Read Module Response : ${response?.data}");
//
//       return response != null &&
//           response.statusCode == 200 &&
//           response.data["success"] == true;
//     } catch (e) {
//       print("Read Module Error : $e");
//       return false;
//     }
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//
//     loadExpandedSections(); // 👈 ADD THIS
//     loadSectionOrder(); // 👈 ADD THIS
//     loadSelectedRate();
//     getCompanyProfile();
//     /// 🔥 Auto refresh every 30 seconds
//     // autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//     //   loadRates(silent: true);
//     // });
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<NotificationProvider>().loadNotificationCount();
//     });
//
//     /// 🔥 IMPORTANT: getCompanyProfile() have role load thai gaya pachi
//     /// j loadRates() call kare che (andar), etle e ne j direct call karo.
//     /// loadRates() ne ahi thi direct call NA karo — nahi to role khali
//     /// hova thi admin check khoto padi shake ane location popup fasi jay.
//
//
//     //updateSectionOrder();
//     /// 🔥 DEFAULT DASHBOARD ITEMS
//     loadDashboardItems();
//     loadBottomNavItems(); // 🔥 ADD
//   }
//
//   Future<void> loadSelectedRate() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     selectedSymbol = prefs.getString("selected_rate_symbol") ?? "GOLD";
//
//     updateSelectedRate();
//
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   void updateSelectedRate() {
//     if (rates.isEmpty) return;
//
//     try {
//       selectedRate = rates.firstWhere((e) => e["symbol"] == selectedSymbol);
//     } catch (e) {
//       selectedRate = rates.first;
//     }
//   }
//
//   /// ============================================================
//   /// 🔥 Raw numeric rate kadhva mate
//   ///
//   /// "formatted_rate" ma comma (,) ke ₹ symbol hoy to pan
//   /// clean double value male e mate.
//   /// ============================================================
//   double? _parseRateValue(dynamic item) {
//     final dynamic raw = item["rate"] ?? item["formatted_rate"];
//     if (raw == null) return null;
//
//     final String cleaned = raw
//         .toString()
//         .replaceAll(",", "")
//         .replaceAll("₹", "")
//         .trim();
//
//     return double.tryParse(cleaned);
//   }
//
//   /// ============================================================
//   /// 🔥 Naya rates aavya pachi dareek symbol nu color update karo
//   ///
//   /// - Rate vadhyu  → Green
//   /// - Rate ghatyu  → Red
//   /// - Same rahyu   → Pehla no color j rakho (change nathi karvanu)
//   ///
//   /// IMPORTANT: Aa function ne `rates` variable update karta
//   /// PEHLA call karvanu, nahi to old vs new compare kai nahi thashe.
//   /// ============================================================
//   void _updateRateColors(List newRatesList) {
//     for (var item in newRatesList) {
//       final String symbol = item["symbol"]?.toString() ?? "";
//       if (symbol.isEmpty) continue;
//
//       final double? newRate = _parseRateValue(item);
//       if (newRate == null) continue;
//
//       if (_previousRateValues.containsKey(symbol)) {
//         final double oldRate = _previousRateValues[symbol]!;
//
//         if (newRate > oldRate) {
//           _rateColors[symbol] = const Color(0xff2ECC71); // 🟢 Green
//         } else if (newRate < oldRate) {
//           _rateColors[symbol] = const Color(0xffE53935); // 🔴 Red
//         }
//         // Equal hoy to jado color j rahese
//       }
//
//       _previousRateValues[symbol] = newRate;
//     }
//   }
//
//   Future<void> loadBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String>? savedTitles = prefs.getStringList("bottom_nav_items");
//
//     List<Map<String, dynamic>> customItems = [];
//
//     if (savedTitles != null && savedTitles.isNotEmpty) {
//       for (var title in savedTitles) {
//         var match = allMenuItems.firstWhere(
//               (e) => e["title"] == title,
//           orElse: () => {},
//         );
//         if (match.isNotEmpty) {
//           customItems.add({
//             "title": match["title"],
//             "icon": match["icon"],
//             "screen": match["screen"],
//           });
//         }
//       }
//     }
//
//     setState(() {
//       bottomItems = [
//         {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//         ...customItems,
//         {"title": "More", "icon": Icons.more_horiz},
//       ];
//     });
//   }
//
//   Future<void> saveBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     List<String> titles = bottomItems
//         .where((e) => e["title"] != "Dashboard" && e["title"] != "More")
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("bottom_nav_items", titles);
//   }
//
//   void updateSectionOrder(
//       Map<String, List<Map<String, dynamic>>> groupedItems,
//       ) {
//     // Naya section keys (jaisi "Others") ne add karo jo already sectionOrder ma nathi
//     for (var key in groupedItems.keys) {
//       if (!sectionOrder.contains(key)) {
//         sectionOrder.add(key);
//       }
//     }
//
//     // Je sections have exist nathi karta groupedItems ma, ene sectionOrder thi remove karo
//     sectionOrder.removeWhere((s) => !groupedItems.containsKey(s));
//   }
//
//   Future<void> loadDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> excludedTitles =
//         prefs.getStringList("excluded_dashboard_items") ?? [];
//
//     /// 🔥 Have allMenuItems (je already permission pramane filtered che)
//     /// ma thi j dashboard items lese — jetli pan API permission hoy e badha
//     /// automatic dashboard par dekhashe (jo user e manually remove na karyu hoy to)
//     List<Map<String, dynamic>> tempItems = allMenuItems
//         .where((item) => !excludedTitles.contains(item["title"]))
//         .toList();
//
//     setState(() {
//       dashboardItems = tempItems;
//       _updateSectionOrderForNewItems();
//     });
//   }
//
//   Future<void> saveDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     /// 🔥 jetla items allMenuItems ma che pan dashboardItems ma nathi
//     /// (user e remove karya che), e excluded list ma save karo
//     List<String> excludedTitles = allMenuItems
//         .where((m) => !dashboardItems.any((d) => d["title"] == m["title"]))
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("excluded_dashboard_items", excludedTitles);
//
//     /// (Optional) jo old key "dashboard_items" use thato hoy biji jagya pan,
//     /// e clear/remove kari shako ke rehva dyo, have e use nathi thato
//   }
//
//   // એક હેલ્પર ફંક્શન સેક્શન ઓર્ડર મેન્ટેન કરવા માટે
//   void _updateSectionOrderForNewItems() {
//     final Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//
//     for (final item in dashboardItems) {
//       final String section = item["section"] ?? "Others";
//
//       tempGrouped.putIfAbsent(section, () => []);
//       tempGrouped[section]!.add(item);
//     }
//
//     final List<String> newOrder = [];
//
//     /// =========================================
//     /// CURRENT ACTIVE SECTION ALWAYS FIRST
//     /// =========================================
//     if (activeSection != null && tempGrouped.containsKey(activeSection)) {
//       newOrder.add(activeSection!);
//     }
//
//     /// =========================================
//     /// OLD ORDER MAINTAIN
//     /// =========================================
//     for (final section in sectionOrder) {
//       if (tempGrouped.containsKey(section) && !newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     /// =========================================
//     /// NEW SECTIONS ADD
//     /// =========================================
//     for (final section in tempGrouped.keys) {
//       if (!newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     if (!mounted) return;
//
//     setState(() {
//       sectionOrder = newOrder;
//
//       /// Active section open
//       if (activeSection != null) {
//         for (final section in sectionOrder) {
//           expandedSections[section] = section == activeSection;
//         }
//       }
//     });
//   }
//
//   Future<void> getCompanyProfile() async {
//     try {
//       final response = await ApiHelper().getRequest(ApiConstants.userProfile);
//
//       if (response == null) {
//         print("❌ No response — default dashboard load karo");
//         await loadDashboardItems();
//
//         /// 🔥 Profile na male to pan rates load karvo padse (role
//         /// khabar nathi etle _isAdminRole() SharedPreferences mathi
//         /// old saved role check karshe, jo pehla login karyu hoy).
//         await loadRates(silent: true);
//         return;
//       }
//
//       if (response.statusCode == 200) {
//         final jsonData = response.data;
//         final userData = jsonData["data"] ?? {};
//         final companyData = userData["company"] ?? {};
//
//         // ============================================================
//         // PROFILE DATA
//         // ============================================================
//
//         final profileData = userData["profile"] ?? {};
//
//         // ============================================================
//         // PERMISSIONS
//         // ============================================================
//
//         final List permissionsRaw =
//             profileData["permissions"] ?? jsonData["permissions"] ?? [];
//
//         final List<String> permissions = permissionsRaw
//             .map((e) => e.toString())
//             .toList();
//
//         // ============================================================
//         // ROLE NAMES
//         // ============================================================
//
//         final List roleNamesRaw = profileData["role_names"] ?? [];
//
//         final List<String> roleNames = roleNamesRaw
//             .map((e) => e.toString())
//             .toList();
//
//         print("✅ User Permissions: $permissions");
//         print("✅ User Role Names: $roleNames");
//
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//
//         setState(() {
//           name = userData["name"]?.toString() ?? "-";
//           email = userData["email"]?.toString() ?? "-";
//           companyName = companyData["name"]?.toString() ?? "-";
//           City = companyData["city"]?.toString() ?? "-";
//           State = companyData["state"]?.toString() ?? "-";
//           companyLogo= companyData["company_logo_url"]?.toString() ?? "-";
//
//           // Save permissions
//           userPermissions = permissions;
//
//           // Save role names
//           userRoleNames = roleNames;
//
//           // Permission filtering
//           filterMenuByPermission();
//         });
//
//         // ============================================================
//         // SAVE USER DATA
//         // ============================================================
//
//         await prefs.setString("name", userData["name"]?.toString() ?? "-");
//
//         await prefs.setString("email", userData["email"]?.toString() ?? "-");
//
//         await prefs.setString(
//           "companyName",
//           companyData["name"]?.toString() ?? "-",
//         );
//
//         await prefs.setString("city", companyData["city"]?.toString() ?? "-");
//
//         await prefs.setString(
//           "state",
//           companyData["state"]?.toString() ?? "-",
//         );
//
//         await prefs.setString("companyLogo", companyData["company_logo_url"]?.toString() ?? "-");
//         await prefs.setString("role", userData["role"]?.toString() ?? "-");
//
//         await prefs.setStringList("user_permissions", userPermissions);
//
//         await prefs.setStringList("user_role_names", userRoleNames);
//
//         // ============================================================
//         // LOAD DASHBOARD
//         // ============================================================
//
//         await loadDashboardItems();
//
//         /// 🔥 IMPORTANT: role (userRoleNames) have set thai gayu che,
//         /// etle have j loadRates() call karo — jethi admin role hoy
//         /// to location popup skip thay, first-time login par pan.
//         await loadRates(silent: true);
//
//         // ============================================================
//         // 🔥 PLAN ALERT POPUP
//         //
//         // company["plan_alert"]["show_popup"] == true hoy to j popup
//         // dekhadvanu. Frame render thai gaya pachi j dialog kholvi
//         // jaruri che, nahi to context still-building error aave.
//         // ============================================================
//
//         final Map planAlert = companyData["plan_alert"] ?? {};
//
//         if (planAlert["show_popup"] == true && !_planAlertShown) {
//           _planAlertShown = true;
//
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (mounted) {
//               _showPlanAlertDialog(planAlert);
//             }
//           });
//         }
//       } else {
//         // API fail
//         await loadDashboardItems();
//
//         /// 🔥 Profile fail thay to pan rates load karvo padse —
//         /// role SharedPreferences mathi (jo pehla save thayu hoy to) male.
//         await loadRates(silent: true);
//       }
//     } catch (e) {
//       print("❌ Exception: $e");
//
//       // Exception aave to default dashboard load
//       await loadDashboardItems();
//
//       /// 🔥 Exception case ma pan rates load karo.
//       await loadRates(silent: true);
//     }
//   }
//
//   /// ============================================================
//   /// 🔥 PLAN ALERT TYPE -> COLOR / ICON MAPPING
//   /// ============================================================
//   Color _planAlertColor(String type) {
//     switch (type.toLowerCase()) {
//       case "expired":
//         return const Color(0xffE53935);
//       case "warning":
//       case "expiring_soon":
//       case "expiring":
//         return const Color(0xffFF9800);
//       case "active":
//         return const Color(0xff2ECC71);
//       default:
//         return AppColors.primaryDark;
//     }
//   }
//
//   IconData _planAlertIcon(String type) {
//     switch (type.toLowerCase()) {
//       case "expired":
//         return Icons.error_outline_rounded;
//       case "warning":
//       case "expiring_soon":
//       case "expiring":
//         return Icons.warning_amber_rounded;
//       case "active":
//         return Icons.check_circle_outline_rounded;
//       default:
//         return Icons.info_outline_rounded;
//     }
//   }
//
//   String _v(dynamic value) {
//     if (value == null || value.toString().trim().isEmpty) return "-";
//     return value.toString();
//   }
//
//   /// ============================================================
//   /// 🔥 NON-CLOSABLE PLAN ALERT POPUP
//   ///
//   /// - barrierDismissible: false  → bahar tap karta band nathi thatu
//   /// - PopScope(canPop: false)    → back button/gesture thi band nathi thatu
//   /// - No close/OK button         → user koi rite j popup close nathi kari shakto
//   /// ============================================================
//   void _showPlanAlertDialog(Map planAlert) {
//     final String type = (planAlert["type"] ?? "").toString();
//
//     final String title = _v(planAlert["title"]);
//     final String message = _v(planAlert["message"]);
//     final String contactName = _v(planAlert["contact_name"]);
//     final String contactMessage = _v(planAlert["contact_message"]);
//
//     final Color alertColor = _planAlertColor(type);
//     final IconData alertIcon = _planAlertIcon(type);
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       barrierColor: Colors.black.withOpacity(0.55),
//       builder: (dialogContext) {
//         return PopScope(
//           canPop: false,
//           child: Dialog(
//             backgroundColor: Colors.transparent,
//             insetPadding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Container(
//               width: double.infinity,
//               padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//                     blurRadius: 24,
//                     offset: const Offset(0, 12),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   /// ICON
//                   Container(
//                     height: 60,
//                     width: 60,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: alertColor.withOpacity(0.12),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(alertIcon, color: alertColor, size: 32),
//                   ),
//
//                   const SizedBox(height: 16),
//
//                   /// TITLE
//                   Text(
//                     title,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 17,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
//
//                   const SizedBox(height: 8),
//
//                   /// MESSAGE
//                   Text(
//                     message,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: Colors.grey.shade700,
//                       height: 1.4,
//                     ),
//                   ),
//
//                   /// CONTACT INFO (jo available hoy)
//                   if (contactName != "-" || contactMessage != "-") ...[
//                     const SizedBox(height: 16),
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: AppColors.background,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: AppColors.border),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           if (contactName != "-")
//                             Row(
//                               children: [
//                                 Icon(
//                                   Icons.support_agent_rounded,
//                                   size: 15,
//                                   color: AppColors.primaryDark,
//                                 ),
//                                 const SizedBox(width: 6),
//                                 Text(
//                                   contactName,
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w700,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           if (contactMessage != "-") ...[
//                             const SizedBox(height: 4),
//                             Text(
//                               contactMessage,
//                               style: TextStyle(
//                                 fontSize: 11.5,
//                                 color: Colors.grey.shade600,
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ],
//
//                   /// 🔥 NO CLOSE / OK BUTTON — popup close na thai shake
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void filterMenuByPermission() {
//     allMenuItems = allMenuItems.where((item) {
//       String prefix = item["prefix"].toString();
//
//       /// 🔥 Koi pan permission e prefix thi shuru thatu hoy (view/create/edit/delete/manage)
//       /// to e module dikhse
//       return userPermissions.contains("$prefix-view") ||
//           userPermissions.contains("$prefix-manage") ||
//           userPermissions.contains("$prefix-create") ||
//           userPermissions.contains("$prefix-edit") ||
//           userPermissions.contains("$prefix-delete");
//     }).toList();
//   }
//
//   bool isExpanded = false;
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.white,
//       drawer: const GlobalDrawer(),
//       extendBody: true,
//       extendBodyBehindAppBar: true, // IMPORTANT
//       //backgroundColor: AppColors.scaffoldBg,
//       bottomNavigationBar: customBottomNav(),
//       body: Stack(
//         children: [
//           /// ✅ Main Content
//           Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).size.height * 0.09),
//
//               const SizedBox(height: 10),
//
//               /// 🔥 ONLY THIS PART SCROLLABLE
//               Expanded(
//                 child: SingleChildScrollView(
//                   // 👈 ListView ના બદલે આ વાપરો
//                   padding: EdgeInsets.zero,
//                   child: Column(
//                     // 👈 અંદર એક Column ઉમેરો
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 10),
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 350),
//                           curve: Curves.easeInOut,
//                           height: isExpanded ? 240 : 75,
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             gradient: LinearGradient(
//                               colors: [
//                                 AppColors.primaryDark,
//                                 AppColors.secondaryDark,
//                               ],
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(.15),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 5),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               /// HEADER
//                               InkWell(
//                                 onTap: () {
//                                   setState(() {
//                                     isExpanded = !isExpanded;
//                                   });
//                                 },
//                                 child: Container(
//                                   height: 75,
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 15,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       /// LEFT
//                                       Expanded(
//                                         child: Column(
//                                           mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               getGreeting(),
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 3),
//
//                                             Text(
//                                               DateFormat(
//                                                 "dd MMM yyyy",
//                                               ).format(DateTime.now()),
//                                               style: const TextStyle(
//                                                 color: Colors.white70,
//                                                 fontSize: 13,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       /// CENTER
//                                       selectedRate == null
//                                           ? const SizedBox()
//                                           : GestureDetector(
//                                         onTap: () {
//                                           Navigator.push(
//                                             context,
//                                             MaterialPageRoute(
//                                               builder: (context) =>
//                                               const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                             ),
//                                           );
//                                         },
//                                         child: Container(
//                                           padding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 10,
//                                             vertical: 6,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: Colors.white
//                                                 .withOpacity(0.12),
//                                             borderRadius:
//                                             BorderRadius.circular(5),
//                                           ),
//                                           child: Column(
//                                             mainAxisSize: MainAxisSize
//                                                 .min, // 👈 જરૂરી
//                                             crossAxisAlignment:
//                                             CrossAxisAlignment.center,
//                                             children: [
//                                               Text(
//                                                 selectedRate!["symbol"],
//                                                 style: const TextStyle(
//                                                   color: Colors.white70,
//                                                   fontSize: 12,
//                                                   fontWeight:
//                                                   FontWeight.w500,
//                                                 ),
//                                               ),
//                                               const SizedBox(height: 0),
//
//                                               /// 🔥 RATE VALUE — have up/down pramane
//                                               /// green/red color aapiye chiye. Jo koi
//                                               /// color track na thayu hoy (first load)
//                                               /// to default white j rehse.
//                                               Text(
//                                                 "₹${selectedRate!["formatted_rate"]}",
//                                                 style: TextStyle(
//                                                   color: _rateColors[selectedRate!["symbol"]] ??
//                                                       Colors.white,
//                                                   fontSize: 16,
//                                                   fontWeight:
//                                                   FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//
//                                       const SizedBox(width: 0),
//
//                                       AnimatedRotation(
//                                         turns: isExpanded ? .5 : 0,
//                                         duration: const Duration(
//                                           milliseconds: 300,
//                                         ),
//                                         child: const Icon(
//                                           Icons.keyboard_arrow_down,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//
//                               /// EXPAND AREA
//                               Expanded(
//                                 child: AnimatedCrossFade(
//                                   duration: const Duration(milliseconds: 300),
//                                   crossFadeState: isExpanded
//                                       ? CrossFadeState.showSecond
//                                       : CrossFadeState.showFirst,
//
//                                   firstChild: const SizedBox(),
//
//                                   secondChild: Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 10,
//                                     ),
//                                     child: Column(
//                                       children: [
//                                         buildFirstRowStats(),
//                                         const SizedBox(height: 10),
//                                         buildSecondRowStats(),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       metalRateMarquee(),
//                       const SizedBox(height: 10),
//                       Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 10),
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(10),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.06),
//                               blurRadius: 15,
//                               offset: const Offset(0, 5),
//                             ),
//                           ],
//                         ),
//
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Header
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 const Text(
//                                   "New Features",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w700,
//                                     color: Color(0xff14213D),
//                                   ),
//                                 ),
//
//                                 Row(
//                                   children: [
//                                     Text(
//                                       "View All",
//                                       style: TextStyle(
//                                         color: AppColors.primaryDark,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//
//                                     const SizedBox(width: 5),
//
//                                     Container(
//                                       height: 22,
//                                       width: 22,
//                                       decoration: BoxDecoration(
//                                         color: Color(0xffEEF3FF),
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: Icon(
//                                         Icons.arrow_forward_ios,
//                                         size: 12,
//                                         color: AppColors.primaryDark,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             // Options
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 optionItem(
//                                   Icons.bar_chart,
//                                   "BG Remove",
//                                   Color(0xff6C35FF),
//                                   Color(0xffF2EEFF),
//                                 ),
//
//                                 optionItem(
//                                   Icons.inventory_2,
//                                   "Visiting Card",
//                                   Color(0xff00C853),
//                                   Color(0xffEFFFF4),
//                                   onTap: (){
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const PremiumHomeUI(),
//                                       ),
//                                     );
//                                   }
//                                 ),
//
//                                 optionItem(
//                                   Icons.monitor_sharp,
//                                   "Live Rate",
//                                   Color(0xffff9800),
//                                   Color(0xfffff5e8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                                 optionItem(
//                                   Icons.qr_code,
//                                   "ALL QR",
//                                   Color(0xff6A35FF),
//                                   Color(0xffF3EEFF),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const QrListScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                                 // optionItem(
//                                 //   Icons.credit_card,
//                                 //   "Payments",
//                                 //   Color(0xff00BCD4),
//                                 //   Color(0xffE8FBFF),
//                                 // ),
//                                 //
//                                 //
//                                 optionItem(
//                                   Icons.settings,
//                                   "Settings",
//                                   Color(0xff7A8499),
//                                   Color(0xffF4F5F8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const SettingsScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                       popularProductsSection(context),
//                       const SizedBox(
//                         height: 80,
//                       ), // છેલ્લે થોડી જગ્યા આપો (Bottom Nav માટે)
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           /// 🔥 APPBAR CALL HERE
//           buildAppBar(context),
//         ],
//       ),
//       floatingActionButton: Container(
//         height: 45,
//         width: 45,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: const LinearGradient(
//             colors: [AppColors.primaryDark, AppColors.secondaryDark],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black26,
//               blurRadius: 10,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//
//         child: FloatingActionButton(
//           onPressed: () {
//             showMenuSelectionDialog(isBottomNavMode: false);
//           },
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           child: const Icon(Icons.edit, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
//
//   Widget buildAppBar(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final isMobile = width < 600;
//
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: SafeArea(
//         child: Container(
//           padding: EdgeInsets.symmetric(
//             horizontal: isMobile ? 12 : 10,
//             vertical: 0,
//           ),
//
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               /// 🔥 CENTER TITLE
//               Center(
//                 child: Image.asset(
//                   "assets/static/text.png",
//                   height: 30,
//                   width: 200,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//
//               /// LEFT + RIGHT ROW
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   /// LEFT MENU
//                   Row(
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           _scaffoldKey.currentState?.openDrawer();
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//                           decoration: BoxDecoration(
//                             color: AppColors.primaryDark,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                           child: Icon(
//                             Icons.menu,
//                             size: isMobile ? 20 : 24,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   /// RIGHT ICONS
//                   Row(
//                     children: [
//                       Consumer<NotificationProvider>(
//                         builder: (context, provider, child) {
//                           return GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const NotificationScreen(),
//                                 ),
//                               );
//
//                               // Notification screen mathi pachha aavya pachi count refresh
//                               provider.loadNotificationCount();
//                             },
//                             child: Container(
//                               padding: EdgeInsets.all(isMobile ? 6 : 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 20,
//                                     offset: const Offset(5, 10),
//                                   ),
//                                 ],
//                               ),
//                               child: Stack(
//                                 clipBehavior: Clip.none,
//                                 children: [
//                                   Icon(
//                                     Icons.notifications_none,
//                                     size: isMobile ? 22 : 24,
//                                     color: Colors.red,
//                                   ),
//
//                                   if (provider.total > 0)
//                                     Positioned(
//                                       right: -5,
//                                       top: -8,
//                                       child: Container(
//                                         padding: const EdgeInsets.all(3),
//                                         constraints: const BoxConstraints(
//                                           minWidth: 18,
//                                           minHeight: 18,
//                                         ),
//                                         decoration: const BoxDecoration(
//                                           color: Colors.red,
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Center(
//                                           child: Text(
//                                             provider.total > 99
//                                                 ? "99+"
//                                                 : provider.total.toString(),
//                                             style: const TextStyle(
//                                               color: Colors.white,
//                                               fontSize: 9,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//
//                       // SizedBox(width: isMobile ? 8 : 12),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Widget popularProductsSection(BuildContext context) {
//   //   final width = MediaQuery.of(context).size.width;
//   //
//   //   int crossAxisCount() {
//   //     if (width < 600) return 3;
//   //     if (width < 900) return 3;
//   //     if (width < 1200) return 4;
//   //     return 5;
//   //   }
//   //
//   //   double childAspectRatio() {
//   //     if (width < 600) return 0.94;
//   //     if (width < 900) return 1.1;
//   //     return 1.2;
//   //   }
//   //
//   //   // --- GROUPING LOGIC (તમારો ઓરિજિનલ કોડ) ---
//   //   Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//   //   for (var item in dashboardItems) {
//   //     String section = item["section"] ?? "Other";
//   //     if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//   //     tempGrouped[section]!.add(item);
//   //   }
//   //
//   //   Map<String, List<Map<String, dynamic>>> groupedItems = {};
//   //   List<Map<String, dynamic>> otherItems = [];
//   //   tempGrouped.forEach((section, items) {
//   //     if (items.length == 1) {
//   //       otherItems.addAll(items);
//   //     } else {
//   //       groupedItems[section] = items;
//   //     }
//   //   });
//   //   if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//   //
//   //   // સેક્શન ઓર્ડર અપડેટ કરો
//   //   updateSectionOrder(groupedItems);
//   //
//   //   return Padding(
//   //     padding: const EdgeInsets.all(10.0),
//   //     child: ReorderableListView(
//   //       shrinkWrap: true,
//   //       physics: const NeverScrollableScrollPhysics(),
//   //       onReorder: _onReorder,
//   //       // ડ્રેગ કરતી વખતે બેકગ્રાઉન્ડ કલર ટ્રાન્સપરન્ટ રાખવા માટે (Optional)
//   //       proxyDecorator: (child, index, animation) => child,
//   //       children: sectionOrder.map((sectionName) {
//   //         // જો ગ્રુપમાં આ સેક્શન ન હોય તો ખાલી કન્ટેનર રિટર્ન કરો
//   //         if (!groupedItems.containsKey(sectionName))
//   //           return SizedBox(key: ValueKey(sectionName));
//   //
//   //         List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//   //
//   //         return Container(
//   //           key: ValueKey(sectionName), // Reorderable માટે યુનિક કી
//   //           margin: const EdgeInsets.only(bottom: 16),
//   //           padding: const EdgeInsets.all(12),
//   //           decoration: BoxDecoration(
//   //             color: Colors.white,
//   //             borderRadius: BorderRadius.circular(14),
//   //             border: Border.all(color: AppColors.border),
//   //             boxShadow: [
//   //               BoxShadow(
//   //                 color: Colors.black.withOpacity(0.05),
//   //                 blurRadius: 8,
//   //                 offset: const Offset(0, 3),
//   //               ),
//   //             ],
//   //           ),
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               /// 🔥 SECTION TITLE (હવે આ આખી રો ડ્રેગ હેન્ડલ તરીકે કામ કરશે)
//   //               Row(
//   //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //                 children: [
//   //                   Row(
//   //                     crossAxisAlignment: CrossAxisAlignment.center,
//   //                     children: [
//   //                       Container(
//   //                         padding: const EdgeInsets.all(6),
//   //                         decoration: BoxDecoration(
//   //                           gradient: LinearGradient(
//   //                             colors: [
//   //                               AppColors.primaryDark.withOpacity(0.7),
//   //                               AppColors.secondaryDark.withOpacity(0.7),
//   //                             ],
//   //                           ),
//   //                           borderRadius: BorderRadius.circular(10),
//   //                         ),
//   //                         child: const Icon(
//   //                           Icons.drag_indicator,
//   //                           color: Colors.white,
//   //                           size: 20,
//   //                         ),
//   //                       ),
//   //
//   //                       const SizedBox(width: 10),
//   //
//   //                       Column(
//   //                         mainAxisAlignment: MainAxisAlignment.center,
//   //                         crossAxisAlignment: CrossAxisAlignment.start,
//   //                         mainAxisSize: MainAxisSize.min,
//   //                         children: [
//   //                           Text(
//   //                             sectionName,
//   //                             textAlign: TextAlign.center,
//   //                             style: const TextStyle(
//   //                               fontSize: 15,
//   //                               fontWeight: FontWeight.bold,
//   //                               color: Colors.black,
//   //                             ),
//   //                           ),
//   //
//   //                           Text(
//   //                             getSectionSubtitle(sectionName),
//   //                             style: TextStyle(
//   //                               fontSize: 12,
//   //                               color: AppColors.textLight,
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ],
//   //                   ),
//   //                   Container(
//   //                     padding: const EdgeInsets.symmetric(
//   //                       horizontal: 10,
//   //                       vertical: 3,
//   //                     ),
//   //                     decoration: BoxDecoration(
//   //                       gradient: LinearGradient(
//   //                         colors: [
//   //                           AppColors.primaryDark.withOpacity(0.7),
//   //                           AppColors.secondaryDark.withOpacity(0.7),
//   //                         ],
//   //                       ),
//   //                       borderRadius: BorderRadius.circular(8),
//   //                     ),
//   //                     child: Text(
//   //                       "${items.length} Items",
//   //                       style: const TextStyle(
//   //                         color: Colors.white,
//   //                         fontWeight: FontWeight.w600,
//   //                         fontSize: 12,
//   //                       ),
//   //                     ),
//   //                   ),
//   //                 ],
//   //               ),
//   //               const SizedBox(height: 14),
//   //
//   //               /// 🔥 GRID
//   //               GridView.builder(
//   //                 itemCount: items.length,
//   //                 shrinkWrap: true,
//   //                 physics: const NeverScrollableScrollPhysics(),
//   //                 padding: EdgeInsets.zero,
//   //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//   //                   crossAxisCount: crossAxisCount(),
//   //                   crossAxisSpacing: 12,
//   //                   mainAxisSpacing: 12,
//   //                   childAspectRatio: childAspectRatio(),
//   //                 ),
//   //                 itemBuilder: (context, index) {
//   //                   final item = items[index];
//   //                   final module = item["module"] ?? "";
//   //
//   //                   final count = context
//   //                       .watch<NotificationProvider>()
//   //                       .moduleCount(module);
//   //
//   //                   //print("Module: $module -> Count: $count");
//   //                   return _premiumMenuCard(
//   //                     context,
//   //                     item["title"],
//   //                     item["icon"],
//   //                     () async {
//   //                       readModule(module);
//   //                       final result = await Navigator.push(
//   //                         context,
//   //                         MaterialPageRoute(builder: (_) => item["screen"]),
//   //                       );
//   //
//   //                       // 👇 Child page mathi pop thay pachi
//   //                       if (result == true) {
//   //                         print("Refresh");
//   //                         await getCompanyProfile();
//   //                         setState(() {});
//   //                       }
//   //                     },
//   //                     count: count,
//   //                   );
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //         );
//   //       }).toList(),
//   //     ),
//   //   );
//   // }
//
//   Widget popularProductsSection(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//
//     int crossAxisCount() {
//       if (width < 600) return 3;
//       if (width < 900) return 3;
//       if (width < 1200) return 4;
//       return 5;
//     }
//
//     double childAspectRatio() {
//       if (width < 600) return 0.94;
//       if (width < 900) return 1.1;
//       return 1.2;
//     }
//
//     //--- GROUPING LOGIC (same) ---
//     Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//     for (var item in dashboardItems) {
//       String section = item["section"] ?? "Other";
//       if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//       tempGrouped[section]!.add(item);
//     }
//
//     Map<String, List<Map<String, dynamic>>> groupedItems = {};
//     List<Map<String, dynamic>> otherItems = [];
//     tempGrouped.forEach((section, items) {
//       if (userRoleNames.length == 1) {
//         otherItems.addAll(items);
//       } else {
//         groupedItems[section] = items;
//       }
//     });
//
//     if (otherItems.isNotEmpty) {
//       groupedItems["Others"] = otherItems;
//     }
//     if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//
//     // --- GROUPING LOGIC ---
//
//     //updateSectionOrder(groupedItems);
//
//     return Padding(
//       padding: const EdgeInsets.all(10.0),
//       child: ReorderableListView(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         onReorder: _onReorder,
//         proxyDecorator: (child, index, animation) => child,
//         children: sectionOrder.map((sectionName) {
//           if (!groupedItems.containsKey(sectionName))
//             return SizedBox(key: ValueKey(sectionName));
//
//           List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//
//           /// 🔥 Default expanded state (na hoy to true rakho — pehla khulu j dekhay)
//           // bool isExpanded = expandedSections[sectionName] ?? false;
//           /// 🔥 Fakt PEHLU section default open rahe, baki badha collapsed
//           final bool isExpanded = expandedSections[sectionName] ?? false;
//
//           return Material(
//             key: ValueKey(sectionName),
//             color: Colors.transparent,
//             child: Container(
//               key: ValueKey(sectionName),
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: AppColors.border),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// 🔥 SECTION TITLE — have TAP thi expand/collapse thashe
//                   InkWell(
//                     onTap: () async {
//                       final bool currentlyExpanded =
//                           expandedSections[sectionName] ?? false;
//
//                       setState(() {
//                         /// Pehla badha sections close
//                         for (final section in sectionOrder) {
//                           expandedSections[section] = false;
//                         }
//
//                         /// Jo current section pehla close hato,
//                         /// to fakt ene open karo.
//                         ///
//                         /// Jo already open hato,
//                         /// to badha close j rehse.
//                         if (!currentlyExpanded) {
//                           expandedSections[sectionName] = true;
//                         }
//                       });
//
//                       await saveExpandedSections();
//                     },
//                     borderRadius: BorderRadius.circular(8),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             /// 🔥 Drag handle — have ReorderableDragStartListener thi wrap karyu,
//                             /// jethi fakt AA icon j drag mate vaparay, baki title tap expand/collapse kare
//                             ReorderableDragStartListener(
//                               index: sectionOrder.indexOf(sectionName),
//                               child: Container(
//                                 padding: const EdgeInsets.all(6),
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [
//                                       AppColors.primaryDark.withOpacity(0.7),
//                                       AppColors.secondaryDark.withOpacity(0.7),
//                                     ],
//                                   ),
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                                 child: const Icon(
//                                   Icons.drag_indicator,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 10),
//
//                             Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   sectionName,
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                                 Text(
//                                   getSectionSubtitle(sectionName),
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: AppColors.textLight,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 3,
//                               ),
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark.withOpacity(0.7),
//                                     AppColors.secondaryDark.withOpacity(0.7),
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//                               child: Text(
//                                 "${items.length} Items",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 8),
//
//                             /// 🔥 Expand/Collapse Arrow
//                             AnimatedRotation(
//                               turns: isExpanded ? 0.5 : 0,
//                               duration: const Duration(milliseconds: 250),
//                               child: Container(
//                                 padding: const EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.background,
//                                   borderRadius: BorderRadius.circular(6),
//                                   border: Border.all(color: AppColors.border),
//                                 ),
//                                 child: Icon(
//                                   Icons.keyboard_arrow_down,
//                                   size: 18,
//                                   color: AppColors.primaryDark,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   /// 🔥 GRID — AnimatedCrossFade thi smooth expand/collapse
//                   AnimatedCrossFade(
//                     duration: const Duration(milliseconds: 250),
//                     crossFadeState: isExpanded
//                         ? CrossFadeState.showFirst
//                         : CrossFadeState.showSecond,
//                     firstChild: Padding(
//                       padding: const EdgeInsets.only(top: 14),
//                       child: GridView.builder(
//                         itemCount: items.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         padding: EdgeInsets.zero,
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: crossAxisCount(),
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 12,
//                           childAspectRatio: childAspectRatio(),
//                         ),
//                         itemBuilder: (context, index) {
//                           final item = items[index];
//                           final module = item["module"] ?? "";
//
//                           final count = context
//                               .watch<NotificationProvider>()
//                               .moduleCount(module);
//
//                           return _premiumMenuCard(
//                             context,
//                             item["title"],
//                             item["icon"],
//                                 () async {
//                               /// Notification read
//                               readModule(module);
//
//                               /// 🔥 Navigate karta PEHLA section top + open
//                               //moveSectionToTopAndOpen(sectionName);
//
//                               /// Screen open
//                               final result = await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => item["screen"],
//                                 ),
//                               );
//
//                               if (!mounted) return;
//
//                               /// 🔥 BACK AAVYA PACHI FARITHI ENSURE KARO
//                               //await moveSectionToTopAndOpen(sectionName);
//
//                               /// Data refresh required hoy to
//                               if (result == true) {
//                                 await getCompanyProfile();
//                                 WidgetsBinding.instance.addPostFrameCallback((
//                                     _,
//                                     ) {
//                                   context
//                                       .read<NotificationProvider>()
//                                       .loadNotificationCount();
//                                 });
//
//                                 // /// getCompanyProfile rebuild kare pachi pan
//                                 // /// current section restore karo
//                                 // await moveSectionToTopAndOpen(sectionName);
//                               }
//                             },
//                             count: count,
//                           );
//                         },
//                       ),
//                     ),
//                     secondChild: const SizedBox(width: double.infinity),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _premiumMenuCard(
//       BuildContext context,
//       String title,
//       IconData icon,
//       VoidCallback onTap, {
//         int count = 0,
//       }) {
//     return Material(
//       // 🔥 આ ઉમેરવાથી "No Material found" એરર દૂર થશે
//       color: Colors.transparent, // બેકગ્રાઉન્ડ ટ્રાન્સપરન્ટ રાખવું
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.border),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               /// 🔥 ICON CIRCLE
//               Stack(
//                 clipBehavior: Clip.none,
//                 children: [
//                   Container(
//                     height: 40,
//                     width: 40,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(15),
//                       shape: BoxShape.rectangle,
//                     ),
//                     child: Icon(icon, color: Colors.white, size: 22),
//                   ),
//
//                   /// Notification Count
//                   if (count > 0)
//                     Positioned(
//                       top: -6,
//                       right: -6,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 5,
//                           vertical: 2,
//                         ),
//                         constraints: const BoxConstraints(
//                           minWidth: 18,
//                           minHeight: 18,
//                         ),
//                         decoration: const BoxDecoration(
//                           color: Colors.red,
//                           shape: BoxShape.circle,
//                         ),
//                         alignment: Alignment.center,
//                         child: Text(
//                           count > 99 ? "99+" : "$count",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 9,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//
//               const SizedBox(height: 5),
//
//               /// TITLE
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//   //////////////////////////////////////////////////////////////
//   /// 🔵 PRODUCT CARD
//   //////////////////////////////////////////////////////////////
//
//   Widget productCard(
//       BuildContext context,
//       String title,
//       IconData icon,
//       VoidCallback onTap,
//       ) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//     final isTablet = width > 600;
//
//     return GestureDetector(
//       onTap: onTap,
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//           child: Container(
//             padding: EdgeInsets.all(width * 0.04),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.1),
//                 width: 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 15,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   height: isTablet ? width * 0.10 : width * 0.14,
//                   width: isTablet ? width * 0.10 : width * 0.16,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF1E2A55), Color(0xFF1E2A55)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFF0D1633).withOpacity(0.5),
//                         blurRadius: 20,
//                         offset: const Offset(0, 8),
//                       ),
//                     ],
//                   ),
//                   child: Icon(
//                     icon,
//                     color: Colors.white,
//                     size: isTablet ? width * 0.04 : width * 0.06,
//                   ),
//                 ),
//                 SizedBox(height: height * 0.015),
//                 Text(
//                   title,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: AppColors.white,
//                     fontSize: isTablet ? width * 0.022 : width * 0.035,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget customBottomNav() {
//     final size = MediaQuery.of(context).size;
//     final double width = size.width;
//
//     /// ============================================
//     /// RESPONSIVE BREAKPOINTS
//     /// ============================================
//     final bool isVerySmallPhone = width < 340;
//     final bool isSmallPhone = width >= 340 && width < 400;
//     final bool isMobile = width < 600;
//     final bool isTablet = width >= 600 && width < 1000;
//     final bool isDesktop = width >= 1000;
//
//     /// ============================================
//     /// RESPONSIVE HEIGHT
//     /// ============================================
//     final double navHeight;
//
//     if (isDesktop) {
//       navHeight = 78;
//     } else if (isTablet) {
//       navHeight = 72;
//     } else if (isVerySmallPhone) {
//       navHeight = 62;
//     } else if (isSmallPhone) {
//       navHeight = 65;
//     } else {
//       navHeight = 68;
//     }
//
//     /// ============================================
//     /// RESPONSIVE ICON SIZE
//     /// ============================================
//     final double iconSize;
//
//     if (isDesktop) {
//       iconSize = 25;
//     } else if (isTablet) {
//       iconSize = 22;
//     } else if (isVerySmallPhone) {
//       iconSize = 18;
//     } else if (isSmallPhone) {
//       iconSize = 19;
//     } else {
//       iconSize = 21;
//     }
//
//     /// ============================================
//     /// RESPONSIVE FONT SIZE
//     /// ============================================
//     final double fontSize;
//
//     if (isDesktop) {
//       fontSize = 12;
//     } else if (isTablet) {
//       fontSize = 10.5;
//     } else if (isVerySmallPhone) {
//       fontSize = 8.5;
//     } else if (isSmallPhone) {
//       fontSize = 9;
//     } else {
//       fontSize = 10;
//     }
//
//     /// ============================================
//     /// RESPONSIVE HORIZONTAL MARGIN
//     ///
//     /// Tablet ma width cut na kariye.
//     /// Aa overflow avoid karva important che.
//     /// ============================================
//     final double horizontalMargin;
//
//     if (isDesktop) {
//       horizontalMargin = width * 0.12;
//     } else if (isTablet) {
//       horizontalMargin = 8;
//     } else {
//       horizontalMargin = 0;
//     }
//
//     /// ============================================
//     /// RESPONSIVE RADIUS
//     /// ============================================
//     final double radius = isMobile ? 12 : 15;
//
//     return SafeArea(
//       top: false,
//       child: Container(
//         height: navHeight,
//         margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(radius),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.12),
//               blurRadius: 12,
//               offset: const Offset(0, -3),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(radius),
//           child: BottomNavigationBar(
//             /// ========================================
//             /// BASIC
//             /// ========================================
//             backgroundColor: Colors.white,
//
//             currentIndex: selectedIndex,
//
//             type: BottomNavigationBarType.fixed,
//
//             elevation: 0,
//
//             /// ========================================
//             /// ICON
//             /// ========================================
//             iconSize: iconSize,
//
//             /// ========================================
//             /// FONT
//             /// ========================================
//             selectedFontSize: fontSize,
//             unselectedFontSize: fontSize,
//
//             selectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w600,
//               height: 1.0,
//             ),
//
//             unselectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w500,
//               height: 1.0,
//             ),
//
//             /// ========================================
//             /// COLOR
//             /// ========================================
//             selectedItemColor: AppColors.primaryDark,
//
//             unselectedItemColor: Colors.grey.shade600,
//
//             /// ========================================
//             /// LABEL SETTINGS
//             /// ========================================
//             showSelectedLabels: true,
//             showUnselectedLabels: true,
//
//             /// ========================================
//             /// CLICK
//             /// ========================================
//             onTap: (index) {
//               final item = bottomItems[index];
//
//               /// MORE CLICK
//               if (item["title"] == "More") {
//                 showMenuSelectionDialog(isBottomNavMode: true);
//                 return;
//               }
//
//               setState(() {
//                 selectedIndex = index;
//               });
//
//               /// SCREEN OPEN
//               if (item["screen"] != null) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => item["screen"]),
//                 );
//               }
//             },
//
//             /// ========================================
//             /// ITEMS
//             /// ========================================
//             items: bottomItems.map((item) {
//               final String title = item["title"]?.toString() ?? "";
//
//               return BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(bottom: isVerySmallPhone ? 1 : 2),
//                   child: Icon(item["icon"], size: iconSize),
//                 ),
//
//                 /// Long label hoy to short kari shakai
//                 label: title,
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget addNewGlassCard() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(12),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.05), // glass transparency
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 10,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.add, color: AppColors.white, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 "Add New",
//                 style: TextStyle(
//                   color: AppColors.white,
//                   fontWeight: FontWeight.w500,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget gradientIcon(IconData icon, bool selected) {
//     return ShaderMask(
//       shaderCallback: (bounds) {
//         return LinearGradient(
//           colors: selected
//               ? const [Colors.white54, Colors.white54]
//               : const [Colors.white54, Colors.white54],
//         ).createShader(bounds);
//       },
//       child: Icon(icon, color: Colors.white, size: 24),
//     );
//   }
//
//   void showMenuSelectionDialog({bool isBottomNavMode = false}) {
//     List<Map<String, dynamic>> sections = [
//       {
//         "title": "Item Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Item List",
//             "icon": Icons.add_box,
//             "screen": const Itemscreen(),
//             "prefix": "item", // ✅ ADD
//           },
//           {
//             "title": "Label Config",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Labelscreen(),
//             "prefix": "label-config", // ✅ ADD
//           },
//           {
//             "title": "Label Items",
//             "icon": Icons.label_important_outlined,
//             "screen": const label_item_screen(),
//             "prefix": "item-set", // ✅ ADD
//           },
//           {
//             "title": "Label Printing",
//             "icon": Icons.print,
//             "screen": const LabelPrintScreen(),
//             "prefix": "label-print", // ✅ ADD
//           },
//           {
//             "title": "Other Charges",
//             "icon": Icons.settings_applications,
//             "screen": const Othersscreen(),
//             "prefix": "other-charge", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "User Management",
//         "icon": Icons.dashboard_customize,
//         "items": [
//           {
//             "title": "Person",
//             "icon": Icons.person_add,
//             "screen": const Customerscreen(),
//             "prefix": "person", // ✅ ADD
//           },
//           {
//             "title": "Users",
//             "icon": Icons.people,
//             "screen": const Userscreen(),
//             "prefix": "user", // ✅ ADD
//           },
//           {
//             "title": "Category",
//             "icon": Icons.people,
//             "screen": const Categoryscreen(),
//             "prefix": "category-person", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "JobWork Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Labour Formula",
//             "icon": Icons.add_box,
//             "screen": const JobLabourformulaScreen(),
//             "prefix": "labour-formula", // ✅ ADD
//           },
//           {
//             "title": "Production Cost",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Productioncost(),
//             "prefix": "production-cost", // ✅ ADD
//           },
//           {
//             "title": "Production Step",
//             "icon": Icons.label_important_outlined,
//             "screen": const Prooductionstepscreen(),
//             "prefix": "production-step", // ✅ ADD
//           },
//           // {
//           //   "title": "Job Worker",
//           //   "icon": Icons.print,
//           //   "screen": const Jobworkerscreen(),
//           //   "prefix": "job-worker", // ✅ ADD
//           // },
//           {
//             "title": "Jobwork Issue",
//             "icon": Icons.settings_applications,
//             "screen": const JobworkIssueScreen(),
//             "prefix": "jobwork-issue", // ✅ ADD
//           },
//           {
//             "title": "Jobwork Receive",
//             "icon": Icons.settings_applications,
//             "screen": const Jobworkreceivescreen(),
//             "prefix": "jobwork-receive", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Sales",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Sale on Approvals",
//             "icon": Icons.qr_code,
//             "screen": const InvoiceScreen(),
//             "prefix": "approval", // ✅ ADD
//           },
//           {
//             "title": "Sales Estimate",
//             "icon": Icons.sell,
//             "screen": const SellList(),
//             "prefix": "sale", // ✅ ADD
//           },
//           {
//             "title": "Approval Return",
//             "icon": Icons.sell,
//             "screen": const Approvalreturnscreen(),
//             "prefix": "approval-return", // ✅ ADD
//           },
//           {
//             "title": "Rec-Ret-Purchase",
//             "icon": Icons.sell,
//             "screen": const ReciveReturnPurchase(),
//             "prefix": "sale-advance", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Reports & Tools",
//         "icon": Icons.analytics,
//         "items": [
//           {
//             "title": "Sales Summary",
//             "icon": Icons.bar_chart,
//             "screen": const Salesumryreport(),
//             "prefix": "report-sales-summary", // ✅ ADD
//           },
//           {
//             "title": "Reciver Summary",
//             "icon": Icons.qr_code_scanner,
//             "screen": const Purchasereciversummary(),
//             "prefix": "receiver-summary", // ✅ ADD
//           },
//           {
//             "title": "Stock Position",
//             "icon": Icons.bar_chart,
//             "screen": const Stockpositionreport(),
//             "prefix": "report-stock-position", // ✅ ADD
//           },
//           {
//             "title": "Approval Outstanding",
//             "icon": Icons.menu_book,
//             "screen": const Approvaloutstandingreport(),
//             "prefix": "report-approval-outstanding", // ✅ ADD
//           },
//           {
//             "title": "Barcode History",
//             "icon": Icons.menu_book,
//             "screen": const Barcodehistory(),
//             "prefix": "report-barcode-history", // ✅ ADD
//           },
//           {
//             "title": "Worker Loss",
//             "icon": Icons.menu_book,
//             "screen": const WorkerLossReportScreen(),
//             "prefix": "report-worker-loss", // ✅ ADD
//           },
//           {
//             "title": "Approval Summary",
//             "icon": Icons.menu_book,
//             "screen": const ApprovalSummaryScreen(),
//             "prefix": "report-worker-loss", // ✅ ADD
//           },
//           {
//             "title": "Approval Register",
//             "icon": Icons.menu_book,
//             "screen": const ApprovalReturnRegisterScreen(),
//             "prefix": "report-worker-loss", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Role & Permission",
//         "icon": Icons.admin_panel_settings,
//         "items": [
//           {
//             "title": "Roles",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Rolescreen(),
//             "prefix": "role", // ✅ ADD
//           },
//           {
//             "title": "Permissions",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Permissionscreen(),
//             "prefix": "permission", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Casting Management",
//         "icon": Icons.settings,
//         "items": [
//           {
//             "title": "Buch",
//             "icon": Icons.settings,
//             "screen": const Buchscreen(),
//             "prefix": "vacuum-buch",
//           },
//           {
//             "title": "Process",
//             "icon": Icons.settings,
//             "screen": const Processscreen(),
//             "prefix": "vacuum-process",
//           },
//           {
//             "title": "Vacuum Voucher",
//             "icon": Icons.settings,
//             "screen": const Voucherscreen(),
//             "prefix": "vacuum-voucher",
//           },
//           {
//             "title": "Casting Heating",
//             "icon": Icons.settings,
//             "screen": const Castingheatingscreen(),
//             "prefix": "casting-heating",
//           },
//           {
//             "title": "Casting Metal",
//             "icon": Icons.settings,
//             "screen": const Castingmetalscreen(),
//             "prefix": "casting-metal-issue",
//           },
//           {
//             "title": "Casting Receive",
//             "icon": Icons.settings,
//             "screen": const Castingrecivescreen(),
//             "prefix": "casting-release",
//           },
//           {
//             "title": "Tree Cutting Office",
//             "icon": Icons.settings,
//             "screen": const Treecuttingoffice(),
//             "prefix": "tree-cutting-office",
//           },
//           {
//             "title": "Tree Cutting Issue",
//             "icon": Icons.settings,
//             "screen": const Treecuttingissuescreen(),
//             "prefix": "tree-cutting-issue",
//           },
//           {
//             "title": "Tree Cutting Receive",
//             "icon": Icons.settings,
//             "screen": const Treecuttingreceivescreen(),
//             "prefix": "tree-cutting-receive",
//           },
//           {
//             "title": "Casting Sorting",
//             "icon": Icons.settings,
//             "screen": const Castingsortscreen(),
//             "prefix": "casting-sorting",
//           },
//         ],
//       },
//     ];
//
//     List<Map<String, dynamic>> filteredSections = sections
//         .map((section) {
//       List items = (section["items"] as List).where((item) {
//         String prefix = item["prefix"].toString();
//
//         /// 🔥 Same logic — view ya manage both check karo
//         return userPermissions.contains("$prefix-view") ||
//             userPermissions.contains("$prefix-manage") ||
//             userPermissions.contains("$prefix-create") ||
//             userPermissions.contains("$prefix-edit") ||
//             userPermissions.contains("$prefix-delete");
//       }).toList();
//
//       return {
//         "title": section["title"],
//         "icon": section["icon"],
//         "items": items,
//       };
//     })
//         .where((section) => (section["items"] as List).isNotEmpty)
//         .toList();
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setStateBottom) {
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.80,
//
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.background.withOpacity(0.9),
//                     AppColors.background.withOpacity(0.9),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
//               ),
//
//               child: Column(
//                 children: [
//                   const SizedBox(height: 14),
//
//                   Container(
//                     width: 60,
//                     height: 5,
//
//                     decoration: BoxDecoration(
//                       color: Colors.black,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   const Text(
//                     "Customize Dashboard",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   Expanded(
//                     child: ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//
//                       itemCount: filteredSections.length,
//
//                       itemBuilder: (context, sectionIndex) {
//                         final section =
//                         filteredSections[sectionIndex]; // ✅ FIXED
//
//                         return Container(
//                           margin: const EdgeInsets.only(bottom: 14),
//
//                           decoration: BoxDecoration(
//                             color: AppColors.background,
//                             border: Border.all(
//                               color: AppColors.border,
//                               width: 1.5,
//                             ),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//
//                           child: Theme(
//                             data: Theme.of(
//                               context,
//                             ).copyWith(dividerColor: Colors.transparent),
//
//                             child: ExpansionTile(
//                               tilePadding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 4,
//                               ),
//
//                               childrenPadding: const EdgeInsets.only(
//                                 left: 12,
//                                 right: 12,
//                                 bottom: 12,
//                               ),
//
//                               leading: Container(
//                                 padding: const EdgeInsets.all(10),
//
//                                 decoration: BoxDecoration(
//                                   color: AppColors.border,
//                                   border: Border.all(
//                                     color: AppColors.border,
//                                     width: 1.5,
//                                   ),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//
//                                 child: Icon(
//                                   section["icon"],
//                                   color: AppColors.iconBlue,
//                                 ),
//                               ),
//
//                               title: Text(
//                                 section["title"],
//
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 16,
//                                 ),
//                               ),
//
//                               iconColor: AppColors.iconBlue,
//                               collapsedIconColor: AppColors.textPrimary,
//
//                               children: List.generate(section["items"].length, (
//                                   index,
//                                   ) {
//                                 final item = section["items"][index];
//
//                                 bool alreadyAdded = isBottomNavMode
//                                     ? bottomItems.any(
//                                       (e) => e["title"] == item["title"],
//                                 )
//                                     : dashboardItems.any(
//                                       (e) => e["title"] == item["title"],
//                                 );
//
//                                 return Container(
//                                   margin: const EdgeInsets.only(bottom: 10),
//
//                                   padding: const EdgeInsets.all(12),
//
//                                   decoration: BoxDecoration(
//                                     gradient: alreadyAdded
//                                         ? const LinearGradient(
//                                       colors: [
//                                         AppColors.border,
//                                         AppColors.border,
//                                       ],
//                                     )
//                                         : LinearGradient(
//                                       colors: [
//                                         AppColors.border,
//                                         AppColors.border,
//                                       ],
//                                     ),
//
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//
//                                   child: Row(
//                                     children: [
//                                       Container(
//                                         height: 45,
//                                         width: 45,
//
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                               AppColors.border.withOpacity(0.5),
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//
//                                         child: Icon(
//                                           item["icon"],
//                                           color: Colors.black,
//                                         ),
//                                       ),
//
//                                       const SizedBox(width: 14),
//
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//
//                                           children: [
//                                             Text(
//                                               item["title"],
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black
//                                                     : Colors.black,
//
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 4),
//
//                                             Text(
//                                               alreadyAdded
//                                                   ? "Added"
//                                                   : "Tap to add",
//
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black87
//                                                     : Colors.black87,
//
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       InkWell(
//                                         onTap: () async {
//                                           if (isBottomNavMode) {
//                                             /// 🔥 BOTTOM NAV MODE — fakt bottomItems manipulate
//                                             if (alreadyAdded) {
//                                               setStateBottom(() {
//                                                 bottomItems.removeWhere(
//                                                       (e) =>
//                                                   e["title"] ==
//                                                       item["title"],
//                                                 );
//                                               });
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               int customCount =
//                                                   bottomItems.length - 2;
//
//                                               if (customCount >= 2) {
//                                                 Navigator.pop(context);
//                                                 Future.delayed(
//                                                   const Duration(
//                                                     milliseconds: 100,
//                                                   ),
//                                                       () {
//                                                     ScaffoldMessenger.of(
//                                                       context,
//                                                     ).showSnackBar(
//                                                       const SnackBar(
//                                                         content: Text(
//                                                           "Maximum 2 items can be added in bottom navigation",
//                                                         ),
//                                                       ),
//                                                     );
//                                                   },
//                                                 );
//                                                 return;
//                                               }
//
//                                               setStateBottom(() {
//                                                 bottomItems.insert(
//                                                   bottomItems.length - 1,
//                                                   {
//                                                     "title": item["title"],
//                                                     "icon": item["icon"],
//                                                     "screen": item["screen"],
//                                                   },
//                                                 );
//                                               });
//                                             }
//
//                                             await saveBottomNavItems();
//                                           } else {
//                                             /// 🔥 DASHBOARD MODE — dashboardItems manipulate (original logic)
//                                             if (alreadyAdded) {
//                                               dashboardItems.removeWhere(
//                                                     (e) =>
//                                                 e["title"] == item["title"],
//                                               );
//                                               bottomItems.removeWhere(
//                                                     (e) =>
//                                                 e["title"] == item["title"],
//                                               );
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               dashboardItems.add({
//                                                 ...item,
//                                                 "section": section["title"],
//                                               });
//                                             }
//
//                                             await saveDashboardItems();
//                                             await loadDashboardItems();
//                                           }
//
//                                           setStateBottom(() {});
//                                           setState(() {});
//                                         },
//
//                                         child: AnimatedContainer(
//                                           duration: const Duration(
//                                             milliseconds: 250,
//                                           ),
//
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 18,
//                                             vertical: 10,
//                                           ),
//
//                                           // decoration: BoxDecoration(
//                                           //
//                                           //   color: alreadyAdded
//                                           //       ? Colors.green
//                                           //       : null,
//                                           //
//                                           //
//                                           //
//                                           //   gradient: alreadyAdded
//                                           //       ? null
//                                           //       : const LinearGradient(
//                                           //     colors: [
//                                           //       Color(0xffE6C58A),
//                                           //       Color(0xffC8A96A),
//                                           //     ],
//                                           //   ),
//                                           //
//                                           //   borderRadius: BorderRadius.circular(12),
//                                           // ),
//                                           decoration: BoxDecoration(
//                                             gradient: LinearGradient(
//                                               colors: alreadyAdded
//                                                   ? [
//                                                 AppColors.iconBlue
//                                                     .withOpacity(0.5),
//                                                 //AppColors.border.withOpacity(0.5),
//                                                 AppColors.iconBlue
//                                                     .withOpacity(0.5),
//                                               ]
//                                                   : const [
//                                                 Color(0xffE6C58A),
//                                                 Color(0xffC8A96A),
//                                               ],
//                                             ),
//
//                                             borderRadius: BorderRadius.circular(
//                                               5,
//                                             ),
//                                           ),
//
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 alreadyAdded
//                                                     ? Icons.check
//                                                     : Icons.add,
//                                                 color: alreadyAdded
//                                                     ? Colors.white
//                                                     : Colors.black,
//                                                 size: 18,
//                                               ),
//
//                                               const SizedBox(width: 6),
//
//                                               Text(
//                                                 alreadyAdded ? "ADDED" : "ADD",
//
//                                                 style: TextStyle(
//                                                   color: alreadyAdded
//                                                       ? Colors.white
//                                                       : Colors.black,
//                                                   fontWeight: FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               }),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
//
//                     child: InkWell(
//                       onTap: () {
//                         Navigator.pop(context);
//                       },
//
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.primaryDark,
//                               AppColors.secondaryDark,
//                             ],
//                           ),
//
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//
//                         child: const Center(
//                           child: Text(
//                             "DONE",
//
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _onReorder(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) {
//         newIndex -= 1;
//       }
//       final String item = sectionOrder.removeAt(oldIndex);
//       sectionOrder.insert(newIndex, item);
//     });
//   }
//
//   String getSectionSubtitle(String sectionName) {
//     switch (sectionName) {
//       case "Sales":
//         return "Manage all sales activities";
//
//       case "Item Management":
//         return "Manage your inventory & items";
//
//       case "Others":
//         return "Other useful options";
//
//       case "JobWork Management":
//         return "Manage all job work activities";
//
//       case "Report Management":
//         return "Manage all Report activities";
//
//       case "Role Management":
//         return "Manage all Settings activities";
//
//       case "Casting Management":
//         return "Manage all Casting activities";
//
//       case "Management":
//         return "Manage all User activities";
//
//       default:
//         return "";
//     }
//   }
//
//   Widget optionItem(
//       IconData icon,
//       String title,
//       Color iconColor,
//       Color bgColor, {
//         VoidCallback? onTap, // 👈 ADD THIS
//       }) {
//     return InkWell(
//       onTap: onTap, // 👈 ADD THIS
//       borderRadius: BorderRadius.circular(10),
//       child: Column(
//         children: [
//           Container(
//             height: 45,
//             width: 45,
//             decoration: BoxDecoration(
//               color: bgColor,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: iconColor, size: 28),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//               color: Color(0xff14213D),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget metalRateMarquee() {
//     if (rates.isEmpty) {
//       return const SizedBox();
//     }
//
//     String text = "";
//
//     for (var item in rates) {
//       text +=
//       " ${item["symbol"]} (${item["city"]}) : ₹${item["formatted_rate"]}  |";
//     }
//
//     return Container(
//       height: 38,
//       margin: const EdgeInsets.symmetric(horizontal: 10),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xff8B3A3A), Color(0xffC59D5F)],
//         ),
//         borderRadius: BorderRadius.circular(6),
//       ),
//
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10),
//             child: const Icon(
//               Icons.currency_rupee,
//               color: Colors.white,
//               size: 18,
//             ),
//           ),
//
//           Expanded(
//             child: Marquee(
//               text: text,
//
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//
//               velocity: 45,
//
//               blankSpace: 70,
//
//               pauseAfterRound: const Duration(seconds: 2),
//
//               startPadding: 10,
//
//               scrollAxis: Axis.horizontal,
//
//               crossAxisAlignment: CrossAxisAlignment.center,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildStat(IconData icon, String title, String value) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         /// Icon Background
//         Container(
//           height: 30,
//           width: 30,
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(5),
//             border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
//           ),
//           child: Icon(icon, color: Colors.white, size: 16),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           value,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 13,
//           ),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           title,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: Colors.white70, fontSize: 11),
//         ),
//       ],
//     );
//   }
//
//   Widget buildWelcomeSection() {
//     return Row(
//       children: [
//         // Container(
//         //   height: 45,
//         //   width: 45,
//         //   decoration: BoxDecoration(
//         //     color: Colors.white.withOpacity(.15),
//         //     shape: BoxShape.circle,
//         //     border: Border.all(color: Colors.white24),
//         //   ),
//         //   child: const Icon(
//         //     Icons.person,
//         //     color: Colors.white,
//         //     size: 24,
//         //   ),
//         // ),
//         const SizedBox(width: 12),
//
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Good Morning 👋",
//                 style: TextStyle(color: Colors.white70, fontSize: 13),
//               ),
//
//               const SizedBox(height: 2),
//
//               Text(
//                 "Welcome",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(.15),
//             borderRadius: BorderRadius.circular(5),
//           ),
//           child: const Text(
//             "Manager",
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget buildFirstRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.currency_rupee, "Sales", "₹0.00")),
//         Expanded(child: buildStat(Icons.trending_up, "Month Sales", "₹160")),
//         Expanded(child: buildStat(Icons.assignment_return, "Returns", "₹20")),
//         Expanded(child: buildStat(Icons.check_circle, "Complete", "25")),
//       ],
//     );
//   }
//
//   Widget buildSecondRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.approval, "Approvals", "12")),
//         Expanded(child: buildStat(Icons.pending_actions, "Pending", "08")),
//         Expanded(child: buildStat(Icons.local_offer, "Labels", "41")),
//         Expanded(child: buildStat(Icons.people, "Users", "4 / 8")),
//       ],
//     );
//   }
//
//   Future<void> loadExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? saved = prefs.getString("expanded_sections");
//
//     if (saved != null && saved.isNotEmpty) {
//       List<String> openSections = saved.split(",");
//
//       setState(() {
//         // 🔥 Fakt PEHLO section j open rakho (accordion rule)
//         String? firstOpen = openSections.isNotEmpty ? openSections.first : null;
//         expandedSections = {};
//         if (firstOpen != null) {
//           expandedSections[firstOpen] = true;
//         }
//       });
//     }
//   }
//
//   Future<void> saveExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // 🔥 Fakt PEHLO open section j save karo (max 1)
//     List<String> openSections = expandedSections.entries
//         .where((e) => e.value == true)
//         .map((e) => e.key)
//         .toList();
//
//     await prefs.setString("expanded_sections", openSections.join(","));
//   }
//
//   Future<void> saveSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setStringList("section_order", sectionOrder);
//   }
//
//   Future<void> loadSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     final saved = prefs.getStringList("section_order");
//
//     if (saved != null && saved.isNotEmpty) {
//       setState(() {
//         // 🔥 Saved order set karo (agar navi sections hoy to pachi automatically add thai jashe _updateSectionOrderForNewItems() thi)
//         sectionOrder = saved;
//       });
//     }
//   }
// }



// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
// import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
// import 'package:pecifician_sysytem/Approval/Recive_return_purchase.dart';
// import 'package:pecifician_sysytem/Dashboard/DiamondReportsUI.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
// import 'package:pecifician_sysytem/Reports/OutStandingAmount.dart';
// import 'package:pecifician_sysytem/Sell_estimate/SellScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CategoryScreen.dart';
// import 'package:pecifician_sysytem/User/CreateCustomer.dart';
// import 'package:pecifician_sysytem/User/OfficeAccessSettingsScreen.dart';
// import 'package:pecifician_sysytem/User/UserScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
// import 'package:pecifician_sysytem/Visiting%20Card/Visitingcard.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Approval/ApproveListScreen.dart';
// import '../Approval/ReceivevoucharScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/GlobalDrawer.dart';
// import '../Extra/NotificationProvider.dart';
// import '../Settings/LiveMetalRatesScreen.dart';
// import '../Settings/SettingsScreen.dart';
// import '../Item_Mangement/Item/ItemScreen.dart';
// import '../Item_Mangement/Label Print/Label_print_Screen.dart';
// import '../Item_Mangement/Label/LabelScreen.dart';
// import '../Item_Mangement/Label_Items/label_item_screen.dart';
// import '../Item_Mangement/Others/Othersscreen.dart';
// import '../Job Work/Job Work Issue/Jobwork_issue_Screen.dart';
// import '../Job Work/Job Worker/JobWorkerScreen.dart';
// import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
// import '../Job Work/Production_Costs/ProductionCost.dart';
// import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
// import '../Notification/NotificationScreen.dart';
// import '../Reports/ApprovalOutstandingReport.dart';
// import '../Reports/BarcodeHistory.dart';
// import '../Reports/PurchaseReciverSummary.dart';
// import '../Reports/SaleSumryReport.dart';
// import '../Reports/StockPositionReport.dart';
// import '../Role & Permission/PermissionScreen.dart';
// import '../Role & Permission/RoleScreen.dart';
// import '../User/CustomerScreen.dart';
// import '../Vacuum/Casting/CastingHeatingScreen.dart';
// import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
// import '../Vacuum/Casting_Recive/CastingReciveScreen.dart';
// import '../Vacuum/Casting_Sort/CastingSortScreen.dart';
// import '../Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
// import '../Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
// import '../Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
// import '../Vacuum/Vacuum Process/ProcessScreen.dart';
// import '../Vacuum/Vouchar History/VoucharHistoryScreen.dart';
// import 'InventoryScreen.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   int selectedIndex = 0;
//   List<String> sectionOrder = [];
//   List<String> userRoleNames = [];
//   List<String> userPermissions = []; // ✅ aa hovu joiye
//   List<Map<String, dynamic>> bottomItems = [
//     {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//
//     {"title": "More", "icon": Icons.more_horiz},
//   ];
//   List rates = [];
//   String source = "";
//   String updatedAt = "";
//   Timer? autoRefreshTimer;
//   String? activeSection;
//
//   Future<void> moveSectionToTopAndOpen(String sectionName) async {
//     // if (!mounted) return;
//
//     setState(() {
//       activeSection = sectionName;
//
//       /// Section top par
//       sectionOrder.remove(sectionName);
//       sectionOrder.insert(0, sectionName);
//
//       /// Badha close
//       for (final key in sectionOrder) {
//         expandedSections[key] = false;
//       }
//
//       /// Current section open
//       expandedSections[sectionName] = true;
//     });
//
//     /// Persist
//     await saveSectionOrder();
//     await saveExpandedSections();
//   }
//
//   Future<void> loadRates({bool silent = false}) async {
//     try {
//       /// ============================================
//       /// 1. LOCATION SERVICE CHECK
//       /// ============================================
//       final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//
//       if (!serviceEnabled) {
//         if (!silent && mounted) {
//           AppMessage.error(context, "Please enable location service.");
//         }
//
//         return;
//       }
//
//       /// ============================================
//       /// 2. LOCATION PERMISSION CHECK
//       /// ============================================
//       LocationPermission permission = await Geolocator.checkPermission();
//
//       /// Permission denied
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//
//         if (permission == LocationPermission.denied) {
//           if (!silent && mounted) {
//             AppMessage.error(context, "Location permission is required.");
//           }
//
//           return;
//         }
//       }
//
//       /// Permission permanently denied
//       if (permission == LocationPermission.deniedForever) {
//         if (!silent && mounted) {
//           AppMessage.error(
//             context,
//             "Location permission is permanently denied.",
//           );
//         }
//
//         return;
//       }
//
//       /// ============================================
//       /// 3. GET CURRENT LOCATION
//       /// ============================================
//       final Position position = await Geolocator.getCurrentPosition(
//         locationSettings: const LocationSettings(
//           accuracy: LocationAccuracy.high,
//         ),
//       );
//
//       final String latitude = position.latitude.toString();
//
//       final String longitude = position.longitude.toString();
//
//       debugPrint("======================================");
//
//       debugPrint("📍 CURRENT LOCATION");
//
//       debugPrint("Latitude  => $latitude");
//
//       debugPrint("Longitude => $longitude");
//
//       /// ============================================
//       /// 4. GET DEVICE ID
//       /// ============================================
//       String deviceId = "";
//       String deviceName = "";
//
//       try {
//         /// ==========================================
//         /// ANDROID
//         /// ==========================================
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//
//           deviceId = androidInfo.id;
//
//           deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
//
//           //platform = "android";
//         } else if (Platform.isIOS) {
//           final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//
//           deviceId = iosInfo.identifierForVendor ?? "";
//
//           deviceName = iosInfo.name;
//
//           //platform = "ios";
//         }
//       } catch (e) {
//         debugPrint("❌ Device ID Error => $e");
//
//         deviceId = "";
//       }
//
//       debugPrint("📱 Device ID => $deviceId");
//
//       debugPrint("======================================");
//
//       /// ============================================
//       /// 5. CREATE QUERY PARAMETERS
//       /// ============================================
//       final Map<String, dynamic> queryParameters = {
//         "latitude": latitude,
//         "longitude": longitude,
//         "device_id": deviceId,
//       };
//
//       debugPrint(
//         "📤 LIVE RATE QUERY => "
//         "$queryParameters",
//       );
//
//       /// ============================================
//       /// 6. API CALL
//       /// ============================================
//       final response = await ApiHelper().getRequestWithQuery(
//         ApiConstants.live_metal_rates,
//
//         queryParameters: queryParameters,
//
//         showLoading: false,
//       );
//
//       /// ============================================
//       /// 7. DEBUG RESPONSE
//       /// ============================================
//       debugPrint("======================================");
//
//       debugPrint("📥 LIVE RATE RESPONSE");
//
//       debugPrint("Status => ${response?.statusCode}");
//
//       debugPrint("Data => ${response?.data}");
//
//       debugPrint("======================================");
//
//       /// ============================================
//       /// 8. NO RESPONSE
//       /// ============================================
//       if (response == null) {
//         if (!silent && mounted) {
//           AppMessage.error(context, "No response from server.");
//         }
//
//         return;
//       }
//
//       /// ============================================
//       /// 9. SUCCESS
//       /// ============================================
//       if (response.statusCode == 200 && response.data["success"] == true) {
//         final data = response.data;
//
//         if (!mounted) return;
//
//         setState(() {
//           rates = data["data"] ?? [];
//
//           source = data["source"]?.toString() ?? "";
//
//           updatedAt = data["updated_at"]?.toString() ?? "";
//         });
//
//         /// ==========================================
//         /// LOAD SAVED SELECTED RATE
//         /// ==========================================
//         await loadSelectedRate();
//
//         return;
//       }
//
//       /// ============================================
//       /// 10. API ERROR
//       ///
//       /// Backend je message mokle
//       /// e j user ne show thase.
//       /// ============================================
//       String message = "Failed to load live rates";
//
//       final dynamic responseData = response.data;
//
//       if (responseData is Map && responseData["message"] != null) {
//         message = responseData["message"].toString();
//       }
//
//       debugPrint("❌ API MESSAGE => $message");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, message);
//       }
//     }
//     /// ============================================
//     /// 11. ERROR
//     /// ============================================
//     catch (e) {
//       debugPrint("======================================");
//
//       debugPrint("❌ LOAD RATES ERROR => $e");
//
//       debugPrint("======================================");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, "Failed to load live rates");
//       }
//     }
//   }
//
//   Map<String, bool> expandedSections = {};
//   int? expandedIndex;
//   String getGreeting() {
//     final hour = DateTime.now().hour;
//
//     if (hour >= 5 && hour < 12) {
//       return "Good Morning 👋";
//     } else if (hour >= 12 && hour < 17) {
//       return "Good Afternoon ☀️";
//     } else if (hour >= 17 && hour < 21) {
//       return "Good Evening 🌇";
//     } else {
//       return "Good Night 🌙";
//     }
//   }
//
//   String selectedSymbol = "GOLD";
//   Map<String, dynamic>? selectedRate;
//   List<Map<String, dynamic>> allMenuItems = [
//     {
//       "title": "Person",
//       "icon": Icons.person_add,
//       "module": "customer",
//       "screen": const Customerscreen(),
//       "section": "Management",
//       "prefix": "person",
//     },
//     {
//       "title": "Users",
//       "icon": Icons.people,
//       "module": "user",
//       "screen": const Userscreen(),
//       "section": "Management",
//       "prefix": "user",
//     },
//     {
//       "title": "Category",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const Categoryscreen(),
//       "section": "Management",
//       "prefix": "category-person",
//     },
//     {
//       "title": "Office Access",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const OfficeAccessSettingsScreen(),
//       "section": "Management",
//       "prefix": "office-access",
//     },
//     {
//       "title": "Sales Estimate",
//       "icon": Icons.sell,
//       "module": "sale",
//       "screen": const SellList(),
//       "section": "Sales",
//       "prefix": "sale",
//     },
//     {
//       "title": "Sale on Approvals",
//       "icon": Icons.qr_code,
//       "module": "approval",
//       "screen": const InvoiceScreen(),
//       "section": "Sales",
//       "prefix": "approval", // ✅ "view" hatavi nakhyu
//     },
//     {
//       "title": "Approval Return",
//       "icon": Icons.sell,
//       "module": "approval_return",
//       "screen": const Approvalreturnscreen(),
//       "section": "Sales",
//       "prefix": "approval-return",
//     },
//     {
//       "title": "Rec-Ret-Purchase",
//       "icon": Icons.sell,
//       "module": "sale_advance",
//       "screen": const Receivevoucharscreen(),
//       "section": "Sales",
//       "prefix": "sale-advance",
//     },
//     // {
//     //   "title": "Reports",
//     //   "icon": Icons.bar_chart,
//     //   "screen": const DiamondReportsFullUI(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "reports",
//     // },
//     // {
//     //   "title": "Scanner",
//     //   "icon": Icons.qr_code_scanner,
//     //   "screen": const PremiumScannerScreen(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "scanner",
//     // },
//     {
//       "title": "Item List",
//       "icon": Icons.add_box,
//       "module": "item",
//       "screen": const Itemscreen(),
//       "section": "Item Management",
//       "prefix": "item",
//     },
//     {
//       "title": "Label Config",
//       "icon": Icons.production_quantity_limits,
//       "module": "label_config",
//       "screen": const Labelscreen(),
//       "section": "Item Management",
//       "prefix": "label-config",
//     },
//     {
//       "title": "Label Items",
//       "icon": Icons.label_important_outlined,
//       "module": "item_set",
//       "screen": const label_item_screen(),
//       "section": "Item Management",
//       "prefix": "item-set",
//     },
//     {
//       "title": "Label Printing",
//       "icon": Icons.print,
//       "screen": const LabelPrintScreen(),
//       "section": "Item Management",
//       "prefix": "label-print",
//     },
//     {
//       "title": "Other Charges",
//       "icon": Icons.settings_applications,
//       "module": "other_charge",
//       "screen": const Othersscreen(),
//       "section": "Item Management",
//       "prefix": "other-charge",
//     },
//     {
//       "title": "Labour Formula",
//       "icon": Icons.add_box,
//       "module": "labour_formula",
//       "screen": const JobLabourformulaScreen(),
//       "section": "JobWork Management",
//       "prefix": "labour-formula",
//     },
//     {
//       "title": "Production Cost",
//       "icon": Icons.production_quantity_limits,
//       "module": "production_cost",
//       "screen": const Productioncost(),
//       "section": "JobWork Management",
//       "prefix": "production-cost",
//     },
//     {
//       "title": "Production Step",
//       "icon": Icons.label_important_outlined,
//       "module": "production_step",
//       "screen": const Prooductionstepscreen(),
//       "section": "JobWork Management",
//       "prefix": "production-step",
//     },
//     // {
//     //   "title": "Job Worker",
//     //   "icon": Icons.print,
//     //   "module": "job_worker",
//     //   "screen": const Jobworkerscreen(),
//     //   "section": "JobWork Management",
//     //   "prefix": "job-worker",
//     // },
//     {
//       "title": "Jobwork Issue",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_issue",
//       "screen": const JobworkIssueScreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-issue",
//     },
//     {
//       "title": "Jobwork Receive",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_receive",
//       "screen": const Jobworkreceivescreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-receive",
//     },
//     {
//       "title": "Sales Summary",
//       "icon": Icons.add_box,
//       "screen": const Salesumryreport(),
//       "section": "Report Management",
//       "prefix": "report-sales-summary",
//     },
//     {
//       "title": "Receiver Summary",
//       "icon": Icons.production_quantity_limits,
//       "screen": const Purchasereciversummary(),
//       "section": "Report Management",
//       "prefix": "report-purchase-receiver-summary",
//     },
//     {
//       "title": "Stock Position",
//       "icon": Icons.label_important_outlined,
//       "screen": const Stockpositionreport(),
//       "section": "Report Management",
//       "prefix": "report-stock-position",
//     },
//     {
//       "title": "Approval Outstanding",
//       "icon": Icons.print,
//       "screen": const Approvaloutstandingreport(),
//       "section": "Report Management",
//       "prefix": "report-approval-outstanding",
//     },
//     {
//       "title": "Barcode History",
//       "icon": Icons.settings_applications,
//       "screen": const Barcodehistory(),
//       "section": "Report Management",
//       "prefix": "report-barcode-history",
//     },
//     {
//       "title": "Outstanding Amount",
//       "icon": Icons.settings_applications,
//       "screen": const Outstandingamount(),
//       "section": "Report Management",
//       "prefix": "report-outstanding-amount",
//     },
//     {
//       "title": "Roles",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Rolescreen(),
//       "section": "Role Management",
//       "prefix": "role",
//     },
//     {
//       "title": "Permissions",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Permissionscreen(),
//       "section": "Role Management",
//       "prefix": "permission",
//     },
//     {
//       "title": "Buch",
//       "icon": Icons.settings,
//       "module": "vacuum_buch",
//       "screen": const Buchscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-buch",
//     },
//     {
//       "title": "Process",
//       "icon": Icons.settings,
//       "module": "vacuum_process",
//       "screen": const Processscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-process",
//     },
//     {
//       "title": "Vacuum Voucher",
//       "icon": Icons.settings,
//       "module": "vacuum_voucher",
//       "screen": const Voucherscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-voucher",
//     },
//     {
//       "title": "Casting Heating",
//       "icon": Icons.settings,
//       "module": "casting_heating",
//       "screen": const Castingheatingscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-heating",
//     },
//     {
//       "title": "Casting Metal",
//       "icon": Icons.settings,
//       "module": "casting_metal_issue",
//       "screen": const Castingmetalscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-metal-issue",
//     },
//     {
//       "title": "Casting Receive",
//       "icon": Icons.settings,
//       "module": "casting_release",
//       "screen": const Castingrecivescreen(),
//       "section": "Casting Management",
//       "prefix": "casting-release",
//     },
//     {
//       "title": "Tree Cutting Office",
//       "icon": Icons.settings,
//       "module": "tree_cutting_office",
//       "screen": const Treecuttingoffice(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-office",
//     },
//     {
//       "title": "Tree Cutting Issue",
//       "icon": Icons.settings,
//       "module": "tree_cutting_issue",
//       "screen": const Treecuttingissuescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-issue",
//     },
//     {
//       "title": "Tree Cutting Receive",
//       "icon": Icons.settings,
//       "module": "tree_cutting_receive",
//       "screen": const Treecuttingreceivescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-receive",
//     },
//     {
//       "title": "Casting Sorting",
//       "icon": Icons.settings,
//       "module": "casting_sorting",
//       "screen": const Castingsortscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-sorting",
//     },
//
//     {
//       "title": "Voucher History",
//       "icon": Icons.settings,
//       "module": "voucher-history",
//       "screen": const VoucherProcessHistoryScreen(),
//       "section": "Casting Management",
//       "prefix": "voucher-history",
//     },
//   ];
//
//   /// 🔥 DASHBOARD SELECTED ITEMS
//   List<Map<String, dynamic>> dashboardItems = [];
//   String name = "";
//   String email = "";
//   String companyName = "";
//   String State = "";
//   String City = "";
//   String Role = "";
//
//   Future<bool> readModule(String module) async {
//     try {
//       final response = await ApiHelper().postRequest(
//         "https://ornasphere.com/api/notifications/read-module",
//         {"module": module},
//       );
//
//       print("Read Module Response : ${response?.data}");
//
//       return response != null &&
//           response.statusCode == 200 &&
//           response.data["success"] == true;
//     } catch (e) {
//       print("Read Module Error : $e");
//       return false;
//     }
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     loadRates();
//     loadExpandedSections(); // 👈 ADD THIS
//     loadSectionOrder(); // 👈 ADD THIS
//     loadSelectedRate();
//
//     /// 🔥 Auto refresh every 30 seconds
//     // autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//     //   loadRates(silent: true);
//     // });
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<NotificationProvider>().loadNotificationCount();
//     });
//     getCompanyProfile();
//     //updateSectionOrder();
//     /// 🔥 DEFAULT DASHBOARD ITEMS
//     loadDashboardItems();
//     loadBottomNavItems(); // 🔥 ADD
//   }
//
//   Future<void> loadSelectedRate() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     selectedSymbol = prefs.getString("selected_rate_symbol") ?? "GOLD";
//
//     updateSelectedRate();
//
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   void updateSelectedRate() {
//     if (rates.isEmpty) return;
//
//     try {
//       selectedRate = rates.firstWhere((e) => e["symbol"] == selectedSymbol);
//     } catch (e) {
//       selectedRate = rates.first;
//     }
//   }
//
//   Future<void> loadBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String>? savedTitles = prefs.getStringList("bottom_nav_items");
//
//     List<Map<String, dynamic>> customItems = [];
//
//     if (savedTitles != null && savedTitles.isNotEmpty) {
//       for (var title in savedTitles) {
//         var match = allMenuItems.firstWhere(
//           (e) => e["title"] == title,
//           orElse: () => {},
//         );
//         if (match.isNotEmpty) {
//           customItems.add({
//             "title": match["title"],
//             "icon": match["icon"],
//             "screen": match["screen"],
//           });
//         }
//       }
//     }
//
//     setState(() {
//       bottomItems = [
//         {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//         ...customItems,
//         {"title": "More", "icon": Icons.more_horiz},
//       ];
//     });
//   }
//
//   Future<void> saveBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     List<String> titles = bottomItems
//         .where((e) => e["title"] != "Dashboard" && e["title"] != "More")
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("bottom_nav_items", titles);
//   }
//
//   void updateSectionOrder(
//     Map<String, List<Map<String, dynamic>>> groupedItems,
//   ) {
//     // Naya section keys (jaisi "Others") ne add karo jo already sectionOrder ma nathi
//     for (var key in groupedItems.keys) {
//       if (!sectionOrder.contains(key)) {
//         sectionOrder.add(key);
//       }
//     }
//
//     // Je sections have exist nathi karta groupedItems ma, ene sectionOrder thi remove karo
//     sectionOrder.removeWhere((s) => !groupedItems.containsKey(s));
//   }
//
//   Future<void> loadDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> excludedTitles =
//         prefs.getStringList("excluded_dashboard_items") ?? [];
//
//     /// 🔥 Have allMenuItems (je already permission pramane filtered che)
//     /// ma thi j dashboard items lese — jetli pan API permission hoy e badha
//     /// automatic dashboard par dekhashe (jo user e manually remove na karyu hoy to)
//     List<Map<String, dynamic>> tempItems = allMenuItems
//         .where((item) => !excludedTitles.contains(item["title"]))
//         .toList();
//
//     setState(() {
//       dashboardItems = tempItems;
//       _updateSectionOrderForNewItems();
//     });
//   }
//
//   Future<void> saveDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     /// 🔥 jetla items allMenuItems ma che pan dashboardItems ma nathi
//     /// (user e remove karya che), e excluded list ma save karo
//     List<String> excludedTitles = allMenuItems
//         .where((m) => !dashboardItems.any((d) => d["title"] == m["title"]))
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("excluded_dashboard_items", excludedTitles);
//
//     /// (Optional) jo old key "dashboard_items" use thato hoy biji jagya pan,
//     /// e clear/remove kari shako ke rehva dyo, have e use nathi thato
//   }
//
//   // એક હેલ્પર ફંક્શન સેક્શન ઓર્ડર મેન્ટેન કરવા માટે
//   void _updateSectionOrderForNewItems() {
//     final Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//
//     for (final item in dashboardItems) {
//       final String section = item["section"] ?? "Others";
//
//       tempGrouped.putIfAbsent(section, () => []);
//       tempGrouped[section]!.add(item);
//     }
//
//     final List<String> newOrder = [];
//
//     /// =========================================
//     /// CURRENT ACTIVE SECTION ALWAYS FIRST
//     /// =========================================
//     if (activeSection != null && tempGrouped.containsKey(activeSection)) {
//       newOrder.add(activeSection!);
//     }
//
//     /// =========================================
//     /// OLD ORDER MAINTAIN
//     /// =========================================
//     for (final section in sectionOrder) {
//       if (tempGrouped.containsKey(section) && !newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     /// =========================================
//     /// NEW SECTIONS ADD
//     /// =========================================
//     for (final section in tempGrouped.keys) {
//       if (!newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     if (!mounted) return;
//
//     setState(() {
//       sectionOrder = newOrder;
//
//       /// Active section open
//       if (activeSection != null) {
//         for (final section in sectionOrder) {
//           expandedSections[section] = section == activeSection;
//         }
//       }
//     });
//   }
//
//   Future<void> getCompanyProfile() async {
//     try {
//       final response = await ApiHelper().getRequest(ApiConstants.userProfile);
//
//       if (response == null) {
//         print("❌ No response — default dashboard load karo");
//         await loadDashboardItems();
//         return;
//       }
//
//       if (response.statusCode == 200) {
//         final jsonData = response.data;
//         final userData = jsonData["data"] ?? {};
//         final companyData = userData["company"] ?? {};
//
//         // ============================================================
//         // PROFILE DATA
//         // ============================================================
//
//         final profileData = userData["profile"] ?? {};
//
//         // ============================================================
//         // PERMISSIONS
//         // ============================================================
//
//         final List permissionsRaw =
//             profileData["permissions"] ?? jsonData["permissions"] ?? [];
//
//         final List<String> permissions = permissionsRaw
//             .map((e) => e.toString())
//             .toList();
//
//         // ============================================================
//         // ROLE NAMES
//         // ============================================================
//
//         final List roleNamesRaw = profileData["role_names"] ?? [];
//
//         final List<String> roleNames = roleNamesRaw
//             .map((e) => e.toString())
//             .toList();
//
//         print("✅ User Permissions: $permissions");
//         print("✅ User Role Names: $roleNames");
//
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//
//         setState(() {
//           name = userData["name"]?.toString() ?? "-";
//           email = userData["email"]?.toString() ?? "-";
//           companyName = companyData["name"]?.toString() ?? "-";
//           City = companyData["city"]?.toString() ?? "-";
//           State = companyData["state"]?.toString() ?? "-";
//
//           // Save permissions
//           userPermissions = permissions;
//
//           // Save role names
//           userRoleNames = roleNames;
//
//           // Permission filtering
//           filterMenuByPermission();
//         });
//
//         // ============================================================
//         // SAVE USER DATA
//         // ============================================================
//
//         await prefs.setString("name", userData["name"]?.toString() ?? "-");
//
//         await prefs.setString("email", userData["email"]?.toString() ?? "-");
//
//         await prefs.setString(
//           "companyName",
//           companyData["name"]?.toString() ?? "-",
//         );
//
//         await prefs.setString("city", companyData["city"]?.toString() ?? "-");
//
//         await prefs.setString("state", companyData["state"]?.toString() ?? "-");
//
//         await prefs.setString("role", userData["role"]?.toString() ?? "-");
//
//         await prefs.setStringList("user_permissions", userPermissions);
//
//         await prefs.setStringList("user_role_names", userRoleNames);
//
//         // ============================================================
//         // LOAD DASHBOARD
//         // ============================================================
//
//         await loadDashboardItems();
//       } else {
//         // API fail
//         await loadDashboardItems();
//       }
//     } catch (e) {
//       print("❌ Exception: $e");
//
//       // Exception aave to default dashboard load
//       await loadDashboardItems();
//     }
//   }
//
//   void filterMenuByPermission() {
//     allMenuItems = allMenuItems.where((item) {
//       String prefix = item["prefix"].toString();
//
//       /// 🔥 Koi pan permission e prefix thi shuru thatu hoy (view/create/edit/delete/manage)
//       /// to e module dikhse
//       return userPermissions.contains("$prefix-view") ||
//           userPermissions.contains("$prefix-manage") ||
//           userPermissions.contains("$prefix-create") ||
//           userPermissions.contains("$prefix-edit") ||
//           userPermissions.contains("$prefix-delete");
//     }).toList();
//   }
//
//   bool isExpanded = false;
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.white,
//       drawer: const GlobalDrawer(),
//       extendBody: true,
//       extendBodyBehindAppBar: true, // IMPORTANT
//       //backgroundColor: AppColors.scaffoldBg,
//       bottomNavigationBar: customBottomNav(),
//       body: Stack(
//         children: [
//           /// ✅ Main Content
//           Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).size.height * 0.09),
//
//               const SizedBox(height: 10),
//
//               /// 🔥 ONLY THIS PART SCROLLABLE
//               Expanded(
//                 child: SingleChildScrollView(
//                   // 👈 ListView ના બદલે આ વાપરો
//                   padding: EdgeInsets.zero,
//                   child: Column(
//                     // 👈 અંદર એક Column ઉમેરો
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 10),
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 350),
//                           curve: Curves.easeInOut,
//                           height: isExpanded ? 240 : 75,
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             gradient: LinearGradient(
//                               colors: [
//                                 AppColors.primaryDark,
//                                 AppColors.secondaryDark,
//                               ],
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(.15),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 5),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               /// HEADER
//                               InkWell(
//                                 onTap: () {
//                                   setState(() {
//                                     isExpanded = !isExpanded;
//                                   });
//                                 },
//                                 child: Container(
//                                   height: 75,
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 15,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       /// LEFT
//                                       Expanded(
//                                         child: Column(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.center,
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               getGreeting(),
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 3),
//
//                                             Text(
//                                               DateFormat(
//                                                 "dd MMM yyyy",
//                                               ).format(DateTime.now()),
//                                               style: const TextStyle(
//                                                 color: Colors.white70,
//                                                 fontSize: 13,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       /// CENTER
//                                       selectedRate == null
//                                           ? const SizedBox()
//                                           : GestureDetector(
//                                               onTap: () {
//                                                 Navigator.push(
//                                                   context,
//                                                   MaterialPageRoute(
//                                                     builder: (context) =>
//                                                         const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                                   ),
//                                                 );
//                                               },
//                                               child: Container(
//                                                 padding:
//                                                     const EdgeInsets.symmetric(
//                                                       horizontal: 10,
//                                                       vertical: 6,
//                                                     ),
//                                                 decoration: BoxDecoration(
//                                                   color: Colors.white
//                                                       .withOpacity(0.12),
//                                                   borderRadius:
//                                                       BorderRadius.circular(5),
//                                                 ),
//                                                 child: Column(
//                                                   mainAxisSize: MainAxisSize
//                                                       .min, // 👈 જરૂરી
//                                                   crossAxisAlignment:
//                                                       CrossAxisAlignment.center,
//                                                   children: [
//                                                     Text(
//                                                       selectedRate!["symbol"],
//                                                       style: const TextStyle(
//                                                         color: Colors.white70,
//                                                         fontSize: 12,
//                                                         fontWeight:
//                                                             FontWeight.w500,
//                                                       ),
//                                                     ),
//                                                     const SizedBox(height: 0),
//                                                     Text(
//                                                       "₹${selectedRate!["formatted_rate"]}",
//                                                       style: const TextStyle(
//                                                         color: Colors.white,
//                                                         fontSize: 16,
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                               ),
//                                             ),
//
//                                       const SizedBox(width: 0),
//
//                                       AnimatedRotation(
//                                         turns: isExpanded ? .5 : 0,
//                                         duration: const Duration(
//                                           milliseconds: 300,
//                                         ),
//                                         child: const Icon(
//                                           Icons.keyboard_arrow_down,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//
//                               /// EXPAND AREA
//                               Expanded(
//                                 child: AnimatedCrossFade(
//                                   duration: const Duration(milliseconds: 300),
//                                   crossFadeState: isExpanded
//                                       ? CrossFadeState.showSecond
//                                       : CrossFadeState.showFirst,
//
//                                   firstChild: const SizedBox(),
//
//                                   secondChild: Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 10,
//                                     ),
//                                     child: Column(
//                                       children: [
//                                         buildFirstRowStats(),
//                                         const SizedBox(height: 10),
//                                         buildSecondRowStats(),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       metalRateMarquee(),
//                       const SizedBox(height: 10),
//                       Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 10),
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(10),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.06),
//                               blurRadius: 15,
//                               offset: const Offset(0, 5),
//                             ),
//                           ],
//                         ),
//
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Header
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 const Text(
//                                   "New Features",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w700,
//                                     color: Color(0xff14213D),
//                                   ),
//                                 ),
//
//                                 Row(
//                                   children: [
//                                     Text(
//                                       "View All",
//                                       style: TextStyle(
//                                         color: AppColors.primaryDark,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//
//                                     const SizedBox(width: 5),
//
//                                     Container(
//                                       height: 22,
//                                       width: 22,
//                                       decoration: BoxDecoration(
//                                         color: Color(0xffEEF3FF),
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: Icon(
//                                         Icons.arrow_forward_ios,
//                                         size: 12,
//                                         color: AppColors.primaryDark,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             // Options
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 optionItem(
//                                   Icons.bar_chart,
//                                   "BG Remove",
//                                   Color(0xff6C35FF),
//                                   Color(0xffF2EEFF),
//                                 ),
//
//                                 optionItem(
//                                   Icons.inventory_2,
//                                   "Visiting Card",
//                                   Color(0xff00C853),
//                                   Color(0xffEFFFF4),
//                                 ),
//
//                                 optionItem(
//                                   Icons.monitor_sharp,
//                                   "Live Rate",
//                                   Color(0xffff9800),
//                                   Color(0xfffff5e8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                                 optionItem(
//                                   Icons.qr_code,
//                                   "ALL QR",
//                                   Color(0xff6A35FF),
//                                   Color(0xffF3EEFF),
//                                 ),
//
//                                 // optionItem(
//                                 //   Icons.credit_card,
//                                 //   "Payments",
//                                 //   Color(0xff00BCD4),
//                                 //   Color(0xffE8FBFF),
//                                 // ),
//                                 //
//                                 //
//                                 optionItem(
//                                   Icons.settings,
//                                   "Settings",
//                                   Color(0xff7A8499),
//                                   Color(0xffF4F5F8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             const SettingsScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                       popularProductsSection(context),
//                       const SizedBox(
//                         height: 80,
//                       ), // છેલ્લે થોડી જગ્યા આપો (Bottom Nav માટે)
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           /// 🔥 APPBAR CALL HERE
//           buildAppBar(context),
//         ],
//       ),
//       floatingActionButton: Container(
//         height: 45,
//         width: 45,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: const LinearGradient(
//             colors: [AppColors.primaryDark, AppColors.secondaryDark],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black26,
//               blurRadius: 10,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//
//         child: FloatingActionButton(
//           onPressed: () {
//             showMenuSelectionDialog(isBottomNavMode: false);
//           },
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           child: const Icon(Icons.edit, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
//
//   Widget buildAppBar(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final isMobile = width < 600;
//
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: SafeArea(
//         child: Container(
//           padding: EdgeInsets.symmetric(
//             horizontal: isMobile ? 12 : 10,
//             vertical: 0,
//           ),
//
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               /// 🔥 CENTER TITLE
//               Center(
//                 child: Image.asset(
//                   "assets/static/text.png",
//                   height: 30,
//                   width: 200,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//
//               /// LEFT + RIGHT ROW
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   /// LEFT MENU
//                   Row(
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           _scaffoldKey.currentState?.openDrawer();
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//                           decoration: BoxDecoration(
//                             color: AppColors.primaryDark,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                           child: Icon(
//                             Icons.menu,
//                             size: isMobile ? 20 : 24,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   /// RIGHT ICONS
//                   Row(
//                     children: [
//                       Consumer<NotificationProvider>(
//                         builder: (context, provider, child) {
//                           return GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const NotificationScreen(),
//                                 ),
//                               );
//
//                               // Notification screen mathi pachha aavya pachi count refresh
//                               provider.loadNotificationCount();
//                             },
//                             child: Container(
//                               padding: EdgeInsets.all(isMobile ? 6 : 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 20,
//                                     offset: const Offset(5, 10),
//                                   ),
//                                 ],
//                               ),
//                               child: Stack(
//                                 clipBehavior: Clip.none,
//                                 children: [
//                                   Icon(
//                                     Icons.notifications_none,
//                                     size: isMobile ? 22 : 24,
//                                     color: Colors.red,
//                                   ),
//
//                                   if (provider.total > 0)
//                                     Positioned(
//                                       right: -5,
//                                       top: -8,
//                                       child: Container(
//                                         padding: const EdgeInsets.all(3),
//                                         constraints: const BoxConstraints(
//                                           minWidth: 18,
//                                           minHeight: 18,
//                                         ),
//                                         decoration: const BoxDecoration(
//                                           color: Colors.red,
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Center(
//                                           child: Text(
//                                             provider.total > 99
//                                                 ? "99+"
//                                                 : provider.total.toString(),
//                                             style: const TextStyle(
//                                               color: Colors.white,
//                                               fontSize: 9,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//
//                       // SizedBox(width: isMobile ? 8 : 12),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Widget popularProductsSection(BuildContext context) {
//   //   final width = MediaQuery.of(context).size.width;
//   //
//   //   int crossAxisCount() {
//   //     if (width < 600) return 3;
//   //     if (width < 900) return 3;
//   //     if (width < 1200) return 4;
//   //     return 5;
//   //   }
//   //
//   //   double childAspectRatio() {
//   //     if (width < 600) return 0.94;
//   //     if (width < 900) return 1.1;
//   //     return 1.2;
//   //   }
//   //
//   //   // --- GROUPING LOGIC (તમારો ઓરિજિનલ કોડ) ---
//   //   Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//   //   for (var item in dashboardItems) {
//   //     String section = item["section"] ?? "Other";
//   //     if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//   //     tempGrouped[section]!.add(item);
//   //   }
//   //
//   //   Map<String, List<Map<String, dynamic>>> groupedItems = {};
//   //   List<Map<String, dynamic>> otherItems = [];
//   //   tempGrouped.forEach((section, items) {
//   //     if (items.length == 1) {
//   //       otherItems.addAll(items);
//   //     } else {
//   //       groupedItems[section] = items;
//   //     }
//   //   });
//   //   if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//   //
//   //   // સેક્શન ઓર્ડર અપડેટ કરો
//   //   updateSectionOrder(groupedItems);
//   //
//   //   return Padding(
//   //     padding: const EdgeInsets.all(10.0),
//   //     child: ReorderableListView(
//   //       shrinkWrap: true,
//   //       physics: const NeverScrollableScrollPhysics(),
//   //       onReorder: _onReorder,
//   //       // ડ્રેગ કરતી વખતે બેકગ્રાઉન્ડ કલર ટ્રાન્સપરન્ટ રાખવા માટે (Optional)
//   //       proxyDecorator: (child, index, animation) => child,
//   //       children: sectionOrder.map((sectionName) {
//   //         // જો ગ્રુપમાં આ સેક્શન ન હોય તો ખાલી કન્ટેનર રિટર્ન કરો
//   //         if (!groupedItems.containsKey(sectionName))
//   //           return SizedBox(key: ValueKey(sectionName));
//   //
//   //         List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//   //
//   //         return Container(
//   //           key: ValueKey(sectionName), // Reorderable માટે યુનિક કી
//   //           margin: const EdgeInsets.only(bottom: 16),
//   //           padding: const EdgeInsets.all(12),
//   //           decoration: BoxDecoration(
//   //             color: Colors.white,
//   //             borderRadius: BorderRadius.circular(14),
//   //             border: Border.all(color: AppColors.border),
//   //             boxShadow: [
//   //               BoxShadow(
//   //                 color: Colors.black.withOpacity(0.05),
//   //                 blurRadius: 8,
//   //                 offset: const Offset(0, 3),
//   //               ),
//   //             ],
//   //           ),
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               /// 🔥 SECTION TITLE (હવે આ આખી રો ડ્રેગ હેન્ડલ તરીકે કામ કરશે)
//   //               Row(
//   //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //                 children: [
//   //                   Row(
//   //                     crossAxisAlignment: CrossAxisAlignment.center,
//   //                     children: [
//   //                       Container(
//   //                         padding: const EdgeInsets.all(6),
//   //                         decoration: BoxDecoration(
//   //                           gradient: LinearGradient(
//   //                             colors: [
//   //                               AppColors.primaryDark.withOpacity(0.7),
//   //                               AppColors.secondaryDark.withOpacity(0.7),
//   //                             ],
//   //                           ),
//   //                           borderRadius: BorderRadius.circular(10),
//   //                         ),
//   //                         child: const Icon(
//   //                           Icons.drag_indicator,
//   //                           color: Colors.white,
//   //                           size: 20,
//   //                         ),
//   //                       ),
//   //
//   //                       const SizedBox(width: 10),
//   //
//   //                       Column(
//   //                         mainAxisAlignment: MainAxisAlignment.center,
//   //                         crossAxisAlignment: CrossAxisAlignment.start,
//   //                         mainAxisSize: MainAxisSize.min,
//   //                         children: [
//   //                           Text(
//   //                             sectionName,
//   //                             textAlign: TextAlign.center,
//   //                             style: const TextStyle(
//   //                               fontSize: 15,
//   //                               fontWeight: FontWeight.bold,
//   //                               color: Colors.black,
//   //                             ),
//   //                           ),
//   //
//   //                           Text(
//   //                             getSectionSubtitle(sectionName),
//   //                             style: TextStyle(
//   //                               fontSize: 12,
//   //                               color: AppColors.textLight,
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ],
//   //                   ),
//   //                   Container(
//   //                     padding: const EdgeInsets.symmetric(
//   //                       horizontal: 10,
//   //                       vertical: 3,
//   //                     ),
//   //                     decoration: BoxDecoration(
//   //                       gradient: LinearGradient(
//   //                         colors: [
//   //                           AppColors.primaryDark.withOpacity(0.7),
//   //                           AppColors.secondaryDark.withOpacity(0.7),
//   //                         ],
//   //                       ),
//   //                       borderRadius: BorderRadius.circular(8),
//   //                     ),
//   //                     child: Text(
//   //                       "${items.length} Items",
//   //                       style: const TextStyle(
//   //                         color: Colors.white,
//   //                         fontWeight: FontWeight.w600,
//   //                         fontSize: 12,
//   //                       ),
//   //                     ),
//   //                   ),
//   //                 ],
//   //               ),
//   //               const SizedBox(height: 14),
//   //
//   //               /// 🔥 GRID
//   //               GridView.builder(
//   //                 itemCount: items.length,
//   //                 shrinkWrap: true,
//   //                 physics: const NeverScrollableScrollPhysics(),
//   //                 padding: EdgeInsets.zero,
//   //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//   //                   crossAxisCount: crossAxisCount(),
//   //                   crossAxisSpacing: 12,
//   //                   mainAxisSpacing: 12,
//   //                   childAspectRatio: childAspectRatio(),
//   //                 ),
//   //                 itemBuilder: (context, index) {
//   //                   final item = items[index];
//   //                   final module = item["module"] ?? "";
//   //
//   //                   final count = context
//   //                       .watch<NotificationProvider>()
//   //                       .moduleCount(module);
//   //
//   //                   //print("Module: $module -> Count: $count");
//   //                   return _premiumMenuCard(
//   //                     context,
//   //                     item["title"],
//   //                     item["icon"],
//   //                     () async {
//   //                       readModule(module);
//   //                       final result = await Navigator.push(
//   //                         context,
//   //                         MaterialPageRoute(builder: (_) => item["screen"]),
//   //                       );
//   //
//   //                       // 👇 Child page mathi pop thay pachi
//   //                       if (result == true) {
//   //                         print("Refresh");
//   //                         await getCompanyProfile();
//   //                         setState(() {});
//   //                       }
//   //                     },
//   //                     count: count,
//   //                   );
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //         );
//   //       }).toList(),
//   //     ),
//   //   );
//   // }
//
//   Widget popularProductsSection(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//
//     int crossAxisCount() {
//       if (width < 600) return 3;
//       if (width < 900) return 3;
//       if (width < 1200) return 4;
//       return 5;
//     }
//
//     double childAspectRatio() {
//       if (width < 600) return 0.94;
//       if (width < 900) return 1.1;
//       return 1.2;
//     }
//
//     //--- GROUPING LOGIC (same) ---
//     Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//     for (var item in dashboardItems) {
//       String section = item["section"] ?? "Other";
//       if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//       tempGrouped[section]!.add(item);
//     }
//
//     Map<String, List<Map<String, dynamic>>> groupedItems = {};
//     List<Map<String, dynamic>> otherItems = [];
//     tempGrouped.forEach((section, items) {
//       if (userRoleNames.length == 1) {
//         otherItems.addAll(items);
//       } else {
//         groupedItems[section] = items;
//       }
//     });
//
//     if (otherItems.isNotEmpty) {
//       groupedItems["Others"] = otherItems;
//     }
//     if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//
//     // --- GROUPING LOGIC ---
//
//     //updateSectionOrder(groupedItems);
//
//     return Padding(
//       padding: const EdgeInsets.all(10.0),
//       child: ReorderableListView(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         onReorder: _onReorder,
//         proxyDecorator: (child, index, animation) => child,
//         children: sectionOrder.map((sectionName) {
//           if (!groupedItems.containsKey(sectionName))
//             return SizedBox(key: ValueKey(sectionName));
//
//           List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//
//           /// 🔥 Default expanded state (na hoy to true rakho — pehla khulu j dekhay)
//           // bool isExpanded = expandedSections[sectionName] ?? false;
//           /// 🔥 Fakt PEHLU section default open rahe, baki badha collapsed
//           final bool isExpanded = expandedSections[sectionName] ?? false;
//
//           return Material(
//             key: ValueKey(sectionName),
//             color: Colors.transparent,
//             child: Container(
//               key: ValueKey(sectionName),
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: AppColors.border),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// 🔥 SECTION TITLE — have TAP thi expand/collapse thashe
//                   InkWell(
//                     onTap: () async {
//                       final bool currentlyExpanded =
//                           expandedSections[sectionName] ?? false;
//
//                       setState(() {
//                         /// Pehla badha sections close
//                         for (final section in sectionOrder) {
//                           expandedSections[section] = false;
//                         }
//
//                         /// Jo current section pehla close hato,
//                         /// to fakt ene open karo.
//                         ///
//                         /// Jo already open hato,
//                         /// to badha close j rehse.
//                         if (!currentlyExpanded) {
//                           expandedSections[sectionName] = true;
//                         }
//                       });
//
//                       await saveExpandedSections();
//                     },
//                     borderRadius: BorderRadius.circular(8),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             /// 🔥 Drag handle — have ReorderableDragStartListener thi wrap karyu,
//                             /// jethi fakt AA icon j drag mate vaparay, baki title tap expand/collapse kare
//                             ReorderableDragStartListener(
//                               index: sectionOrder.indexOf(sectionName),
//                               child: Container(
//                                 padding: const EdgeInsets.all(6),
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [
//                                       AppColors.primaryDark.withOpacity(0.7),
//                                       AppColors.secondaryDark.withOpacity(0.7),
//                                     ],
//                                   ),
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                                 child: const Icon(
//                                   Icons.drag_indicator,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 10),
//
//                             Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   sectionName,
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                                 Text(
//                                   getSectionSubtitle(sectionName),
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: AppColors.textLight,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 3,
//                               ),
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark.withOpacity(0.7),
//                                     AppColors.secondaryDark.withOpacity(0.7),
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//                               child: Text(
//                                 "${items.length} Items",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 8),
//
//                             /// 🔥 Expand/Collapse Arrow
//                             AnimatedRotation(
//                               turns: isExpanded ? 0.5 : 0,
//                               duration: const Duration(milliseconds: 250),
//                               child: Container(
//                                 padding: const EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.background,
//                                   borderRadius: BorderRadius.circular(6),
//                                   border: Border.all(color: AppColors.border),
//                                 ),
//                                 child: Icon(
//                                   Icons.keyboard_arrow_down,
//                                   size: 18,
//                                   color: AppColors.primaryDark,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   /// 🔥 GRID — AnimatedCrossFade thi smooth expand/collapse
//                   AnimatedCrossFade(
//                     duration: const Duration(milliseconds: 250),
//                     crossFadeState: isExpanded
//                         ? CrossFadeState.showFirst
//                         : CrossFadeState.showSecond,
//                     firstChild: Padding(
//                       padding: const EdgeInsets.only(top: 14),
//                       child: GridView.builder(
//                         itemCount: items.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         padding: EdgeInsets.zero,
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: crossAxisCount(),
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 12,
//                           childAspectRatio: childAspectRatio(),
//                         ),
//                         itemBuilder: (context, index) {
//                           final item = items[index];
//                           final module = item["module"] ?? "";
//
//                           final count = context
//                               .watch<NotificationProvider>()
//                               .moduleCount(module);
//
//                           return _premiumMenuCard(
//                             context,
//                             item["title"],
//                             item["icon"],
//                             () async {
//                               /// Notification read
//                               readModule(module);
//
//                               /// 🔥 Navigate karta PEHLA section top + open
//                               //moveSectionToTopAndOpen(sectionName);
//
//                               /// Screen open
//                               final result = await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => item["screen"],
//                                 ),
//                               );
//
//                               if (!mounted) return;
//
//                               /// 🔥 BACK AAVYA PACHI FARITHI ENSURE KARO
//                               //await moveSectionToTopAndOpen(sectionName);
//
//                               /// Data refresh required hoy to
//                               if (result == true) {
//                                 await getCompanyProfile();
//                                 await loadRates(silent: true);
//                                 WidgetsBinding.instance.addPostFrameCallback((
//                                   _,
//                                 ) {
//                                   context
//                                       .read<NotificationProvider>()
//                                       .loadNotificationCount();
//                                 });
//                                 // /// getCompanyProfile rebuild kare pachi pan
//                                 // /// current section restore karo
//                                 // await moveSectionToTopAndOpen(sectionName);
//                               }
//                             },
//                             count: count,
//                           );
//                         },
//                       ),
//                     ),
//                     secondChild: const SizedBox(width: double.infinity),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _premiumMenuCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     VoidCallback onTap, {
//     int count = 0,
//   }) {
//     return Material(
//       // 🔥 આ ઉમેરવાથી "No Material found" એરર દૂર થશે
//       color: Colors.transparent, // બેકગ્રાઉન્ડ ટ્રાન્સપરન્ટ રાખવું
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.border),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               /// 🔥 ICON CIRCLE
//               Stack(
//                 clipBehavior: Clip.none,
//                 children: [
//                   Container(
//                     height: 40,
//                     width: 40,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(15),
//                       shape: BoxShape.rectangle,
//                     ),
//                     child: Icon(icon, color: Colors.white, size: 22),
//                   ),
//
//                   /// Notification Count
//                   if (count > 0)
//                     Positioned(
//                       top: -6,
//                       right: -6,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 5,
//                           vertical: 2,
//                         ),
//                         constraints: const BoxConstraints(
//                           minWidth: 18,
//                           minHeight: 18,
//                         ),
//                         decoration: const BoxDecoration(
//                           color: Colors.red,
//                           shape: BoxShape.circle,
//                         ),
//                         alignment: Alignment.center,
//                         child: Text(
//                           count > 99 ? "99+" : "$count",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 9,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//
//               const SizedBox(height: 5),
//
//               /// TITLE
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//   //////////////////////////////////////////////////////////////
//   /// 🔵 PRODUCT CARD
//   //////////////////////////////////////////////////////////////
//
//   Widget productCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     VoidCallback onTap,
//   ) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//     final isTablet = width > 600;
//
//     return GestureDetector(
//       onTap: onTap,
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//           child: Container(
//             padding: EdgeInsets.all(width * 0.04),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.1),
//                 width: 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 15,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   height: isTablet ? width * 0.10 : width * 0.14,
//                   width: isTablet ? width * 0.10 : width * 0.16,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF1E2A55), Color(0xFF1E2A55)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFF0D1633).withOpacity(0.5),
//                         blurRadius: 20,
//                         offset: const Offset(0, 8),
//                       ),
//                     ],
//                   ),
//                   child: Icon(
//                     icon,
//                     color: Colors.white,
//                     size: isTablet ? width * 0.04 : width * 0.06,
//                   ),
//                 ),
//                 SizedBox(height: height * 0.015),
//                 Text(
//                   title,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: AppColors.white,
//                     fontSize: isTablet ? width * 0.022 : width * 0.035,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget customBottomNav() {
//     final size = MediaQuery.of(context).size;
//     final double width = size.width;
//
//     /// ============================================
//     /// RESPONSIVE BREAKPOINTS
//     /// ============================================
//     final bool isVerySmallPhone = width < 340;
//     final bool isSmallPhone = width >= 340 && width < 400;
//     final bool isMobile = width < 600;
//     final bool isTablet = width >= 600 && width < 1000;
//     final bool isDesktop = width >= 1000;
//
//     /// ============================================
//     /// RESPONSIVE HEIGHT
//     /// ============================================
//     final double navHeight;
//
//     if (isDesktop) {
//       navHeight = 78;
//     } else if (isTablet) {
//       navHeight = 72;
//     } else if (isVerySmallPhone) {
//       navHeight = 62;
//     } else if (isSmallPhone) {
//       navHeight = 65;
//     } else {
//       navHeight = 68;
//     }
//
//     /// ============================================
//     /// RESPONSIVE ICON SIZE
//     /// ============================================
//     final double iconSize;
//
//     if (isDesktop) {
//       iconSize = 25;
//     } else if (isTablet) {
//       iconSize = 22;
//     } else if (isVerySmallPhone) {
//       iconSize = 18;
//     } else if (isSmallPhone) {
//       iconSize = 19;
//     } else {
//       iconSize = 21;
//     }
//
//     /// ============================================
//     /// RESPONSIVE FONT SIZE
//     /// ============================================
//     final double fontSize;
//
//     if (isDesktop) {
//       fontSize = 12;
//     } else if (isTablet) {
//       fontSize = 10.5;
//     } else if (isVerySmallPhone) {
//       fontSize = 8.5;
//     } else if (isSmallPhone) {
//       fontSize = 9;
//     } else {
//       fontSize = 10;
//     }
//
//     /// ============================================
//     /// RESPONSIVE HORIZONTAL MARGIN
//     ///
//     /// Tablet ma width cut na kariye.
//     /// Aa overflow avoid karva important che.
//     /// ============================================
//     final double horizontalMargin;
//
//     if (isDesktop) {
//       horizontalMargin = width * 0.12;
//     } else if (isTablet) {
//       horizontalMargin = 8;
//     } else {
//       horizontalMargin = 0;
//     }
//
//     /// ============================================
//     /// RESPONSIVE RADIUS
//     /// ============================================
//     final double radius = isMobile ? 12 : 15;
//
//     return SafeArea(
//       top: false,
//       child: Container(
//         height: navHeight,
//         margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(radius),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.12),
//               blurRadius: 12,
//               offset: const Offset(0, -3),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(radius),
//           child: BottomNavigationBar(
//             /// ========================================
//             /// BASIC
//             /// ========================================
//             backgroundColor: Colors.white,
//
//             currentIndex: selectedIndex,
//
//             type: BottomNavigationBarType.fixed,
//
//             elevation: 0,
//
//             /// ========================================
//             /// ICON
//             /// ========================================
//             iconSize: iconSize,
//
//             /// ========================================
//             /// FONT
//             /// ========================================
//             selectedFontSize: fontSize,
//             unselectedFontSize: fontSize,
//
//             selectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w600,
//               height: 1.0,
//             ),
//
//             unselectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w500,
//               height: 1.0,
//             ),
//
//             /// ========================================
//             /// COLOR
//             /// ========================================
//             selectedItemColor: AppColors.primaryDark,
//
//             unselectedItemColor: Colors.grey.shade600,
//
//             /// ========================================
//             /// LABEL SETTINGS
//             /// ========================================
//             showSelectedLabels: true,
//             showUnselectedLabels: true,
//
//             /// ========================================
//             /// CLICK
//             /// ========================================
//             onTap: (index) {
//               final item = bottomItems[index];
//
//               /// MORE CLICK
//               if (item["title"] == "More") {
//                 showMenuSelectionDialog(isBottomNavMode: true);
//                 return;
//               }
//
//               setState(() {
//                 selectedIndex = index;
//               });
//
//               /// SCREEN OPEN
//               if (item["screen"] != null) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => item["screen"]),
//                 );
//               }
//             },
//
//             /// ========================================
//             /// ITEMS
//             /// ========================================
//             items: bottomItems.map((item) {
//               final String title = item["title"]?.toString() ?? "";
//
//               return BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(bottom: isVerySmallPhone ? 1 : 2),
//                   child: Icon(item["icon"], size: iconSize),
//                 ),
//
//                 /// Long label hoy to short kari shakai
//                 label: title,
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget addNewGlassCard() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(12),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.05), // glass transparency
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 10,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.add, color: AppColors.white, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 "Add New",
//                 style: TextStyle(
//                   color: AppColors.white,
//                   fontWeight: FontWeight.w500,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget gradientIcon(IconData icon, bool selected) {
//     return ShaderMask(
//       shaderCallback: (bounds) {
//         return LinearGradient(
//           colors: selected
//               ? const [Colors.white54, Colors.white54]
//               : const [Colors.white54, Colors.white54],
//         ).createShader(bounds);
//       },
//       child: Icon(icon, color: Colors.white, size: 24),
//     );
//   }
//
//   void showMenuSelectionDialog({bool isBottomNavMode = false}) {
//     List<Map<String, dynamic>> sections = [
//       {
//         "title": "Item Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Item List",
//             "icon": Icons.add_box,
//             "screen": const Itemscreen(),
//             "prefix": "item", // ✅ ADD
//           },
//           {
//             "title": "Label Config",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Labelscreen(),
//             "prefix": "label-config", // ✅ ADD
//           },
//           {
//             "title": "Label Items",
//             "icon": Icons.label_important_outlined,
//             "screen": const label_item_screen(),
//             "prefix": "item-set", // ✅ ADD
//           },
//           {
//             "title": "Label Printing",
//             "icon": Icons.print,
//             "screen": const LabelPrintScreen(),
//             "prefix": "label-print", // ✅ ADD
//           },
//           {
//             "title": "Other Charges",
//             "icon": Icons.settings_applications,
//             "screen": const Othersscreen(),
//             "prefix": "other-charge", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "User Management",
//         "icon": Icons.dashboard_customize,
//         "items": [
//           {
//             "title": "Person",
//             "icon": Icons.person_add,
//             "screen": const Customerscreen(),
//             "prefix": "person", // ✅ ADD
//           },
//           {
//             "title": "Users",
//             "icon": Icons.people,
//             "screen": const Userscreen(),
//             "prefix": "user", // ✅ ADD
//           },
//           {
//             "title": "Category",
//             "icon": Icons.people,
//             "screen": const Categoryscreen(),
//             "prefix": "category-person", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "JobWork Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Labour Formula",
//             "icon": Icons.add_box,
//             "screen": const JobLabourformulaScreen(),
//             "prefix": "labour-formula", // ✅ ADD
//           },
//           {
//             "title": "Production Cost",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Productioncost(),
//             "prefix": "production-cost", // ✅ ADD
//           },
//           {
//             "title": "Production Step",
//             "icon": Icons.label_important_outlined,
//             "screen": const Prooductionstepscreen(),
//             "prefix": "production-step", // ✅ ADD
//           },
//           // {
//           //   "title": "Job Worker",
//           //   "icon": Icons.print,
//           //   "screen": const Jobworkerscreen(),
//           //   "prefix": "job-worker", // ✅ ADD
//           // },
//           {
//             "title": "Jobwork Issue",
//             "icon": Icons.settings_applications,
//             "screen": const JobworkIssueScreen(),
//             "prefix": "jobwork-issue", // ✅ ADD
//           },
//           {
//             "title": "Jobwork Receive",
//             "icon": Icons.settings_applications,
//             "screen": const Jobworkreceivescreen(),
//             "prefix": "jobwork-receive", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Sales",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Sale on Approvals",
//             "icon": Icons.qr_code,
//             "screen": const InvoiceScreen(),
//             "prefix": "approval", // ✅ ADD
//           },
//           {
//             "title": "Sales Estimate",
//             "icon": Icons.sell,
//             "screen": const SellList(),
//             "prefix": "sale", // ✅ ADD
//           },
//           {
//             "title": "Approval Return",
//             "icon": Icons.sell,
//             "screen": const Approvalreturnscreen(),
//             "prefix": "approval-return", // ✅ ADD
//           },
//           {
//             "title": "Rec-Ret-Purchase",
//             "icon": Icons.sell,
//             "screen": const ReciveReturnPurchase(),
//             "prefix": "sale-advance", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Reports & Tools",
//         "icon": Icons.analytics,
//         "items": [
//           {
//             "title": "Sales Summary",
//             "icon": Icons.bar_chart,
//             "screen": const Salesumryreport(),
//             "prefix": "report-sales-summary", // ✅ ADD
//           },
//           {
//             "title": "Reciver Summary",
//             "icon": Icons.qr_code_scanner,
//             "screen": const Purchasereciversummary(),
//             "prefix": "receiver-summary", // ✅ ADD
//           },
//           {
//             "title": "Stock Position",
//             "icon": Icons.bar_chart,
//             "screen": const Stockpositionreport(),
//             "prefix": "report-stock-position", // ✅ ADD
//           },
//           {
//             "title": "Approval Outstanding",
//             "icon": Icons.menu_book,
//             "screen": const Approvaloutstandingreport(),
//             "prefix": "report-approval-outstanding", // ✅ ADD
//           },
//           {
//             "title": "Barcode History",
//             "icon": Icons.menu_book,
//             "screen": const Barcodehistory(),
//             "prefix": "report-barcode-history", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Role & Permission",
//         "icon": Icons.admin_panel_settings,
//         "items": [
//           {
//             "title": "Roles",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Rolescreen(),
//             "prefix": "role", // ✅ ADD
//           },
//           {
//             "title": "Permissions",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Permissionscreen(),
//             "prefix": "permission", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Casting Management",
//         "icon": Icons.settings,
//         "items": [
//           {
//             "title": "Buch",
//             "icon": Icons.settings,
//             "screen": const Buchscreen(),
//             "prefix": "vacuum-buch",
//           },
//           {
//             "title": "Process",
//             "icon": Icons.settings,
//             "screen": const Processscreen(),
//             "prefix": "vacuum-process",
//           },
//           {
//             "title": "Vacuum Voucher",
//             "icon": Icons.settings,
//             "screen": const Voucherscreen(),
//             "prefix": "vacuum-voucher",
//           },
//           {
//             "title": "Casting Heating",
//             "icon": Icons.settings,
//             "screen": const Castingheatingscreen(),
//             "prefix": "casting-heating",
//           },
//           {
//             "title": "Casting Metal",
//             "icon": Icons.settings,
//             "screen": const Castingmetalscreen(),
//             "prefix": "casting-metal-issue",
//           },
//           {
//             "title": "Casting Receive",
//             "icon": Icons.settings,
//             "screen": const Castingrecivescreen(),
//             "prefix": "casting-release",
//           },
//           {
//             "title": "Tree Cutting Office",
//             "icon": Icons.settings,
//             "screen": const Treecuttingoffice(),
//             "prefix": "tree-cutting-office",
//           },
//           {
//             "title": "Tree Cutting Issue",
//             "icon": Icons.settings,
//             "screen": const Treecuttingissuescreen(),
//             "prefix": "tree-cutting-issue",
//           },
//           {
//             "title": "Tree Cutting Receive",
//             "icon": Icons.settings,
//             "screen": const Treecuttingreceivescreen(),
//             "prefix": "tree-cutting-receive",
//           },
//           {
//             "title": "Casting Sorting",
//             "icon": Icons.settings,
//             "screen": const Castingsortscreen(),
//             "prefix": "casting-sorting",
//           },
//         ],
//       },
//     ];
//
//     List<Map<String, dynamic>> filteredSections = sections
//         .map((section) {
//           List items = (section["items"] as List).where((item) {
//             String prefix = item["prefix"].toString();
//
//             /// 🔥 Same logic — view ya manage both check karo
//             return userPermissions.contains("$prefix-view") ||
//                 userPermissions.contains("$prefix-manage") ||
//                 userPermissions.contains("$prefix-create") ||
//                 userPermissions.contains("$prefix-edit") ||
//                 userPermissions.contains("$prefix-delete");
//           }).toList();
//
//           return {
//             "title": section["title"],
//             "icon": section["icon"],
//             "items": items,
//           };
//         })
//         .where((section) => (section["items"] as List).isNotEmpty)
//         .toList();
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setStateBottom) {
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.80,
//
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.background.withOpacity(0.9),
//                     AppColors.background.withOpacity(0.9),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
//               ),
//
//               child: Column(
//                 children: [
//                   const SizedBox(height: 14),
//
//                   Container(
//                     width: 60,
//                     height: 5,
//
//                     decoration: BoxDecoration(
//                       color: Colors.black,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   const Text(
//                     "Customize Dashboard",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   Expanded(
//                     child: ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//
//                       itemCount: filteredSections.length,
//
//                       itemBuilder: (context, sectionIndex) {
//                         final section =
//                             filteredSections[sectionIndex]; // ✅ FIXED
//
//                         return Container(
//                           margin: const EdgeInsets.only(bottom: 14),
//
//                           decoration: BoxDecoration(
//                             color: AppColors.background,
//                             border: Border.all(
//                               color: AppColors.border,
//                               width: 1.5,
//                             ),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//
//                           child: Theme(
//                             data: Theme.of(
//                               context,
//                             ).copyWith(dividerColor: Colors.transparent),
//
//                             child: ExpansionTile(
//                               tilePadding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 4,
//                               ),
//
//                               childrenPadding: const EdgeInsets.only(
//                                 left: 12,
//                                 right: 12,
//                                 bottom: 12,
//                               ),
//
//                               leading: Container(
//                                 padding: const EdgeInsets.all(10),
//
//                                 decoration: BoxDecoration(
//                                   color: AppColors.border,
//                                   border: Border.all(
//                                     color: AppColors.border,
//                                     width: 1.5,
//                                   ),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//
//                                 child: Icon(
//                                   section["icon"],
//                                   color: AppColors.iconBlue,
//                                 ),
//                               ),
//
//                               title: Text(
//                                 section["title"],
//
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 16,
//                                 ),
//                               ),
//
//                               iconColor: AppColors.iconBlue,
//                               collapsedIconColor: AppColors.textPrimary,
//
//                               children: List.generate(section["items"].length, (
//                                 index,
//                               ) {
//                                 final item = section["items"][index];
//
//                                 bool alreadyAdded = isBottomNavMode
//                                     ? bottomItems.any(
//                                         (e) => e["title"] == item["title"],
//                                       )
//                                     : dashboardItems.any(
//                                         (e) => e["title"] == item["title"],
//                                       );
//
//                                 return Container(
//                                   margin: const EdgeInsets.only(bottom: 10),
//
//                                   padding: const EdgeInsets.all(12),
//
//                                   decoration: BoxDecoration(
//                                     gradient: alreadyAdded
//                                         ? const LinearGradient(
//                                             colors: [
//                                               AppColors.border,
//                                               AppColors.border,
//                                             ],
//                                           )
//                                         : LinearGradient(
//                                             colors: [
//                                               AppColors.border,
//                                               AppColors.border,
//                                             ],
//                                           ),
//
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//
//                                   child: Row(
//                                     children: [
//                                       Container(
//                                         height: 45,
//                                         width: 45,
//
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                               AppColors.border.withOpacity(0.5),
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//
//                                         child: Icon(
//                                           item["icon"],
//                                           color: Colors.black,
//                                         ),
//                                       ),
//
//                                       const SizedBox(width: 14),
//
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//
//                                           children: [
//                                             Text(
//                                               item["title"],
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black
//                                                     : Colors.black,
//
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 4),
//
//                                             Text(
//                                               alreadyAdded
//                                                   ? "Added"
//                                                   : "Tap to add",
//
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black87
//                                                     : Colors.black87,
//
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       InkWell(
//                                         onTap: () async {
//                                           if (isBottomNavMode) {
//                                             /// 🔥 BOTTOM NAV MODE — fakt bottomItems manipulate
//                                             if (alreadyAdded) {
//                                               setStateBottom(() {
//                                                 bottomItems.removeWhere(
//                                                   (e) =>
//                                                       e["title"] ==
//                                                       item["title"],
//                                                 );
//                                               });
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               int customCount =
//                                                   bottomItems.length - 2;
//
//                                               if (customCount >= 2) {
//                                                 Navigator.pop(context);
//                                                 Future.delayed(
//                                                   const Duration(
//                                                     milliseconds: 100,
//                                                   ),
//                                                   () {
//                                                     ScaffoldMessenger.of(
//                                                       context,
//                                                     ).showSnackBar(
//                                                       const SnackBar(
//                                                         content: Text(
//                                                           "Maximum 2 items can be added in bottom navigation",
//                                                         ),
//                                                       ),
//                                                     );
//                                                   },
//                                                 );
//                                                 return;
//                                               }
//
//                                               setStateBottom(() {
//                                                 bottomItems.insert(
//                                                   bottomItems.length - 1,
//                                                   {
//                                                     "title": item["title"],
//                                                     "icon": item["icon"],
//                                                     "screen": item["screen"],
//                                                   },
//                                                 );
//                                               });
//                                             }
//
//                                             await saveBottomNavItems();
//                                           } else {
//                                             /// 🔥 DASHBOARD MODE — dashboardItems manipulate (original logic)
//                                             if (alreadyAdded) {
//                                               dashboardItems.removeWhere(
//                                                 (e) =>
//                                                     e["title"] == item["title"],
//                                               );
//                                               bottomItems.removeWhere(
//                                                 (e) =>
//                                                     e["title"] == item["title"],
//                                               );
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               dashboardItems.add({
//                                                 ...item,
//                                                 "section": section["title"],
//                                               });
//                                             }
//
//                                             await saveDashboardItems();
//                                             await loadDashboardItems();
//                                           }
//
//                                           setStateBottom(() {});
//                                           setState(() {});
//                                         },
//
//                                         child: AnimatedContainer(
//                                           duration: const Duration(
//                                             milliseconds: 250,
//                                           ),
//
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 18,
//                                             vertical: 10,
//                                           ),
//
//                                           // decoration: BoxDecoration(
//                                           //
//                                           //   color: alreadyAdded
//                                           //       ? Colors.green
//                                           //       : null,
//                                           //
//                                           //
//                                           //
//                                           //   gradient: alreadyAdded
//                                           //       ? null
//                                           //       : const LinearGradient(
//                                           //     colors: [
//                                           //       Color(0xffE6C58A),
//                                           //       Color(0xffC8A96A),
//                                           //     ],
//                                           //   ),
//                                           //
//                                           //   borderRadius: BorderRadius.circular(12),
//                                           // ),
//                                           decoration: BoxDecoration(
//                                             gradient: LinearGradient(
//                                               colors: alreadyAdded
//                                                   ? [
//                                                       AppColors.iconBlue
//                                                           .withOpacity(0.5),
//                                                       //AppColors.border.withOpacity(0.5),
//                                                       AppColors.iconBlue
//                                                           .withOpacity(0.5),
//                                                     ]
//                                                   : const [
//                                                       Color(0xffE6C58A),
//                                                       Color(0xffC8A96A),
//                                                     ],
//                                             ),
//
//                                             borderRadius: BorderRadius.circular(
//                                               5,
//                                             ),
//                                           ),
//
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 alreadyAdded
//                                                     ? Icons.check
//                                                     : Icons.add,
//                                                 color: alreadyAdded
//                                                     ? Colors.white
//                                                     : Colors.black,
//                                                 size: 18,
//                                               ),
//
//                                               const SizedBox(width: 6),
//
//                                               Text(
//                                                 alreadyAdded ? "ADDED" : "ADD",
//
//                                                 style: TextStyle(
//                                                   color: alreadyAdded
//                                                       ? Colors.white
//                                                       : Colors.black,
//                                                   fontWeight: FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               }),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
//
//                     child: InkWell(
//                       onTap: () {
//                         Navigator.pop(context);
//                       },
//
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.primaryDark,
//                               AppColors.secondaryDark,
//                             ],
//                           ),
//
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//
//                         child: const Center(
//                           child: Text(
//                             "DONE",
//
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _onReorder(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) {
//         newIndex -= 1;
//       }
//       final String item = sectionOrder.removeAt(oldIndex);
//       sectionOrder.insert(newIndex, item);
//     });
//   }
//
//   String getSectionSubtitle(String sectionName) {
//     switch (sectionName) {
//       case "Sales":
//         return "Manage all sales activities";
//
//       case "Item Management":
//         return "Manage your inventory & items";
//
//       case "Others":
//         return "Other useful options";
//
//       case "JobWork Management":
//         return "Manage all job work activities";
//
//       case "Report Management":
//         return "Manage all Report activities";
//
//       case "Role Management":
//         return "Manage all Settings activities";
//
//       case "Casting Management":
//         return "Manage all Casting activities";
//
//       case "Management":
//         return "Manage all User activities";
//
//       default:
//         return "";
//     }
//   }
//
//   Widget optionItem(
//     IconData icon,
//     String title,
//     Color iconColor,
//     Color bgColor, {
//     VoidCallback? onTap, // 👈 ADD THIS
//   }) {
//     return InkWell(
//       onTap: onTap, // 👈 ADD THIS
//       borderRadius: BorderRadius.circular(10),
//       child: Column(
//         children: [
//           Container(
//             height: 45,
//             width: 45,
//             decoration: BoxDecoration(
//               color: bgColor,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: iconColor, size: 28),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//               color: Color(0xff14213D),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget metalRateMarquee() {
//     if (rates.isEmpty) {
//       return const SizedBox();
//     }
//
//     String text = "";
//
//     for (var item in rates) {
//       text +=
//           " ${item["symbol"]} (${item["city"]}) : ₹${item["formatted_rate"]}  |";
//     }
//
//     return Container(
//       height: 38,
//       margin: const EdgeInsets.symmetric(horizontal: 10),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xff8B3A3A), Color(0xffC59D5F)],
//         ),
//         borderRadius: BorderRadius.circular(6),
//       ),
//
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10),
//             child: const Icon(
//               Icons.currency_rupee,
//               color: Colors.white,
//               size: 18,
//             ),
//           ),
//
//           Expanded(
//             child: Marquee(
//               text: text,
//
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//
//               velocity: 45,
//
//               blankSpace: 70,
//
//               pauseAfterRound: const Duration(seconds: 2),
//
//               startPadding: 10,
//
//               scrollAxis: Axis.horizontal,
//
//               crossAxisAlignment: CrossAxisAlignment.center,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildStat(IconData icon, String title, String value) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         /// Icon Background
//         Container(
//           height: 30,
//           width: 30,
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(5),
//             border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
//           ),
//           child: Icon(icon, color: Colors.white, size: 16),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           value,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 13,
//           ),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           title,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: Colors.white70, fontSize: 11),
//         ),
//       ],
//     );
//   }
//
//   Widget buildWelcomeSection() {
//     return Row(
//       children: [
//         // Container(
//         //   height: 45,
//         //   width: 45,
//         //   decoration: BoxDecoration(
//         //     color: Colors.white.withOpacity(.15),
//         //     shape: BoxShape.circle,
//         //     border: Border.all(color: Colors.white24),
//         //   ),
//         //   child: const Icon(
//         //     Icons.person,
//         //     color: Colors.white,
//         //     size: 24,
//         //   ),
//         // ),
//         const SizedBox(width: 12),
//
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Good Morning 👋",
//                 style: TextStyle(color: Colors.white70, fontSize: 13),
//               ),
//
//               const SizedBox(height: 2),
//
//               Text(
//                 "Welcome",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(.15),
//             borderRadius: BorderRadius.circular(5),
//           ),
//           child: const Text(
//             "Manager",
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget buildFirstRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.currency_rupee, "Sales", "₹0.00")),
//         Expanded(child: buildStat(Icons.trending_up, "Month Sales", "₹160")),
//         Expanded(child: buildStat(Icons.assignment_return, "Returns", "₹20")),
//         Expanded(child: buildStat(Icons.check_circle, "Complete", "25")),
//       ],
//     );
//   }
//
//   Widget buildSecondRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.approval, "Approvals", "12")),
//         Expanded(child: buildStat(Icons.pending_actions, "Pending", "08")),
//         Expanded(child: buildStat(Icons.local_offer, "Labels", "41")),
//         Expanded(child: buildStat(Icons.people, "Users", "4 / 8")),
//       ],
//     );
//   }
//
//   Future<void> loadExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? saved = prefs.getString("expanded_sections");
//
//     if (saved != null && saved.isNotEmpty) {
//       List<String> openSections = saved.split(",");
//
//       setState(() {
//         // 🔥 Fakt PEHLO section j open rakho (accordion rule)
//         String? firstOpen = openSections.isNotEmpty ? openSections.first : null;
//         expandedSections = {};
//         if (firstOpen != null) {
//           expandedSections[firstOpen] = true;
//         }
//       });
//     }
//   }
//
//   Future<void> saveExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // 🔥 Fakt PEHLO open section j save karo (max 1)
//     List<String> openSections = expandedSections.entries
//         .where((e) => e.value == true)
//         .map((e) => e.key)
//         .toList();
//
//     await prefs.setString("expanded_sections", openSections.join(","));
//   }
//
//   Future<void> saveSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setStringList("section_order", sectionOrder);
//   }
//
//   Future<void> loadSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     final saved = prefs.getStringList("section_order");
//
//     if (saved != null && saved.isNotEmpty) {
//       setState(() {
//         // 🔥 Saved order set karo (agar navi sections hoy to pachi automatically add thai jashe _updateSectionOrderForNewItems() thi)
//         sectionOrder = saved;
//       });
//     }
//   }
// }


// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
// import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
// import 'package:pecifician_sysytem/Approval/Recive_return_purchase.dart';
// import 'package:pecifician_sysytem/Dashboard/DiamondReportsUI.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
// import 'package:pecifician_sysytem/QR%20Making/AddQrScreen.dart';
// import 'package:pecifician_sysytem/QR%20Making/QrListScreen.dart';
// import 'package:pecifician_sysytem/Reports/ApprovalReturnRegisterScreen.dart';
// import 'package:pecifician_sysytem/Reports/ApprovalSummaryScreen.dart';
// import 'package:pecifician_sysytem/Reports/OutStandingAmount.dart';
// import 'package:pecifician_sysytem/Reports/WorkerLossReportScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/SellScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CategoryScreen.dart';
// import 'package:pecifician_sysytem/User/CreateCustomer.dart';
// import 'package:pecifician_sysytem/User/OfficeAccessSettingsScreen.dart';
// import 'package:pecifician_sysytem/User/UserScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
// import 'package:pecifician_sysytem/Visiting%20Card/Visitingcard.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Approval/ApproveListScreen.dart';
// import '../Approval/ReceivevoucharScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/GlobalDrawer.dart';
// import '../Extra/NotificationProvider.dart';
// import '../Settings/LiveMetalRatesScreen.dart';
// import '../Settings/SettingsScreen.dart';
// import '../Item_Mangement/Item/ItemScreen.dart';
// import '../Item_Mangement/Label Print/Label_print_Screen.dart';
// import '../Item_Mangement/Label/LabelScreen.dart';
// import '../Item_Mangement/Label_Items/label_item_screen.dart';
// import '../Item_Mangement/Others/Othersscreen.dart';
// import '../Job Work/Job Work Issue/Jobwork_issue_Screen.dart';
// import '../Job Work/Job Worker/JobWorkerScreen.dart';
// import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
// import '../Job Work/Production_Costs/ProductionCost.dart';
// import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
// import '../Notification/NotificationScreen.dart';
// import '../Reports/ApprovalOutstandingReport.dart';
// import '../Reports/BarcodeHistory.dart';
// import '../Reports/PurchaseReciverSummary.dart';
// import '../Reports/SaleSumryReport.dart';
// import '../Reports/StockPositionReport.dart';
// import '../Role & Permission/PermissionScreen.dart';
// import '../Role & Permission/RoleScreen.dart';
// import '../User/CustomerScreen.dart';
// import '../Vacuum/Casting/CastingHeatingScreen.dart';
// import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
// import '../Vacuum/Casting_Recive/CastingReciveScreen.dart';
// import '../Vacuum/Casting_Sort/CastingSortScreen.dart';
// import '../Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
// import '../Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
// import '../Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
// import '../Vacuum/Vacuum Process/ProcessScreen.dart';
// import '../Vacuum/Vouchar History/VoucharHistoryScreen.dart';
// import 'InventoryScreen.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   int selectedIndex = 0;
//   List<String> sectionOrder = [];
//   List<String> userRoleNames = [];
//   List<String> userPermissions = []; // ✅ aa hovu joiye
//   List<Map<String, dynamic>> bottomItems = [
//     {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//
//     {"title": "More", "icon": Icons.more_horiz},
//   ];
//   List rates = [];
//   String source = "";
//   String updatedAt = "";
//   Timer? autoRefreshTimer;
//   String? activeSection;
//   Map<String, double> _previousRateValues = {};
//   Map<String, Color> _rateColors = {};
//   /// ============================================================
//   /// 🔥 PLAN ALERT POPUP GUARD
//   ///
//   /// Ek j session ma popup vaar-vaar na khule (dar vaar getCompanyProfile
//   /// call thay tyare) — matra jyare tak user e already dekhi na hoy.
//   /// Jo tame har vaar j dekhadvu hoy to aa flag hatavi shakay.
//   /// ============================================================
//   bool _planAlertShown = false;
//
//   Future<void> moveSectionToTopAndOpen(String sectionName) async {
//     // if (!mounted) return;
//
//     setState(() {
//       activeSection = sectionName;
//
//       /// Section top par
//       sectionOrder.remove(sectionName);
//       sectionOrder.insert(0, sectionName);
//
//       /// Badha close
//       for (final key in sectionOrder) {
//         expandedSections[key] = false;
//       }
//
//       /// Current section open
//       expandedSections[sectionName] = true;
//     });
//
//     /// Persist
//     await saveSectionOrder();
//     await saveExpandedSections();
//   }
//
//   /// ============================================================
//   /// 🔥 CHECK IF CURRENT USER IS ADMIN
//   ///
//   /// SharedPreferences ma save thayela "user_role_names" check kare che.
//   /// Fallback tarike current in-memory `userRoleNames` list vaparay che.
//   /// ============================================================
//   Future<bool> _isAdminRole() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     final List<String> savedRoles =
//         prefs.getStringList("user_role_names") ?? [];
//
//     final List<String> roles = savedRoles.isNotEmpty
//         ? savedRoles
//         : userRoleNames;
//
//     return roles.any(
//           (r) =>
//       r.toLowerCase().trim() == "admin" ||
//           r.toLowerCase().trim().contains("admin"),
//     );
//   }
//
//   Future<void> loadRates({bool silent = false}) async {
//     try {
//       /// ============================================
//       /// 🔥 ADMIN CHECK — Default lat/long use karva mate
//       /// ============================================
//       final bool isAdmin = await _isAdminRole();
//
//       String latitude = "";
//       String longitude = "";
//
//       if (isAdmin) {
//         /// ============================================
//         /// 🔥 ADMIN — Fixed default coordinates
//         /// ============================================
//         latitude = "23.0492348";
//         longitude = "72.5800721";
//
//         debugPrint("======================================");
//         debugPrint("🔥 ADMIN ROLE — Using default location");
//         debugPrint("Latitude  => $latitude");
//         debugPrint("Longitude => $longitude");
//         debugPrint("======================================");
//       } else {
//         /// ============================================
//         /// 1. LOCATION SERVICE CHECK
//         ///
//         /// 🔥 IMPORTANT: Service bandh hoy to pan
//         /// return NA karvanu — API call thavi j joie,
//         /// fakt lat/long empty rehse.
//         /// ============================================
//         try {
//           final bool serviceEnabled =
//           await Geolocator.isLocationServiceEnabled();
//
//           if (!serviceEnabled) {
//             debugPrint("⚠️ Location service disabled — proceeding without lat/long");
//
//             if (!silent && mounted) {
//               AppMessage.error(context, "Please enable location service.");
//             }
//           } else {
//             /// ============================================
//             /// 2. LOCATION PERMISSION CHECK
//             /// ============================================
//             LocationPermission permission = await Geolocator.checkPermission();
//
//             if (permission == LocationPermission.denied) {
//               permission = await Geolocator.requestPermission();
//             }
//
//             if (permission == LocationPermission.denied) {
//               debugPrint("⚠️ Location permission denied — proceeding without lat/long");
//
//               if (!silent && mounted) {
//                 AppMessage.error(context, "Location permission is required.");
//               }
//             } else if (permission == LocationPermission.deniedForever) {
//               debugPrint(
//                 "⚠️ Location permission permanently denied — proceeding without lat/long",
//               );
//
//               if (!silent && mounted) {
//                 AppMessage.error(
//                   context,
//                   "Location permission is permanently denied.",
//                 );
//               }
//             } else {
//               /// ============================================
//               /// 3. GET CURRENT LOCATION
//               /// ============================================
//               final Position position = await Geolocator.getCurrentPosition(
//                 locationSettings: const LocationSettings(
//                   accuracy: LocationAccuracy.high,
//                 ),
//               );
//
//               latitude = position.latitude.toString();
//               longitude = position.longitude.toString();
//
//               debugPrint("======================================");
//               debugPrint("📍 CURRENT LOCATION");
//               debugPrint("Latitude  => $latitude");
//               debugPrint("Longitude => $longitude");
//             }
//           }
//         } catch (e) {
//           /// 🔥 Location related koi pan error aave to pan
//           /// aagad vadho (API call j thavi joie)
//           debugPrint("❌ Location Error => $e — proceeding without lat/long");
//         }
//       }
//
//       /// ============================================
//       /// 4. GET DEVICE ID
//       /// ============================================
//       String deviceId = "";
//       String deviceName = "";
//
//       try {
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//           deviceId = androidInfo.id;
//           deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
//         } else if (Platform.isIOS) {
//           final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//           deviceId = iosInfo.identifierForVendor ?? "";
//           deviceName = iosInfo.name;
//         }
//       } catch (e) {
//         debugPrint("❌ Device ID Error => $e");
//         deviceId = "";
//       }
//
//       debugPrint("📱 Device ID => $deviceId");
//       debugPrint("======================================");
//
//       /// ============================================
//       /// 5. CREATE QUERY PARAMETERS
//       /// ============================================
//       final Map<String, dynamic> queryParameters = {
//         "latitude": latitude,
//         "longitude": longitude,
//         "device_id": deviceId,
//       };
//
//       debugPrint("📤 LIVE RATE QUERY => $queryParameters");
//
//       /// ============================================
//       /// 6. API CALL — Location hoy ke na hoy, always thavi joie
//       /// ============================================
//       final response = await ApiHelper().getRequestWithQuery(
//         ApiConstants.live_metal_rates,
//         queryParameters: queryParameters,
//         showLoading: false,
//       );
//
//       debugPrint("======================================");
//       debugPrint("📥 LIVE RATE RESPONSE");
//       debugPrint("Status => ${response?.statusCode}");
//       debugPrint("Data => ${response?.data}");
//       debugPrint("======================================");
//
//       if (response == null) {
//         if (!silent && mounted) {
//           AppMessage.error(context, "No response from server.");
//         }
//         return;
//       }
//
//       if (response.statusCode == 200 && response.data["success"] == true) {
//         final data = response.data;
//         if (!mounted) return;
//
//         setState(() {
//           final List newRates = data["data"] ?? [];
//
//           /// 🔥 Color compare karva mate rates update karta
//           /// PEHLA j call karvanu
//           _updateRateColors(newRates);
//
//           rates = newRates;
//
//           source = data["source"]?.toString() ?? "";
//
//           updatedAt = data["updated_at"]?.toString() ?? "";
//         });
//
//         await loadSelectedRate();
//         return;
//       }
//
//       String message = "Failed to load live rates";
//       final dynamic responseData = response.data;
//
//       if (responseData is Map && responseData["message"] != null) {
//         message = responseData["message"].toString();
//       }
//
//       debugPrint("❌ API MESSAGE => $message");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, message);
//       }
//     } catch (e) {
//       debugPrint("======================================");
//       debugPrint("❌ LOAD RATES ERROR => $e");
//       debugPrint("======================================");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, "Failed to load live rates");
//       }
//     }
//   }
//
//   Map<String, bool> expandedSections = {};
//   int? expandedIndex;
//   String getGreeting() {
//     final hour = DateTime.now().hour;
//
//     if (hour >= 5 && hour < 12) {
//       return "Good Morning 👋";
//     } else if (hour >= 12 && hour < 17) {
//       return "Good Afternoon ☀️";
//     } else if (hour >= 17 && hour < 21) {
//       return "Good Evening 🌇";
//     } else {
//       return "Good Night 🌙";
//     }
//   }
//
//   String selectedSymbol = "GOLD";
//   Map<String, dynamic>? selectedRate;
//   List<Map<String, dynamic>> allMenuItems = [
//     {
//       "title": "Person",
//       "icon": Icons.person_add,
//       "module": "customer",
//       "screen": const Customerscreen(),
//       "section": "Management",
//       "prefix": "person",
//     },
//     {
//       "title": "Users",
//       "icon": Icons.people,
//       "module": "user",
//       "screen": const Userscreen(),
//       "section": "Management",
//       "prefix": "user",
//     },
//     {
//       "title": "Category",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const Categoryscreen(),
//       "section": "Management",
//       "prefix": "category-person",
//     },
//     {
//       "title": "Office Access",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const OfficeAccessSettingsScreen(),
//       "section": "Management",
//       "prefix": "office-access",
//     },
//     {
//       "title": "Sales Estimate",
//       "icon": Icons.sell,
//       "module": "sale",
//       "screen": const SellList(),
//       "section": "Sales",
//       "prefix": "sale",
//     },
//     {
//       "title": "Sale on Approvals",
//       "icon": Icons.qr_code,
//       "module": "approval",
//       "screen": const InvoiceScreen(),
//       "section": "Sales",
//       "prefix": "approval", // ✅ "view" hatavi nakhyu
//     },
//     {
//       "title": "Approval Return",
//       "icon": Icons.sell,
//       "module": "approval_return",
//       "screen": const Approvalreturnscreen(),
//       "section": "Sales",
//       "prefix": "approval-return",
//     },
//     {
//       "title": "Rec-Ret-Purchase",
//       "icon": Icons.sell,
//       "module": "sale_advance",
//       "screen": const Receivevoucharscreen(),
//       "section": "Sales",
//       "prefix": "sale-advance",
//     },
//     // {
//     //   "title": "Reports",
//     //   "icon": Icons.bar_chart,
//     //   "screen": const DiamondReportsFullUI(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "reports",
//     // },
//     // {
//     //   "title": "Scanner",
//     //   "icon": Icons.qr_code_scanner,
//     //   "screen": const PremiumScannerScreen(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "scanner",
//     // },
//     {
//       "title": "Item List",
//       "icon": Icons.add_box,
//       "module": "item",
//       "screen": const Itemscreen(),
//       "section": "Item Management",
//       "prefix": "item",
//     },
//     {
//       "title": "Label Config",
//       "icon": Icons.production_quantity_limits,
//       "module": "label_config",
//       "screen": const Labelscreen(),
//       "section": "Item Management",
//       "prefix": "label-config",
//     },
//     {
//       "title": "Label Items",
//       "icon": Icons.label_important_outlined,
//       "module": "item_set",
//       "screen": const label_item_screen(),
//       "section": "Item Management",
//       "prefix": "item-set",
//     },
//     {
//       "title": "Label Printing",
//       "icon": Icons.print,
//       "screen": const LabelPrintScreen(),
//       "section": "Item Management",
//       "prefix": "label-print",
//     },
//     {
//       "title": "Other Charges",
//       "icon": Icons.settings_applications,
//       "module": "other_charge",
//       "screen": const Othersscreen(),
//       "section": "Item Management",
//       "prefix": "other-charge",
//     },
//     {
//       "title": "Labour Formula",
//       "icon": Icons.add_box,
//       "module": "labour_formula",
//       "screen": const JobLabourformulaScreen(),
//       "section": "JobWork Management",
//       "prefix": "labour-formula",
//     },
//     {
//       "title": "Production Cost",
//       "icon": Icons.production_quantity_limits,
//       "module": "production_cost",
//       "screen": const Productioncost(),
//       "section": "JobWork Management",
//       "prefix": "production-cost",
//     },
//     {
//       "title": "Production Step",
//       "icon": Icons.label_important_outlined,
//       "module": "production_step",
//       "screen": const Prooductionstepscreen(),
//       "section": "JobWork Management",
//       "prefix": "production-step",
//     },
//     // {
//     //   "title": "Job Worker",
//     //   "icon": Icons.print,
//     //   "module": "job_worker",
//     //   "screen": const Jobworkerscreen(),
//     //   "section": "JobWork Management",
//     //   "prefix": "job-worker",
//     // },
//     {
//       "title": "Jobwork Issue",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_issue",
//       "screen": const JobworkIssueScreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-issue",
//     },
//     {
//       "title": "Jobwork Receive",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_receive",
//       "screen": const Jobworkreceivescreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-receive",
//     },
//     {
//       "title": "Sales Summary",
//       "icon": Icons.add_box,
//       "screen": const Salesumryreport(),
//       "section": "Report Management",
//       "prefix": "report-sales-summary",
//     },
//     {
//       "title": "Receiver Summary",
//       "icon": Icons.production_quantity_limits,
//       "screen": const Purchasereciversummary(),
//       "section": "Report Management",
//       "prefix": "report-purchase-receiver-summary",
//     },
//     {
//       "title": "Stock Position",
//       "icon": Icons.label_important_outlined,
//       "screen": const Stockpositionreport(),
//       "section": "Report Management",
//       "prefix": "report-stock-position",
//     },
//     {
//       "title": "Approval Outstanding",
//       "icon": Icons.print,
//       "screen": const Approvaloutstandingreport(),
//       "section": "Report Management",
//       "prefix": "report-approval-outstanding",
//     },
//     {
//       "title": "Barcode History",
//       "icon": Icons.settings_applications,
//       "screen": const Barcodehistory(),
//       "section": "Report Management",
//       "prefix": "report-barcode-history",
//     },
//     {
//       "title": "Outstanding Amount",
//       "icon": Icons.settings_applications,
//       "screen": const Outstandingamount(),
//       "section": "Report Management",
//       "prefix": "report-outstanding-amount",
//     },
//     {
//       "title": "Worker Loss",
//       "icon": Icons.settings_applications,
//       "screen": const WorkerLossReportScreen(),
//       "section": "Report Management",
//       "prefix": "report-worker-loss",
//     },
//     {
//       "title": "Approval Summary",
//       "icon": Icons.settings_applications,
//       "screen": const ApprovalSummaryScreen(),
//       "section": "Report Management",
//       "prefix": "report-worker-loss",
//     },
//     {
//       "title": "Approval Register",
//       "icon": Icons.settings_applications,
//       "screen": const ApprovalReturnRegisterScreen(),
//       "section": "Report Management",
//       "prefix": "report-worker-loss",
//     },
//     {
//       "title": "Roles",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Rolescreen(),
//       "section": "Role Management",
//       "prefix": "role",
//     },
//     {
//       "title": "Permissions",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Permissionscreen(),
//       "section": "Role Management",
//       "prefix": "permission",
//     },
//     {
//       "title": "Buch",
//       "icon": Icons.settings,
//       "module": "vacuum_buch",
//       "screen": const Buchscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-buch",
//     },
//     {
//       "title": "Process",
//       "icon": Icons.settings,
//       "module": "vacuum_process",
//       "screen": const Processscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-process",
//     },
//     {
//       "title": "Vacuum Voucher",
//       "icon": Icons.settings,
//       "module": "vacuum_voucher",
//       "screen": const Voucherscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-voucher",
//     },
//     {
//       "title": "Casting Heating",
//       "icon": Icons.settings,
//       "module": "casting_heating",
//       "screen": const Castingheatingscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-heating",
//     },
//     {
//       "title": "Casting Metal",
//       "icon": Icons.settings,
//       "module": "casting_metal_issue",
//       "screen": const Castingmetalscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-metal-issue",
//     },
//     {
//       "title": "Casting Receive",
//       "icon": Icons.settings,
//       "module": "casting_release",
//       "screen": const Castingrecivescreen(),
//       "section": "Casting Management",
//       "prefix": "casting-release",
//     },
//     {
//       "title": "Tree Cutting Office",
//       "icon": Icons.settings,
//       "module": "tree_cutting_office",
//       "screen": const Treecuttingoffice(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-office",
//     },
//     {
//       "title": "Tree Cutting Issue",
//       "icon": Icons.settings,
//       "module": "tree_cutting_issue",
//       "screen": const Treecuttingissuescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-issue",
//     },
//     {
//       "title": "Tree Cutting Receive",
//       "icon": Icons.settings,
//       "module": "tree_cutting_receive",
//       "screen": const Treecuttingreceivescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-receive",
//     },
//     {
//       "title": "Casting Sorting",
//       "icon": Icons.settings,
//       "module": "casting_sorting",
//       "screen": const Castingsortscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-sorting",
//     },
//
//     {
//       "title": "Voucher History",
//       "icon": Icons.settings,
//       "module": "voucher-history",
//       "screen": const VoucherProcessHistoryScreen(),
//       "section": "Casting Management",
//       "prefix": "voucher-history",
//     },
//   ];
//
//   /// 🔥 DASHBOARD SELECTED ITEMS
//   List<Map<String, dynamic>> dashboardItems = [];
//   String name = "";
//   String email = "";
//   String companyName = "";
//   String State = "";
//   String City = "";
//   String Role = "";
//   String companyLogo = "";
//
//   Future<bool> readModule(String module) async {
//     try {
//       final response = await ApiHelper().postRequest(
//         "${ApiConstants.baseUrl}notifications/read-module",
//         {"module": module},
//       );
//
//       print("Read Module Response : ${response?.data}");
//
//       return response != null &&
//           response.statusCode == 200 &&
//           response.data["success"] == true;
//     } catch (e) {
//       print("Read Module Error : $e");
//       return false;
//     }
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//
//     loadExpandedSections(); // 👈 ADD THIS
//     loadSectionOrder(); // 👈 ADD THIS
//     loadSelectedRate();
//     getCompanyProfile();
//     /// 🔥 Auto refresh every 30 seconds
//     // autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//     //   loadRates(silent: true);
//     // });
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<NotificationProvider>().loadNotificationCount();
//     });
//
//     /// 🔥 IMPORTANT: getCompanyProfile() have role load thai gaya pachi
//     /// j loadRates() call kare che (andar), etle e ne j direct call karo.
//     /// loadRates() ne ahi thi direct call NA karo — nahi to role khali
//     /// hova thi admin check khoto padi shake ane location popup fasi jay.
//
//
//     //updateSectionOrder();
//     /// 🔥 DEFAULT DASHBOARD ITEMS
//     loadDashboardItems();
//     loadBottomNavItems(); // 🔥 ADD
//   }
//
//   Future<void> loadSelectedRate() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     selectedSymbol = prefs.getString("selected_rate_symbol") ?? "GOLD";
//
//     updateSelectedRate();
//
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   void updateSelectedRate() {
//     if (rates.isEmpty) return;
//
//     try {
//       selectedRate = rates.firstWhere((e) => e["symbol"] == selectedSymbol);
//     } catch (e) {
//       selectedRate = rates.first;
//     }
//   }
//
//   /// ============================================================
//   /// 🔥 Raw numeric rate kadhva mate
//   ///
//   /// "formatted_rate" ma comma (,) ke ₹ symbol hoy to pan
//   /// clean double value male e mate.
//   /// ============================================================
//   double? _parseRateValue(dynamic item) {
//     final dynamic raw = item["rate"] ?? item["formatted_rate"];
//     if (raw == null) return null;
//
//     final String cleaned = raw
//         .toString()
//         .replaceAll(",", "")
//         .replaceAll("₹", "")
//         .trim();
//
//     return double.tryParse(cleaned);
//   }
//
//   /// ============================================================
//   /// 🔥 Naya rates aavya pachi dareek symbol nu color update karo
//   ///
//   /// - Rate vadhyu  → Green
//   /// - Rate ghatyu  → Red
//   /// - Same rahyu   → Pehla no color j rakho (change nathi karvanu)
//   ///
//   /// IMPORTANT: Aa function ne `rates` variable update karta
//   /// PEHLA call karvanu, nahi to old vs new compare kai nahi thashe.
//   /// ============================================================
//   void _updateRateColors(List newRatesList) {
//     for (var item in newRatesList) {
//       final String symbol = item["symbol"]?.toString() ?? "";
//       if (symbol.isEmpty) continue;
//
//       final double? newRate = _parseRateValue(item);
//       if (newRate == null) continue;
//
//       if (_previousRateValues.containsKey(symbol)) {
//         final double oldRate = _previousRateValues[symbol]!;
//
//         if (newRate > oldRate) {
//           _rateColors[symbol] = const Color(0xff2ECC71); // 🟢 Green
//         } else if (newRate < oldRate) {
//           _rateColors[symbol] = const Color(0xffE53935); // 🔴 Red
//         }
//         // Equal hoy to jado color j rahese
//       }
//
//       _previousRateValues[symbol] = newRate;
//     }
//   }
//
//   Future<void> loadBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String>? savedTitles = prefs.getStringList("bottom_nav_items");
//
//     List<Map<String, dynamic>> customItems = [];
//
//     if (savedTitles != null && savedTitles.isNotEmpty) {
//       for (var title in savedTitles) {
//         var match = allMenuItems.firstWhere(
//               (e) => e["title"] == title,
//           orElse: () => {},
//         );
//         if (match.isNotEmpty) {
//           customItems.add({
//             "title": match["title"],
//             "icon": match["icon"],
//             "screen": match["screen"],
//           });
//         }
//       }
//     }
//
//     setState(() {
//       bottomItems = [
//         {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//         ...customItems,
//         {"title": "More", "icon": Icons.more_horiz},
//       ];
//     });
//   }
//
//   Future<void> saveBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     List<String> titles = bottomItems
//         .where((e) => e["title"] != "Dashboard" && e["title"] != "More")
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("bottom_nav_items", titles);
//   }
//
//   void updateSectionOrder(
//       Map<String, List<Map<String, dynamic>>> groupedItems,
//       ) {
//     // Naya section keys (jaisi "Others") ne add karo jo already sectionOrder ma nathi
//     for (var key in groupedItems.keys) {
//       if (!sectionOrder.contains(key)) {
//         sectionOrder.add(key);
//       }
//     }
//
//     // Je sections have exist nathi karta groupedItems ma, ene sectionOrder thi remove karo
//     sectionOrder.removeWhere((s) => !groupedItems.containsKey(s));
//   }
//
//   Future<void> loadDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> excludedTitles =
//         prefs.getStringList("excluded_dashboard_items") ?? [];
//
//     /// 🔥 Have allMenuItems (je already permission pramane filtered che)
//     /// ma thi j dashboard items lese — jetli pan API permission hoy e badha
//     /// automatic dashboard par dekhashe (jo user e manually remove na karyu hoy to)
//     List<Map<String, dynamic>> tempItems = allMenuItems
//         .where((item) => !excludedTitles.contains(item["title"]))
//         .toList();
//
//     setState(() {
//       dashboardItems = tempItems;
//       _updateSectionOrderForNewItems();
//     });
//   }
//
//   Future<void> saveDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     /// 🔥 jetla items allMenuItems ma che pan dashboardItems ma nathi
//     /// (user e remove karya che), e excluded list ma save karo
//     List<String> excludedTitles = allMenuItems
//         .where((m) => !dashboardItems.any((d) => d["title"] == m["title"]))
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("excluded_dashboard_items", excludedTitles);
//
//     /// (Optional) jo old key "dashboard_items" use thato hoy biji jagya pan,
//     /// e clear/remove kari shako ke rehva dyo, have e use nathi thato
//   }
//
//   // એક હેલ્પર ફંક્શન સેક્શન ઓર્ડર મેન્ટેન કરવા માટે
//   void _updateSectionOrderForNewItems() {
//     final Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//
//     for (final item in dashboardItems) {
//       final String section = item["section"] ?? "Others";
//
//       tempGrouped.putIfAbsent(section, () => []);
//       tempGrouped[section]!.add(item);
//     }
//
//     final List<String> newOrder = [];
//
//     /// =========================================
//     /// CURRENT ACTIVE SECTION ALWAYS FIRST
//     /// =========================================
//     if (activeSection != null && tempGrouped.containsKey(activeSection)) {
//       newOrder.add(activeSection!);
//     }
//
//     /// =========================================
//     /// OLD ORDER MAINTAIN
//     /// =========================================
//     for (final section in sectionOrder) {
//       if (tempGrouped.containsKey(section) && !newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     /// =========================================
//     /// NEW SECTIONS ADD
//     /// =========================================
//     for (final section in tempGrouped.keys) {
//       if (!newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     if (!mounted) return;
//
//     setState(() {
//       sectionOrder = newOrder;
//
//       /// Active section open
//       if (activeSection != null) {
//         for (final section in sectionOrder) {
//           expandedSections[section] = section == activeSection;
//         }
//       }
//     });
//   }
//
//   Future<void> getCompanyProfile() async {
//     try {
//       final response = await ApiHelper().getRequest(ApiConstants.userProfile);
//
//       if (response == null) {
//         print("❌ No response — default dashboard load karo");
//         await loadDashboardItems();
//
//         /// 🔥 Profile na male to pan rates load karvo padse (role
//         /// khabar nathi etle _isAdminRole() SharedPreferences mathi
//         /// old saved role check karshe, jo pehla login karyu hoy).
//         await loadRates(silent: true);
//         return;
//       }
//
//       if (response.statusCode == 200) {
//         final jsonData = response.data;
//         final userData = jsonData["data"] ?? {};
//         final companyData = userData["company"] ?? {};
//
//         // ============================================================
//         // PROFILE DATA
//         // ============================================================
//
//         final profileData = userData["profile"] ?? {};
//
//         // ============================================================
//         // PERMISSIONS
//         // ============================================================
//
//         final List permissionsRaw =
//             profileData["permissions"] ?? jsonData["permissions"] ?? [];
//
//         final List<String> permissions = permissionsRaw
//             .map((e) => e.toString())
//             .toList();
//
//         // ============================================================
//         // ROLE NAMES
//         // ============================================================
//
//         final List roleNamesRaw = profileData["role_names"] ?? [];
//
//         final List<String> roleNames = roleNamesRaw
//             .map((e) => e.toString())
//             .toList();
//
//         print("✅ User Permissions: $permissions");
//         print("✅ User Role Names: $roleNames");
//
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//
//         setState(() {
//           name = userData["name"]?.toString() ?? "-";
//           email = userData["email"]?.toString() ?? "-";
//           companyName = companyData["name"]?.toString() ?? "-";
//           City = companyData["city"]?.toString() ?? "-";
//           State = companyData["state"]?.toString() ?? "-";
//           companyLogo= companyData["company_logo_url"]?.toString() ?? "-";
//
//           // Save permissions
//           userPermissions = permissions;
//
//           // Save role names
//           userRoleNames = roleNames;
//
//           // Permission filtering
//           filterMenuByPermission();
//         });
//
//         // ============================================================
//         // SAVE USER DATA
//         // ============================================================
//
//         await prefs.setString("name", userData["name"]?.toString() ?? "-");
//
//         await prefs.setString("email", userData["email"]?.toString() ?? "-");
//
//         await prefs.setString(
//           "companyName",
//           companyData["name"]?.toString() ?? "-",
//         );
//
//         await prefs.setString("city", companyData["city"]?.toString() ?? "-");
//
//         await prefs.setString(
//           "state",
//           companyData["state"]?.toString() ?? "-",
//         );
//
//         await prefs.setString("companyLogo", companyData["company_logo_url"]?.toString() ?? "-");
//         await prefs.setString("role", userData["role"]?.toString() ?? "-");
//
//         await prefs.setStringList("user_permissions", userPermissions);
//
//         await prefs.setStringList("user_role_names", userRoleNames);
//
//         // ============================================================
//         // LOAD DASHBOARD
//         // ============================================================
//
//         await loadDashboardItems();
//
//         /// 🔥 IMPORTANT: role (userRoleNames) have set thai gayu che,
//         /// etle have j loadRates() call karo — jethi admin role hoy
//         /// to location popup skip thay, first-time login par pan.
//         await loadRates(silent: true);
//
//         // ============================================================
//         // 🔥 PLAN ALERT POPUP
//         //
//         // company["plan_alert"]["show_popup"] == true hoy to j popup
//         // dekhadvanu. Frame render thai gaya pachi j dialog kholvi
//         // jaruri che, nahi to context still-building error aave.
//         // ============================================================
//
//         final Map planAlert = companyData["plan_alert"] ?? {};
//
//         if (planAlert["show_popup"] == true && !_planAlertShown) {
//           _planAlertShown = true;
//
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (mounted) {
//               _showPlanAlertDialog(planAlert);
//             }
//           });
//         }
//       } else {
//         // API fail
//         await loadDashboardItems();
//
//         /// 🔥 Profile fail thay to pan rates load karvo padse —
//         /// role SharedPreferences mathi (jo pehla save thayu hoy to) male.
//         await loadRates(silent: true);
//       }
//     } catch (e) {
//       print("❌ Exception: $e");
//
//       // Exception aave to default dashboard load
//       await loadDashboardItems();
//
//       /// 🔥 Exception case ma pan rates load karo.
//       await loadRates(silent: true);
//     }
//   }
//
//   /// ============================================================
//   /// 🔥 PLAN ALERT TYPE -> COLOR / ICON MAPPING
//   /// ============================================================
//   Color _planAlertColor(String type) {
//     switch (type.toLowerCase()) {
//       case "expired":
//         return const Color(0xffE53935);
//       case "warning":
//       case "expiring_soon":
//       case "expiring":
//         return const Color(0xffFF9800);
//       case "active":
//         return const Color(0xff2ECC71);
//       default:
//         return AppColors.primaryDark;
//     }
//   }
//
//   IconData _planAlertIcon(String type) {
//     switch (type.toLowerCase()) {
//       case "expired":
//         return Icons.error_outline_rounded;
//       case "warning":
//       case "expiring_soon":
//       case "expiring":
//         return Icons.warning_amber_rounded;
//       case "active":
//         return Icons.check_circle_outline_rounded;
//       default:
//         return Icons.info_outline_rounded;
//     }
//   }
//
//   String _v(dynamic value) {
//     if (value == null || value.toString().trim().isEmpty) return "-";
//     return value.toString();
//   }
//
//   /// ============================================================
//   /// 🔥 NON-CLOSABLE PLAN ALERT POPUP
//   ///
//   /// - barrierDismissible: false  → bahar tap karta band nathi thatu
//   /// - PopScope(canPop: false)    → back button/gesture thi band nathi thatu
//   /// - No close/OK button         → user koi rite j popup close nathi kari shakto
//   /// ============================================================
//   void _showPlanAlertDialog(Map planAlert) {
//     final String type = (planAlert["type"] ?? "").toString();
//
//     final String title = _v(planAlert["title"]);
//     final String message = _v(planAlert["message"]);
//     final String contactName = _v(planAlert["contact_name"]);
//     final String contactMessage = _v(planAlert["contact_message"]);
//
//     final Color alertColor = _planAlertColor(type);
//     final IconData alertIcon = _planAlertIcon(type);
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       barrierColor: Colors.black.withOpacity(0.55),
//       builder: (dialogContext) {
//         return PopScope(
//           canPop: false,
//           child: Dialog(
//             backgroundColor: Colors.transparent,
//             insetPadding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Container(
//               width: double.infinity,
//               padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//                     blurRadius: 24,
//                     offset: const Offset(0, 12),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   /// ICON
//                   Container(
//                     height: 60,
//                     width: 60,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: alertColor.withOpacity(0.12),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(alertIcon, color: alertColor, size: 32),
//                   ),
//
//                   const SizedBox(height: 16),
//
//                   /// TITLE
//                   Text(
//                     title,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 17,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
//
//                   const SizedBox(height: 8),
//
//                   /// MESSAGE
//                   Text(
//                     message,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: Colors.grey.shade700,
//                       height: 1.4,
//                     ),
//                   ),
//
//                   /// CONTACT INFO (jo available hoy)
//                   if (contactName != "-" || contactMessage != "-") ...[
//                     const SizedBox(height: 16),
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: AppColors.background,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: AppColors.border),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           if (contactName != "-")
//                             Row(
//                               children: [
//                                 Icon(
//                                   Icons.support_agent_rounded,
//                                   size: 15,
//                                   color: AppColors.primaryDark,
//                                 ),
//                                 const SizedBox(width: 6),
//                                 Text(
//                                   contactName,
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w700,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           if (contactMessage != "-") ...[
//                             const SizedBox(height: 4),
//                             Text(
//                               contactMessage,
//                               style: TextStyle(
//                                 fontSize: 11.5,
//                                 color: Colors.grey.shade600,
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ],
//
//                   /// 🔥 NO CLOSE / OK BUTTON — popup close na thai shake
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void filterMenuByPermission() {
//     allMenuItems = allMenuItems.where((item) {
//       String prefix = item["prefix"].toString();
//
//       /// 🔥 Koi pan permission e prefix thi shuru thatu hoy (view/create/edit/delete/manage)
//       /// to e module dikhse
//       return userPermissions.contains("$prefix-view") ||
//           userPermissions.contains("$prefix-manage") ||
//           userPermissions.contains("$prefix-create") ||
//           userPermissions.contains("$prefix-edit") ||
//           userPermissions.contains("$prefix-delete");
//     }).toList();
//   }
//
//   bool isExpanded = false;
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.white,
//       drawer: const GlobalDrawer(),
//       extendBody: true,
//       extendBodyBehindAppBar: true, // IMPORTANT
//       //backgroundColor: AppColors.scaffoldBg,
//       bottomNavigationBar: customBottomNav(),
//       body: Stack(
//         children: [
//           /// ✅ Main Content
//           Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).size.height * 0.09),
//
//               const SizedBox(height: 10),
//
//               /// 🔥 ONLY THIS PART SCROLLABLE
//               Expanded(
//                 child: SingleChildScrollView(
//                   // 👈 ListView ના બદલે આ વાપરો
//                   padding: EdgeInsets.zero,
//                   child: Column(
//                     // 👈 અંદર એક Column ઉમેરો
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 10),
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 350),
//                           curve: Curves.easeInOut,
//                           height: isExpanded ? 240 : 75,
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             gradient: LinearGradient(
//                               colors: [
//                                 AppColors.primaryDark,
//                                 AppColors.secondaryDark,
//                               ],
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(.15),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 5),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               /// HEADER
//                               InkWell(
//                                 onTap: () {
//                                   setState(() {
//                                     isExpanded = !isExpanded;
//                                   });
//                                 },
//                                 child: Container(
//                                   height: 75,
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 15,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       /// LEFT
//                                       Expanded(
//                                         child: Column(
//                                           mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               getGreeting(),
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 3),
//
//                                             Text(
//                                               DateFormat(
//                                                 "dd MMM yyyy",
//                                               ).format(DateTime.now()),
//                                               style: const TextStyle(
//                                                 color: Colors.white70,
//                                                 fontSize: 13,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       /// CENTER
//                                       selectedRate == null
//                                           ? const SizedBox()
//                                           : GestureDetector(
//                                         onTap: () {
//                                           Navigator.push(
//                                             context,
//                                             MaterialPageRoute(
//                                               builder: (context) =>
//                                               const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                             ),
//                                           );
//                                         },
//                                         child: Container(
//                                           padding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 10,
//                                             vertical: 6,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: Colors.white
//                                                 .withOpacity(0.12),
//                                             borderRadius:
//                                             BorderRadius.circular(5),
//                                           ),
//                                           child: Column(
//                                             mainAxisSize: MainAxisSize
//                                                 .min, // 👈 જરૂરી
//                                             crossAxisAlignment:
//                                             CrossAxisAlignment.center,
//                                             children: [
//                                               Text(
//                                                 selectedRate!["symbol"],
//                                                 style: const TextStyle(
//                                                   color: Colors.white70,
//                                                   fontSize: 12,
//                                                   fontWeight:
//                                                   FontWeight.w500,
//                                                 ),
//                                               ),
//                                               const SizedBox(height: 0),
//
//                                               /// 🔥 RATE VALUE — have up/down pramane
//                                               /// green/red color aapiye chiye. Jo koi
//                                               /// color track na thayu hoy (first load)
//                                               /// to default white j rehse.
//                                               Text(
//                                                 "₹${selectedRate!["formatted_rate"]}",
//                                                 style: TextStyle(
//                                                   color: _rateColors[selectedRate!["symbol"]] ??
//                                                       Colors.white,
//                                                   fontSize: 16,
//                                                   fontWeight:
//                                                   FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//
//                                       const SizedBox(width: 0),
//
//                                       AnimatedRotation(
//                                         turns: isExpanded ? .5 : 0,
//                                         duration: const Duration(
//                                           milliseconds: 300,
//                                         ),
//                                         child: const Icon(
//                                           Icons.keyboard_arrow_down,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//
//                               /// EXPAND AREA
//                               Expanded(
//                                 child: AnimatedCrossFade(
//                                   duration: const Duration(milliseconds: 300),
//                                   crossFadeState: isExpanded
//                                       ? CrossFadeState.showSecond
//                                       : CrossFadeState.showFirst,
//
//                                   firstChild: const SizedBox(),
//
//                                   secondChild: Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 10,
//                                     ),
//                                     child: Column(
//                                       children: [
//                                         buildFirstRowStats(),
//                                         const SizedBox(height: 10),
//                                         buildSecondRowStats(),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       metalRateMarquee(),
//                       const SizedBox(height: 10),
//                       Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 10),
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(10),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.06),
//                               blurRadius: 15,
//                               offset: const Offset(0, 5),
//                             ),
//                           ],
//                         ),
//
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Header
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 const Text(
//                                   "New Features",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w700,
//                                     color: Color(0xff14213D),
//                                   ),
//                                 ),
//
//                                 Row(
//                                   children: [
//                                     Text(
//                                       "View All",
//                                       style: TextStyle(
//                                         color: AppColors.primaryDark,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//
//                                     const SizedBox(width: 5),
//
//                                     Container(
//                                       height: 22,
//                                       width: 22,
//                                       decoration: BoxDecoration(
//                                         color: Color(0xffEEF3FF),
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: Icon(
//                                         Icons.arrow_forward_ios,
//                                         size: 12,
//                                         color: AppColors.primaryDark,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             // Options
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 optionItem(
//                                   Icons.bar_chart,
//                                   "BG Remove",
//                                   Color(0xff6C35FF),
//                                   Color(0xffF2EEFF),
//                                 ),
//
//                                 optionItem(
//                                   Icons.inventory_2,
//                                   "Visiting Card",
//                                   Color(0xff00C853),
//                                   Color(0xffEFFFF4),
//                                   onTap: (){
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const PremiumHomeUI(),
//                                       ),
//                                     );
//                                   }
//                                 ),
//
//                                 optionItem(
//                                   Icons.monitor_sharp,
//                                   "Live Rate",
//                                   Color(0xffff9800),
//                                   Color(0xfffff5e8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                                 optionItem(
//                                   Icons.qr_code,
//                                   "ALL QR",
//                                   Color(0xff6A35FF),
//                                   Color(0xffF3EEFF),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const QrListScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                                 // optionItem(
//                                 //   Icons.credit_card,
//                                 //   "Payments",
//                                 //   Color(0xff00BCD4),
//                                 //   Color(0xffE8FBFF),
//                                 // ),
//                                 //
//                                 //
//                                 optionItem(
//                                   Icons.settings,
//                                   "Settings",
//                                   Color(0xff7A8499),
//                                   Color(0xffF4F5F8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                         const SettingsScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                       popularProductsSection(context),
//                       const SizedBox(
//                         height: 80,
//                       ), // છેલ્લે થોડી જગ્યા આપો (Bottom Nav માટે)
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           /// 🔥 APPBAR CALL HERE
//           buildAppBar(context),
//         ],
//       ),
//       floatingActionButton: Container(
//         height: 45,
//         width: 45,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: const LinearGradient(
//             colors: [AppColors.primaryDark, AppColors.secondaryDark],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black26,
//               blurRadius: 10,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//
//         child: FloatingActionButton(
//           onPressed: () {
//             showMenuSelectionDialog(isBottomNavMode: false);
//           },
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           child: const Icon(Icons.edit, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
//
//   Widget buildAppBar(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final isMobile = width < 600;
//
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: SafeArea(
//         child: Container(
//           padding: EdgeInsets.symmetric(
//             horizontal: isMobile ? 12 : 10,
//             vertical: 0,
//           ),
//
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               /// 🔥 CENTER TITLE
//               Center(
//                 child: Image.asset(
//                   "assets/static/text.png",
//                   height: 30,
//                   width: 200,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//
//               /// LEFT + RIGHT ROW
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   /// LEFT MENU
//                   Row(
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           _scaffoldKey.currentState?.openDrawer();
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//                           decoration: BoxDecoration(
//                             color: AppColors.primaryDark,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                           child: Icon(
//                             Icons.menu,
//                             size: isMobile ? 20 : 24,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   /// RIGHT ICONS
//                   Row(
//                     children: [
//                       Consumer<NotificationProvider>(
//                         builder: (context, provider, child) {
//                           return GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const NotificationScreen(),
//                                 ),
//                               );
//
//                               // Notification screen mathi pachha aavya pachi count refresh
//                               provider.loadNotificationCount();
//                             },
//                             child: Container(
//                               padding: EdgeInsets.all(isMobile ? 6 : 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 20,
//                                     offset: const Offset(5, 10),
//                                   ),
//                                 ],
//                               ),
//                               child: Stack(
//                                 clipBehavior: Clip.none,
//                                 children: [
//                                   Icon(
//                                     Icons.notifications_none,
//                                     size: isMobile ? 22 : 24,
//                                     color: Colors.red,
//                                   ),
//
//                                   if (provider.total > 0)
//                                     Positioned(
//                                       right: -5,
//                                       top: -8,
//                                       child: Container(
//                                         padding: const EdgeInsets.all(3),
//                                         constraints: const BoxConstraints(
//                                           minWidth: 18,
//                                           minHeight: 18,
//                                         ),
//                                         decoration: const BoxDecoration(
//                                           color: Colors.red,
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Center(
//                                           child: Text(
//                                             provider.total > 99
//                                                 ? "99+"
//                                                 : provider.total.toString(),
//                                             style: const TextStyle(
//                                               color: Colors.white,
//                                               fontSize: 9,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//
//                       // SizedBox(width: isMobile ? 8 : 12),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Widget popularProductsSection(BuildContext context) {
//   //   final width = MediaQuery.of(context).size.width;
//   //
//   //   int crossAxisCount() {
//   //     if (width < 600) return 3;
//   //     if (width < 900) return 3;
//   //     if (width < 1200) return 4;
//   //     return 5;
//   //   }
//   //
//   //   double childAspectRatio() {
//   //     if (width < 600) return 0.94;
//   //     if (width < 900) return 1.1;
//   //     return 1.2;
//   //   }
//   //
//   //   // --- GROUPING LOGIC (તમારો ઓરિજિનલ કોડ) ---
//   //   Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//   //   for (var item in dashboardItems) {
//   //     String section = item["section"] ?? "Other";
//   //     if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//   //     tempGrouped[section]!.add(item);
//   //   }
//   //
//   //   Map<String, List<Map<String, dynamic>>> groupedItems = {};
//   //   List<Map<String, dynamic>> otherItems = [];
//   //   tempGrouped.forEach((section, items) {
//   //     if (items.length == 1) {
//   //       otherItems.addAll(items);
//   //     } else {
//   //       groupedItems[section] = items;
//   //     }
//   //   });
//   //   if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//   //
//   //   // સેક્શન ઓર્ડર અપડેટ કરો
//   //   updateSectionOrder(groupedItems);
//   //
//   //   return Padding(
//   //     padding: const EdgeInsets.all(10.0),
//   //     child: ReorderableListView(
//   //       shrinkWrap: true,
//   //       physics: const NeverScrollableScrollPhysics(),
//   //       onReorder: _onReorder,
//   //       // ડ્રેગ કરતી વખતે બેકગ્રાઉન્ડ કલર ટ્રાન્સપરન્ટ રાખવા માટે (Optional)
//   //       proxyDecorator: (child, index, animation) => child,
//   //       children: sectionOrder.map((sectionName) {
//   //         // જો ગ્રુપમાં આ સેક્શન ન હોય તો ખાલી કન્ટેનર રિટર્ન કરો
//   //         if (!groupedItems.containsKey(sectionName))
//   //           return SizedBox(key: ValueKey(sectionName));
//   //
//   //         List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//   //
//   //         return Container(
//   //           key: ValueKey(sectionName), // Reorderable માટે યુનિક કી
//   //           margin: const EdgeInsets.only(bottom: 16),
//   //           padding: const EdgeInsets.all(12),
//   //           decoration: BoxDecoration(
//   //             color: Colors.white,
//   //             borderRadius: BorderRadius.circular(14),
//   //             border: Border.all(color: AppColors.border),
//   //             boxShadow: [
//   //               BoxShadow(
//   //                 color: Colors.black.withOpacity(0.05),
//   //                 blurRadius: 8,
//   //                 offset: const Offset(0, 3),
//   //               ),
//   //             ],
//   //           ),
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               /// 🔥 SECTION TITLE (હવે આ આખી રો ડ્રેગ હેન્ડલ તરીકે કામ કરશે)
//   //               Row(
//   //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //                 children: [
//   //                   Row(
//   //                     crossAxisAlignment: CrossAxisAlignment.center,
//   //                     children: [
//   //                       Container(
//   //                         padding: const EdgeInsets.all(6),
//   //                         decoration: BoxDecoration(
//   //                           gradient: LinearGradient(
//   //                             colors: [
//   //                               AppColors.primaryDark.withOpacity(0.7),
//   //                               AppColors.secondaryDark.withOpacity(0.7),
//   //                             ],
//   //                           ),
//   //                           borderRadius: BorderRadius.circular(10),
//   //                         ),
//   //                         child: const Icon(
//   //                           Icons.drag_indicator,
//   //                           color: Colors.white,
//   //                           size: 20,
//   //                         ),
//   //                       ),
//   //
//   //                       const SizedBox(width: 10),
//   //
//   //                       Column(
//   //                         mainAxisAlignment: MainAxisAlignment.center,
//   //                         crossAxisAlignment: CrossAxisAlignment.start,
//   //                         mainAxisSize: MainAxisSize.min,
//   //                         children: [
//   //                           Text(
//   //                             sectionName,
//   //                             textAlign: TextAlign.center,
//   //                             style: const TextStyle(
//   //                               fontSize: 15,
//   //                               fontWeight: FontWeight.bold,
//   //                               color: Colors.black,
//   //                             ),
//   //                           ),
//   //
//   //                           Text(
//   //                             getSectionSubtitle(sectionName),
//   //                             style: TextStyle(
//   //                               fontSize: 12,
//   //                               color: AppColors.textLight,
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ],
//   //                   ),
//   //                   Container(
//   //                     padding: const EdgeInsets.symmetric(
//   //                       horizontal: 10,
//   //                       vertical: 3,
//   //                     ),
//   //                     decoration: BoxDecoration(
//   //                       gradient: LinearGradient(
//   //                         colors: [
//   //                           AppColors.primaryDark.withOpacity(0.7),
//   //                           AppColors.secondaryDark.withOpacity(0.7),
//   //                         ],
//   //                       ),
//   //                       borderRadius: BorderRadius.circular(8),
//   //                     ),
//   //                     child: Text(
//   //                       "${items.length} Items",
//   //                       style: const TextStyle(
//   //                         color: Colors.white,
//   //                         fontWeight: FontWeight.w600,
//   //                         fontSize: 12,
//   //                       ),
//   //                     ),
//   //                   ),
//   //                 ],
//   //               ),
//   //               const SizedBox(height: 14),
//   //
//   //               /// 🔥 GRID
//   //               GridView.builder(
//   //                 itemCount: items.length,
//   //                 shrinkWrap: true,
//   //                 physics: const NeverScrollableScrollPhysics(),
//   //                 padding: EdgeInsets.zero,
//   //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//   //                   crossAxisCount: crossAxisCount(),
//   //                   crossAxisSpacing: 12,
//   //                   mainAxisSpacing: 12,
//   //                   childAspectRatio: childAspectRatio(),
//   //                 ),
//   //                 itemBuilder: (context, index) {
//   //                   final item = items[index];
//   //                   final module = item["module"] ?? "";
//   //
//   //                   final count = context
//   //                       .watch<NotificationProvider>()
//   //                       .moduleCount(module);
//   //
//   //                   //print("Module: $module -> Count: $count");
//   //                   return _premiumMenuCard(
//   //                     context,
//   //                     item["title"],
//   //                     item["icon"],
//   //                     () async {
//   //                       readModule(module);
//   //                       final result = await Navigator.push(
//   //                         context,
//   //                         MaterialPageRoute(builder: (_) => item["screen"]),
//   //                       );
//   //
//   //                       // 👇 Child page mathi pop thay pachi
//   //                       if (result == true) {
//   //                         print("Refresh");
//   //                         await getCompanyProfile();
//   //                         setState(() {});
//   //                       }
//   //                     },
//   //                     count: count,
//   //                   );
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //         );
//   //       }).toList(),
//   //     ),
//   //   );
//   // }
//
//   Widget popularProductsSection(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//
//     int crossAxisCount() {
//       if (width < 600) return 3;
//       if (width < 900) return 3;
//       if (width < 1200) return 4;
//       return 5;
//     }
//
//     double childAspectRatio() {
//       if (width < 600) return 0.94;
//       if (width < 900) return 1.1;
//       return 1.2;
//     }
//
//     //--- GROUPING LOGIC (same) ---
//     Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//     for (var item in dashboardItems) {
//       String section = item["section"] ?? "Other";
//       if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//       tempGrouped[section]!.add(item);
//     }
//
//     Map<String, List<Map<String, dynamic>>> groupedItems = {};
//     List<Map<String, dynamic>> otherItems = [];
//     tempGrouped.forEach((section, items) {
//       if (userRoleNames.length == 1) {
//         otherItems.addAll(items);
//       } else {
//         groupedItems[section] = items;
//       }
//     });
//
//     if (otherItems.isNotEmpty) {
//       groupedItems["Others"] = otherItems;
//     }
//     if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//
//     // --- GROUPING LOGIC ---
//
//     //updateSectionOrder(groupedItems);
//
//     return Padding(
//       padding: const EdgeInsets.all(10.0),
//       child: ReorderableListView(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         onReorder: _onReorder,
//         proxyDecorator: (child, index, animation) => child,
//         children: sectionOrder.map((sectionName) {
//           if (!groupedItems.containsKey(sectionName))
//             return SizedBox(key: ValueKey(sectionName));
//
//           List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//
//           /// 🔥 Default expanded state (na hoy to true rakho — pehla khulu j dekhay)
//           // bool isExpanded = expandedSections[sectionName] ?? false;
//           /// 🔥 Fakt PEHLU section default open rahe, baki badha collapsed
//           final bool isExpanded = expandedSections[sectionName] ?? false;
//
//           return Material(
//             key: ValueKey(sectionName),
//             color: Colors.transparent,
//             child: Container(
//               key: ValueKey(sectionName),
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: AppColors.border),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// 🔥 SECTION TITLE — have TAP thi expand/collapse thashe
//                   InkWell(
//                     onTap: () async {
//                       final bool currentlyExpanded =
//                           expandedSections[sectionName] ?? false;
//
//                       setState(() {
//                         /// Pehla badha sections close
//                         for (final section in sectionOrder) {
//                           expandedSections[section] = false;
//                         }
//
//                         /// Jo current section pehla close hato,
//                         /// to fakt ene open karo.
//                         ///
//                         /// Jo already open hato,
//                         /// to badha close j rehse.
//                         if (!currentlyExpanded) {
//                           expandedSections[sectionName] = true;
//                         }
//                       });
//
//                       await saveExpandedSections();
//                     },
//                     borderRadius: BorderRadius.circular(8),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             /// 🔥 Drag handle — have ReorderableDragStartListener thi wrap karyu,
//                             /// jethi fakt AA icon j drag mate vaparay, baki title tap expand/collapse kare
//                             ReorderableDragStartListener(
//                               index: sectionOrder.indexOf(sectionName),
//                               child: Container(
//                                 padding: const EdgeInsets.all(6),
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [
//                                       AppColors.primaryDark.withOpacity(0.7),
//                                       AppColors.secondaryDark.withOpacity(0.7),
//                                     ],
//                                   ),
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                                 child: const Icon(
//                                   Icons.drag_indicator,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 10),
//
//                             Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   sectionName,
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                                 Text(
//                                   getSectionSubtitle(sectionName),
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: AppColors.textLight,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 3,
//                               ),
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark.withOpacity(0.7),
//                                     AppColors.secondaryDark.withOpacity(0.7),
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//                               child: Text(
//                                 "${items.length} Items",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 8),
//
//                             /// 🔥 Expand/Collapse Arrow
//                             AnimatedRotation(
//                               turns: isExpanded ? 0.5 : 0,
//                               duration: const Duration(milliseconds: 250),
//                               child: Container(
//                                 padding: const EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.background,
//                                   borderRadius: BorderRadius.circular(6),
//                                   border: Border.all(color: AppColors.border),
//                                 ),
//                                 child: Icon(
//                                   Icons.keyboard_arrow_down,
//                                   size: 18,
//                                   color: AppColors.primaryDark,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   /// 🔥 GRID — AnimatedCrossFade thi smooth expand/collapse
//                   AnimatedCrossFade(
//                     duration: const Duration(milliseconds: 250),
//                     crossFadeState: isExpanded
//                         ? CrossFadeState.showFirst
//                         : CrossFadeState.showSecond,
//                     firstChild: Padding(
//                       padding: const EdgeInsets.only(top: 14),
//                       child: GridView.builder(
//                         itemCount: items.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         padding: EdgeInsets.zero,
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: crossAxisCount(),
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 12,
//                           childAspectRatio: childAspectRatio(),
//                         ),
//                         itemBuilder: (context, index) {
//                           final item = items[index];
//                           final module = item["module"] ?? "";
//
//                           final count = context
//                               .watch<NotificationProvider>()
//                               .moduleCount(module);
//
//                           return _premiumMenuCard(
//                             context,
//                             item["title"],
//                             item["icon"],
//                                 () async {
//                               /// Notification read
//                               readModule(module);
//
//                               /// 🔥 Navigate karta PEHLA section top + open
//                               //moveSectionToTopAndOpen(sectionName);
//
//                               /// Screen open
//                               final result = await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => item["screen"],
//                                 ),
//                               );
//
//                               if (!mounted) return;
//
//                               /// 🔥 BACK AAVYA PACHI FARITHI ENSURE KARO
//                               //await moveSectionToTopAndOpen(sectionName);
//
//                               /// Data refresh required hoy to
//                               if (result == true) {
//                                 await getCompanyProfile();
//                                 WidgetsBinding.instance.addPostFrameCallback((
//                                     _,
//                                     ) {
//                                   context
//                                       .read<NotificationProvider>()
//                                       .loadNotificationCount();
//                                 });
//
//                                 // /// getCompanyProfile rebuild kare pachi pan
//                                 // /// current section restore karo
//                                 // await moveSectionToTopAndOpen(sectionName);
//                               }
//                             },
//                             count: count,
//                           );
//                         },
//                       ),
//                     ),
//                     secondChild: const SizedBox(width: double.infinity),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _premiumMenuCard(
//       BuildContext context,
//       String title,
//       IconData icon,
//       VoidCallback onTap, {
//         int count = 0,
//       }) {
//     return Material(
//       // 🔥 આ ઉમેરવાથી "No Material found" એરર દૂર થશે
//       color: Colors.transparent, // બેકગ્રાઉન્ડ ટ્રાન્સપરન્ટ રાખવું
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.border),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               /// 🔥 ICON CIRCLE
//               Stack(
//                 clipBehavior: Clip.none,
//                 children: [
//                   Container(
//                     height: 40,
//                     width: 40,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(15),
//                       shape: BoxShape.rectangle,
//                     ),
//                     child: Icon(icon, color: Colors.white, size: 22),
//                   ),
//
//                   /// Notification Count
//                   if (count > 0)
//                     Positioned(
//                       top: -6,
//                       right: -6,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 5,
//                           vertical: 2,
//                         ),
//                         constraints: const BoxConstraints(
//                           minWidth: 18,
//                           minHeight: 18,
//                         ),
//                         decoration: const BoxDecoration(
//                           color: Colors.red,
//                           shape: BoxShape.circle,
//                         ),
//                         alignment: Alignment.center,
//                         child: Text(
//                           count > 99 ? "99+" : "$count",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 9,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//
//               const SizedBox(height: 5),
//
//               /// TITLE
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//   //////////////////////////////////////////////////////////////
//   /// 🔵 PRODUCT CARD
//   //////////////////////////////////////////////////////////////
//
//   Widget productCard(
//       BuildContext context,
//       String title,
//       IconData icon,
//       VoidCallback onTap,
//       ) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//     final isTablet = width > 600;
//
//     return GestureDetector(
//       onTap: onTap,
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//           child: Container(
//             padding: EdgeInsets.all(width * 0.04),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.1),
//                 width: 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 15,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   height: isTablet ? width * 0.10 : width * 0.14,
//                   width: isTablet ? width * 0.10 : width * 0.16,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF1E2A55), Color(0xFF1E2A55)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFF0D1633).withOpacity(0.5),
//                         blurRadius: 20,
//                         offset: const Offset(0, 8),
//                       ),
//                     ],
//                   ),
//                   child: Icon(
//                     icon,
//                     color: Colors.white,
//                     size: isTablet ? width * 0.04 : width * 0.06,
//                   ),
//                 ),
//                 SizedBox(height: height * 0.015),
//                 Text(
//                   title,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: AppColors.white,
//                     fontSize: isTablet ? width * 0.022 : width * 0.035,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget customBottomNav() {
//     final size = MediaQuery.of(context).size;
//     final double width = size.width;
//
//     /// ============================================
//     /// RESPONSIVE BREAKPOINTS
//     /// ============================================
//     final bool isVerySmallPhone = width < 340;
//     final bool isSmallPhone = width >= 340 && width < 400;
//     final bool isMobile = width < 600;
//     final bool isTablet = width >= 600 && width < 1000;
//     final bool isDesktop = width >= 1000;
//
//     /// ============================================
//     /// RESPONSIVE HEIGHT
//     /// ============================================
//     final double navHeight;
//
//     if (isDesktop) {
//       navHeight = 78;
//     } else if (isTablet) {
//       navHeight = 72;
//     } else if (isVerySmallPhone) {
//       navHeight = 62;
//     } else if (isSmallPhone) {
//       navHeight = 65;
//     } else {
//       navHeight = 68;
//     }
//
//     /// ============================================
//     /// RESPONSIVE ICON SIZE
//     /// ============================================
//     final double iconSize;
//
//     if (isDesktop) {
//       iconSize = 25;
//     } else if (isTablet) {
//       iconSize = 22;
//     } else if (isVerySmallPhone) {
//       iconSize = 18;
//     } else if (isSmallPhone) {
//       iconSize = 19;
//     } else {
//       iconSize = 21;
//     }
//
//     /// ============================================
//     /// RESPONSIVE FONT SIZE
//     /// ============================================
//     final double fontSize;
//
//     if (isDesktop) {
//       fontSize = 12;
//     } else if (isTablet) {
//       fontSize = 10.5;
//     } else if (isVerySmallPhone) {
//       fontSize = 8.5;
//     } else if (isSmallPhone) {
//       fontSize = 9;
//     } else {
//       fontSize = 10;
//     }
//
//     /// ============================================
//     /// RESPONSIVE HORIZONTAL MARGIN
//     ///
//     /// Tablet ma width cut na kariye.
//     /// Aa overflow avoid karva important che.
//     /// ============================================
//     final double horizontalMargin;
//
//     if (isDesktop) {
//       horizontalMargin = width * 0.12;
//     } else if (isTablet) {
//       horizontalMargin = 8;
//     } else {
//       horizontalMargin = 0;
//     }
//
//     /// ============================================
//     /// RESPONSIVE RADIUS
//     /// ============================================
//     final double radius = isMobile ? 12 : 15;
//
//     return SafeArea(
//       top: false,
//       child: Container(
//         height: navHeight,
//         margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(radius),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.12),
//               blurRadius: 12,
//               offset: const Offset(0, -3),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(radius),
//           child: BottomNavigationBar(
//             /// ========================================
//             /// BASIC
//             /// ========================================
//             backgroundColor: Colors.white,
//
//             currentIndex: selectedIndex,
//
//             type: BottomNavigationBarType.fixed,
//
//             elevation: 0,
//
//             /// ========================================
//             /// ICON
//             /// ========================================
//             iconSize: iconSize,
//
//             /// ========================================
//             /// FONT
//             /// ========================================
//             selectedFontSize: fontSize,
//             unselectedFontSize: fontSize,
//
//             selectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w600,
//               height: 1.0,
//             ),
//
//             unselectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w500,
//               height: 1.0,
//             ),
//
//             /// ========================================
//             /// COLOR
//             /// ========================================
//             selectedItemColor: AppColors.primaryDark,
//
//             unselectedItemColor: Colors.grey.shade600,
//
//             /// ========================================
//             /// LABEL SETTINGS
//             /// ========================================
//             showSelectedLabels: true,
//             showUnselectedLabels: true,
//
//             /// ========================================
//             /// CLICK
//             /// ========================================
//             onTap: (index) {
//               final item = bottomItems[index];
//
//               /// MORE CLICK
//               if (item["title"] == "More") {
//                 showMenuSelectionDialog(isBottomNavMode: true);
//                 return;
//               }
//
//               setState(() {
//                 selectedIndex = index;
//               });
//
//               /// SCREEN OPEN
//               if (item["screen"] != null) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => item["screen"]),
//                 );
//               }
//             },
//
//             /// ========================================
//             /// ITEMS
//             /// ========================================
//             items: bottomItems.map((item) {
//               final String title = item["title"]?.toString() ?? "";
//
//               return BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(bottom: isVerySmallPhone ? 1 : 2),
//                   child: Icon(item["icon"], size: iconSize),
//                 ),
//
//                 /// Long label hoy to short kari shakai
//                 label: title,
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget addNewGlassCard() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(12),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.05), // glass transparency
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 10,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.add, color: AppColors.white, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 "Add New",
//                 style: TextStyle(
//                   color: AppColors.white,
//                   fontWeight: FontWeight.w500,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget gradientIcon(IconData icon, bool selected) {
//     return ShaderMask(
//       shaderCallback: (bounds) {
//         return LinearGradient(
//           colors: selected
//               ? const [Colors.white54, Colors.white54]
//               : const [Colors.white54, Colors.white54],
//         ).createShader(bounds);
//       },
//       child: Icon(icon, color: Colors.white, size: 24),
//     );
//   }
//
//   void showMenuSelectionDialog({bool isBottomNavMode = false}) {
//     List<Map<String, dynamic>> sections = [
//       {
//         "title": "Item Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Item List",
//             "icon": Icons.add_box,
//             "screen": const Itemscreen(),
//             "prefix": "item", // ✅ ADD
//           },
//           {
//             "title": "Label Config",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Labelscreen(),
//             "prefix": "label-config", // ✅ ADD
//           },
//           {
//             "title": "Label Items",
//             "icon": Icons.label_important_outlined,
//             "screen": const label_item_screen(),
//             "prefix": "item-set", // ✅ ADD
//           },
//           {
//             "title": "Label Printing",
//             "icon": Icons.print,
//             "screen": const LabelPrintScreen(),
//             "prefix": "label-print", // ✅ ADD
//           },
//           {
//             "title": "Other Charges",
//             "icon": Icons.settings_applications,
//             "screen": const Othersscreen(),
//             "prefix": "other-charge", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "User Management",
//         "icon": Icons.dashboard_customize,
//         "items": [
//           {
//             "title": "Person",
//             "icon": Icons.person_add,
//             "screen": const Customerscreen(),
//             "prefix": "person", // ✅ ADD
//           },
//           {
//             "title": "Users",
//             "icon": Icons.people,
//             "screen": const Userscreen(),
//             "prefix": "user", // ✅ ADD
//           },
//           {
//             "title": "Category",
//             "icon": Icons.people,
//             "screen": const Categoryscreen(),
//             "prefix": "category-person", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "JobWork Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Labour Formula",
//             "icon": Icons.add_box,
//             "screen": const JobLabourformulaScreen(),
//             "prefix": "labour-formula", // ✅ ADD
//           },
//           {
//             "title": "Production Cost",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Productioncost(),
//             "prefix": "production-cost", // ✅ ADD
//           },
//           {
//             "title": "Production Step",
//             "icon": Icons.label_important_outlined,
//             "screen": const Prooductionstepscreen(),
//             "prefix": "production-step", // ✅ ADD
//           },
//           // {
//           //   "title": "Job Worker",
//           //   "icon": Icons.print,
//           //   "screen": const Jobworkerscreen(),
//           //   "prefix": "job-worker", // ✅ ADD
//           // },
//           {
//             "title": "Jobwork Issue",
//             "icon": Icons.settings_applications,
//             "screen": const JobworkIssueScreen(),
//             "prefix": "jobwork-issue", // ✅ ADD
//           },
//           {
//             "title": "Jobwork Receive",
//             "icon": Icons.settings_applications,
//             "screen": const Jobworkreceivescreen(),
//             "prefix": "jobwork-receive", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Sales",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Sale on Approvals",
//             "icon": Icons.qr_code,
//             "screen": const InvoiceScreen(),
//             "prefix": "approval", // ✅ ADD
//           },
//           {
//             "title": "Sales Estimate",
//             "icon": Icons.sell,
//             "screen": const SellList(),
//             "prefix": "sale", // ✅ ADD
//           },
//           {
//             "title": "Approval Return",
//             "icon": Icons.sell,
//             "screen": const Approvalreturnscreen(),
//             "prefix": "approval-return", // ✅ ADD
//           },
//           {
//             "title": "Rec-Ret-Purchase",
//             "icon": Icons.sell,
//             "screen": const ReciveReturnPurchase(),
//             "prefix": "sale-advance", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Reports & Tools",
//         "icon": Icons.analytics,
//         "items": [
//           {
//             "title": "Sales Summary",
//             "icon": Icons.bar_chart,
//             "screen": const Salesumryreport(),
//             "prefix": "report-sales-summary", // ✅ ADD
//           },
//           {
//             "title": "Reciver Summary",
//             "icon": Icons.qr_code_scanner,
//             "screen": const Purchasereciversummary(),
//             "prefix": "receiver-summary", // ✅ ADD
//           },
//           {
//             "title": "Stock Position",
//             "icon": Icons.bar_chart,
//             "screen": const Stockpositionreport(),
//             "prefix": "report-stock-position", // ✅ ADD
//           },
//           {
//             "title": "Approval Outstanding",
//             "icon": Icons.menu_book,
//             "screen": const Approvaloutstandingreport(),
//             "prefix": "report-approval-outstanding", // ✅ ADD
//           },
//           {
//             "title": "Barcode History",
//             "icon": Icons.menu_book,
//             "screen": const Barcodehistory(),
//             "prefix": "report-barcode-history", // ✅ ADD
//           },
//           {
//             "title": "Worker Loss",
//             "icon": Icons.menu_book,
//             "screen": const WorkerLossReportScreen(),
//             "prefix": "report-worker-loss", // ✅ ADD
//           },
//           {
//             "title": "Approval Summary",
//             "icon": Icons.menu_book,
//             "screen": const ApprovalSummaryScreen(),
//             "prefix": "report-worker-loss", // ✅ ADD
//           },
//           {
//             "title": "Approval Register",
//             "icon": Icons.menu_book,
//             "screen": const ApprovalReturnRegisterScreen(),
//             "prefix": "report-worker-loss", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Role & Permission",
//         "icon": Icons.admin_panel_settings,
//         "items": [
//           {
//             "title": "Roles",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Rolescreen(),
//             "prefix": "role", // ✅ ADD
//           },
//           {
//             "title": "Permissions",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Permissionscreen(),
//             "prefix": "permission", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Casting Management",
//         "icon": Icons.settings,
//         "items": [
//           {
//             "title": "Buch",
//             "icon": Icons.settings,
//             "screen": const Buchscreen(),
//             "prefix": "vacuum-buch",
//           },
//           {
//             "title": "Process",
//             "icon": Icons.settings,
//             "screen": const Processscreen(),
//             "prefix": "vacuum-process",
//           },
//           {
//             "title": "Vacuum Voucher",
//             "icon": Icons.settings,
//             "screen": const Voucherscreen(),
//             "prefix": "vacuum-voucher",
//           },
//           {
//             "title": "Casting Heating",
//             "icon": Icons.settings,
//             "screen": const Castingheatingscreen(),
//             "prefix": "casting-heating",
//           },
//           {
//             "title": "Casting Metal",
//             "icon": Icons.settings,
//             "screen": const Castingmetalscreen(),
//             "prefix": "casting-metal-issue",
//           },
//           {
//             "title": "Casting Receive",
//             "icon": Icons.settings,
//             "screen": const Castingrecivescreen(),
//             "prefix": "casting-release",
//           },
//           {
//             "title": "Tree Cutting Office",
//             "icon": Icons.settings,
//             "screen": const Treecuttingoffice(),
//             "prefix": "tree-cutting-office",
//           },
//           {
//             "title": "Tree Cutting Issue",
//             "icon": Icons.settings,
//             "screen": const Treecuttingissuescreen(),
//             "prefix": "tree-cutting-issue",
//           },
//           {
//             "title": "Tree Cutting Receive",
//             "icon": Icons.settings,
//             "screen": const Treecuttingreceivescreen(),
//             "prefix": "tree-cutting-receive",
//           },
//           {
//             "title": "Casting Sorting",
//             "icon": Icons.settings,
//             "screen": const Castingsortscreen(),
//             "prefix": "casting-sorting",
//           },
//         ],
//       },
//     ];
//
//     List<Map<String, dynamic>> filteredSections = sections
//         .map((section) {
//       List items = (section["items"] as List).where((item) {
//         String prefix = item["prefix"].toString();
//
//         /// 🔥 Same logic — view ya manage both check karo
//         return userPermissions.contains("$prefix-view") ||
//             userPermissions.contains("$prefix-manage") ||
//             userPermissions.contains("$prefix-create") ||
//             userPermissions.contains("$prefix-edit") ||
//             userPermissions.contains("$prefix-delete");
//       }).toList();
//
//       return {
//         "title": section["title"],
//         "icon": section["icon"],
//         "items": items,
//       };
//     })
//         .where((section) => (section["items"] as List).isNotEmpty)
//         .toList();
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setStateBottom) {
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.80,
//
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.background.withOpacity(0.9),
//                     AppColors.background.withOpacity(0.9),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
//               ),
//
//               child: Column(
//                 children: [
//                   const SizedBox(height: 14),
//
//                   Container(
//                     width: 60,
//                     height: 5,
//
//                     decoration: BoxDecoration(
//                       color: Colors.black,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   const Text(
//                     "Customize Dashboard",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   Expanded(
//                     child: ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//
//                       itemCount: filteredSections.length,
//
//                       itemBuilder: (context, sectionIndex) {
//                         final section =
//                         filteredSections[sectionIndex]; // ✅ FIXED
//
//                         return Container(
//                           margin: const EdgeInsets.only(bottom: 14),
//
//                           decoration: BoxDecoration(
//                             color: AppColors.background,
//                             border: Border.all(
//                               color: AppColors.border,
//                               width: 1.5,
//                             ),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//
//                           child: Theme(
//                             data: Theme.of(
//                               context,
//                             ).copyWith(dividerColor: Colors.transparent),
//
//                             child: ExpansionTile(
//                               tilePadding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 4,
//                               ),
//
//                               childrenPadding: const EdgeInsets.only(
//                                 left: 12,
//                                 right: 12,
//                                 bottom: 12,
//                               ),
//
//                               leading: Container(
//                                 padding: const EdgeInsets.all(10),
//
//                                 decoration: BoxDecoration(
//                                   color: AppColors.border,
//                                   border: Border.all(
//                                     color: AppColors.border,
//                                     width: 1.5,
//                                   ),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//
//                                 child: Icon(
//                                   section["icon"],
//                                   color: AppColors.iconBlue,
//                                 ),
//                               ),
//
//                               title: Text(
//                                 section["title"],
//
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 16,
//                                 ),
//                               ),
//
//                               iconColor: AppColors.iconBlue,
//                               collapsedIconColor: AppColors.textPrimary,
//
//                               children: List.generate(section["items"].length, (
//                                   index,
//                                   ) {
//                                 final item = section["items"][index];
//
//                                 bool alreadyAdded = isBottomNavMode
//                                     ? bottomItems.any(
//                                       (e) => e["title"] == item["title"],
//                                 )
//                                     : dashboardItems.any(
//                                       (e) => e["title"] == item["title"],
//                                 );
//
//                                 return Container(
//                                   margin: const EdgeInsets.only(bottom: 10),
//
//                                   padding: const EdgeInsets.all(12),
//
//                                   decoration: BoxDecoration(
//                                     gradient: alreadyAdded
//                                         ? const LinearGradient(
//                                       colors: [
//                                         AppColors.border,
//                                         AppColors.border,
//                                       ],
//                                     )
//                                         : LinearGradient(
//                                       colors: [
//                                         AppColors.border,
//                                         AppColors.border,
//                                       ],
//                                     ),
//
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//
//                                   child: Row(
//                                     children: [
//                                       Container(
//                                         height: 45,
//                                         width: 45,
//
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                               AppColors.border.withOpacity(0.5),
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//
//                                         child: Icon(
//                                           item["icon"],
//                                           color: Colors.black,
//                                         ),
//                                       ),
//
//                                       const SizedBox(width: 14),
//
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//
//                                           children: [
//                                             Text(
//                                               item["title"],
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black
//                                                     : Colors.black,
//
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 4),
//
//                                             Text(
//                                               alreadyAdded
//                                                   ? "Added"
//                                                   : "Tap to add",
//
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black87
//                                                     : Colors.black87,
//
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       InkWell(
//                                         onTap: () async {
//                                           if (isBottomNavMode) {
//                                             /// 🔥 BOTTOM NAV MODE — fakt bottomItems manipulate
//                                             if (alreadyAdded) {
//                                               setStateBottom(() {
//                                                 bottomItems.removeWhere(
//                                                       (e) =>
//                                                   e["title"] ==
//                                                       item["title"],
//                                                 );
//                                               });
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               int customCount =
//                                                   bottomItems.length - 2;
//
//                                               if (customCount >= 2) {
//                                                 Navigator.pop(context);
//                                                 Future.delayed(
//                                                   const Duration(
//                                                     milliseconds: 100,
//                                                   ),
//                                                       () {
//                                                     ScaffoldMessenger.of(
//                                                       context,
//                                                     ).showSnackBar(
//                                                       const SnackBar(
//                                                         content: Text(
//                                                           "Maximum 2 items can be added in bottom navigation",
//                                                         ),
//                                                       ),
//                                                     );
//                                                   },
//                                                 );
//                                                 return;
//                                               }
//
//                                               setStateBottom(() {
//                                                 bottomItems.insert(
//                                                   bottomItems.length - 1,
//                                                   {
//                                                     "title": item["title"],
//                                                     "icon": item["icon"],
//                                                     "screen": item["screen"],
//                                                   },
//                                                 );
//                                               });
//                                             }
//
//                                             await saveBottomNavItems();
//                                           } else {
//                                             /// 🔥 DASHBOARD MODE — dashboardItems manipulate (original logic)
//                                             if (alreadyAdded) {
//                                               dashboardItems.removeWhere(
//                                                     (e) =>
//                                                 e["title"] == item["title"],
//                                               );
//                                               bottomItems.removeWhere(
//                                                     (e) =>
//                                                 e["title"] == item["title"],
//                                               );
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               dashboardItems.add({
//                                                 ...item,
//                                                 "section": section["title"],
//                                               });
//                                             }
//
//                                             await saveDashboardItems();
//                                             await loadDashboardItems();
//                                           }
//
//                                           setStateBottom(() {});
//                                           setState(() {});
//                                         },
//
//                                         child: AnimatedContainer(
//                                           duration: const Duration(
//                                             milliseconds: 250,
//                                           ),
//
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 18,
//                                             vertical: 10,
//                                           ),
//
//                                           // decoration: BoxDecoration(
//                                           //
//                                           //   color: alreadyAdded
//                                           //       ? Colors.green
//                                           //       : null,
//                                           //
//                                           //
//                                           //
//                                           //   gradient: alreadyAdded
//                                           //       ? null
//                                           //       : const LinearGradient(
//                                           //     colors: [
//                                           //       Color(0xffE6C58A),
//                                           //       Color(0xffC8A96A),
//                                           //     ],
//                                           //   ),
//                                           //
//                                           //   borderRadius: BorderRadius.circular(12),
//                                           // ),
//                                           decoration: BoxDecoration(
//                                             gradient: LinearGradient(
//                                               colors: alreadyAdded
//                                                   ? [
//                                                 AppColors.iconBlue
//                                                     .withOpacity(0.5),
//                                                 //AppColors.border.withOpacity(0.5),
//                                                 AppColors.iconBlue
//                                                     .withOpacity(0.5),
//                                               ]
//                                                   : const [
//                                                 Color(0xffE6C58A),
//                                                 Color(0xffC8A96A),
//                                               ],
//                                             ),
//
//                                             borderRadius: BorderRadius.circular(
//                                               5,
//                                             ),
//                                           ),
//
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 alreadyAdded
//                                                     ? Icons.check
//                                                     : Icons.add,
//                                                 color: alreadyAdded
//                                                     ? Colors.white
//                                                     : Colors.black,
//                                                 size: 18,
//                                               ),
//
//                                               const SizedBox(width: 6),
//
//                                               Text(
//                                                 alreadyAdded ? "ADDED" : "ADD",
//
//                                                 style: TextStyle(
//                                                   color: alreadyAdded
//                                                       ? Colors.white
//                                                       : Colors.black,
//                                                   fontWeight: FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               }),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
//
//                     child: InkWell(
//                       onTap: () {
//                         Navigator.pop(context);
//                       },
//
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.primaryDark,
//                               AppColors.secondaryDark,
//                             ],
//                           ),
//
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//
//                         child: const Center(
//                           child: Text(
//                             "DONE",
//
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _onReorder(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) {
//         newIndex -= 1;
//       }
//       final String item = sectionOrder.removeAt(oldIndex);
//       sectionOrder.insert(newIndex, item);
//     });
//   }
//
//   String getSectionSubtitle(String sectionName) {
//     switch (sectionName) {
//       case "Sales":
//         return "Manage all sales activities";
//
//       case "Item Management":
//         return "Manage your inventory & items";
//
//       case "Others":
//         return "Other useful options";
//
//       case "JobWork Management":
//         return "Manage all job work activities";
//
//       case "Report Management":
//         return "Manage all Report activities";
//
//       case "Role Management":
//         return "Manage all Settings activities";
//
//       case "Casting Management":
//         return "Manage all Casting activities";
//
//       case "Management":
//         return "Manage all User activities";
//
//       default:
//         return "";
//     }
//   }
//
//   Widget optionItem(
//       IconData icon,
//       String title,
//       Color iconColor,
//       Color bgColor, {
//         VoidCallback? onTap, // 👈 ADD THIS
//       }) {
//     return InkWell(
//       onTap: onTap, // 👈 ADD THIS
//       borderRadius: BorderRadius.circular(10),
//       child: Column(
//         children: [
//           Container(
//             height: 45,
//             width: 45,
//             decoration: BoxDecoration(
//               color: bgColor,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: iconColor, size: 28),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//               color: Color(0xff14213D),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget metalRateMarquee() {
//     if (rates.isEmpty) {
//       return const SizedBox();
//     }
//
//     String text = "";
//
//     for (var item in rates) {
//       text +=
//       " ${item["symbol"]} (${item["city"]}) : ₹${item["formatted_rate"]}  |";
//     }
//
//     return Container(
//       height: 38,
//       margin: const EdgeInsets.symmetric(horizontal: 10),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xff8B3A3A), Color(0xffC59D5F)],
//         ),
//         borderRadius: BorderRadius.circular(6),
//       ),
//
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10),
//             child: const Icon(
//               Icons.currency_rupee,
//               color: Colors.white,
//               size: 18,
//             ),
//           ),
//
//           Expanded(
//             child: Marquee(
//               text: text,
//
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//
//               velocity: 45,
//
//               blankSpace: 70,
//
//               pauseAfterRound: const Duration(seconds: 2),
//
//               startPadding: 10,
//
//               scrollAxis: Axis.horizontal,
//
//               crossAxisAlignment: CrossAxisAlignment.center,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildStat(IconData icon, String title, String value) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         /// Icon Background
//         Container(
//           height: 30,
//           width: 30,
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(5),
//             border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
//           ),
//           child: Icon(icon, color: Colors.white, size: 16),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           value,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 13,
//           ),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           title,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: Colors.white70, fontSize: 11),
//         ),
//       ],
//     );
//   }
//
//   Widget buildWelcomeSection() {
//     return Row(
//       children: [
//         // Container(
//         //   height: 45,
//         //   width: 45,
//         //   decoration: BoxDecoration(
//         //     color: Colors.white.withOpacity(.15),
//         //     shape: BoxShape.circle,
//         //     border: Border.all(color: Colors.white24),
//         //   ),
//         //   child: const Icon(
//         //     Icons.person,
//         //     color: Colors.white,
//         //     size: 24,
//         //   ),
//         // ),
//         const SizedBox(width: 12),
//
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Good Morning 👋",
//                 style: TextStyle(color: Colors.white70, fontSize: 13),
//               ),
//
//               const SizedBox(height: 2),
//
//               Text(
//                 "Welcome",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(.15),
//             borderRadius: BorderRadius.circular(5),
//           ),
//           child: const Text(
//             "Manager",
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget buildFirstRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.currency_rupee, "Sales", "₹0.00")),
//         Expanded(child: buildStat(Icons.trending_up, "Month Sales", "₹160")),
//         Expanded(child: buildStat(Icons.assignment_return, "Returns", "₹20")),
//         Expanded(child: buildStat(Icons.check_circle, "Complete", "25")),
//       ],
//     );
//   }
//
//   Widget buildSecondRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.approval, "Approvals", "12")),
//         Expanded(child: buildStat(Icons.pending_actions, "Pending", "08")),
//         Expanded(child: buildStat(Icons.local_offer, "Labels", "41")),
//         Expanded(child: buildStat(Icons.people, "Users", "4 / 8")),
//       ],
//     );
//   }
//
//   Future<void> loadExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? saved = prefs.getString("expanded_sections");
//
//     if (saved != null && saved.isNotEmpty) {
//       List<String> openSections = saved.split(",");
//
//       setState(() {
//         // 🔥 Fakt PEHLO section j open rakho (accordion rule)
//         String? firstOpen = openSections.isNotEmpty ? openSections.first : null;
//         expandedSections = {};
//         if (firstOpen != null) {
//           expandedSections[firstOpen] = true;
//         }
//       });
//     }
//   }
//
//   Future<void> saveExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // 🔥 Fakt PEHLO open section j save karo (max 1)
//     List<String> openSections = expandedSections.entries
//         .where((e) => e.value == true)
//         .map((e) => e.key)
//         .toList();
//
//     await prefs.setString("expanded_sections", openSections.join(","));
//   }
//
//   Future<void> saveSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setStringList("section_order", sectionOrder);
//   }
//
//   Future<void> loadSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     final saved = prefs.getStringList("section_order");
//
//     if (saved != null && saved.isNotEmpty) {
//       setState(() {
//         // 🔥 Saved order set karo (agar navi sections hoy to pachi automatically add thai jashe _updateSectionOrderForNewItems() thi)
//         sectionOrder = saved;
//       });
//     }
//   }
// }



// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
// import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
// import 'package:pecifician_sysytem/Approval/Recive_return_purchase.dart';
// import 'package:pecifician_sysytem/Dashboard/DiamondReportsUI.dart';
// import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
// import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
// import 'package:pecifician_sysytem/Reports/OutStandingAmount.dart';
// import 'package:pecifician_sysytem/Sell_estimate/SellScreen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
// import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
// import 'package:pecifician_sysytem/User/CategoryScreen.dart';
// import 'package:pecifician_sysytem/User/CreateCustomer.dart';
// import 'package:pecifician_sysytem/User/OfficeAccessSettingsScreen.dart';
// import 'package:pecifician_sysytem/User/UserScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
// import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
// import 'package:pecifician_sysytem/Visiting%20Card/Visitingcard.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Approval/ApproveListScreen.dart';
// import '../Approval/ReceivevoucharScreen.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/GlobalDrawer.dart';
// import '../Extra/NotificationProvider.dart';
// import '../Settings/LiveMetalRatesScreen.dart';
// import '../Settings/SettingsScreen.dart';
// import '../Item_Mangement/Item/ItemScreen.dart';
// import '../Item_Mangement/Label Print/Label_print_Screen.dart';
// import '../Item_Mangement/Label/LabelScreen.dart';
// import '../Item_Mangement/Label_Items/label_item_screen.dart';
// import '../Item_Mangement/Others/Othersscreen.dart';
// import '../Job Work/Job Work Issue/Jobwork_issue_Screen.dart';
// import '../Job Work/Job Worker/JobWorkerScreen.dart';
// import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
// import '../Job Work/Production_Costs/ProductionCost.dart';
// import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
// import '../Notification/NotificationScreen.dart';
// import '../Reports/ApprovalOutstandingReport.dart';
// import '../Reports/BarcodeHistory.dart';
// import '../Reports/PurchaseReciverSummary.dart';
// import '../Reports/SaleSumryReport.dart';
// import '../Reports/StockPositionReport.dart';
// import '../Role & Permission/PermissionScreen.dart';
// import '../Role & Permission/RoleScreen.dart';
// import '../User/CustomerScreen.dart';
// import '../Vacuum/Casting/CastingHeatingScreen.dart';
// import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
// import '../Vacuum/Casting_Recive/CastingReciveScreen.dart';
// import '../Vacuum/Casting_Sort/CastingSortScreen.dart';
// import '../Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
// import '../Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
// import '../Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
// import '../Vacuum/Vacuum Process/ProcessScreen.dart';
// import '../Vacuum/Vouchar History/VoucharHistoryScreen.dart';
// import 'InventoryScreen.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   int selectedIndex = 0;
//   List<String> sectionOrder = [];
//   List<String> userRoleNames = [];
//   List<String> userPermissions = []; // ✅ aa hovu joiye
//   List<Map<String, dynamic>> bottomItems = [
//     {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//
//     {"title": "More", "icon": Icons.more_horiz},
//   ];
//   List rates = [];
//   String source = "";
//   String updatedAt = "";
//   Timer? autoRefreshTimer;
//   String? activeSection;
//
//   Future<void> moveSectionToTopAndOpen(String sectionName) async {
//     // if (!mounted) return;
//
//     setState(() {
//       activeSection = sectionName;
//
//       /// Section top par
//       sectionOrder.remove(sectionName);
//       sectionOrder.insert(0, sectionName);
//
//       /// Badha close
//       for (final key in sectionOrder) {
//         expandedSections[key] = false;
//       }
//
//       /// Current section open
//       expandedSections[sectionName] = true;
//     });
//
//     /// Persist
//     await saveSectionOrder();
//     await saveExpandedSections();
//   }
//
//   Future<void> loadRates({bool silent = false}) async {
//     try {
//       /// ============================================
//       /// 1. LOCATION SERVICE CHECK
//       /// ============================================
//       final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//
//       if (!serviceEnabled) {
//         if (!silent && mounted) {
//           AppMessage.error(context, "Please enable location service.");
//         }
//
//         return;
//       }
//
//       /// ============================================
//       /// 2. LOCATION PERMISSION CHECK
//       /// ============================================
//       LocationPermission permission = await Geolocator.checkPermission();
//
//       /// Permission denied
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//
//         if (permission == LocationPermission.denied) {
//           if (!silent && mounted) {
//             AppMessage.error(context, "Location permission is required.");
//           }
//
//           return;
//         }
//       }
//
//       /// Permission permanently denied
//       if (permission == LocationPermission.deniedForever) {
//         if (!silent && mounted) {
//           AppMessage.error(
//             context,
//             "Location permission is permanently denied.",
//           );
//         }
//
//         return;
//       }
//
//       /// ============================================
//       /// 3. GET CURRENT LOCATION
//       /// ============================================
//       final Position position = await Geolocator.getCurrentPosition(
//         locationSettings: const LocationSettings(
//           accuracy: LocationAccuracy.high,
//         ),
//       );
//
//       final String latitude = position.latitude.toString();
//
//       final String longitude = position.longitude.toString();
//
//       debugPrint("======================================");
//
//       debugPrint("📍 CURRENT LOCATION");
//
//       debugPrint("Latitude  => $latitude");
//
//       debugPrint("Longitude => $longitude");
//
//       /// ============================================
//       /// 4. GET DEVICE ID
//       /// ============================================
//       String deviceId = "";
//       String deviceName = "";
//
//       try {
//         /// ==========================================
//         /// ANDROID
//         /// ==========================================
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//         if (Platform.isAndroid) {
//           final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//
//           deviceId = androidInfo.id;
//
//           deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
//
//           //platform = "android";
//         } else if (Platform.isIOS) {
//           final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//
//           deviceId = iosInfo.identifierForVendor ?? "";
//
//           deviceName = iosInfo.name;
//
//           //platform = "ios";
//         }
//       } catch (e) {
//         debugPrint("❌ Device ID Error => $e");
//
//         deviceId = "";
//       }
//
//       debugPrint("📱 Device ID => $deviceId");
//
//       debugPrint("======================================");
//
//       /// ============================================
//       /// 5. CREATE QUERY PARAMETERS
//       /// ============================================
//       final Map<String, dynamic> queryParameters = {
//         "latitude": latitude,
//         "longitude": longitude,
//         "device_id": deviceId,
//       };
//
//       debugPrint(
//         "📤 LIVE RATE QUERY => "
//         "$queryParameters",
//       );
//
//       /// ============================================
//       /// 6. API CALL
//       /// ============================================
//       final response = await ApiHelper().getRequestWithQuery(
//         ApiConstants.live_metal_rates,
//
//         queryParameters: queryParameters,
//
//         showLoading: false,
//       );
//
//       /// ============================================
//       /// 7. DEBUG RESPONSE
//       /// ============================================
//       debugPrint("======================================");
//
//       debugPrint("📥 LIVE RATE RESPONSE");
//
//       debugPrint("Status => ${response?.statusCode}");
//
//       debugPrint("Data => ${response?.data}");
//
//       debugPrint("======================================");
//
//       /// ============================================
//       /// 8. NO RESPONSE
//       /// ============================================
//       if (response == null) {
//         if (!silent && mounted) {
//           AppMessage.error(context, "No response from server.");
//         }
//
//         return;
//       }
//
//       /// ============================================
//       /// 9. SUCCESS
//       /// ============================================
//       if (response.statusCode == 200 && response.data["success"] == true) {
//         final data = response.data;
//
//         if (!mounted) return;
//
//         setState(() {
//           rates = data["data"] ?? [];
//
//           source = data["source"]?.toString() ?? "";
//
//           updatedAt = data["updated_at"]?.toString() ?? "";
//         });
//
//         /// ==========================================
//         /// LOAD SAVED SELECTED RATE
//         /// ==========================================
//         await loadSelectedRate();
//
//         return;
//       }
//
//       /// ============================================
//       /// 10. API ERROR
//       ///
//       /// Backend je message mokle
//       /// e j user ne show thase.
//       /// ============================================
//       String message = "Failed to load live rates";
//
//       final dynamic responseData = response.data;
//
//       if (responseData is Map && responseData["message"] != null) {
//         message = responseData["message"].toString();
//       }
//
//       debugPrint("❌ API MESSAGE => $message");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, message);
//       }
//     }
//     /// ============================================
//     /// 11. ERROR
//     /// ============================================
//     catch (e) {
//       debugPrint("======================================");
//
//       debugPrint("❌ LOAD RATES ERROR => $e");
//
//       debugPrint("======================================");
//
//       if (!silent && mounted) {
//         AppMessage.error(context, "Failed to load live rates");
//       }
//     }
//   }
//
//   Map<String, bool> expandedSections = {};
//   int? expandedIndex;
//   String getGreeting() {
//     final hour = DateTime.now().hour;
//
//     if (hour >= 5 && hour < 12) {
//       return "Good Morning 👋";
//     } else if (hour >= 12 && hour < 17) {
//       return "Good Afternoon ☀️";
//     } else if (hour >= 17 && hour < 21) {
//       return "Good Evening 🌇";
//     } else {
//       return "Good Night 🌙";
//     }
//   }
//
//   String selectedSymbol = "GOLD";
//   Map<String, dynamic>? selectedRate;
//   List<Map<String, dynamic>> allMenuItems = [
//     {
//       "title": "Person",
//       "icon": Icons.person_add,
//       "module": "customer",
//       "screen": const Customerscreen(),
//       "section": "Management",
//       "prefix": "person",
//     },
//     {
//       "title": "Users",
//       "icon": Icons.people,
//       "module": "user",
//       "screen": const Userscreen(),
//       "section": "Management",
//       "prefix": "user",
//     },
//     {
//       "title": "Category",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const Categoryscreen(),
//       "section": "Management",
//       "prefix": "category-person",
//     },
//     {
//       "title": "Office Access",
//       "icon": Icons.people,
//       "module": "category",
//       "screen": const OfficeAccessSettingsScreen(),
//       "section": "Management",
//       "prefix": "office-access",
//     },
//     {
//       "title": "Sales Estimate",
//       "icon": Icons.sell,
//       "module": "sale",
//       "screen": const SellList(),
//       "section": "Sales",
//       "prefix": "sale",
//     },
//     {
//       "title": "Sale on Approvals",
//       "icon": Icons.qr_code,
//       "module": "approval",
//       "screen": const InvoiceScreen(),
//       "section": "Sales",
//       "prefix": "approval", // ✅ "view" hatavi nakhyu
//     },
//     {
//       "title": "Approval Return",
//       "icon": Icons.sell,
//       "module": "approval_return",
//       "screen": const Approvalreturnscreen(),
//       "section": "Sales",
//       "prefix": "approval-return",
//     },
//     {
//       "title": "Rec-Ret-Purchase",
//       "icon": Icons.sell,
//       "module": "sale_advance",
//       "screen": const Receivevoucharscreen(),
//       "section": "Sales",
//       "prefix": "sale-advance",
//     },
//     // {
//     //   "title": "Reports",
//     //   "icon": Icons.bar_chart,
//     //   "screen": const DiamondReportsFullUI(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "reports",
//     // },
//     // {
//     //   "title": "Scanner",
//     //   "icon": Icons.qr_code_scanner,
//     //   "screen": const PremiumScannerScreen(),
//     //   "section": "Reports & Tools",
//     //   "prefix": "scanner",
//     // },
//     {
//       "title": "Item List",
//       "icon": Icons.add_box,
//       "module": "item",
//       "screen": const Itemscreen(),
//       "section": "Item Management",
//       "prefix": "item",
//     },
//     {
//       "title": "Label Config",
//       "icon": Icons.production_quantity_limits,
//       "module": "label_config",
//       "screen": const Labelscreen(),
//       "section": "Item Management",
//       "prefix": "label-config",
//     },
//     {
//       "title": "Label Items",
//       "icon": Icons.label_important_outlined,
//       "module": "item_set",
//       "screen": const label_item_screen(),
//       "section": "Item Management",
//       "prefix": "item-set",
//     },
//     {
//       "title": "Label Printing",
//       "icon": Icons.print,
//       "screen": const LabelPrintScreen(),
//       "section": "Item Management",
//       "prefix": "label-print",
//     },
//     {
//       "title": "Other Charges",
//       "icon": Icons.settings_applications,
//       "module": "other_charge",
//       "screen": const Othersscreen(),
//       "section": "Item Management",
//       "prefix": "other-charge",
//     },
//     {
//       "title": "Labour Formula",
//       "icon": Icons.add_box,
//       "module": "labour_formula",
//       "screen": const JobLabourformulaScreen(),
//       "section": "JobWork Management",
//       "prefix": "labour-formula",
//     },
//     {
//       "title": "Production Cost",
//       "icon": Icons.production_quantity_limits,
//       "module": "production_cost",
//       "screen": const Productioncost(),
//       "section": "JobWork Management",
//       "prefix": "production-cost",
//     },
//     {
//       "title": "Production Step",
//       "icon": Icons.label_important_outlined,
//       "module": "production_step",
//       "screen": const Prooductionstepscreen(),
//       "section": "JobWork Management",
//       "prefix": "production-step",
//     },
//     // {
//     //   "title": "Job Worker",
//     //   "icon": Icons.print,
//     //   "module": "job_worker",
//     //   "screen": const Jobworkerscreen(),
//     //   "section": "JobWork Management",
//     //   "prefix": "job-worker",
//     // },
//     {
//       "title": "Jobwork Issue",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_issue",
//       "screen": const JobworkIssueScreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-issue",
//     },
//     {
//       "title": "Jobwork Receive",
//       "icon": Icons.settings_applications,
//       "module": "jobwork_receive",
//       "screen": const Jobworkreceivescreen(),
//       "section": "JobWork Management",
//       "prefix": "jobwork-receive",
//     },
//     {
//       "title": "Sales Summary",
//       "icon": Icons.add_box,
//       "screen": const Salesumryreport(),
//       "section": "Report Management",
//       "prefix": "report-sales-summary",
//     },
//     {
//       "title": "Receiver Summary",
//       "icon": Icons.production_quantity_limits,
//       "screen": const Purchasereciversummary(),
//       "section": "Report Management",
//       "prefix": "report-purchase-receiver-summary",
//     },
//     {
//       "title": "Stock Position",
//       "icon": Icons.label_important_outlined,
//       "screen": const Stockpositionreport(),
//       "section": "Report Management",
//       "prefix": "report-stock-position",
//     },
//     {
//       "title": "Approval Outstanding",
//       "icon": Icons.print,
//       "screen": const Approvaloutstandingreport(),
//       "section": "Report Management",
//       "prefix": "report-approval-outstanding",
//     },
//     {
//       "title": "Barcode History",
//       "icon": Icons.settings_applications,
//       "screen": const Barcodehistory(),
//       "section": "Report Management",
//       "prefix": "report-barcode-history",
//     },
//     {
//       "title": "Outstanding Amount",
//       "icon": Icons.settings_applications,
//       "screen": const Outstandingamount(),
//       "section": "Report Management",
//       "prefix": "report-outstanding-amount",
//     },
//     {
//       "title": "Roles",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Rolescreen(),
//       "section": "Role Management",
//       "prefix": "role",
//     },
//     {
//       "title": "Permissions",
//       "icon": Icons.admin_panel_settings,
//       "screen": const Permissionscreen(),
//       "section": "Role Management",
//       "prefix": "permission",
//     },
//     {
//       "title": "Buch",
//       "icon": Icons.settings,
//       "module": "vacuum_buch",
//       "screen": const Buchscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-buch",
//     },
//     {
//       "title": "Process",
//       "icon": Icons.settings,
//       "module": "vacuum_process",
//       "screen": const Processscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-process",
//     },
//     {
//       "title": "Vacuum Voucher",
//       "icon": Icons.settings,
//       "module": "vacuum_voucher",
//       "screen": const Voucherscreen(),
//       "section": "Casting Management",
//       "prefix": "vacuum-voucher",
//     },
//     {
//       "title": "Casting Heating",
//       "icon": Icons.settings,
//       "module": "casting_heating",
//       "screen": const Castingheatingscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-heating",
//     },
//     {
//       "title": "Casting Metal",
//       "icon": Icons.settings,
//       "module": "casting_metal_issue",
//       "screen": const Castingmetalscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-metal-issue",
//     },
//     {
//       "title": "Casting Receive",
//       "icon": Icons.settings,
//       "module": "casting_release",
//       "screen": const Castingrecivescreen(),
//       "section": "Casting Management",
//       "prefix": "casting-release",
//     },
//     {
//       "title": "Tree Cutting Office",
//       "icon": Icons.settings,
//       "module": "tree_cutting_office",
//       "screen": const Treecuttingoffice(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-office",
//     },
//     {
//       "title": "Tree Cutting Issue",
//       "icon": Icons.settings,
//       "module": "tree_cutting_issue",
//       "screen": const Treecuttingissuescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-issue",
//     },
//     {
//       "title": "Tree Cutting Receive",
//       "icon": Icons.settings,
//       "module": "tree_cutting_receive",
//       "screen": const Treecuttingreceivescreen(),
//       "section": "Casting Management",
//       "prefix": "tree-cutting-receive",
//     },
//     {
//       "title": "Casting Sorting",
//       "icon": Icons.settings,
//       "module": "casting_sorting",
//       "screen": const Castingsortscreen(),
//       "section": "Casting Management",
//       "prefix": "casting-sorting",
//     },
//
//     {
//       "title": "Voucher History",
//       "icon": Icons.settings,
//       "module": "voucher-history",
//       "screen": const VoucherProcessHistoryScreen(),
//       "section": "Casting Management",
//       "prefix": "voucher-history",
//     },
//   ];
//
//   /// 🔥 DASHBOARD SELECTED ITEMS
//   List<Map<String, dynamic>> dashboardItems = [];
//   String name = "";
//   String email = "";
//   String companyName = "";
//   String State = "";
//   String City = "";
//   String Role = "";
//
//   Future<bool> readModule(String module) async {
//     try {
//       final response = await ApiHelper().postRequest(
//         "https://ornasphere.com/api/notifications/read-module",
//         {"module": module},
//       );
//
//       print("Read Module Response : ${response?.data}");
//
//       return response != null &&
//           response.statusCode == 200 &&
//           response.data["success"] == true;
//     } catch (e) {
//       print("Read Module Error : $e");
//       return false;
//     }
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     loadRates();
//     loadExpandedSections(); // 👈 ADD THIS
//     loadSectionOrder(); // 👈 ADD THIS
//     loadSelectedRate();
//
//     /// 🔥 Auto refresh every 30 seconds
//     // autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//     //   loadRates(silent: true);
//     // });
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<NotificationProvider>().loadNotificationCount();
//     });
//     getCompanyProfile();
//     //updateSectionOrder();
//     /// 🔥 DEFAULT DASHBOARD ITEMS
//     loadDashboardItems();
//     loadBottomNavItems(); // 🔥 ADD
//   }
//
//   Future<void> loadSelectedRate() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     selectedSymbol = prefs.getString("selected_rate_symbol") ?? "GOLD";
//
//     updateSelectedRate();
//
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   void updateSelectedRate() {
//     if (rates.isEmpty) return;
//
//     try {
//       selectedRate = rates.firstWhere((e) => e["symbol"] == selectedSymbol);
//     } catch (e) {
//       selectedRate = rates.first;
//     }
//   }
//
//   Future<void> loadBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String>? savedTitles = prefs.getStringList("bottom_nav_items");
//
//     List<Map<String, dynamic>> customItems = [];
//
//     if (savedTitles != null && savedTitles.isNotEmpty) {
//       for (var title in savedTitles) {
//         var match = allMenuItems.firstWhere(
//           (e) => e["title"] == title,
//           orElse: () => {},
//         );
//         if (match.isNotEmpty) {
//           customItems.add({
//             "title": match["title"],
//             "icon": match["icon"],
//             "screen": match["screen"],
//           });
//         }
//       }
//     }
//
//     setState(() {
//       bottomItems = [
//         {"title": "Dashboard", "icon": Icons.dashboard_outlined},
//         ...customItems,
//         {"title": "More", "icon": Icons.more_horiz},
//       ];
//     });
//   }
//
//   Future<void> saveBottomNavItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     List<String> titles = bottomItems
//         .where((e) => e["title"] != "Dashboard" && e["title"] != "More")
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("bottom_nav_items", titles);
//   }
//
//   void updateSectionOrder(
//     Map<String, List<Map<String, dynamic>>> groupedItems,
//   ) {
//     // Naya section keys (jaisi "Others") ne add karo jo already sectionOrder ma nathi
//     for (var key in groupedItems.keys) {
//       if (!sectionOrder.contains(key)) {
//         sectionOrder.add(key);
//       }
//     }
//
//     // Je sections have exist nathi karta groupedItems ma, ene sectionOrder thi remove karo
//     sectionOrder.removeWhere((s) => !groupedItems.containsKey(s));
//   }
//
//   Future<void> loadDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> excludedTitles =
//         prefs.getStringList("excluded_dashboard_items") ?? [];
//
//     /// 🔥 Have allMenuItems (je already permission pramane filtered che)
//     /// ma thi j dashboard items lese — jetli pan API permission hoy e badha
//     /// automatic dashboard par dekhashe (jo user e manually remove na karyu hoy to)
//     List<Map<String, dynamic>> tempItems = allMenuItems
//         .where((item) => !excludedTitles.contains(item["title"]))
//         .toList();
//
//     setState(() {
//       dashboardItems = tempItems;
//       _updateSectionOrderForNewItems();
//     });
//   }
//
//   Future<void> saveDashboardItems() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     /// 🔥 jetla items allMenuItems ma che pan dashboardItems ma nathi
//     /// (user e remove karya che), e excluded list ma save karo
//     List<String> excludedTitles = allMenuItems
//         .where((m) => !dashboardItems.any((d) => d["title"] == m["title"]))
//         .map((e) => e["title"].toString())
//         .toList();
//
//     await prefs.setStringList("excluded_dashboard_items", excludedTitles);
//
//     /// (Optional) jo old key "dashboard_items" use thato hoy biji jagya pan,
//     /// e clear/remove kari shako ke rehva dyo, have e use nathi thato
//   }
//
//   // એક હેલ્પર ફંક્શન સેક્શન ઓર્ડર મેન્ટેન કરવા માટે
//   void _updateSectionOrderForNewItems() {
//     final Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//
//     for (final item in dashboardItems) {
//       final String section = item["section"] ?? "Others";
//
//       tempGrouped.putIfAbsent(section, () => []);
//       tempGrouped[section]!.add(item);
//     }
//
//     final List<String> newOrder = [];
//
//     /// =========================================
//     /// CURRENT ACTIVE SECTION ALWAYS FIRST
//     /// =========================================
//     if (activeSection != null && tempGrouped.containsKey(activeSection)) {
//       newOrder.add(activeSection!);
//     }
//
//     /// =========================================
//     /// OLD ORDER MAINTAIN
//     /// =========================================
//     for (final section in sectionOrder) {
//       if (tempGrouped.containsKey(section) && !newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     /// =========================================
//     /// NEW SECTIONS ADD
//     /// =========================================
//     for (final section in tempGrouped.keys) {
//       if (!newOrder.contains(section)) {
//         newOrder.add(section);
//       }
//     }
//
//     if (!mounted) return;
//
//     setState(() {
//       sectionOrder = newOrder;
//
//       /// Active section open
//       if (activeSection != null) {
//         for (final section in sectionOrder) {
//           expandedSections[section] = section == activeSection;
//         }
//       }
//     });
//   }
//
//   Future<void> getCompanyProfile() async {
//     try {
//       final response = await ApiHelper().getRequest(ApiConstants.userProfile);
//
//       if (response == null) {
//         print("❌ No response — default dashboard load karo");
//         await loadDashboardItems();
//         return;
//       }
//
//       if (response.statusCode == 200) {
//         final jsonData = response.data;
//         final userData = jsonData["data"] ?? {};
//         final companyData = userData["company"] ?? {};
//
//         // ============================================================
//         // PROFILE DATA
//         // ============================================================
//
//         final profileData = userData["profile"] ?? {};
//
//         // ============================================================
//         // PERMISSIONS
//         // ============================================================
//
//         final List permissionsRaw =
//             profileData["permissions"] ?? jsonData["permissions"] ?? [];
//
//         final List<String> permissions = permissionsRaw
//             .map((e) => e.toString())
//             .toList();
//
//         // ============================================================
//         // ROLE NAMES
//         // ============================================================
//
//         final List roleNamesRaw = profileData["role_names"] ?? [];
//
//         final List<String> roleNames = roleNamesRaw
//             .map((e) => e.toString())
//             .toList();
//
//         print("✅ User Permissions: $permissions");
//         print("✅ User Role Names: $roleNames");
//
//         SharedPreferences prefs = await SharedPreferences.getInstance();
//
//         setState(() {
//           name = userData["name"]?.toString() ?? "-";
//           email = userData["email"]?.toString() ?? "-";
//           companyName = companyData["name"]?.toString() ?? "-";
//           City = companyData["city"]?.toString() ?? "-";
//           State = companyData["state"]?.toString() ?? "-";
//
//           // Save permissions
//           userPermissions = permissions;
//
//           // Save role names
//           userRoleNames = roleNames;
//
//           // Permission filtering
//           filterMenuByPermission();
//         });
//
//         // ============================================================
//         // SAVE USER DATA
//         // ============================================================
//
//         await prefs.setString("name", userData["name"]?.toString() ?? "-");
//
//         await prefs.setString("email", userData["email"]?.toString() ?? "-");
//
//         await prefs.setString(
//           "companyName",
//           companyData["name"]?.toString() ?? "-",
//         );
//
//         await prefs.setString("city", companyData["city"]?.toString() ?? "-");
//
//         await prefs.setString("state", companyData["state"]?.toString() ?? "-");
//
//         await prefs.setString("role", userData["role"]?.toString() ?? "-");
//
//         await prefs.setStringList("user_permissions", userPermissions);
//
//         await prefs.setStringList("user_role_names", userRoleNames);
//
//         // ============================================================
//         // LOAD DASHBOARD
//         // ============================================================
//
//         await loadDashboardItems();
//       } else {
//         // API fail
//         await loadDashboardItems();
//       }
//     } catch (e) {
//       print("❌ Exception: $e");
//
//       // Exception aave to default dashboard load
//       await loadDashboardItems();
//     }
//   }
//
//   void filterMenuByPermission() {
//     allMenuItems = allMenuItems.where((item) {
//       String prefix = item["prefix"].toString();
//
//       /// 🔥 Koi pan permission e prefix thi shuru thatu hoy (view/create/edit/delete/manage)
//       /// to e module dikhse
//       return userPermissions.contains("$prefix-view") ||
//           userPermissions.contains("$prefix-manage") ||
//           userPermissions.contains("$prefix-create") ||
//           userPermissions.contains("$prefix-edit") ||
//           userPermissions.contains("$prefix-delete");
//     }).toList();
//   }
//
//   bool isExpanded = false;
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.white,
//       drawer: const GlobalDrawer(),
//       extendBody: true,
//       extendBodyBehindAppBar: true, // IMPORTANT
//       //backgroundColor: AppColors.scaffoldBg,
//       bottomNavigationBar: customBottomNav(),
//       body: Stack(
//         children: [
//           /// ✅ Main Content
//           Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).size.height * 0.09),
//
//               const SizedBox(height: 10),
//
//               /// 🔥 ONLY THIS PART SCROLLABLE
//               Expanded(
//                 child: SingleChildScrollView(
//                   // 👈 ListView ના બદલે આ વાપરો
//                   padding: EdgeInsets.zero,
//                   child: Column(
//                     // 👈 અંદર એક Column ઉમેરો
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 10),
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 350),
//                           curve: Curves.easeInOut,
//                           height: isExpanded ? 240 : 75,
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             gradient: LinearGradient(
//                               colors: [
//                                 AppColors.primaryDark,
//                                 AppColors.secondaryDark,
//                               ],
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(.15),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 5),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             children: [
//                               /// HEADER
//                               InkWell(
//                                 onTap: () {
//                                   setState(() {
//                                     isExpanded = !isExpanded;
//                                   });
//                                 },
//                                 child: Container(
//                                   height: 75,
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 15,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       /// LEFT
//                                       Expanded(
//                                         child: Column(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.center,
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               getGreeting(),
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 3),
//
//                                             Text(
//                                               DateFormat(
//                                                 "dd MMM yyyy",
//                                               ).format(DateTime.now()),
//                                               style: const TextStyle(
//                                                 color: Colors.white70,
//                                                 fontSize: 13,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       /// CENTER
//                                       selectedRate == null
//                                           ? const SizedBox()
//                                           : GestureDetector(
//                                               onTap: () {
//                                                 Navigator.push(
//                                                   context,
//                                                   MaterialPageRoute(
//                                                     builder: (context) =>
//                                                         const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                                   ),
//                                                 );
//                                               },
//                                               child: Container(
//                                                 padding:
//                                                     const EdgeInsets.symmetric(
//                                                       horizontal: 10,
//                                                       vertical: 6,
//                                                     ),
//                                                 decoration: BoxDecoration(
//                                                   color: Colors.white
//                                                       .withOpacity(0.12),
//                                                   borderRadius:
//                                                       BorderRadius.circular(5),
//                                                 ),
//                                                 child: Column(
//                                                   mainAxisSize: MainAxisSize
//                                                       .min, // 👈 જરૂરી
//                                                   crossAxisAlignment:
//                                                       CrossAxisAlignment.center,
//                                                   children: [
//                                                     Text(
//                                                       selectedRate!["symbol"],
//                                                       style: const TextStyle(
//                                                         color: Colors.white70,
//                                                         fontSize: 12,
//                                                         fontWeight:
//                                                             FontWeight.w500,
//                                                       ),
//                                                     ),
//                                                     const SizedBox(height: 0),
//                                                     Text(
//                                                       "₹${selectedRate!["formatted_rate"]}",
//                                                       style: const TextStyle(
//                                                         color: Colors.white,
//                                                         fontSize: 16,
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                               ),
//                                             ),
//
//                                       const SizedBox(width: 0),
//
//                                       AnimatedRotation(
//                                         turns: isExpanded ? .5 : 0,
//                                         duration: const Duration(
//                                           milliseconds: 300,
//                                         ),
//                                         child: const Icon(
//                                           Icons.keyboard_arrow_down,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//
//                               /// EXPAND AREA
//                               Expanded(
//                                 child: AnimatedCrossFade(
//                                   duration: const Duration(milliseconds: 300),
//                                   crossFadeState: isExpanded
//                                       ? CrossFadeState.showSecond
//                                       : CrossFadeState.showFirst,
//
//                                   firstChild: const SizedBox(),
//
//                                   secondChild: Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 10,
//                                     ),
//                                     child: Column(
//                                       children: [
//                                         buildFirstRowStats(),
//                                         const SizedBox(height: 10),
//                                         buildSecondRowStats(),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       metalRateMarquee(),
//                       const SizedBox(height: 10),
//                       Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 10),
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(10),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.06),
//                               blurRadius: 15,
//                               offset: const Offset(0, 5),
//                             ),
//                           ],
//                         ),
//
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Header
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 const Text(
//                                   "New Features",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w700,
//                                     color: Color(0xff14213D),
//                                   ),
//                                 ),
//
//                                 Row(
//                                   children: [
//                                     Text(
//                                       "View All",
//                                       style: TextStyle(
//                                         color: AppColors.primaryDark,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//
//                                     const SizedBox(width: 5),
//
//                                     Container(
//                                       height: 22,
//                                       width: 22,
//                                       decoration: BoxDecoration(
//                                         color: Color(0xffEEF3FF),
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: Icon(
//                                         Icons.arrow_forward_ios,
//                                         size: 12,
//                                         color: AppColors.primaryDark,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             // Options
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 optionItem(
//                                   Icons.bar_chart,
//                                   "BG Remove",
//                                   Color(0xff6C35FF),
//                                   Color(0xffF2EEFF),
//                                 ),
//
//                                 optionItem(
//                                   Icons.inventory_2,
//                                   "Visiting Card",
//                                   Color(0xff00C853),
//                                   Color(0xffEFFFF4),
//                                 ),
//
//                                 optionItem(
//                                   Icons.monitor_sharp,
//                                   "Live Rate",
//                                   Color(0xffff9800),
//                                   Color(0xfffff5e8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//
//                                 optionItem(
//                                   Icons.qr_code,
//                                   "ALL QR",
//                                   Color(0xff6A35FF),
//                                   Color(0xffF3EEFF),
//                                 ),
//
//                                 // optionItem(
//                                 //   Icons.credit_card,
//                                 //   "Payments",
//                                 //   Color(0xff00BCD4),
//                                 //   Color(0xffE8FBFF),
//                                 // ),
//                                 //
//                                 //
//                                 optionItem(
//                                   Icons.settings,
//                                   "Settings",
//                                   Color(0xff7A8499),
//                                   Color(0xffF4F5F8),
//                                   onTap: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             const SettingsScreen(), // 👈 tamari target screen nu naam
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                       popularProductsSection(context),
//                       const SizedBox(
//                         height: 80,
//                       ), // છેલ્લે થોડી જગ્યા આપો (Bottom Nav માટે)
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           /// 🔥 APPBAR CALL HERE
//           buildAppBar(context),
//         ],
//       ),
//       floatingActionButton: Container(
//         height: 45,
//         width: 45,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: const LinearGradient(
//             colors: [AppColors.primaryDark, AppColors.secondaryDark],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black26,
//               blurRadius: 10,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//
//         child: FloatingActionButton(
//           onPressed: () {
//             showMenuSelectionDialog(isBottomNavMode: false);
//           },
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           child: const Icon(Icons.edit, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
//
//   Widget buildAppBar(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final isMobile = width < 600;
//
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: SafeArea(
//         child: Container(
//           padding: EdgeInsets.symmetric(
//             horizontal: isMobile ? 12 : 10,
//             vertical: 0,
//           ),
//
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               /// 🔥 CENTER TITLE
//               Center(
//                 child: Image.asset(
//                   "assets/static/text.png",
//                   height: 30,
//                   width: 200,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//
//               /// LEFT + RIGHT ROW
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   /// LEFT MENU
//                   Row(
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           _scaffoldKey.currentState?.openDrawer();
//                         },
//                         child: Container(
//                           padding: EdgeInsets.all(isMobile ? 6 : 8),
//                           decoration: BoxDecoration(
//                             color: AppColors.primaryDark,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                           child: Icon(
//                             Icons.menu,
//                             size: isMobile ? 20 : 24,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   /// RIGHT ICONS
//                   Row(
//                     children: [
//                       Consumer<NotificationProvider>(
//                         builder: (context, provider, child) {
//                           return GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const NotificationScreen(),
//                                 ),
//                               );
//
//                               // Notification screen mathi pachha aavya pachi count refresh
//                               provider.loadNotificationCount();
//                             },
//                             child: Container(
//                               padding: EdgeInsets.all(isMobile ? 6 : 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 20,
//                                     offset: const Offset(5, 10),
//                                   ),
//                                 ],
//                               ),
//                               child: Stack(
//                                 clipBehavior: Clip.none,
//                                 children: [
//                                   Icon(
//                                     Icons.notifications_none,
//                                     size: isMobile ? 22 : 24,
//                                     color: Colors.red,
//                                   ),
//
//                                   if (provider.total > 0)
//                                     Positioned(
//                                       right: -5,
//                                       top: -8,
//                                       child: Container(
//                                         padding: const EdgeInsets.all(3),
//                                         constraints: const BoxConstraints(
//                                           minWidth: 18,
//                                           minHeight: 18,
//                                         ),
//                                         decoration: const BoxDecoration(
//                                           color: Colors.red,
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Center(
//                                           child: Text(
//                                             provider.total > 99
//                                                 ? "99+"
//                                                 : provider.total.toString(),
//                                             style: const TextStyle(
//                                               color: Colors.white,
//                                               fontSize: 9,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//
//                       // SizedBox(width: isMobile ? 8 : 12),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Widget popularProductsSection(BuildContext context) {
//   //   final width = MediaQuery.of(context).size.width;
//   //
//   //   int crossAxisCount() {
//   //     if (width < 600) return 3;
//   //     if (width < 900) return 3;
//   //     if (width < 1200) return 4;
//   //     return 5;
//   //   }
//   //
//   //   double childAspectRatio() {
//   //     if (width < 600) return 0.94;
//   //     if (width < 900) return 1.1;
//   //     return 1.2;
//   //   }
//   //
//   //   // --- GROUPING LOGIC (તમારો ઓરિજિનલ કોડ) ---
//   //   Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//   //   for (var item in dashboardItems) {
//   //     String section = item["section"] ?? "Other";
//   //     if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//   //     tempGrouped[section]!.add(item);
//   //   }
//   //
//   //   Map<String, List<Map<String, dynamic>>> groupedItems = {};
//   //   List<Map<String, dynamic>> otherItems = [];
//   //   tempGrouped.forEach((section, items) {
//   //     if (items.length == 1) {
//   //       otherItems.addAll(items);
//   //     } else {
//   //       groupedItems[section] = items;
//   //     }
//   //   });
//   //   if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//   //
//   //   // સેક્શન ઓર્ડર અપડેટ કરો
//   //   updateSectionOrder(groupedItems);
//   //
//   //   return Padding(
//   //     padding: const EdgeInsets.all(10.0),
//   //     child: ReorderableListView(
//   //       shrinkWrap: true,
//   //       physics: const NeverScrollableScrollPhysics(),
//   //       onReorder: _onReorder,
//   //       // ડ્રેગ કરતી વખતે બેકગ્રાઉન્ડ કલર ટ્રાન્સપરન્ટ રાખવા માટે (Optional)
//   //       proxyDecorator: (child, index, animation) => child,
//   //       children: sectionOrder.map((sectionName) {
//   //         // જો ગ્રુપમાં આ સેક્શન ન હોય તો ખાલી કન્ટેનર રિટર્ન કરો
//   //         if (!groupedItems.containsKey(sectionName))
//   //           return SizedBox(key: ValueKey(sectionName));
//   //
//   //         List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//   //
//   //         return Container(
//   //           key: ValueKey(sectionName), // Reorderable માટે યુનિક કી
//   //           margin: const EdgeInsets.only(bottom: 16),
//   //           padding: const EdgeInsets.all(12),
//   //           decoration: BoxDecoration(
//   //             color: Colors.white,
//   //             borderRadius: BorderRadius.circular(14),
//   //             border: Border.all(color: AppColors.border),
//   //             boxShadow: [
//   //               BoxShadow(
//   //                 color: Colors.black.withOpacity(0.05),
//   //                 blurRadius: 8,
//   //                 offset: const Offset(0, 3),
//   //               ),
//   //             ],
//   //           ),
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               /// 🔥 SECTION TITLE (હવે આ આખી રો ડ્રેગ હેન્ડલ તરીકે કામ કરશે)
//   //               Row(
//   //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //                 children: [
//   //                   Row(
//   //                     crossAxisAlignment: CrossAxisAlignment.center,
//   //                     children: [
//   //                       Container(
//   //                         padding: const EdgeInsets.all(6),
//   //                         decoration: BoxDecoration(
//   //                           gradient: LinearGradient(
//   //                             colors: [
//   //                               AppColors.primaryDark.withOpacity(0.7),
//   //                               AppColors.secondaryDark.withOpacity(0.7),
//   //                             ],
//   //                           ),
//   //                           borderRadius: BorderRadius.circular(10),
//   //                         ),
//   //                         child: const Icon(
//   //                           Icons.drag_indicator,
//   //                           color: Colors.white,
//   //                           size: 20,
//   //                         ),
//   //                       ),
//   //
//   //                       const SizedBox(width: 10),
//   //
//   //                       Column(
//   //                         mainAxisAlignment: MainAxisAlignment.center,
//   //                         crossAxisAlignment: CrossAxisAlignment.start,
//   //                         mainAxisSize: MainAxisSize.min,
//   //                         children: [
//   //                           Text(
//   //                             sectionName,
//   //                             textAlign: TextAlign.center,
//   //                             style: const TextStyle(
//   //                               fontSize: 15,
//   //                               fontWeight: FontWeight.bold,
//   //                               color: Colors.black,
//   //                             ),
//   //                           ),
//   //
//   //                           Text(
//   //                             getSectionSubtitle(sectionName),
//   //                             style: TextStyle(
//   //                               fontSize: 12,
//   //                               color: AppColors.textLight,
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ],
//   //                   ),
//   //                   Container(
//   //                     padding: const EdgeInsets.symmetric(
//   //                       horizontal: 10,
//   //                       vertical: 3,
//   //                     ),
//   //                     decoration: BoxDecoration(
//   //                       gradient: LinearGradient(
//   //                         colors: [
//   //                           AppColors.primaryDark.withOpacity(0.7),
//   //                           AppColors.secondaryDark.withOpacity(0.7),
//   //                         ],
//   //                       ),
//   //                       borderRadius: BorderRadius.circular(8),
//   //                     ),
//   //                     child: Text(
//   //                       "${items.length} Items",
//   //                       style: const TextStyle(
//   //                         color: Colors.white,
//   //                         fontWeight: FontWeight.w600,
//   //                         fontSize: 12,
//   //                       ),
//   //                     ),
//   //                   ),
//   //                 ],
//   //               ),
//   //               const SizedBox(height: 14),
//   //
//   //               /// 🔥 GRID
//   //               GridView.builder(
//   //                 itemCount: items.length,
//   //                 shrinkWrap: true,
//   //                 physics: const NeverScrollableScrollPhysics(),
//   //                 padding: EdgeInsets.zero,
//   //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//   //                   crossAxisCount: crossAxisCount(),
//   //                   crossAxisSpacing: 12,
//   //                   mainAxisSpacing: 12,
//   //                   childAspectRatio: childAspectRatio(),
//   //                 ),
//   //                 itemBuilder: (context, index) {
//   //                   final item = items[index];
//   //                   final module = item["module"] ?? "";
//   //
//   //                   final count = context
//   //                       .watch<NotificationProvider>()
//   //                       .moduleCount(module);
//   //
//   //                   //print("Module: $module -> Count: $count");
//   //                   return _premiumMenuCard(
//   //                     context,
//   //                     item["title"],
//   //                     item["icon"],
//   //                     () async {
//   //                       readModule(module);
//   //                       final result = await Navigator.push(
//   //                         context,
//   //                         MaterialPageRoute(builder: (_) => item["screen"]),
//   //                       );
//   //
//   //                       // 👇 Child page mathi pop thay pachi
//   //                       if (result == true) {
//   //                         print("Refresh");
//   //                         await getCompanyProfile();
//   //                         setState(() {});
//   //                       }
//   //                     },
//   //                     count: count,
//   //                   );
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //         );
//   //       }).toList(),
//   //     ),
//   //   );
//   // }
//
//   Widget popularProductsSection(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//
//     int crossAxisCount() {
//       if (width < 600) return 3;
//       if (width < 900) return 3;
//       if (width < 1200) return 4;
//       return 5;
//     }
//
//     double childAspectRatio() {
//       if (width < 600) return 0.94;
//       if (width < 900) return 1.1;
//       return 1.2;
//     }
//
//     //--- GROUPING LOGIC (same) ---
//     Map<String, List<Map<String, dynamic>>> tempGrouped = {};
//     for (var item in dashboardItems) {
//       String section = item["section"] ?? "Other";
//       if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
//       tempGrouped[section]!.add(item);
//     }
//
//     Map<String, List<Map<String, dynamic>>> groupedItems = {};
//     List<Map<String, dynamic>> otherItems = [];
//     tempGrouped.forEach((section, items) {
//       if (userRoleNames.length == 1) {
//         otherItems.addAll(items);
//       } else {
//         groupedItems[section] = items;
//       }
//     });
//
//     if (otherItems.isNotEmpty) {
//       groupedItems["Others"] = otherItems;
//     }
//     if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
//
//     // --- GROUPING LOGIC ---
//
//     //updateSectionOrder(groupedItems);
//
//     return Padding(
//       padding: const EdgeInsets.all(10.0),
//       child: ReorderableListView(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         onReorder: _onReorder,
//         proxyDecorator: (child, index, animation) => child,
//         children: sectionOrder.map((sectionName) {
//           if (!groupedItems.containsKey(sectionName))
//             return SizedBox(key: ValueKey(sectionName));
//
//           List<Map<String, dynamic>> items = groupedItems[sectionName]!;
//
//           /// 🔥 Default expanded state (na hoy to true rakho — pehla khulu j dekhay)
//           // bool isExpanded = expandedSections[sectionName] ?? false;
//           /// 🔥 Fakt PEHLU section default open rahe, baki badha collapsed
//           final bool isExpanded = expandedSections[sectionName] ?? false;
//
//           return Material(
//             key: ValueKey(sectionName),
//             color: Colors.transparent,
//             child: Container(
//               key: ValueKey(sectionName),
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: AppColors.border),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// 🔥 SECTION TITLE — have TAP thi expand/collapse thashe
//                   InkWell(
//                     onTap: () async {
//                       final bool currentlyExpanded =
//                           expandedSections[sectionName] ?? false;
//
//                       setState(() {
//                         /// Pehla badha sections close
//                         for (final section in sectionOrder) {
//                           expandedSections[section] = false;
//                         }
//
//                         /// Jo current section pehla close hato,
//                         /// to fakt ene open karo.
//                         ///
//                         /// Jo already open hato,
//                         /// to badha close j rehse.
//                         if (!currentlyExpanded) {
//                           expandedSections[sectionName] = true;
//                         }
//                       });
//
//                       await saveExpandedSections();
//                     },
//                     borderRadius: BorderRadius.circular(8),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             /// 🔥 Drag handle — have ReorderableDragStartListener thi wrap karyu,
//                             /// jethi fakt AA icon j drag mate vaparay, baki title tap expand/collapse kare
//                             ReorderableDragStartListener(
//                               index: sectionOrder.indexOf(sectionName),
//                               child: Container(
//                                 padding: const EdgeInsets.all(6),
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [
//                                       AppColors.primaryDark.withOpacity(0.7),
//                                       AppColors.secondaryDark.withOpacity(0.7),
//                                     ],
//                                   ),
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                                 child: const Icon(
//                                   Icons.drag_indicator,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 10),
//
//                             Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   sectionName,
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                                 Text(
//                                   getSectionSubtitle(sectionName),
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: AppColors.textLight,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 3,
//                               ),
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark.withOpacity(0.7),
//                                     AppColors.secondaryDark.withOpacity(0.7),
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//                               child: Text(
//                                 "${items.length} Items",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//
//                             const SizedBox(width: 8),
//
//                             /// 🔥 Expand/Collapse Arrow
//                             AnimatedRotation(
//                               turns: isExpanded ? 0.5 : 0,
//                               duration: const Duration(milliseconds: 250),
//                               child: Container(
//                                 padding: const EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.background,
//                                   borderRadius: BorderRadius.circular(6),
//                                   border: Border.all(color: AppColors.border),
//                                 ),
//                                 child: Icon(
//                                   Icons.keyboard_arrow_down,
//                                   size: 18,
//                                   color: AppColors.primaryDark,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   /// 🔥 GRID — AnimatedCrossFade thi smooth expand/collapse
//                   AnimatedCrossFade(
//                     duration: const Duration(milliseconds: 250),
//                     crossFadeState: isExpanded
//                         ? CrossFadeState.showFirst
//                         : CrossFadeState.showSecond,
//                     firstChild: Padding(
//                       padding: const EdgeInsets.only(top: 14),
//                       child: GridView.builder(
//                         itemCount: items.length,
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         padding: EdgeInsets.zero,
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: crossAxisCount(),
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 12,
//                           childAspectRatio: childAspectRatio(),
//                         ),
//                         itemBuilder: (context, index) {
//                           final item = items[index];
//                           final module = item["module"] ?? "";
//
//                           final count = context
//                               .watch<NotificationProvider>()
//                               .moduleCount(module);
//
//                           return _premiumMenuCard(
//                             context,
//                             item["title"],
//                             item["icon"],
//                             () async {
//                               /// Notification read
//                               readModule(module);
//
//                               /// 🔥 Navigate karta PEHLA section top + open
//                               //moveSectionToTopAndOpen(sectionName);
//
//                               /// Screen open
//                               final result = await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => item["screen"],
//                                 ),
//                               );
//
//                               if (!mounted) return;
//
//                               /// 🔥 BACK AAVYA PACHI FARITHI ENSURE KARO
//                               //await moveSectionToTopAndOpen(sectionName);
//
//                               /// Data refresh required hoy to
//                               if (result == true) {
//                                 await getCompanyProfile();
//                                 await loadRates(silent: true);
//                                 WidgetsBinding.instance.addPostFrameCallback((
//                                   _,
//                                 ) {
//                                   context
//                                       .read<NotificationProvider>()
//                                       .loadNotificationCount();
//                                 });
//                                 // /// getCompanyProfile rebuild kare pachi pan
//                                 // /// current section restore karo
//                                 // await moveSectionToTopAndOpen(sectionName);
//                               }
//                             },
//                             count: count,
//                           );
//                         },
//                       ),
//                     ),
//                     secondChild: const SizedBox(width: double.infinity),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _premiumMenuCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     VoidCallback onTap, {
//     int count = 0,
//   }) {
//     return Material(
//       // 🔥 આ ઉમેરવાથી "No Material found" એરર દૂર થશે
//       color: Colors.transparent, // બેકગ્રાઉન્ડ ટ્રાન્સપરન્ટ રાખવું
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.border),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 6,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               /// 🔥 ICON CIRCLE
//               Stack(
//                 clipBehavior: Clip.none,
//                 children: [
//                   Container(
//                     height: 40,
//                     width: 40,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(15),
//                       shape: BoxShape.rectangle,
//                     ),
//                     child: Icon(icon, color: Colors.white, size: 22),
//                   ),
//
//                   /// Notification Count
//                   if (count > 0)
//                     Positioned(
//                       top: -6,
//                       right: -6,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 5,
//                           vertical: 2,
//                         ),
//                         constraints: const BoxConstraints(
//                           minWidth: 18,
//                           minHeight: 18,
//                         ),
//                         decoration: const BoxDecoration(
//                           color: Colors.red,
//                           shape: BoxShape.circle,
//                         ),
//                         alignment: Alignment.center,
//                         child: Text(
//                           count > 99 ? "99+" : "$count",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 9,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//
//               const SizedBox(height: 5),
//
//               /// TITLE
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//   //////////////////////////////////////////////////////////////
//   /// 🔵 PRODUCT CARD
//   //////////////////////////////////////////////////////////////
//
//   Widget productCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     VoidCallback onTap,
//   ) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//     final isTablet = width > 600;
//
//     return GestureDetector(
//       onTap: onTap,
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//           child: Container(
//             padding: EdgeInsets.all(width * 0.04),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.1),
//                 width: 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 15,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   height: isTablet ? width * 0.10 : width * 0.14,
//                   width: isTablet ? width * 0.10 : width * 0.16,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF1E2A55), Color(0xFF1E2A55)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFF0D1633).withOpacity(0.5),
//                         blurRadius: 20,
//                         offset: const Offset(0, 8),
//                       ),
//                     ],
//                   ),
//                   child: Icon(
//                     icon,
//                     color: Colors.white,
//                     size: isTablet ? width * 0.04 : width * 0.06,
//                   ),
//                 ),
//                 SizedBox(height: height * 0.015),
//                 Text(
//                   title,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: AppColors.white,
//                     fontSize: isTablet ? width * 0.022 : width * 0.035,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget customBottomNav() {
//     final size = MediaQuery.of(context).size;
//     final double width = size.width;
//
//     /// ============================================
//     /// RESPONSIVE BREAKPOINTS
//     /// ============================================
//     final bool isVerySmallPhone = width < 340;
//     final bool isSmallPhone = width >= 340 && width < 400;
//     final bool isMobile = width < 600;
//     final bool isTablet = width >= 600 && width < 1000;
//     final bool isDesktop = width >= 1000;
//
//     /// ============================================
//     /// RESPONSIVE HEIGHT
//     /// ============================================
//     final double navHeight;
//
//     if (isDesktop) {
//       navHeight = 78;
//     } else if (isTablet) {
//       navHeight = 72;
//     } else if (isVerySmallPhone) {
//       navHeight = 62;
//     } else if (isSmallPhone) {
//       navHeight = 65;
//     } else {
//       navHeight = 68;
//     }
//
//     /// ============================================
//     /// RESPONSIVE ICON SIZE
//     /// ============================================
//     final double iconSize;
//
//     if (isDesktop) {
//       iconSize = 25;
//     } else if (isTablet) {
//       iconSize = 22;
//     } else if (isVerySmallPhone) {
//       iconSize = 18;
//     } else if (isSmallPhone) {
//       iconSize = 19;
//     } else {
//       iconSize = 21;
//     }
//
//     /// ============================================
//     /// RESPONSIVE FONT SIZE
//     /// ============================================
//     final double fontSize;
//
//     if (isDesktop) {
//       fontSize = 12;
//     } else if (isTablet) {
//       fontSize = 10.5;
//     } else if (isVerySmallPhone) {
//       fontSize = 8.5;
//     } else if (isSmallPhone) {
//       fontSize = 9;
//     } else {
//       fontSize = 10;
//     }
//
//     /// ============================================
//     /// RESPONSIVE HORIZONTAL MARGIN
//     ///
//     /// Tablet ma width cut na kariye.
//     /// Aa overflow avoid karva important che.
//     /// ============================================
//     final double horizontalMargin;
//
//     if (isDesktop) {
//       horizontalMargin = width * 0.12;
//     } else if (isTablet) {
//       horizontalMargin = 8;
//     } else {
//       horizontalMargin = 0;
//     }
//
//     /// ============================================
//     /// RESPONSIVE RADIUS
//     /// ============================================
//     final double radius = isMobile ? 12 : 15;
//
//     return SafeArea(
//       top: false,
//       child: Container(
//         height: navHeight,
//         margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(radius),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.12),
//               blurRadius: 12,
//               offset: const Offset(0, -3),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(radius),
//           child: BottomNavigationBar(
//             /// ========================================
//             /// BASIC
//             /// ========================================
//             backgroundColor: Colors.white,
//
//             currentIndex: selectedIndex,
//
//             type: BottomNavigationBarType.fixed,
//
//             elevation: 0,
//
//             /// ========================================
//             /// ICON
//             /// ========================================
//             iconSize: iconSize,
//
//             /// ========================================
//             /// FONT
//             /// ========================================
//             selectedFontSize: fontSize,
//             unselectedFontSize: fontSize,
//
//             selectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w600,
//               height: 1.0,
//             ),
//
//             unselectedLabelStyle: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w500,
//               height: 1.0,
//             ),
//
//             /// ========================================
//             /// COLOR
//             /// ========================================
//             selectedItemColor: AppColors.primaryDark,
//
//             unselectedItemColor: Colors.grey.shade600,
//
//             /// ========================================
//             /// LABEL SETTINGS
//             /// ========================================
//             showSelectedLabels: true,
//             showUnselectedLabels: true,
//
//             /// ========================================
//             /// CLICK
//             /// ========================================
//             onTap: (index) {
//               final item = bottomItems[index];
//
//               /// MORE CLICK
//               if (item["title"] == "More") {
//                 showMenuSelectionDialog(isBottomNavMode: true);
//                 return;
//               }
//
//               setState(() {
//                 selectedIndex = index;
//               });
//
//               /// SCREEN OPEN
//               if (item["screen"] != null) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => item["screen"]),
//                 );
//               }
//             },
//
//             /// ========================================
//             /// ITEMS
//             /// ========================================
//             items: bottomItems.map((item) {
//               final String title = item["title"]?.toString() ?? "";
//
//               return BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(bottom: isVerySmallPhone ? 1 : 2),
//                   child: Icon(item["icon"], size: iconSize),
//                 ),
//
//                 /// Long label hoy to short kari shakai
//                 label: title,
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget addNewGlassCard() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(12),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.05), // glass transparency
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 10,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.add, color: AppColors.white, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 "Add New",
//                 style: TextStyle(
//                   color: AppColors.white,
//                   fontWeight: FontWeight.w500,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget gradientIcon(IconData icon, bool selected) {
//     return ShaderMask(
//       shaderCallback: (bounds) {
//         return LinearGradient(
//           colors: selected
//               ? const [Colors.white54, Colors.white54]
//               : const [Colors.white54, Colors.white54],
//         ).createShader(bounds);
//       },
//       child: Icon(icon, color: Colors.white, size: 24),
//     );
//   }
//
//   void showMenuSelectionDialog({bool isBottomNavMode = false}) {
//     List<Map<String, dynamic>> sections = [
//       {
//         "title": "Item Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Item List",
//             "icon": Icons.add_box,
//             "screen": const Itemscreen(),
//             "prefix": "item", // ✅ ADD
//           },
//           {
//             "title": "Label Config",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Labelscreen(),
//             "prefix": "label-config", // ✅ ADD
//           },
//           {
//             "title": "Label Items",
//             "icon": Icons.label_important_outlined,
//             "screen": const label_item_screen(),
//             "prefix": "item-set", // ✅ ADD
//           },
//           {
//             "title": "Label Printing",
//             "icon": Icons.print,
//             "screen": const LabelPrintScreen(),
//             "prefix": "label-print", // ✅ ADD
//           },
//           {
//             "title": "Other Charges",
//             "icon": Icons.settings_applications,
//             "screen": const Othersscreen(),
//             "prefix": "other-charge", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "User Management",
//         "icon": Icons.dashboard_customize,
//         "items": [
//           {
//             "title": "Person",
//             "icon": Icons.person_add,
//             "screen": const Customerscreen(),
//             "prefix": "person", // ✅ ADD
//           },
//           {
//             "title": "Users",
//             "icon": Icons.people,
//             "screen": const Userscreen(),
//             "prefix": "user", // ✅ ADD
//           },
//           {
//             "title": "Category",
//             "icon": Icons.people,
//             "screen": const Categoryscreen(),
//             "prefix": "category-person", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "JobWork Management",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Labour Formula",
//             "icon": Icons.add_box,
//             "screen": const JobLabourformulaScreen(),
//             "prefix": "labour-formula", // ✅ ADD
//           },
//           {
//             "title": "Production Cost",
//             "icon": Icons.production_quantity_limits,
//             "screen": const Productioncost(),
//             "prefix": "production-cost", // ✅ ADD
//           },
//           {
//             "title": "Production Step",
//             "icon": Icons.label_important_outlined,
//             "screen": const Prooductionstepscreen(),
//             "prefix": "production-step", // ✅ ADD
//           },
//           // {
//           //   "title": "Job Worker",
//           //   "icon": Icons.print,
//           //   "screen": const Jobworkerscreen(),
//           //   "prefix": "job-worker", // ✅ ADD
//           // },
//           {
//             "title": "Jobwork Issue",
//             "icon": Icons.settings_applications,
//             "screen": const JobworkIssueScreen(),
//             "prefix": "jobwork-issue", // ✅ ADD
//           },
//           {
//             "title": "Jobwork Receive",
//             "icon": Icons.settings_applications,
//             "screen": const Jobworkreceivescreen(),
//             "prefix": "jobwork-receive", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Sales",
//         "icon": Icons.inventory_2,
//         "items": [
//           {
//             "title": "Sale on Approvals",
//             "icon": Icons.qr_code,
//             "screen": const InvoiceScreen(),
//             "prefix": "approval", // ✅ ADD
//           },
//           {
//             "title": "Sales Estimate",
//             "icon": Icons.sell,
//             "screen": const SellList(),
//             "prefix": "sale", // ✅ ADD
//           },
//           {
//             "title": "Approval Return",
//             "icon": Icons.sell,
//             "screen": const Approvalreturnscreen(),
//             "prefix": "approval-return", // ✅ ADD
//           },
//           {
//             "title": "Rec-Ret-Purchase",
//             "icon": Icons.sell,
//             "screen": const ReciveReturnPurchase(),
//             "prefix": "sale-advance", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Reports & Tools",
//         "icon": Icons.analytics,
//         "items": [
//           {
//             "title": "Sales Summary",
//             "icon": Icons.bar_chart,
//             "screen": const Salesumryreport(),
//             "prefix": "report-sales-summary", // ✅ ADD
//           },
//           {
//             "title": "Reciver Summary",
//             "icon": Icons.qr_code_scanner,
//             "screen": const Purchasereciversummary(),
//             "prefix": "receiver-summary", // ✅ ADD
//           },
//           {
//             "title": "Stock Position",
//             "icon": Icons.bar_chart,
//             "screen": const Stockpositionreport(),
//             "prefix": "report-stock-position", // ✅ ADD
//           },
//           {
//             "title": "Approval Outstanding",
//             "icon": Icons.menu_book,
//             "screen": const Approvaloutstandingreport(),
//             "prefix": "report-approval-outstanding", // ✅ ADD
//           },
//           {
//             "title": "Barcode History",
//             "icon": Icons.menu_book,
//             "screen": const Barcodehistory(),
//             "prefix": "report-barcode-history", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Role & Permission",
//         "icon": Icons.admin_panel_settings,
//         "items": [
//           {
//             "title": "Roles",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Rolescreen(),
//             "prefix": "role", // ✅ ADD
//           },
//           {
//             "title": "Permissions",
//             "icon": Icons.admin_panel_settings,
//             "screen": const Permissionscreen(),
//             "prefix": "permission", // ✅ ADD
//           },
//         ],
//       },
//
//       {
//         "title": "Casting Management",
//         "icon": Icons.settings,
//         "items": [
//           {
//             "title": "Buch",
//             "icon": Icons.settings,
//             "screen": const Buchscreen(),
//             "prefix": "vacuum-buch",
//           },
//           {
//             "title": "Process",
//             "icon": Icons.settings,
//             "screen": const Processscreen(),
//             "prefix": "vacuum-process",
//           },
//           {
//             "title": "Vacuum Voucher",
//             "icon": Icons.settings,
//             "screen": const Voucherscreen(),
//             "prefix": "vacuum-voucher",
//           },
//           {
//             "title": "Casting Heating",
//             "icon": Icons.settings,
//             "screen": const Castingheatingscreen(),
//             "prefix": "casting-heating",
//           },
//           {
//             "title": "Casting Metal",
//             "icon": Icons.settings,
//             "screen": const Castingmetalscreen(),
//             "prefix": "casting-metal-issue",
//           },
//           {
//             "title": "Casting Receive",
//             "icon": Icons.settings,
//             "screen": const Castingrecivescreen(),
//             "prefix": "casting-release",
//           },
//           {
//             "title": "Tree Cutting Office",
//             "icon": Icons.settings,
//             "screen": const Treecuttingoffice(),
//             "prefix": "tree-cutting-office",
//           },
//           {
//             "title": "Tree Cutting Issue",
//             "icon": Icons.settings,
//             "screen": const Treecuttingissuescreen(),
//             "prefix": "tree-cutting-issue",
//           },
//           {
//             "title": "Tree Cutting Receive",
//             "icon": Icons.settings,
//             "screen": const Treecuttingreceivescreen(),
//             "prefix": "tree-cutting-receive",
//           },
//           {
//             "title": "Casting Sorting",
//             "icon": Icons.settings,
//             "screen": const Castingsortscreen(),
//             "prefix": "casting-sorting",
//           },
//         ],
//       },
//     ];
//
//     List<Map<String, dynamic>> filteredSections = sections
//         .map((section) {
//           List items = (section["items"] as List).where((item) {
//             String prefix = item["prefix"].toString();
//
//             /// 🔥 Same logic — view ya manage both check karo
//             return userPermissions.contains("$prefix-view") ||
//                 userPermissions.contains("$prefix-manage") ||
//                 userPermissions.contains("$prefix-create") ||
//                 userPermissions.contains("$prefix-edit") ||
//                 userPermissions.contains("$prefix-delete");
//           }).toList();
//
//           return {
//             "title": section["title"],
//             "icon": section["icon"],
//             "items": items,
//           };
//         })
//         .where((section) => (section["items"] as List).isNotEmpty)
//         .toList();
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setStateBottom) {
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.80,
//
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.background.withOpacity(0.9),
//                     AppColors.background.withOpacity(0.9),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
//               ),
//
//               child: Column(
//                 children: [
//                   const SizedBox(height: 14),
//
//                   Container(
//                     width: 60,
//                     height: 5,
//
//                     decoration: BoxDecoration(
//                       color: Colors.black,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   const Text(
//                     "Customize Dashboard",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   Expanded(
//                     child: ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//
//                       itemCount: filteredSections.length,
//
//                       itemBuilder: (context, sectionIndex) {
//                         final section =
//                             filteredSections[sectionIndex]; // ✅ FIXED
//
//                         return Container(
//                           margin: const EdgeInsets.only(bottom: 14),
//
//                           decoration: BoxDecoration(
//                             color: AppColors.background,
//                             border: Border.all(
//                               color: AppColors.border,
//                               width: 1.5,
//                             ),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//
//                           child: Theme(
//                             data: Theme.of(
//                               context,
//                             ).copyWith(dividerColor: Colors.transparent),
//
//                             child: ExpansionTile(
//                               tilePadding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 4,
//                               ),
//
//                               childrenPadding: const EdgeInsets.only(
//                                 left: 12,
//                                 right: 12,
//                                 bottom: 12,
//                               ),
//
//                               leading: Container(
//                                 padding: const EdgeInsets.all(10),
//
//                                 decoration: BoxDecoration(
//                                   color: AppColors.border,
//                                   border: Border.all(
//                                     color: AppColors.border,
//                                     width: 1.5,
//                                   ),
//                                   borderRadius: BorderRadius.circular(6),
//                                 ),
//
//                                 child: Icon(
//                                   section["icon"],
//                                   color: AppColors.iconBlue,
//                                 ),
//                               ),
//
//                               title: Text(
//                                 section["title"],
//
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 16,
//                                 ),
//                               ),
//
//                               iconColor: AppColors.iconBlue,
//                               collapsedIconColor: AppColors.textPrimary,
//
//                               children: List.generate(section["items"].length, (
//                                 index,
//                               ) {
//                                 final item = section["items"][index];
//
//                                 bool alreadyAdded = isBottomNavMode
//                                     ? bottomItems.any(
//                                         (e) => e["title"] == item["title"],
//                                       )
//                                     : dashboardItems.any(
//                                         (e) => e["title"] == item["title"],
//                                       );
//
//                                 return Container(
//                                   margin: const EdgeInsets.only(bottom: 10),
//
//                                   padding: const EdgeInsets.all(12),
//
//                                   decoration: BoxDecoration(
//                                     gradient: alreadyAdded
//                                         ? const LinearGradient(
//                                             colors: [
//                                               AppColors.border,
//                                               AppColors.border,
//                                             ],
//                                           )
//                                         : LinearGradient(
//                                             colors: [
//                                               AppColors.border,
//                                               AppColors.border,
//                                             ],
//                                           ),
//
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//
//                                   child: Row(
//                                     children: [
//                                       Container(
//                                         height: 45,
//                                         width: 45,
//
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                               AppColors.border.withOpacity(0.5),
//                                               AppColors.iconBlue.withOpacity(
//                                                 0.5,
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//
//                                         child: Icon(
//                                           item["icon"],
//                                           color: Colors.black,
//                                         ),
//                                       ),
//
//                                       const SizedBox(width: 14),
//
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//
//                                           children: [
//                                             Text(
//                                               item["title"],
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black
//                                                     : Colors.black,
//
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 4),
//
//                                             Text(
//                                               alreadyAdded
//                                                   ? "Added"
//                                                   : "Tap to add",
//
//                                               style: TextStyle(
//                                                 color: alreadyAdded
//                                                     ? Colors.black87
//                                                     : Colors.black87,
//
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//
//                                       InkWell(
//                                         onTap: () async {
//                                           if (isBottomNavMode) {
//                                             /// 🔥 BOTTOM NAV MODE — fakt bottomItems manipulate
//                                             if (alreadyAdded) {
//                                               setStateBottom(() {
//                                                 bottomItems.removeWhere(
//                                                   (e) =>
//                                                       e["title"] ==
//                                                       item["title"],
//                                                 );
//                                               });
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               int customCount =
//                                                   bottomItems.length - 2;
//
//                                               if (customCount >= 2) {
//                                                 Navigator.pop(context);
//                                                 Future.delayed(
//                                                   const Duration(
//                                                     milliseconds: 100,
//                                                   ),
//                                                   () {
//                                                     ScaffoldMessenger.of(
//                                                       context,
//                                                     ).showSnackBar(
//                                                       const SnackBar(
//                                                         content: Text(
//                                                           "Maximum 2 items can be added in bottom navigation",
//                                                         ),
//                                                       ),
//                                                     );
//                                                   },
//                                                 );
//                                                 return;
//                                               }
//
//                                               setStateBottom(() {
//                                                 bottomItems.insert(
//                                                   bottomItems.length - 1,
//                                                   {
//                                                     "title": item["title"],
//                                                     "icon": item["icon"],
//                                                     "screen": item["screen"],
//                                                   },
//                                                 );
//                                               });
//                                             }
//
//                                             await saveBottomNavItems();
//                                           } else {
//                                             /// 🔥 DASHBOARD MODE — dashboardItems manipulate (original logic)
//                                             if (alreadyAdded) {
//                                               dashboardItems.removeWhere(
//                                                 (e) =>
//                                                     e["title"] == item["title"],
//                                               );
//                                               bottomItems.removeWhere(
//                                                 (e) =>
//                                                     e["title"] == item["title"],
//                                               );
//
//                                               if (selectedIndex >=
//                                                   bottomItems.length) {
//                                                 selectedIndex =
//                                                     bottomItems.length - 1;
//                                               }
//                                             } else {
//                                               dashboardItems.add({
//                                                 ...item,
//                                                 "section": section["title"],
//                                               });
//                                             }
//
//                                             await saveDashboardItems();
//                                             await loadDashboardItems();
//                                           }
//
//                                           setStateBottom(() {});
//                                           setState(() {});
//                                         },
//
//                                         child: AnimatedContainer(
//                                           duration: const Duration(
//                                             milliseconds: 250,
//                                           ),
//
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 18,
//                                             vertical: 10,
//                                           ),
//
//                                           // decoration: BoxDecoration(
//                                           //
//                                           //   color: alreadyAdded
//                                           //       ? Colors.green
//                                           //       : null,
//                                           //
//                                           //
//                                           //
//                                           //   gradient: alreadyAdded
//                                           //       ? null
//                                           //       : const LinearGradient(
//                                           //     colors: [
//                                           //       Color(0xffE6C58A),
//                                           //       Color(0xffC8A96A),
//                                           //     ],
//                                           //   ),
//                                           //
//                                           //   borderRadius: BorderRadius.circular(12),
//                                           // ),
//                                           decoration: BoxDecoration(
//                                             gradient: LinearGradient(
//                                               colors: alreadyAdded
//                                                   ? [
//                                                       AppColors.iconBlue
//                                                           .withOpacity(0.5),
//                                                       //AppColors.border.withOpacity(0.5),
//                                                       AppColors.iconBlue
//                                                           .withOpacity(0.5),
//                                                     ]
//                                                   : const [
//                                                       Color(0xffE6C58A),
//                                                       Color(0xffC8A96A),
//                                                     ],
//                                             ),
//
//                                             borderRadius: BorderRadius.circular(
//                                               5,
//                                             ),
//                                           ),
//
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 alreadyAdded
//                                                     ? Icons.check
//                                                     : Icons.add,
//                                                 color: alreadyAdded
//                                                     ? Colors.white
//                                                     : Colors.black,
//                                                 size: 18,
//                                               ),
//
//                                               const SizedBox(width: 6),
//
//                                               Text(
//                                                 alreadyAdded ? "ADDED" : "ADD",
//
//                                                 style: TextStyle(
//                                                   color: alreadyAdded
//                                                       ? Colors.white
//                                                       : Colors.black,
//                                                   fontWeight: FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               }),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
//
//                     child: InkWell(
//                       onTap: () {
//                         Navigator.pop(context);
//                       },
//
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.primaryDark,
//                               AppColors.secondaryDark,
//                             ],
//                           ),
//
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//
//                         child: const Center(
//                           child: Text(
//                             "DONE",
//
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _onReorder(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) {
//         newIndex -= 1;
//       }
//       final String item = sectionOrder.removeAt(oldIndex);
//       sectionOrder.insert(newIndex, item);
//     });
//   }
//
//   String getSectionSubtitle(String sectionName) {
//     switch (sectionName) {
//       case "Sales":
//         return "Manage all sales activities";
//
//       case "Item Management":
//         return "Manage your inventory & items";
//
//       case "Others":
//         return "Other useful options";
//
//       case "JobWork Management":
//         return "Manage all job work activities";
//
//       case "Report Management":
//         return "Manage all Report activities";
//
//       case "Role Management":
//         return "Manage all Settings activities";
//
//       case "Casting Management":
//         return "Manage all Casting activities";
//
//       case "Management":
//         return "Manage all User activities";
//
//       default:
//         return "";
//     }
//   }
//
//   Widget optionItem(
//     IconData icon,
//     String title,
//     Color iconColor,
//     Color bgColor, {
//     VoidCallback? onTap, // 👈 ADD THIS
//   }) {
//     return InkWell(
//       onTap: onTap, // 👈 ADD THIS
//       borderRadius: BorderRadius.circular(10),
//       child: Column(
//         children: [
//           Container(
//             height: 45,
//             width: 45,
//             decoration: BoxDecoration(
//               color: bgColor,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: iconColor, size: 28),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//               color: Color(0xff14213D),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget metalRateMarquee() {
//     if (rates.isEmpty) {
//       return const SizedBox();
//     }
//
//     String text = "";
//
//     for (var item in rates) {
//       text +=
//           " ${item["symbol"]} (${item["city"]}) : ₹${item["formatted_rate"]}  |";
//     }
//
//     return Container(
//       height: 38,
//       margin: const EdgeInsets.symmetric(horizontal: 10),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xff8B3A3A), Color(0xffC59D5F)],
//         ),
//         borderRadius: BorderRadius.circular(6),
//       ),
//
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10),
//             child: const Icon(
//               Icons.currency_rupee,
//               color: Colors.white,
//               size: 18,
//             ),
//           ),
//
//           Expanded(
//             child: Marquee(
//               text: text,
//
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//
//               velocity: 45,
//
//               blankSpace: 70,
//
//               pauseAfterRound: const Duration(seconds: 2),
//
//               startPadding: 10,
//
//               scrollAxis: Axis.horizontal,
//
//               crossAxisAlignment: CrossAxisAlignment.center,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget buildStat(IconData icon, String title, String value) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         /// Icon Background
//         Container(
//           height: 30,
//           width: 30,
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(5),
//             border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
//           ),
//           child: Icon(icon, color: Colors.white, size: 16),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           value,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 13,
//           ),
//         ),
//
//         const SizedBox(height: 0),
//
//         Text(
//           title,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: Colors.white70, fontSize: 11),
//         ),
//       ],
//     );
//   }
//
//   Widget buildWelcomeSection() {
//     return Row(
//       children: [
//         // Container(
//         //   height: 45,
//         //   width: 45,
//         //   decoration: BoxDecoration(
//         //     color: Colors.white.withOpacity(.15),
//         //     shape: BoxShape.circle,
//         //     border: Border.all(color: Colors.white24),
//         //   ),
//         //   child: const Icon(
//         //     Icons.person,
//         //     color: Colors.white,
//         //     size: 24,
//         //   ),
//         // ),
//         const SizedBox(width: 12),
//
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Good Morning 👋",
//                 style: TextStyle(color: Colors.white70, fontSize: 13),
//               ),
//
//               const SizedBox(height: 2),
//
//               Text(
//                 "Welcome",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(.15),
//             borderRadius: BorderRadius.circular(5),
//           ),
//           child: const Text(
//             "Manager",
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget buildFirstRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.currency_rupee, "Sales", "₹0.00")),
//         Expanded(child: buildStat(Icons.trending_up, "Month Sales", "₹160")),
//         Expanded(child: buildStat(Icons.assignment_return, "Returns", "₹20")),
//         Expanded(child: buildStat(Icons.check_circle, "Complete", "25")),
//       ],
//     );
//   }
//
//   Widget buildSecondRowStats() {
//     return Row(
//       children: [
//         Expanded(child: buildStat(Icons.approval, "Approvals", "12")),
//         Expanded(child: buildStat(Icons.pending_actions, "Pending", "08")),
//         Expanded(child: buildStat(Icons.local_offer, "Labels", "41")),
//         Expanded(child: buildStat(Icons.people, "Users", "4 / 8")),
//       ],
//     );
//   }
//
//   Future<void> loadExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? saved = prefs.getString("expanded_sections");
//
//     if (saved != null && saved.isNotEmpty) {
//       List<String> openSections = saved.split(",");
//
//       setState(() {
//         // 🔥 Fakt PEHLO section j open rakho (accordion rule)
//         String? firstOpen = openSections.isNotEmpty ? openSections.first : null;
//         expandedSections = {};
//         if (firstOpen != null) {
//           expandedSections[firstOpen] = true;
//         }
//       });
//     }
//   }
//
//   Future<void> saveExpandedSections() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // 🔥 Fakt PEHLO open section j save karo (max 1)
//     List<String> openSections = expandedSections.entries
//         .where((e) => e.value == true)
//         .map((e) => e.key)
//         .toList();
//
//     await prefs.setString("expanded_sections", openSections.join(","));
//   }
//
//   Future<void> saveSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setStringList("section_order", sectionOrder);
//   }
//
//   Future<void> loadSectionOrder() async {
//     final prefs = await SharedPreferences.getInstance();
//     final saved = prefs.getStringList("section_order");
//
//     if (saved != null && saved.isNotEmpty) {
//       setState(() {
//         // 🔥 Saved order set karo (agar navi sections hoy to pachi automatically add thai jashe _updateSectionOrderForNewItems() thi)
//         sectionOrder = saved;
//       });
//     }
//   }
// }


import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:pecifician_sysytem/Approval/ApprovalreturnScreen.dart';
import 'package:pecifician_sysytem/Approval/Recive_return_purchase.dart';
import 'package:pecifician_sysytem/Dashboard/DiamondReportsUI.dart';
import 'package:pecifician_sysytem/Dashboard/PremiumScannerScreen.dart';
import 'package:pecifician_sysytem/Job%20Work/JobWork%20Receive/JobworkReceiveScreen.dart';
import 'package:pecifician_sysytem/QR%20Making/AddQrScreen.dart';
import 'package:pecifician_sysytem/QR%20Making/QrListScreen.dart';
import 'package:pecifician_sysytem/Reports/ApprovalReturnRegisterScreen.dart';
import 'package:pecifician_sysytem/Reports/ApprovalSummaryScreen.dart';
import 'package:pecifician_sysytem/Reports/OutStandingAmount.dart';
import 'package:pecifician_sysytem/Reports/WorkerLossReportScreen.dart';
import 'package:pecifician_sysytem/Sell_estimate/SellScreen.dart';
import 'package:pecifician_sysytem/Sell_estimate/Sell_list.dart';
import 'package:pecifician_sysytem/Sell_estimate/Sell_list_screen.dart';
import 'package:pecifician_sysytem/Sell_estimate/Sell_return_Screen.dart';
import 'package:pecifician_sysytem/User/CategoryScreen.dart';
import 'package:pecifician_sysytem/User/CreateCustomer.dart';
import 'package:pecifician_sysytem/User/OfficeAccessSettingsScreen.dart';
import 'package:pecifician_sysytem/User/UserScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
import 'package:pecifician_sysytem/Vacuum/Voucher/VoucherScreen.dart';
import 'package:pecifician_sysytem/Visiting%20Card/Visitingcard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Approval/ApproveListScreen.dart';
import '../Approval/ReceivevoucharScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/GlobalDrawer.dart';
import '../Extra/NotificationProvider.dart';
import '../Settings/LiveMetalRatesScreen.dart';
import '../Settings/SettingsScreen.dart';
import '../Item_Mangement/Item/ItemScreen.dart';
import '../Item_Mangement/Label Print/Label_print_Screen.dart';
import '../Item_Mangement/Label/LabelScreen.dart';
import '../Item_Mangement/Label_Items/label_item_screen.dart';
import '../Item_Mangement/Others/Othersscreen.dart';
import '../Job Work/Job Work Issue/Jobwork_issue_Screen.dart';
import '../Job Work/Job Worker/JobWorkerScreen.dart';
import '../Job Work/Labour_Formula/Job_labourformula_Screen.dart';
import '../Job Work/Production_Costs/ProductionCost.dart';
import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
import '../Notification/NotificationScreen.dart';
import '../Reports/ApprovalOutstandingReport.dart';
import '../Reports/BarcodeHistory.dart';
import '../Reports/PurchaseReciverSummary.dart';
import '../Reports/SaleSumryReport.dart';
import '../Reports/StockPositionReport.dart';
import '../Role & Permission/PermissionScreen.dart';
import '../Role & Permission/RoleScreen.dart';
import '../Splash/LoginScreen.dart';
import '../User/CustomerScreen.dart';
import '../Vacuum/Casting/CastingHeatingScreen.dart';
import '../Vacuum/Casting_Metal/CastingMetalScreen.dart';
import '../Vacuum/Casting_Recive/CastingReciveScreen.dart';
import '../Vacuum/Casting_Sort/CastingSortScreen.dart';
import '../Vacuum/Tree_Cutting_Issue/TreeCuttingIssueScreen.dart';
import '../Vacuum/Tree_Cutting_Office/TreeCuttingOffice.dart';
import '../Vacuum/Tree_Cutting_Recive/TreeCuttingReceiveScreen.dart';
import '../Vacuum/Vacuum Process/ProcessScreen.dart';
import '../Vacuum/Vouchar History/VoucharHistoryScreen.dart';
import 'InventoryScreen.dart';
// 🔑 TODO: tamara Login screen nu sachu path / class naam muko

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int selectedIndex = 0;
  List<String> sectionOrder = [];
  List<String> userRoleNames = [];
  List<String> userPermissions = []; // ✅ aa hovu joiye
  List<Map<String, dynamic>> bottomItems = [
    {"title": "Dashboard", "icon": Icons.dashboard_outlined},

    {"title": "More", "icon": Icons.more_horiz},
  ];
  List rates = [];
  String source = "";
  String updatedAt = "";
  Timer? autoRefreshTimer;
  String? activeSection;
  Map<String, double> _previousRateValues = {};
  Map<String, Color> _rateColors = {};
  /// ============================================================
  /// 🔥 PLAN ALERT POPUP GUARD
  ///
  /// Ek j session ma popup vaar-vaar na khule (dar vaar getCompanyProfile
  /// call thay tyare) — matra jyare tak user e already dekhi na hoy.
  /// Jo tame har vaar j dekhadvu hoy to aa flag hatavi shakay.
  /// ============================================================
  bool _planAlertShown = false;

  /// ============================================================
  /// 🔥 TRIAL BADGE + PLAN EXPIRE (appbar ma "Trial • N days")
  /// ============================================================
  bool _isTrialPlan = false; // company.plan == "trial"
  DateTime? _planExpiresAt; // trial_countdown.expires_at / plan_expires_at
  int _planDaysRemaining = 0; // API no plan_days_remaining (fallback)
  bool _planExpired = false;
  bool _expiredPopupOpen = false; // expire popup ek j vaar khule
  Timer? _planTimer; // dar minute badge update + expire check

  Future<void> moveSectionToTopAndOpen(String sectionName) async {
    // if (!mounted) return;

    setState(() {
      activeSection = sectionName;

      /// Section top par
      sectionOrder.remove(sectionName);
      sectionOrder.insert(0, sectionName);

      /// Badha close
      for (final key in sectionOrder) {
        expandedSections[key] = false;
      }

      /// Current section open
      expandedSections[sectionName] = true;
    });

    /// Persist
    await saveSectionOrder();
    await saveExpandedSections();
  }

  /// ============================================================
  /// 🔥 CHECK IF CURRENT USER IS ADMIN
  ///
  /// SharedPreferences ma save thayela "user_role_names" check kare che.
  /// Fallback tarike current in-memory `userRoleNames` list vaparay che.
  /// ============================================================
  Future<bool> _isAdminRole() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> savedRoles =
        prefs.getStringList("user_role_names") ?? [];

    final List<String> roles = savedRoles.isNotEmpty
        ? savedRoles
        : userRoleNames;

    return roles.any(
          (r) =>
      r.toLowerCase().trim() == "admin" ||
          r.toLowerCase().trim().contains("admin"),
    );
  }

  Future<void> loadRates({bool silent = false}) async {
    try {
      /// ============================================
      /// 🔥 ADMIN CHECK — Default lat/long use karva mate
      /// ============================================
      final bool isAdmin = await _isAdminRole();

      String latitude = "";
      String longitude = "";

      if (isAdmin) {
        /// ============================================
        /// 🔥 ADMIN — Fixed default coordinates
        /// ============================================
        latitude = "23.0492348";
        longitude = "72.5800721";

        debugPrint("======================================");
        debugPrint("🔥 ADMIN ROLE — Using default location");
        debugPrint("Latitude  => $latitude");
        debugPrint("Longitude => $longitude");
        debugPrint("======================================");
      } else {
        /// ============================================
        /// 1. LOCATION SERVICE CHECK
        ///
        /// 🔥 IMPORTANT: Service bandh hoy to pan
        /// return NA karvanu — API call thavi j joie,
        /// fakt lat/long empty rehse.
        /// ============================================
        try {
          final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

          if (!serviceEnabled) {
            debugPrint("⚠️ Location service disabled — proceeding without lat/long");

            if (!silent && mounted) {
              AppMessage.error(context, "Please enable location service.");
            }
          } else {
            /// ============================================
            /// 2. LOCATION PERMISSION CHECK
            /// ============================================
            LocationPermission permission = await Geolocator.checkPermission();

            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }

            if (permission == LocationPermission.denied) {
              debugPrint("⚠️ Location permission denied — proceeding without lat/long");

              if (!silent && mounted) {
                AppMessage.error(context, "Location permission is required.");
              }
            } else if (permission == LocationPermission.deniedForever) {
              debugPrint(
                "⚠️ Location permission permanently denied — proceeding without lat/long",
              );

              if (!silent && mounted) {
                AppMessage.error(
                  context,
                  "Location permission is permanently denied.",
                );
              }
            } else {
              /// ============================================
              /// 3. GET CURRENT LOCATION
              /// ============================================
              final Position position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                ),
              );

              latitude = position.latitude.toString();
              longitude = position.longitude.toString();

              debugPrint("======================================");
              debugPrint("📍 CURRENT LOCATION");
              debugPrint("Latitude  => $latitude");
              debugPrint("Longitude => $longitude");
            }
          }
        } catch (e) {
          /// 🔥 Location related koi pan error aave to pan
          /// aagad vadho (API call j thavi joie)
          debugPrint("❌ Location Error => $e — proceeding without lat/long");
        }
      }

      /// ============================================
      /// 4. GET DEVICE ID
      /// ============================================
      String deviceId = "";
      String deviceName = "";

      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

        if (Platform.isAndroid) {
          final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
          deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
        } else if (Platform.isIOS) {
          final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? "";
          deviceName = iosInfo.name;
        }
      } catch (e) {
        debugPrint("❌ Device ID Error => $e");
        deviceId = "";
      }

      debugPrint("📱 Device ID => $deviceId");
      debugPrint("======================================");

      /// ============================================
      /// 5. CREATE QUERY PARAMETERS
      /// ============================================
      final Map<String, dynamic> queryParameters = {
        "latitude": latitude,
        "longitude": longitude,
        "device_id": deviceId,
      };

      debugPrint("📤 LIVE RATE QUERY => $queryParameters");

      /// ============================================
      /// 6. API CALL — Location hoy ke na hoy, always thavi joie
      /// ============================================
      final response = await ApiHelper().getRequestWithQuery(
        ApiConstants.live_metal_rates,
        queryParameters: queryParameters,
        showLoading: false,
      );

      debugPrint("======================================");
      debugPrint("📥 LIVE RATE RESPONSE");
      debugPrint("Status => ${response?.statusCode}");
      debugPrint("Data => ${response?.data}");
      debugPrint("======================================");

      if (response == null) {
        if (!silent && mounted) {
          AppMessage.error(context, "No response from server.");
        }
        return;
      }

      if (response.statusCode == 200 && response.data["success"] == true) {
        final data = response.data;
        if (!mounted) return;

        setState(() {
          final List newRates = data["data"] ?? [];

          /// 🔥 Color compare karva mate rates update karta
          /// PEHLA j call karvanu
          _updateRateColors(newRates);

          rates = newRates;

          source = data["source"]?.toString() ?? "";

          updatedAt = data["updated_at"]?.toString() ?? "";
        });

        await loadSelectedRate();
        return;
      }

      String message = "Failed to load live rates";
      final dynamic responseData = response.data;

      if (responseData is Map && responseData["message"] != null) {
        message = responseData["message"].toString();
      }

      debugPrint("❌ API MESSAGE => $message");

      if (!silent && mounted) {
        AppMessage.error(context, message);
      }
    } catch (e) {
      debugPrint("======================================");
      debugPrint("❌ LOAD RATES ERROR => $e");
      debugPrint("======================================");

      if (!silent && mounted) {
        AppMessage.error(context, "Failed to load live rates");
      }
    }
  }

  Map<String, bool> expandedSections = {};
  int? expandedIndex;
  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return "Good Morning 👋";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon ☀️";
    } else if (hour >= 17 && hour < 21) {
      return "Good Evening 🌇";
    } else {
      return "Good Night 🌙";
    }
  }

  String selectedSymbol = "GOLD";
  Map<String, dynamic>? selectedRate;
  List<Map<String, dynamic>> allMenuItems = [
    {
      "title": "Person",
      "icon": Icons.person_add,
      "module": "customer",
      "screen": const Customerscreen(),
      "section": "Management",
      "prefix": "person",
    },
    {
      "title": "Users",
      "icon": Icons.people,
      "module": "user",
      "screen": const Userscreen(),
      "section": "Management",
      "prefix": "user",
    },
    {
      "title": "Category",
      "icon": Icons.people,
      "module": "category",
      "screen": const Categoryscreen(),
      "section": "Management",
      "prefix": "category-person",
    },
    {
      "title": "Office Access",
      "icon": Icons.people,
      "module": "category",
      "screen": const OfficeAccessSettingsScreen(),
      "section": "Management",
      "prefix": "office-access",
    },
    {
      "title": "Sales Estimate",
      "icon": Icons.sell,
      "module": "sale",
      "screen": const SellList(),
      "section": "Sales",
      "prefix": "sale",
    },
    {
      "title": "Sale on Approvals",
      "icon": Icons.qr_code,
      "module": "approval",
      "screen": const InvoiceScreen(),
      "section": "Sales",
      "prefix": "approval", // ✅ "view" hatavi nakhyu
    },
    {
      "title": "Approval Return",
      "icon": Icons.sell,
      "module": "approval_return",
      "screen": const Approvalreturnscreen(),
      "section": "Sales",
      "prefix": "approval-return",
    },
    {
      "title": "Rec-Ret-Purchase",
      "icon": Icons.sell,
      "module": "sale_advance",
      "screen": const Receivevoucharscreen(),
      "section": "Sales",
      "prefix": "sale-advance",
    },
    // {
    //   "title": "Reports",
    //   "icon": Icons.bar_chart,
    //   "screen": const DiamondReportsFullUI(),
    //   "section": "Reports & Tools",
    //   "prefix": "reports",
    // },
    // {
    //   "title": "Scanner",
    //   "icon": Icons.qr_code_scanner,
    //   "screen": const PremiumScannerScreen(),
    //   "section": "Reports & Tools",
    //   "prefix": "scanner",
    // },
    {
      "title": "Item List",
      "icon": Icons.add_box,
      "module": "item",
      "screen": const Itemscreen(),
      "section": "Item Management",
      "prefix": "item",
    },
    {
      "title": "Label Config",
      "icon": Icons.production_quantity_limits,
      "module": "label_config",
      "screen": const Labelscreen(),
      "section": "Item Management",
      "prefix": "label-config",
    },
    {
      "title": "Label Items",
      "icon": Icons.label_important_outlined,
      "module": "item_set",
      "screen": const label_item_screen(),
      "section": "Item Management",
      "prefix": "item-set",
    },
    {
      "title": "Label Printing",
      "icon": Icons.print,
      "screen": const LabelPrintScreen(),
      "section": "Item Management",
      "prefix": "label-print",
    },
    {
      "title": "Other Charges",
      "icon": Icons.settings_applications,
      "module": "other_charge",
      "screen": const Othersscreen(),
      "section": "Item Management",
      "prefix": "other-charge",
    },
    {
      "title": "Labour Formula",
      "icon": Icons.add_box,
      "module": "labour_formula",
      "screen": const JobLabourformulaScreen(),
      "section": "JobWork Management",
      "prefix": "labour-formula",
    },
    {
      "title": "Production Cost",
      "icon": Icons.production_quantity_limits,
      "module": "production_cost",
      "screen": const Productioncost(),
      "section": "JobWork Management",
      "prefix": "production-cost",
    },
    {
      "title": "Production Step",
      "icon": Icons.label_important_outlined,
      "module": "production_step",
      "screen": const Prooductionstepscreen(),
      "section": "JobWork Management",
      "prefix": "production-step",
    },
    // {
    //   "title": "Job Worker",
    //   "icon": Icons.print,
    //   "module": "job_worker",
    //   "screen": const Jobworkerscreen(),
    //   "section": "JobWork Management",
    //   "prefix": "job-worker",
    // },
    {
      "title": "Jobwork Issue",
      "icon": Icons.settings_applications,
      "module": "jobwork_issue",
      "screen": const JobworkIssueScreen(),
      "section": "JobWork Management",
      "prefix": "jobwork-issue",
    },
    {
      "title": "Jobwork Receive",
      "icon": Icons.settings_applications,
      "module": "jobwork_receive",
      "screen": const Jobworkreceivescreen(),
      "section": "JobWork Management",
      "prefix": "jobwork-receive",
    },
    {
      "title": "Sales Summary",
      "icon": Icons.add_box,
      "screen": const Salesumryreport(),
      "section": "Report Management",
      "prefix": "report-sales-summary",
    },
    {
      "title": "Receiver Summary",
      "icon": Icons.production_quantity_limits,
      "screen": const Purchasereciversummary(),
      "section": "Report Management",
      "prefix": "report-purchase-receiver-summary",
    },
    {
      "title": "Stock Position",
      "icon": Icons.label_important_outlined,
      "screen": const Stockpositionreport(),
      "section": "Report Management",
      "prefix": "report-stock-position",
    },
    {
      "title": "Approval Outstanding",
      "icon": Icons.print,
      "screen": const Approvaloutstandingreport(),
      "section": "Report Management",
      "prefix": "report-approval-outstanding",
    },
    {
      "title": "Barcode History",
      "icon": Icons.settings_applications,
      "screen": const Barcodehistory(),
      "section": "Report Management",
      "prefix": "report-barcode-history",
    },
    {
      "title": "Outstanding Amount",
      "icon": Icons.settings_applications,
      "screen": const Outstandingamount(),
      "section": "Report Management",
      "prefix": "report-outstanding-amount",
    },
    {
      "title": "Worker Loss",
      "icon": Icons.settings_applications,
      "screen": const WorkerLossReportScreen(),
      "section": "Report Management",
      "prefix": "report-worker-loss",
    },
    {
      "title": "Approval Summary",
      "icon": Icons.settings_applications,
      "screen": const ApprovalSummaryScreen(),
      "section": "Report Management",
      "prefix": "report-worker-loss",
    },
    {
      "title": "Approval Register",
      "icon": Icons.settings_applications,
      "screen": const ApprovalReturnRegisterScreen(),
      "section": "Report Management",
      "prefix": "report-worker-loss",
    },
    {
      "title": "Roles",
      "icon": Icons.admin_panel_settings,
      "screen": const Rolescreen(),
      "section": "Role Management",
      "prefix": "role",
    },
    {
      "title": "Permissions",
      "icon": Icons.admin_panel_settings,
      "screen": const Permissionscreen(),
      "section": "Role Management",
      "prefix": "permission",
    },
    {
      "title": "Buch",
      "icon": Icons.settings,
      "module": "vacuum_buch",
      "screen": const Buchscreen(),
      "section": "Casting Management",
      "prefix": "vacuum-buch",
    },
    {
      "title": "Process",
      "icon": Icons.settings,
      "module": "vacuum_process",
      "screen": const Processscreen(),
      "section": "Casting Management",
      "prefix": "vacuum-process",
    },
    {
      "title": "Vacuum Voucher",
      "icon": Icons.settings,
      "module": "vacuum_voucher",
      "screen": const Voucherscreen(),
      "section": "Casting Management",
      "prefix": "vacuum-voucher",
    },
    {
      "title": "Casting Heating",
      "icon": Icons.settings,
      "module": "casting_heating",
      "screen": const Castingheatingscreen(),
      "section": "Casting Management",
      "prefix": "casting-heating",
    },
    {
      "title": "Casting Metal",
      "icon": Icons.settings,
      "module": "casting_metal_issue",
      "screen": const Castingmetalscreen(),
      "section": "Casting Management",
      "prefix": "casting-metal-issue",
    },
    {
      "title": "Casting Receive",
      "icon": Icons.settings,
      "module": "casting_release",
      "screen": const Castingrecivescreen(),
      "section": "Casting Management",
      "prefix": "casting-release",
    },
    {
      "title": "Tree Cutting Office",
      "icon": Icons.settings,
      "module": "tree_cutting_office",
      "screen": const Treecuttingoffice(),
      "section": "Casting Management",
      "prefix": "tree-cutting-office",
    },
    {
      "title": "Tree Cutting Issue",
      "icon": Icons.settings,
      "module": "tree_cutting_issue",
      "screen": const Treecuttingissuescreen(),
      "section": "Casting Management",
      "prefix": "tree-cutting-issue",
    },
    {
      "title": "Tree Cutting Receive",
      "icon": Icons.settings,
      "module": "tree_cutting_receive",
      "screen": const Treecuttingreceivescreen(),
      "section": "Casting Management",
      "prefix": "tree-cutting-receive",
    },
    {
      "title": "Casting Sorting",
      "icon": Icons.settings,
      "module": "casting_sorting",
      "screen": const Castingsortscreen(),
      "section": "Casting Management",
      "prefix": "casting-sorting",
    },

    {
      "title": "Voucher History",
      "icon": Icons.settings,
      "module": "voucher-history",
      "screen": const VoucherProcessHistoryScreen(),
      "section": "Casting Management",
      "prefix": "voucher-history",
    },
  ];

  /// 🔥 DASHBOARD SELECTED ITEMS
  List<Map<String, dynamic>> dashboardItems = [];
  String name = "";
  String email = "";
  String companyName = "";
  String State = "";
  String City = "";
  String Role = "";
  String companyLogo = "";

  // ============================================================
  // 🔔 NOTIFICATION COUNT — card ke bell, game tya thi read thay,
  // Home par pachha aavta BANNE jagya e count jato rahe
  // ============================================================

  /// Card par click karela module — count turant 0 (card + bell banne ma).
  /// static etle HomeScreen navi bane (pushReplacement) to pan yaad rahe.
  /// Server count 0 aave pachhi set mathi nikli jay → navi notification dekhay.
  static final Set<String> _readModules = {};

  /// Card no count
  int _visibleCount(String module, int serverCount) {
    if (module.isEmpty || !_readModules.contains(module)) return serverCount;
    if (serverCount == 0) _readModules.remove(module);
    return 0;
  }

  /// Bell no total — click karela module no count minus
  int _visibleTotal(NotificationProvider provider) {
    int hidden = 0;
    for (final m in _readModules) {
      hidden += provider.moduleCount(m);
    }
    final int t = provider.total - hidden;
    return t < 0 ? 0 : t;
  }

  /// Count server mathi farithi — turant + thodi var pachhi bijivar
  /// (read API ane back thavanu ek sathe thay to pan sacho count aave)
  void _refreshNotificationCount() {
    if (!mounted) return;
    context.read<NotificationProvider>().loadNotificationCount();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      context.read<NotificationProvider>().loadNotificationCount();
      setState(() {});
    });
  }

  Future<bool> readModule(String module) async {
    try {
      final response = await ApiHelper().postRequest(
        "${ApiConstants.baseUrl}notifications/read-module",
        {"module": module},
      );

      print("Read Module Response : ${response?.data}");

      return response != null &&
          response.statusCode == 200 &&
          response.data["success"] == true;
    } catch (e) {
      print("Read Module Error : $e");
      return false;
    }
  }

  @override
  void dispose() {
    _planTimer?.cancel();
    autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    loadExpandedSections(); // 👈 ADD THIS
    loadSectionOrder(); // 👈 ADD THIS
    loadSelectedRate();
    getCompanyProfile();
    /// 🔥 Auto refresh every 30 seconds
    // autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    //   loadRates(silent: true);
    // });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Home navi bane (page mathi back) tyare pan sacho count
      _refreshNotificationCount();
    });

    /// 🔥 IMPORTANT: getCompanyProfile() have role load thai gaya pachi
    /// j loadRates() call kare che (andar), etle e ne j direct call karo.
    /// loadRates() ne ahi thi direct call NA karo — nahi to role khali
    /// hova thi admin check khoto padi shake ane location popup fasi jay.


    //updateSectionOrder();
    /// 🔥 DEFAULT DASHBOARD ITEMS
    loadDashboardItems();
    loadBottomNavItems(); // 🔥 ADD
  }

  Future<void> loadSelectedRate() async {
    final prefs = await SharedPreferences.getInstance();

    selectedSymbol = prefs.getString("selected_rate_symbol") ?? "GOLD";

    updateSelectedRate();

    if (mounted) {
      setState(() {});
    }
  }

  void updateSelectedRate() {
    if (rates.isEmpty) return;

    try {
      selectedRate = rates.firstWhere((e) => e["symbol"] == selectedSymbol);
    } catch (e) {
      selectedRate = rates.first;
    }
  }

  /// ============================================================
  /// 🔥 Raw numeric rate kadhva mate
  ///
  /// "formatted_rate" ma comma (,) ke ₹ symbol hoy to pan
  /// clean double value male e mate.
  /// ============================================================
  double? _parseRateValue(dynamic item) {
    final dynamic raw = item["rate"] ?? item["formatted_rate"];
    if (raw == null) return null;

    final String cleaned = raw
        .toString()
        .replaceAll(",", "")
        .replaceAll("₹", "")
        .trim();

    return double.tryParse(cleaned);
  }

  /// ============================================================
  /// 🔥 Naya rates aavya pachi dareek symbol nu color update karo
  ///
  /// - Rate vadhyu  → Green
  /// - Rate ghatyu  → Red
  /// - Same rahyu   → Pehla no color j rakho (change nathi karvanu)
  ///
  /// IMPORTANT: Aa function ne `rates` variable update karta
  /// PEHLA call karvanu, nahi to old vs new compare kai nahi thashe.
  /// ============================================================
  void _updateRateColors(List newRatesList) {
    for (var item in newRatesList) {
      final String symbol = item["symbol"]?.toString() ?? "";
      if (symbol.isEmpty) continue;

      final double? newRate = _parseRateValue(item);
      if (newRate == null) continue;

      if (_previousRateValues.containsKey(symbol)) {
        final double oldRate = _previousRateValues[symbol]!;

        if (newRate > oldRate) {
          _rateColors[symbol] = const Color(0xff2ECC71); // 🟢 Green
        } else if (newRate < oldRate) {
          _rateColors[symbol] = const Color(0xffE53935); // 🔴 Red
        }
        // Equal hoy to jado color j rahese
      }

      _previousRateValues[symbol] = newRate;
    }
  }

  Future<void> loadBottomNavItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTitles = prefs.getStringList("bottom_nav_items");

    List<Map<String, dynamic>> customItems = [];

    if (savedTitles != null && savedTitles.isNotEmpty) {
      for (var title in savedTitles) {
        var match = allMenuItems.firstWhere(
              (e) => e["title"] == title,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          customItems.add({
            "title": match["title"],
            "icon": match["icon"],
            "screen": match["screen"],
          });
        }
      }
    }

    setState(() {
      bottomItems = [
        {"title": "Dashboard", "icon": Icons.dashboard_outlined},
        ...customItems,
        {"title": "More", "icon": Icons.more_horiz},
      ];
    });
  }

  Future<void> saveBottomNavItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> titles = bottomItems
        .where((e) => e["title"] != "Dashboard" && e["title"] != "More")
        .map((e) => e["title"].toString())
        .toList();

    await prefs.setStringList("bottom_nav_items", titles);
  }

  void updateSectionOrder(
      Map<String, List<Map<String, dynamic>>> groupedItems,
      ) {
    // Naya section keys (jaisi "Others") ne add karo jo already sectionOrder ma nathi
    for (var key in groupedItems.keys) {
      if (!sectionOrder.contains(key)) {
        sectionOrder.add(key);
      }
    }

    // Je sections have exist nathi karta groupedItems ma, ene sectionOrder thi remove karo
    sectionOrder.removeWhere((s) => !groupedItems.containsKey(s));
  }

  Future<void> loadDashboardItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> excludedTitles =
        prefs.getStringList("excluded_dashboard_items") ?? [];

    /// 🔥 Have allMenuItems (je already permission pramane filtered che)
    /// ma thi j dashboard items lese — jetli pan API permission hoy e badha
    /// automatic dashboard par dekhashe (jo user e manually remove na karyu hoy to)
    List<Map<String, dynamic>> tempItems = allMenuItems
        .where((item) => !excludedTitles.contains(item["title"]))
        .toList();

    setState(() {
      dashboardItems = tempItems;
      _updateSectionOrderForNewItems();
    });
  }

  Future<void> saveDashboardItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    /// 🔥 jetla items allMenuItems ma che pan dashboardItems ma nathi
    /// (user e remove karya che), e excluded list ma save karo
    List<String> excludedTitles = allMenuItems
        .where((m) => !dashboardItems.any((d) => d["title"] == m["title"]))
        .map((e) => e["title"].toString())
        .toList();

    await prefs.setStringList("excluded_dashboard_items", excludedTitles);

    /// (Optional) jo old key "dashboard_items" use thato hoy biji jagya pan,
    /// e clear/remove kari shako ke rehva dyo, have e use nathi thato
  }

  // એક હેલ્પર ફંક્શન સેક્શન ઓર્ડર મેન્ટેન કરવા માટે
  void _updateSectionOrderForNewItems() {
    final Map<String, List<Map<String, dynamic>>> tempGrouped = {};

    for (final item in dashboardItems) {
      final String section = item["section"] ?? "Others";

      tempGrouped.putIfAbsent(section, () => []);
      tempGrouped[section]!.add(item);
    }

    final List<String> newOrder = [];

    /// =========================================
    /// CURRENT ACTIVE SECTION ALWAYS FIRST
    /// =========================================
    if (activeSection != null && tempGrouped.containsKey(activeSection)) {
      newOrder.add(activeSection!);
    }

    /// =========================================
    /// OLD ORDER MAINTAIN
    /// =========================================
    for (final section in sectionOrder) {
      if (tempGrouped.containsKey(section) && !newOrder.contains(section)) {
        newOrder.add(section);
      }
    }

    /// =========================================
    /// NEW SECTIONS ADD
    /// =========================================
    for (final section in tempGrouped.keys) {
      if (!newOrder.contains(section)) {
        newOrder.add(section);
      }
    }

    if (!mounted) return;

    setState(() {
      sectionOrder = newOrder;

      /// Active section open
      if (activeSection != null) {
        for (final section in sectionOrder) {
          expandedSections[section] = section == activeSection;
        }
      }
    });
  }

  Future<void> getCompanyProfile() async {
    try {
      final response = await ApiHelper().getRequest(ApiConstants.userProfile);

      if (response == null) {
        print("❌ No response — default dashboard load karo");
        await loadDashboardItems();

        /// 🔥 Profile na male to pan rates load karvo padse (role
        /// khabar nathi etle _isAdminRole() SharedPreferences mathi
        /// old saved role check karshe, jo pehla login karyu hoy).
        await loadRates(silent: true);
        return;
      }

      if (response.statusCode == 200) {
        final jsonData = response.data;
        final userData = jsonData["data"] ?? {};
        final companyData = userData["company"] ?? {};

        // ============================================================
        // PROFILE DATA
        // ============================================================

        final profileData = userData["profile"] ?? {};

        // ============================================================
        // PERMISSIONS
        // ============================================================

        final List permissionsRaw =
            profileData["permissions"] ?? jsonData["permissions"] ?? [];

        final List<String> permissions = permissionsRaw
            .map((e) => e.toString())
            .toList();

        // ============================================================
        // ROLE NAMES
        // ============================================================

        final List roleNamesRaw = profileData["role_names"] ?? [];

        final List<String> roleNames = roleNamesRaw
            .map((e) => e.toString())
            .toList();

        print("✅ User Permissions: $permissions");
        print("✅ User Role Names: $roleNames");

        SharedPreferences prefs = await SharedPreferences.getInstance();

        setState(() {
          name = userData["name"]?.toString() ?? "-";
          email = userData["email"]?.toString() ?? "-";
          companyName = companyData["name"]?.toString() ?? "-";
          City = companyData["city"]?.toString() ?? "-";
          State = companyData["state"]?.toString() ?? "-";
          companyLogo= companyData["company_logo_url"]?.toString() ?? "-";

          // Save permissions
          userPermissions = permissions;

          // Save role names
          userRoleNames = roleNames;

          // Permission filtering
          filterMenuByPermission();
        });

        // ============================================================
        // SAVE USER DATA
        // ============================================================

        await prefs.setString("name", userData["name"]?.toString() ?? "-");

        await prefs.setString("email", userData["email"]?.toString() ?? "-");

        await prefs.setString(
          "companyName",
          companyData["name"]?.toString() ?? "-",
        );

        await prefs.setString("city", companyData["city"]?.toString() ?? "-");

        await prefs.setString(
          "state",
          companyData["state"]?.toString() ?? "-",
        );

        await prefs.setString("companyLogo", companyData["company_logo_url"]?.toString() ?? "-");
        await prefs.setString("role", userData["role"]?.toString() ?? "-");

        await prefs.setStringList("user_permissions", userPermissions);

        await prefs.setStringList("user_role_names", userRoleNames);

        // ============================================================
        // LOAD DASHBOARD
        // ============================================================

        await loadDashboardItems();

        /// 🔥 IMPORTANT: role (userRoleNames) have set thai gayu che,
        /// etle have j loadRates() call karo — jethi admin role hoy
        /// to location popup skip thay, first-time login par pan.
        await loadRates(silent: true);

        // ============================================================
        // 🔥 PLAN ALERT POPUP
        //
        // company["plan_alert"]["show_popup"] == true hoy to j popup
        // dekhadvanu. Frame render thai gaya pachi j dialog kholvi
        // jaruri che, nahi to context still-building error aave.
        // ============================================================

        _applyPlanInfo(jsonData);
      } else {
        // 🔥 Plan expire hoy to server 401/403 sathe plan_alert mokli shake
        if (response.data is Map) _applyPlanInfo(response.data as Map);

        // API fail
        await loadDashboardItems();

        /// 🔥 Profile fail thay to pan rates load karvo padse —
        /// role SharedPreferences mathi (jo pehla save thayu hoy to) male.
        await loadRates(silent: true);
      }
    } catch (e) {
      print("❌ Exception: $e");

      // Exception aave to default dashboard load
      await loadDashboardItems();

      /// 🔥 Exception case ma pan rates load karo.
      await loadRates(silent: true);
    }
  }

  /// ============================================================
  /// 🔥 PLAN INFO (trial badge + expire popup)
  ///
  /// Response ma company 3 jagya e aave chhe:
  ///   data.company / profile.company / company (top level)
  /// ============================================================
  void _applyPlanInfo(Map jsonData) {
    try {
      final dynamic data = jsonData["data"];
      Map company = {};
      if (data is Map && data["company"] is Map) {
        company = data["company"];
      } else if (jsonData["company"] is Map) {
        company = jsonData["company"];
      } else if (jsonData["profile"] is Map &&
          jsonData["profile"]["company"] is Map) {
        company = jsonData["profile"]["company"];
      }

      final Map planAlert = company["plan_alert"] is Map
          ? company["plan_alert"]
          : (jsonData["plan_alert"] is Map ? jsonData["plan_alert"] : {});

      final Map countdown =
      company["trial_countdown"] is Map ? company["trial_countdown"] : {};

      final String plan = (company["plan"] ?? "").toString().toLowerCase();

      final bool isTrial = plan == "trial" || countdown["is_trial"] == true;

      final bool expired = company["plan_expired"] == true ||
          countdown["expired"] == true ||
          planAlert["blocking"] == true ||
          (planAlert["type"] ?? "").toString().toLowerCase() == "expired";

      // Expire time: device ane server na time no farak na nade e mate
      // remaining_seconds thi gano (nahi to expires_at)
      DateTime? expiresAt;
      final int? remainSec =
      int.tryParse("${countdown["remaining_seconds"] ?? ""}");
      if (remainSec != null) {
        expiresAt = DateTime.now().add(Duration(seconds: remainSec));
      } else {
        expiresAt = DateTime.tryParse(
          (countdown["expires_at"] ?? company["plan_expires_at"] ?? "")
              .toString(),
        );
      }

      if (!mounted) return;

      setState(() {
        _isTrialPlan = isTrial && (countdown["show"] != false);
        _planExpiresAt = expiresAt;
        _planDaysRemaining = int.tryParse(
            "${company["plan_days_remaining"] ?? jsonData["plan_days_remaining"] ?? 0}") ??
            0;
        _planExpired = expired;
      });

      // Dar minute badge update + expire thay e j vakhte popup
      _planTimer?.cancel();
      if (expiresAt != null && !expired) {
        _planTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          if (!mounted) return;
          if (_planExpiresAt != null &&
              DateTime.now().isAfter(_planExpiresAt!)) {
            _planTimer?.cancel();
            setState(() => _planExpired = true);
            _showPlanExpiredDialog(planAlert);
          } else {
            setState(() {}); // days / hours refresh
          }
        });
      }

      // 🔒 Plan expire → login sivay biju kai nahi
      if (expired) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPlanExpiredDialog(planAlert);
        });
        return;
      }

      // ⚠️ Biju alert (warning) — show_popup true hoy to j, ek vaar
      if (planAlert["show_popup"] == true && !_planAlertShown) {
        _planAlertShown = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showPlanAlertDialog(planAlert);
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Plan info error: $e");
    }
  }

  /// "10 days" / "5 hrs" / "20 min"
  String get _trialLeftText {
    if (_planExpired) return "Expired";
    final DateTime? exp = _planExpiresAt;
    if (exp == null) {
      return "$_planDaysRemaining ${_planDaysRemaining == 1 ? 'day' : 'days'}";
    }
    final Duration left = exp.difference(DateTime.now());
    if (left.isNegative) return "Expired";
    if (left.inDays >= 1) {
      final int d = left.inDays;
      return "$d ${d == 1 ? 'day' : 'days'}";
    }
    if (left.inHours >= 1) return "${left.inHours} hrs";
    return "${left.inMinutes.clamp(1, 59)} min";
  }

  /// 🔥 TRIAL ROW — Good Morning card ni upar nani line
  ///   ⏳ Trial Plan  •  10 days left            Expires 01 Nov 2026
  Widget _trialRow() {
    final bool urgent = _planExpired ||
        (_planExpiresAt != null &&
            _planExpiresAt!.difference(DateTime.now()).inDays < 3);
    final Color c =
    urgent ? const Color(0xffE53935) : const Color(0xffF57C00);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 15, color: c),
            const SizedBox(width: 6),
            Text(
              "Trial Plan",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text("•", style: TextStyle(color: c, fontSize: 12)),
            ),
            Expanded(
              child: Text(
                _planExpired ? "Expired" : "$_trialLeftText left",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
            ),
            if (_planExpiresAt != null)
              Text(
                "Expires ${DateFormat("dd MMM yyyy").format(_planExpiresAt!)}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// 🔒 PLAN EXPIRED POPUP
  ///
  /// - Bahar tap / back button thi band nathi thatu
  /// - Ek j button: "Go to Login" → logout kari ne login screen
  /// ============================================================
  void _showPlanExpiredDialog(Map planAlert) {
    if (_expiredPopupOpen || !mounted) return;
    _expiredPopupOpen = true;

    final String title = _v(planAlert["title"]) == "-" ||
        planAlert["type"]?.toString().toLowerCase() == "trial"
        ? "Your plan has expired"
        : _v(planAlert["title"]);
    final String message = _v(planAlert["message"]) == "-" ||
        planAlert["type"]?.toString().toLowerCase() == "trial"
        ? "Your plan has expired. Please contact your administrator to renew the plan, then log in again."
        : _v(planAlert["message"]);

    const Color red = Color(0xffE53935);

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: red.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _goToLogin,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        "Go to Login",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
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

  /// 🔓 Logout (token + user data) → Login screen, pachhu aavi na shake
  Future<void> _goToLogin() async {
    _planTimer?.cancel();
    autoRefreshTimer?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      // Fakt login/user data kadho — dashboard order / rate jevi settings rahe
      for (final key in prefs.getKeys().toList()) {
        final String k = key.toLowerCase();
        if (k.contains("token") ||
            k.contains("login") ||
            const {
              "name",
              "email",
              "companyname",
              "city",
              "state",
              "companylogo",
              "role",
              "user_permissions",
              "user_role_names",
            }.contains(k)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint("❌ Logout clear error: $e");
    }

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  /// ============================================================
  /// 🔥 PLAN ALERT TYPE -> COLOR / ICON MAPPING
  /// ============================================================
  Color _planAlertColor(String type) {
    switch (type.toLowerCase()) {
      case "expired":
        return const Color(0xffE53935);
      case "warning":
      case "expiring_soon":
      case "expiring":
        return const Color(0xffFF9800);
      case "active":
        return const Color(0xff2ECC71);
      default:
        return AppColors.primaryDark;
    }
  }

  IconData _planAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case "expired":
        return Icons.error_outline_rounded;
      case "warning":
      case "expiring_soon":
      case "expiring":
        return Icons.warning_amber_rounded;
      case "active":
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _v(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return "-";
    return value.toString();
  }

  /// ============================================================
  /// 🔥 NON-CLOSABLE PLAN ALERT POPUP
  ///
  /// - barrierDismissible: false  → bahar tap karta band nathi thatu
  /// - PopScope(canPop: false)    → back button/gesture thi band nathi thatu
  /// - No close/OK button         → user koi rite j popup close nathi kari shakto
  /// ============================================================
  void _showPlanAlertDialog(Map planAlert) {
    final String type = (planAlert["type"] ?? "").toString();

    final String title = _v(planAlert["title"]);
    final String message = _v(planAlert["message"]);
    final String contactName = _v(planAlert["contact_name"]);
    final String contactMessage = _v(planAlert["contact_message"]);

    final Color alertColor = _planAlertColor(type);
    final IconData alertIcon = _planAlertIcon(type);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// ICON
                  Container(
                    height: 60,
                    width: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: alertColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(alertIcon, color: alertColor, size: 32),
                  ),

                  const SizedBox(height: 16),

                  /// TITLE
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// MESSAGE
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),

                  /// CONTACT INFO (jo available hoy)
                  if (contactName != "-" || contactMessage != "-") ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (contactName != "-")
                            Row(
                              children: [
                                Icon(
                                  Icons.support_agent_rounded,
                                  size: 15,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  contactName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          if (contactMessage != "-") ...[
                            const SizedBox(height: 4),
                            Text(
                              contactMessage,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  /// ✅ Warning (plan chalu) → OK thi band thay.
                  /// Plan expire thay tyare _showPlanExpiredDialog khule
                  /// (ema fakt "Go to Login" chhe, band nathi thatu).
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alertColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        "OK",
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  void filterMenuByPermission() {
    allMenuItems = allMenuItems.where((item) {
      String prefix = item["prefix"].toString();

      /// 🔥 Koi pan permission e prefix thi shuru thatu hoy (view/create/edit/delete/manage)
      /// to e module dikhse
      return userPermissions.contains("$prefix-view") ||
          userPermissions.contains("$prefix-manage") ||
          userPermissions.contains("$prefix-create") ||
          userPermissions.contains("$prefix-edit") ||
          userPermissions.contains("$prefix-delete");
    }).toList();
  }

  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawer: const GlobalDrawer(),
      extendBody: true,
      extendBodyBehindAppBar: true, // IMPORTANT
      //backgroundColor: AppColors.scaffoldBg,
      bottomNavigationBar: customBottomNav(),
      body: Stack(
        children: [
          /// ✅ Main Content
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.09),

              const SizedBox(height: 10),

              /// 🔥 ONLY THIS PART SCROLLABLE
              Expanded(
                child: SingleChildScrollView(
                  // 👈 ListView ના બદલે આ વાપરો
                  padding: EdgeInsets.zero,
                  child: Column(
                    // 👈 અંદર એક Column ઉમેરો
                    children: [
                      /// ⏳ TRIAL PLAN ROW (fakt trial plan ma)
                      if (_isTrialPlan) _trialRow(),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          height: isExpanded ? 240 : 75,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.secondaryDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.15),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              /// HEADER
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    isExpanded = !isExpanded;
                                  });
                                },
                                child: Container(
                                  height: 75,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  child: Row(
                                    children: [
                                      /// LEFT
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              getGreeting(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 3),

                                            Text(
                                              DateFormat(
                                                "dd MMM yyyy",
                                              ).format(DateTime.now()),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      /// CENTER
                                      selectedRate == null
                                          ? const SizedBox()
                                          : GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                              const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withOpacity(0.12),
                                            borderRadius:
                                            BorderRadius.circular(5),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize
                                                .min, // 👈 જરૂરી
                                            crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                selectedRate!["symbol"],
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 0),

                                              /// 🔥 RATE VALUE — have up/down pramane
                                              /// green/red color aapiye chiye. Jo koi
                                              /// color track na thayu hoy (first load)
                                              /// to default white j rehse.
                                              Text(
                                                "₹${selectedRate!["formatted_rate"]}",
                                                style: TextStyle(
                                                  color: _rateColors[selectedRate!["symbol"]] ??
                                                      Colors.white,
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 0),

                                      AnimatedRotation(
                                        turns: isExpanded ? .5 : 0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              /// EXPAND AREA
                              Expanded(
                                child: AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 300),
                                  crossFadeState: isExpanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,

                                  firstChild: const SizedBox(),

                                  secondChild: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Column(
                                      children: [
                                        buildFirstRowStats(),
                                        const SizedBox(height: 10),
                                        buildSecondRowStats(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      metalRateMarquee(),
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "New Features",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff14213D),
                                  ),
                                ),

                                Row(
                                  children: [
                                    Text(
                                      "View All",
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    const SizedBox(width: 5),

                                    Container(
                                      height: 22,
                                      width: 22,
                                      decoration: BoxDecoration(
                                        color: Color(0xffEEF3FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Options
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                optionItem(
                                  Icons.bar_chart,
                                  "BG Remove",
                                  Color(0xff6C35FF),
                                  Color(0xffF2EEFF),
                                ),

                                optionItem(
                                    Icons.inventory_2,
                                    "Visiting Card",
                                    Color(0xff00C853),
                                    Color(0xffEFFFF4),
                                    onTap: (){
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                          const PremiumHomeUI(),
                                        ),
                                      );
                                    }
                                ),

                                optionItem(
                                  Icons.monitor_sharp,
                                  "Live Rate",
                                  Color(0xffff9800),
                                  Color(0xfffff5e8),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const LiveMetalRatesScreen(), // 👈 tamari target screen nu naam
                                      ),
                                    );
                                  },
                                ),

                                optionItem(
                                  Icons.qr_code,
                                  "ALL QR",
                                  Color(0xff6A35FF),
                                  Color(0xffF3EEFF),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const QrListScreen(), // 👈 tamari target screen nu naam
                                      ),
                                    );
                                  },
                                ),

                                // optionItem(
                                //   Icons.credit_card,
                                //   "Payments",
                                //   Color(0xff00BCD4),
                                //   Color(0xffE8FBFF),
                                // ),
                                //
                                //
                                optionItem(
                                  Icons.settings,
                                  "Settings",
                                  Color(0xff7A8499),
                                  Color(0xffF4F5F8),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const SettingsScreen(), // 👈 tamari target screen nu naam
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      popularProductsSection(context),
                      const SizedBox(
                        height: 80,
                      ), // છેલ્લે થોડી જગ્યા આપો (Bottom Nav માટે)
                    ],
                  ),
                ),
              ),
            ],
          ),

          /// 🔥 APPBAR CALL HERE
          buildAppBar(context),
        ],
      ),
      floatingActionButton: Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.secondaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),

        child: FloatingActionButton(
          onPressed: () {
            showMenuSelectionDialog(isBottomNavMode: false);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.edit, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget buildAppBar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 10,
            vertical: 0,
          ),

          child: Stack(
            alignment: Alignment.center,
            children: [
              /// 🔥 CENTER TITLE
              Center(
                child: Image.asset(
                  "assets/static/text.png",
                  height: 30,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),

              /// LEFT + RIGHT ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// LEFT MENU
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            Icons.menu,
                            size: isMobile ? 20 : 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  /// RIGHT ICONS
                  Row(
                    children: [
                      Consumer<NotificationProvider>(
                        builder: (context, provider, child) {
                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              );

                              if (!mounted) return;

                              /// 🔥 Pachha aavya → card + bell banne no count refresh
                              _refreshNotificationCount();

                              /// Data refresh required hoy to
                              if (result == true) {
                                await getCompanyProfile();
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 6 : 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 20,
                                    offset: const Offset(5, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: isMobile ? 22 : 24,
                                    color: Colors.red,
                                  ),

                                  if (_visibleTotal(provider) > 0)
                                    Positioned(
                                      right: -5,
                                      top: -8,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _visibleTotal(provider) > 99
                                                ? "99+"
                                                : _visibleTotal(provider).toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // SizedBox(width: isMobile ? 8 : 12),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget popularProductsSection(BuildContext context) {
  //   final width = MediaQuery.of(context).size.width;
  //
  //   int crossAxisCount() {
  //     if (width < 600) return 3;
  //     if (width < 900) return 3;
  //     if (width < 1200) return 4;
  //     return 5;
  //   }
  //
  //   double childAspectRatio() {
  //     if (width < 600) return 0.94;
  //     if (width < 900) return 1.1;
  //     return 1.2;
  //   }
  //
  //   // --- GROUPING LOGIC (તમારો ઓરિજિનલ કોડ) ---
  //   Map<String, List<Map<String, dynamic>>> tempGrouped = {};
  //   for (var item in dashboardItems) {
  //     String section = item["section"] ?? "Other";
  //     if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
  //     tempGrouped[section]!.add(item);
  //   }
  //
  //   Map<String, List<Map<String, dynamic>>> groupedItems = {};
  //   List<Map<String, dynamic>> otherItems = [];
  //   tempGrouped.forEach((section, items) {
  //     if (items.length == 1) {
  //       otherItems.addAll(items);
  //     } else {
  //       groupedItems[section] = items;
  //     }
  //   });
  //   if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;
  //
  //   // સેક્શન ઓર્ડર અપડેટ કરો
  //   updateSectionOrder(groupedItems);
  //
  //   return Padding(
  //     padding: const EdgeInsets.all(10.0),
  //     child: ReorderableListView(
  //       shrinkWrap: true,
  //       physics: const NeverScrollableScrollPhysics(),
  //       onReorder: _onReorder,
  //       // ડ્રેગ કરતી વખતે બેકગ્રાઉન્ડ કલર ટ્રાન્સપરન્ટ રાખવા માટે (Optional)
  //       proxyDecorator: (child, index, animation) => child,
  //       children: sectionOrder.map((sectionName) {
  //         // જો ગ્રુપમાં આ સેક્શન ન હોય તો ખાલી કન્ટેનર રિટર્ન કરો
  //         if (!groupedItems.containsKey(sectionName))
  //           return SizedBox(key: ValueKey(sectionName));
  //
  //         List<Map<String, dynamic>> items = groupedItems[sectionName]!;
  //
  //         return Container(
  //           key: ValueKey(sectionName), // Reorderable માટે યુનિક કી
  //           margin: const EdgeInsets.only(bottom: 16),
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.circular(14),
  //             border: Border.all(color: AppColors.border),
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
  //               /// 🔥 SECTION TITLE (હવે આ આખી રો ડ્રેગ હેન્ડલ તરીકે કામ કરશે)
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Row(
  //                     crossAxisAlignment: CrossAxisAlignment.center,
  //                     children: [
  //                       Container(
  //                         padding: const EdgeInsets.all(6),
  //                         decoration: BoxDecoration(
  //                           gradient: LinearGradient(
  //                             colors: [
  //                               AppColors.primaryDark.withOpacity(0.7),
  //                               AppColors.secondaryDark.withOpacity(0.7),
  //                             ],
  //                           ),
  //                           borderRadius: BorderRadius.circular(10),
  //                         ),
  //                         child: const Icon(
  //                           Icons.drag_indicator,
  //                           color: Colors.white,
  //                           size: 20,
  //                         ),
  //                       ),
  //
  //                       const SizedBox(width: 10),
  //
  //                       Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         mainAxisSize: MainAxisSize.min,
  //                         children: [
  //                           Text(
  //                             sectionName,
  //                             textAlign: TextAlign.center,
  //                             style: const TextStyle(
  //                               fontSize: 15,
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.black,
  //                             ),
  //                           ),
  //
  //                           Text(
  //                             getSectionSubtitle(sectionName),
  //                             style: TextStyle(
  //                               fontSize: 12,
  //                               color: AppColors.textLight,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 10,
  //                       vertical: 3,
  //                     ),
  //                     decoration: BoxDecoration(
  //                       gradient: LinearGradient(
  //                         colors: [
  //                           AppColors.primaryDark.withOpacity(0.7),
  //                           AppColors.secondaryDark.withOpacity(0.7),
  //                         ],
  //                       ),
  //                       borderRadius: BorderRadius.circular(8),
  //                     ),
  //                     child: Text(
  //                       "${items.length} Items",
  //                       style: const TextStyle(
  //                         color: Colors.white,
  //                         fontWeight: FontWeight.w600,
  //                         fontSize: 12,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 14),
  //
  //               /// 🔥 GRID
  //               GridView.builder(
  //                 itemCount: items.length,
  //                 shrinkWrap: true,
  //                 physics: const NeverScrollableScrollPhysics(),
  //                 padding: EdgeInsets.zero,
  //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //                   crossAxisCount: crossAxisCount(),
  //                   crossAxisSpacing: 12,
  //                   mainAxisSpacing: 12,
  //                   childAspectRatio: childAspectRatio(),
  //                 ),
  //                 itemBuilder: (context, index) {
  //                   final item = items[index];
  //                   final module = item["module"] ?? "";
  //
  //                   final count = context
  //                       .watch<NotificationProvider>()
  //                       .moduleCount(module);
  //
  //                   //print("Module: $module -> Count: $count");
  //                   return _premiumMenuCard(
  //                     context,
  //                     item["title"],
  //                     item["icon"],
  //                     () async {
  //                       readModule(module);
  //                       final result = await Navigator.push(
  //                         context,
  //                         MaterialPageRoute(builder: (_) => item["screen"]),
  //                       );
  //
  //                       // 👇 Child page mathi pop thay pachi
  //                       if (result == true) {
  //                         print("Refresh");
  //                         await getCompanyProfile();
  //                         setState(() {});
  //                       }
  //                     },
  //                     count: count,
  //                   );
  //                 },
  //               ),
  //             ],
  //           ),
  //         );
  //       }).toList(),
  //     ),
  //   );
  // }

  Widget popularProductsSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount() {
      if (width < 600) return 3;
      if (width < 900) return 3;
      if (width < 1200) return 4;
      return 5;
    }

    double childAspectRatio() {
      if (width < 600) return 0.94;
      if (width < 900) return 1.1;
      return 1.2;
    }

    //--- GROUPING LOGIC (same) ---
    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    for (var item in dashboardItems) {
      String section = item["section"] ?? "Other";
      if (!tempGrouped.containsKey(section)) tempGrouped[section] = [];
      tempGrouped[section]!.add(item);
    }

    Map<String, List<Map<String, dynamic>>> groupedItems = {};
    List<Map<String, dynamic>> otherItems = [];
    tempGrouped.forEach((section, items) {
      if (userRoleNames.length == 1) {
        otherItems.addAll(items);
      } else {
        groupedItems[section] = items;
      }
    });

    if (otherItems.isNotEmpty) {
      groupedItems["Others"] = otherItems;
    }
    if (otherItems.isNotEmpty) groupedItems["Others"] = otherItems;

    // --- GROUPING LOGIC ---

    //updateSectionOrder(groupedItems);

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: _onReorder,
        proxyDecorator: (child, index, animation) => child,
        children: sectionOrder.map((sectionName) {
          if (!groupedItems.containsKey(sectionName))
            return SizedBox(key: ValueKey(sectionName));

          List<Map<String, dynamic>> items = groupedItems[sectionName]!;

          /// 🔥 Default expanded state (na hoy to true rakho — pehla khulu j dekhay)
          // bool isExpanded = expandedSections[sectionName] ?? false;
          /// 🔥 Fakt PEHLU section default open rahe, baki badha collapsed
          final bool isExpanded = expandedSections[sectionName] ?? false;

          return Material(
            key: ValueKey(sectionName),
            color: Colors.transparent,
            child: Container(
              key: ValueKey(sectionName),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔥 SECTION TITLE — have TAP thi expand/collapse thashe
                  InkWell(
                    onTap: () async {
                      final bool currentlyExpanded =
                          expandedSections[sectionName] ?? false;

                      setState(() {
                        /// Pehla badha sections close
                        for (final section in sectionOrder) {
                          expandedSections[section] = false;
                        }

                        /// Jo current section pehla close hato,
                        /// to fakt ene open karo.
                        ///
                        /// Jo already open hato,
                        /// to badha close j rehse.
                        if (!currentlyExpanded) {
                          expandedSections[sectionName] = true;
                        }
                      });

                      await saveExpandedSections();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            /// 🔥 Drag handle — have ReorderableDragStartListener thi wrap karyu,
                            /// jethi fakt AA icon j drag mate vaparay, baki title tap expand/collapse kare
                            ReorderableDragStartListener(
                              index: sectionOrder.indexOf(sectionName),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark.withOpacity(0.7),
                                      AppColors.secondaryDark.withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.drag_indicator,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sectionName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  getSectionSubtitle(sectionName),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryDark.withOpacity(0.7),
                                    AppColors.secondaryDark.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                "${items.length} Items",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            /// 🔥 Expand/Collapse Arrow
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  /// 🔥 GRID — AnimatedCrossFade thi smooth expand/collapse
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: GridView.builder(
                        itemCount: items.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: childAspectRatio(),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final module = item["module"] ?? "";

                          final int count = _visibleCount(
                            module.toString(),
                            context
                                .watch<NotificationProvider>()
                                .moduleCount(module),
                          );

                          return _premiumMenuCard(
                            context,
                            item["title"],
                            item["icon"],
                                () async {
                              /// 🔥 Notification read — count hoy to j.
                              /// Card + bell banne ma turant count hide
                              Future<bool>? readFuture;
                              if (count > 0) {
                                setState(() =>
                                    _readModules.add(module.toString()));
                                readFuture = readModule(module);
                              }

                              /// 🔥 Navigate karta PEHLA section top + open
                              //moveSectionToTopAndOpen(sectionName);

                              /// Screen open
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => item["screen"],
                                ),
                              );

                              if (readFuture != null) {
                                final bool ok = await readFuture;
                                // API fail → count paachho
                                if (!ok) _readModules.remove(module.toString());
                              }
                              if (!mounted) return;

                              /// 🔥 Pachha aavya → card + bell banne no count refresh
                              _refreshNotificationCount();

                              /// 🔥 BACK AAVYA PACHI FARITHI ENSURE KARO
                              //await moveSectionToTopAndOpen(sectionName);

                              /// Data refresh required hoy to
                              if (result == true) {
                                await getCompanyProfile();

                                // /// getCompanyProfile rebuild kare pachi pan
                                // /// current section restore karo
                                // await moveSectionToTopAndOpen(sectionName);
                              }
                            },
                            count: count,
                          );
                        },
                      ),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _premiumMenuCard(
      BuildContext context,
      String title,
      IconData icon,
      VoidCallback onTap, {
        int count = 0,
      }) {
    return Material(
      // 🔥 આ ઉમેરવાથી "No Material found" એરર દૂર થશે
      color: Colors.transparent, // બેકગ્રાઉન્ડ ટ્રાન્સપરન્ટ રાખવું
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// 🔥 ICON CIRCLE
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(0.7),
                          AppColors.secondaryDark.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      shape: BoxShape.rectangle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),

                  /// Notification Count
                  if (count > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 99 ? "99+" : "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 5),

              /// TITLE
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  //////////////////////////////////////////////////////////////
  /// 🔵 PRODUCT CARD
  //////////////////////////////////////////////////////////////

  Widget productCard(
      BuildContext context,
      String title,
      IconData icon,
      VoidCallback onTap,
      ) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isTablet = width > 600;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: EdgeInsets.all(width * 0.04),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: isTablet ? width * 0.10 : width * 0.14,
                  width: isTablet ? width * 0.10 : width * 0.16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2A55), Color(0xFF1E2A55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D1633).withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isTablet ? width * 0.04 : width * 0.06,
                  ),
                ),
                SizedBox(height: height * 0.015),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: isTablet ? width * 0.022 : width * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget customBottomNav() {
    final size = MediaQuery.of(context).size;
    final double width = size.width;

    /// ============================================
    /// RESPONSIVE BREAKPOINTS
    /// ============================================
    final bool isVerySmallPhone = width < 340;
    final bool isSmallPhone = width >= 340 && width < 400;
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1000;
    final bool isDesktop = width >= 1000;

    /// ============================================
    /// RESPONSIVE HEIGHT
    /// ============================================
    final double navHeight;

    if (isDesktop) {
      navHeight = 78;
    } else if (isTablet) {
      navHeight = 72;
    } else if (isVerySmallPhone) {
      navHeight = 62;
    } else if (isSmallPhone) {
      navHeight = 65;
    } else {
      navHeight = 68;
    }

    /// ============================================
    /// RESPONSIVE ICON SIZE
    /// ============================================
    final double iconSize;

    if (isDesktop) {
      iconSize = 25;
    } else if (isTablet) {
      iconSize = 22;
    } else if (isVerySmallPhone) {
      iconSize = 18;
    } else if (isSmallPhone) {
      iconSize = 19;
    } else {
      iconSize = 21;
    }

    /// ============================================
    /// RESPONSIVE FONT SIZE
    /// ============================================
    final double fontSize;

    if (isDesktop) {
      fontSize = 12;
    } else if (isTablet) {
      fontSize = 10.5;
    } else if (isVerySmallPhone) {
      fontSize = 8.5;
    } else if (isSmallPhone) {
      fontSize = 9;
    } else {
      fontSize = 10;
    }

    /// ============================================
    /// RESPONSIVE HORIZONTAL MARGIN
    ///
    /// Tablet ma width cut na kariye.
    /// Aa overflow avoid karva important che.
    /// ============================================
    final double horizontalMargin;

    if (isDesktop) {
      horizontalMargin = width * 0.12;
    } else if (isTablet) {
      horizontalMargin = 8;
    } else {
      horizontalMargin = 0;
    }

    /// ============================================
    /// RESPONSIVE RADIUS
    /// ============================================
    final double radius = isMobile ? 12 : 15;

    return SafeArea(
      top: false,
      child: Container(
        height: navHeight,
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BottomNavigationBar(
            /// ========================================
            /// BASIC
            /// ========================================
            backgroundColor: Colors.white,

            currentIndex: selectedIndex,

            type: BottomNavigationBarType.fixed,

            elevation: 0,

            /// ========================================
            /// ICON
            /// ========================================
            iconSize: iconSize,

            /// ========================================
            /// FONT
            /// ========================================
            selectedFontSize: fontSize,
            unselectedFontSize: fontSize,

            selectedLabelStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),

            unselectedLabelStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),

            /// ========================================
            /// COLOR
            /// ========================================
            selectedItemColor: AppColors.primaryDark,

            unselectedItemColor: Colors.grey.shade600,

            /// ========================================
            /// LABEL SETTINGS
            /// ========================================
            showSelectedLabels: true,
            showUnselectedLabels: true,

            /// ========================================
            /// CLICK
            /// ========================================
            onTap: (index) {
              final item = bottomItems[index];

              /// MORE CLICK
              if (item["title"] == "More") {
                showMenuSelectionDialog(isBottomNavMode: true);
                return;
              }

              setState(() {
                selectedIndex = index;
              });

              /// SCREEN OPEN
              if (item["screen"] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item["screen"]),
                );
              }
            },

            /// ========================================
            /// ITEMS
            /// ========================================
            items: bottomItems.map((item) {
              final String title = item["title"]?.toString() ?? "";

              return BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: isVerySmallPhone ? 1 : 2),
                  child: Icon(item["icon"], size: iconSize),
                ),

                /// Long label hoy to short kari shakai
                label: title,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget addNewGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), // glass transparency
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add, color: AppColors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Add New",
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget gradientIcon(IconData icon, bool selected) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: selected
              ? const [Colors.white54, Colors.white54]
              : const [Colors.white54, Colors.white54],
        ).createShader(bounds);
      },
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  void showMenuSelectionDialog({bool isBottomNavMode = false}) {
    List<Map<String, dynamic>> sections = [
      {
        "title": "Item Management",
        "icon": Icons.inventory_2,
        "items": [
          {
            "title": "Item List",
            "icon": Icons.add_box,
            "screen": const Itemscreen(),
            "prefix": "item", // ✅ ADD
          },
          {
            "title": "Label Config",
            "icon": Icons.production_quantity_limits,
            "screen": const Labelscreen(),
            "prefix": "label-config", // ✅ ADD
          },
          {
            "title": "Label Items",
            "icon": Icons.label_important_outlined,
            "screen": const label_item_screen(),
            "prefix": "item-set", // ✅ ADD
          },
          {
            "title": "Label Printing",
            "icon": Icons.print,
            "screen": const LabelPrintScreen(),
            "prefix": "label-print", // ✅ ADD
          },
          {
            "title": "Other Charges",
            "icon": Icons.settings_applications,
            "screen": const Othersscreen(),
            "prefix": "other-charge", // ✅ ADD
          },
        ],
      },

      {
        "title": "User Management",
        "icon": Icons.dashboard_customize,
        "items": [
          {
            "title": "Person",
            "icon": Icons.person_add,
            "screen": const Customerscreen(),
            "prefix": "person", // ✅ ADD
          },
          {
            "title": "Users",
            "icon": Icons.people,
            "screen": const Userscreen(),
            "prefix": "user", // ✅ ADD
          },
          {
            "title": "Category",
            "icon": Icons.people,
            "screen": const Categoryscreen(),
            "prefix": "category-person", // ✅ ADD
          },
        ],
      },

      {
        "title": "JobWork Management",
        "icon": Icons.inventory_2,
        "items": [
          {
            "title": "Labour Formula",
            "icon": Icons.add_box,
            "screen": const JobLabourformulaScreen(),
            "prefix": "labour-formula", // ✅ ADD
          },
          {
            "title": "Production Cost",
            "icon": Icons.production_quantity_limits,
            "screen": const Productioncost(),
            "prefix": "production-cost", // ✅ ADD
          },
          {
            "title": "Production Step",
            "icon": Icons.label_important_outlined,
            "screen": const Prooductionstepscreen(),
            "prefix": "production-step", // ✅ ADD
          },
          // {
          //   "title": "Job Worker",
          //   "icon": Icons.print,
          //   "screen": const Jobworkerscreen(),
          //   "prefix": "job-worker", // ✅ ADD
          // },
          {
            "title": "Jobwork Issue",
            "icon": Icons.settings_applications,
            "screen": const JobworkIssueScreen(),
            "prefix": "jobwork-issue", // ✅ ADD
          },
          {
            "title": "Jobwork Receive",
            "icon": Icons.settings_applications,
            "screen": const Jobworkreceivescreen(),
            "prefix": "jobwork-receive", // ✅ ADD
          },
        ],
      },

      {
        "title": "Sales",
        "icon": Icons.inventory_2,
        "items": [
          {
            "title": "Sale on Approvals",
            "icon": Icons.qr_code,
            "screen": const InvoiceScreen(),
            "prefix": "approval", // ✅ ADD
          },
          {
            "title": "Sales Estimate",
            "icon": Icons.sell,
            "screen": const SellList(),
            "prefix": "sale", // ✅ ADD
          },
          {
            "title": "Approval Return",
            "icon": Icons.sell,
            "screen": const Approvalreturnscreen(),
            "prefix": "approval-return", // ✅ ADD
          },
          {
            "title": "Rec-Ret-Purchase",
            "icon": Icons.sell,
            "screen": const ReciveReturnPurchase(),
            "prefix": "sale-advance", // ✅ ADD
          },
        ],
      },

      {
        "title": "Reports & Tools",
        "icon": Icons.analytics,
        "items": [
          {
            "title": "Sales Summary",
            "icon": Icons.bar_chart,
            "screen": const Salesumryreport(),
            "prefix": "report-sales-summary", // ✅ ADD
          },
          {
            "title": "Reciver Summary",
            "icon": Icons.qr_code_scanner,
            "screen": const Purchasereciversummary(),
            "prefix": "receiver-summary", // ✅ ADD
          },
          {
            "title": "Stock Position",
            "icon": Icons.bar_chart,
            "screen": const Stockpositionreport(),
            "prefix": "report-stock-position", // ✅ ADD
          },
          {
            "title": "Approval Outstanding",
            "icon": Icons.menu_book,
            "screen": const Approvaloutstandingreport(),
            "prefix": "report-approval-outstanding", // ✅ ADD
          },
          {
            "title": "Barcode History",
            "icon": Icons.menu_book,
            "screen": const Barcodehistory(),
            "prefix": "report-barcode-history", // ✅ ADD
          },
          {
            "title": "Worker Loss",
            "icon": Icons.menu_book,
            "screen": const WorkerLossReportScreen(),
            "prefix": "report-worker-loss", // ✅ ADD
          },
          {
            "title": "Approval Summary",
            "icon": Icons.menu_book,
            "screen": const ApprovalSummaryScreen(),
            "prefix": "report-worker-loss", // ✅ ADD
          },
          {
            "title": "Approval Register",
            "icon": Icons.menu_book,
            "screen": const ApprovalReturnRegisterScreen(),
            "prefix": "report-worker-loss", // ✅ ADD
          },
        ],
      },

      {
        "title": "Role & Permission",
        "icon": Icons.admin_panel_settings,
        "items": [
          {
            "title": "Roles",
            "icon": Icons.admin_panel_settings,
            "screen": const Rolescreen(),
            "prefix": "role", // ✅ ADD
          },
          {
            "title": "Permissions",
            "icon": Icons.admin_panel_settings,
            "screen": const Permissionscreen(),
            "prefix": "permission", // ✅ ADD
          },
        ],
      },

      {
        "title": "Casting Management",
        "icon": Icons.settings,
        "items": [
          {
            "title": "Buch",
            "icon": Icons.settings,
            "screen": const Buchscreen(),
            "prefix": "vacuum-buch",
          },
          {
            "title": "Process",
            "icon": Icons.settings,
            "screen": const Processscreen(),
            "prefix": "vacuum-process",
          },
          {
            "title": "Vacuum Voucher",
            "icon": Icons.settings,
            "screen": const Voucherscreen(),
            "prefix": "vacuum-voucher",
          },
          {
            "title": "Casting Heating",
            "icon": Icons.settings,
            "screen": const Castingheatingscreen(),
            "prefix": "casting-heating",
          },
          {
            "title": "Casting Metal",
            "icon": Icons.settings,
            "screen": const Castingmetalscreen(),
            "prefix": "casting-metal-issue",
          },
          {
            "title": "Casting Receive",
            "icon": Icons.settings,
            "screen": const Castingrecivescreen(),
            "prefix": "casting-release",
          },
          {
            "title": "Tree Cutting Office",
            "icon": Icons.settings,
            "screen": const Treecuttingoffice(),
            "prefix": "tree-cutting-office",
          },
          {
            "title": "Tree Cutting Issue",
            "icon": Icons.settings,
            "screen": const Treecuttingissuescreen(),
            "prefix": "tree-cutting-issue",
          },
          {
            "title": "Tree Cutting Receive",
            "icon": Icons.settings,
            "screen": const Treecuttingreceivescreen(),
            "prefix": "tree-cutting-receive",
          },
          {
            "title": "Casting Sorting",
            "icon": Icons.settings,
            "screen": const Castingsortscreen(),
            "prefix": "casting-sorting",
          },
        ],
      },
    ];

    List<Map<String, dynamic>> filteredSections = sections
        .map((section) {
      List items = (section["items"] as List).where((item) {
        String prefix = item["prefix"].toString();

        /// 🔥 Same logic — view ya manage both check karo
        return userPermissions.contains("$prefix-view") ||
            userPermissions.contains("$prefix-manage") ||
            userPermissions.contains("$prefix-create") ||
            userPermissions.contains("$prefix-edit") ||
            userPermissions.contains("$prefix-delete");
      }).toList();

      return {
        "title": section["title"],
        "icon": section["icon"],
        "items": items,
      };
    })
        .where((section) => (section["items"] as List).isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottom) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.80,

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.background.withOpacity(0.9),
                    AppColors.background.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),

                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),

              child: Column(
                children: [
                  const SizedBox(height: 14),

                  Container(
                    width: 60,
                    height: 5,

                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Customize Dashboard",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),

                      itemCount: filteredSections.length,

                      itemBuilder: (context, sectionIndex) {
                        final section =
                        filteredSections[sectionIndex]; // ✅ FIXED

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),

                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),

                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),

                              childrenPadding: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                bottom: 12,
                              ),

                              leading: Container(
                                padding: const EdgeInsets.all(10),

                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),

                                child: Icon(
                                  section["icon"],
                                  color: AppColors.iconBlue,
                                ),
                              ),

                              title: Text(
                                section["title"],

                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              iconColor: AppColors.iconBlue,
                              collapsedIconColor: AppColors.textPrimary,

                              children: List.generate(section["items"].length, (
                                  index,
                                  ) {
                                final item = section["items"][index];

                                bool alreadyAdded = isBottomNavMode
                                    ? bottomItems.any(
                                      (e) => e["title"] == item["title"],
                                )
                                    : dashboardItems.any(
                                      (e) => e["title"] == item["title"],
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),

                                  padding: const EdgeInsets.all(12),

                                  decoration: BoxDecoration(
                                    gradient: alreadyAdded
                                        ? const LinearGradient(
                                      colors: [
                                        AppColors.border,
                                        AppColors.border,
                                      ],
                                    )
                                        : LinearGradient(
                                      colors: [
                                        AppColors.border,
                                        AppColors.border,
                                      ],
                                    ),

                                    borderRadius: BorderRadius.circular(10),
                                  ),

                                  child: Row(
                                    children: [
                                      Container(
                                        height: 45,
                                        width: 45,

                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,

                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.iconBlue.withOpacity(
                                                0.5,
                                              ),
                                              AppColors.border.withOpacity(0.5),
                                              AppColors.iconBlue.withOpacity(
                                                0.5,
                                              ),
                                            ],
                                          ),
                                        ),

                                        child: Icon(
                                          item["icon"],
                                          color: Colors.black,
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                          children: [
                                            Text(
                                              item["title"],
                                              style: TextStyle(
                                                color: alreadyAdded
                                                    ? Colors.black
                                                    : Colors.black,

                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            Text(
                                              alreadyAdded
                                                  ? "Added"
                                                  : "Tap to add",

                                              style: TextStyle(
                                                color: alreadyAdded
                                                    ? Colors.black87
                                                    : Colors.black87,

                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      InkWell(
                                        onTap: () async {
                                          if (isBottomNavMode) {
                                            /// 🔥 BOTTOM NAV MODE — fakt bottomItems manipulate
                                            if (alreadyAdded) {
                                              setStateBottom(() {
                                                bottomItems.removeWhere(
                                                      (e) =>
                                                  e["title"] ==
                                                      item["title"],
                                                );
                                              });

                                              if (selectedIndex >=
                                                  bottomItems.length) {
                                                selectedIndex =
                                                    bottomItems.length - 1;
                                              }
                                            } else {
                                              int customCount =
                                                  bottomItems.length - 2;

                                              if (customCount >= 2) {
                                                Navigator.pop(context);
                                                Future.delayed(
                                                  const Duration(
                                                    milliseconds: 100,
                                                  ),
                                                      () {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "Maximum 2 items can be added in bottom navigation",
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                                return;
                                              }

                                              setStateBottom(() {
                                                bottomItems.insert(
                                                  bottomItems.length - 1,
                                                  {
                                                    "title": item["title"],
                                                    "icon": item["icon"],
                                                    "screen": item["screen"],
                                                  },
                                                );
                                              });
                                            }

                                            await saveBottomNavItems();
                                          } else {
                                            /// 🔥 DASHBOARD MODE — dashboardItems manipulate (original logic)
                                            if (alreadyAdded) {
                                              dashboardItems.removeWhere(
                                                    (e) =>
                                                e["title"] == item["title"],
                                              );
                                              bottomItems.removeWhere(
                                                    (e) =>
                                                e["title"] == item["title"],
                                              );

                                              if (selectedIndex >=
                                                  bottomItems.length) {
                                                selectedIndex =
                                                    bottomItems.length - 1;
                                              }
                                            } else {
                                              dashboardItems.add({
                                                ...item,
                                                "section": section["title"],
                                              });
                                            }

                                            await saveDashboardItems();
                                            await loadDashboardItems();
                                          }

                                          setStateBottom(() {});
                                          setState(() {});
                                        },

                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),

                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 10,
                                          ),

                                          // decoration: BoxDecoration(
                                          //
                                          //   color: alreadyAdded
                                          //       ? Colors.green
                                          //       : null,
                                          //
                                          //
                                          //
                                          //   gradient: alreadyAdded
                                          //       ? null
                                          //       : const LinearGradient(
                                          //     colors: [
                                          //       Color(0xffE6C58A),
                                          //       Color(0xffC8A96A),
                                          //     ],
                                          //   ),
                                          //
                                          //   borderRadius: BorderRadius.circular(12),
                                          // ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: alreadyAdded
                                                  ? [
                                                AppColors.iconBlue
                                                    .withOpacity(0.5),
                                                //AppColors.border.withOpacity(0.5),
                                                AppColors.iconBlue
                                                    .withOpacity(0.5),
                                              ]
                                                  : const [
                                                Color(0xffE6C58A),
                                                Color(0xffC8A96A),
                                              ],
                                            ),

                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),

                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                alreadyAdded
                                                    ? Icons.check
                                                    : Icons.add,
                                                color: alreadyAdded
                                                    ? Colors.white
                                                    : Colors.black,
                                                size: 18,
                                              ),

                                              const SizedBox(width: 6),

                                              Text(
                                                alreadyAdded ? "ADDED" : "ADD",

                                                style: TextStyle(
                                                  color: alreadyAdded
                                                      ? Colors.white
                                                      : Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),

                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },

                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),

                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.secondaryDark,
                            ],
                          ),

                          borderRadius: BorderRadius.circular(10),
                        ),

                        child: const Center(
                          child: Text(
                            "DONE",

                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final String item = sectionOrder.removeAt(oldIndex);
      sectionOrder.insert(newIndex, item);
    });
  }

  String getSectionSubtitle(String sectionName) {
    switch (sectionName) {
      case "Sales":
        return "Manage all sales activities";

      case "Item Management":
        return "Manage your inventory & items";

      case "Others":
        return "Other useful options";

      case "JobWork Management":
        return "Manage all job work activities";

      case "Report Management":
        return "Manage all Report activities";

      case "Role Management":
        return "Manage all Settings activities";

      case "Casting Management":
        return "Manage all Casting activities";

      case "Management":
        return "Manage all User activities";

      default:
        return "";
    }
  }

  Widget optionItem(
      IconData icon,
      String title,
      Color iconColor,
      Color bgColor, {
        VoidCallback? onTap, // 👈 ADD THIS
      }) {
    return InkWell(
      onTap: onTap, // 👈 ADD THIS
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xff14213D),
            ),
          ),
        ],
      ),
    );
  }

  Widget metalRateMarquee() {
    if (rates.isEmpty) {
      return const SizedBox();
    }

    String text = "";

    for (var item in rates) {
      text +=
      " ${item["symbol"]} (${item["city"]}) : ₹${item["formatted_rate"]}  |";
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff8B3A3A), Color(0xffC59D5F)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Icon(
              Icons.currency_rupee,
              color: Colors.white,
              size: 18,
            ),
          ),

          Expanded(
            child: Marquee(
              text: text,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),

              velocity: 45,

              blankSpace: 70,

              pauseAfterRound: const Duration(seconds: 2),

              startPadding: 10,

              scrollAxis: Axis.horizontal,

              crossAxisAlignment: CrossAxisAlignment.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStat(IconData icon, String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// Icon Background
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),

        const SizedBox(height: 0),

        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 0),

        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget buildWelcomeSection() {
    return Row(
      children: [
        // Container(
        //   height: 45,
        //   width: 45,
        //   decoration: BoxDecoration(
        //     color: Colors.white.withOpacity(.15),
        //     shape: BoxShape.circle,
        //     border: Border.all(color: Colors.white24),
        //   ),
        //   child: const Icon(
        //     Icons.person,
        //     color: Colors.white,
        //     size: 24,
        //   ),
        // ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Good Morning 👋",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 2),

              Text(
                "Welcome",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "Manager",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget buildFirstRowStats() {
    return Row(
      children: [
        Expanded(child: buildStat(Icons.currency_rupee, "Sales", "₹0.00")),
        Expanded(child: buildStat(Icons.trending_up, "Month Sales", "₹160")),
        Expanded(child: buildStat(Icons.assignment_return, "Returns", "₹20")),
        Expanded(child: buildStat(Icons.check_circle, "Complete", "25")),
      ],
    );
  }

  Widget buildSecondRowStats() {
    return Row(
      children: [
        Expanded(child: buildStat(Icons.approval, "Approvals", "12")),
        Expanded(child: buildStat(Icons.pending_actions, "Pending", "08")),
        Expanded(child: buildStat(Icons.local_offer, "Labels", "41")),
        Expanded(child: buildStat(Icons.people, "Users", "4 / 8")),
      ],
    );
  }

  Future<void> loadExpandedSections() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString("expanded_sections");

    if (saved != null && saved.isNotEmpty) {
      List<String> openSections = saved.split(",");

      setState(() {
        // 🔥 Fakt PEHLO section j open rakho (accordion rule)
        String? firstOpen = openSections.isNotEmpty ? openSections.first : null;
        expandedSections = {};
        if (firstOpen != null) {
          expandedSections[firstOpen] = true;
        }
      });
    }
  }

  Future<void> saveExpandedSections() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 Fakt PEHLO open section j save karo (max 1)
    List<String> openSections = expandedSections.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    await prefs.setString("expanded_sections", openSections.join(","));
  }

  Future<void> saveSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("section_order", sectionOrder);
  }

  Future<void> loadSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList("section_order");

    if (saved != null && saved.isNotEmpty) {
      setState(() {
        // 🔥 Saved order set karo (agar navi sections hoy to pachi automatically add thai jashe _updateSectionOrderForNewItems() thi)
        sectionOrder = saved;
      });
    }
  }
}
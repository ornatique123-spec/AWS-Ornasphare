// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:ui';
//
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pecifician_sysytem/Extra/AppColors.dart';
// import 'package:provider/provider.dart';
//
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Dashboard/HomeScreen.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/ItemProvider.dart';
// import '../Extra/PremiumSearchableDropdown.dart';
// import '../Offline Data/offline_api_helper.dart';
// import 'ApproveListScreen.dart';
//
// class Createapprovalscreen extends StatefulWidget {
//   final Map<String, dynamic>? userData;
//
//   const Createapprovalscreen({Key? key, this.userData}) : super(key: key);
//
//   @override
//   State<Createapprovalscreen> createState() => _CreateapprovalscreenState();
// }
//
// class _CreateapprovalscreenState extends State<Createapprovalscreen>
//     with WidgetsBindingObserver {
//   /// ============================================================
//   /// SCANNER
//   /// ============================================================
//
//   late final MobileScannerController scannerController =
//       MobileScannerController(
//         detectionSpeed: DetectionSpeed.noDuplicates,
//         formats: [BarcodeFormat.qrCode],
//         autoStart: false,
//       );
//
//   bool _scannerReady = false;
//
//   String? lastCode;
//   bool isBusy = false;
//
//   /// ============================================================
//   /// CONTROLLERS
//   /// ============================================================
//
//   final TextEditingController searchController = TextEditingController();
//
//   final TextEditingController fromDateController = TextEditingController();
//
//   final TextEditingController toDateController = TextEditingController();
//
//   final TextEditingController remarksController = TextEditingController();
//
//   final FocusNode searchFocusNode = FocusNode();
//
//   final Map<String, TextEditingController> controllers = {};
//
//   Timer? _debounce;
//
//   /// ============================================================
//   /// STATE
//   /// ============================================================
//
//   List userlist = [];
//
//   bool isLoading = false;
//   bool isProcessing = false;
//   bool isSearchEnabled = false;
//
//   String? selectedItem;
//   String? selectedCompanyId;
//   String? selectedUserId;
//
//   List cartItems = [];
//
//   List<Map<String, dynamic>> items = [];
//   List<Map<String, dynamic>> allItems = [];
//
//   List searchResults = [];
//
//   bool showScannerFull = false;
//
//   bool get isEditMode => widget.userData != null;
//
//   List<Map<String, dynamic>> uniqueItems = [];
//
//   /// ============================================================
//   /// INIT
//   /// ============================================================
//
//   @override
//   void initState() {
//     super.initState();
//
//     WidgetsBinding.instance.addObserver(this);
//
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
//     });
//
//     if (isEditMode) {
//       final user = widget.userData!;
//
//       selectedItem = user["customer_id"]?.toString();
//
//       remarksController.text = user["remarks"]?.toString() ?? "";
//
//       final id = int.tryParse(user["id"]?.toString() ?? "");
//
//       if (id != null) {
//         getCartItems();
//         loadEditData(id);
//       }
//     }
//   }
//
//   /// ============================================================
//   /// DISPOSE
//   /// ============================================================
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//
//     _debounce?.cancel();
//
//     scannerController.dispose();
//
//     searchController.dispose();
//     fromDateController.dispose();
//     toDateController.dispose();
//     remarksController.dispose();
//
//     searchFocusNode.dispose();
//
//     for (final controller in controllers.values) {
//       controller.dispose();
//     }
//
//     controllers.clear();
//
//     super.dispose();
//   }
//
//   /// ============================================================
//   /// APP LIFECYCLE
//   /// ============================================================
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (!scannerController.value.isInitialized) {
//       return;
//     }
//
//     if (state == AppLifecycleState.inactive ||
//         state == AppLifecycleState.paused) {
//       scannerController.stop();
//       _scannerReady = false;
//     } else if (state == AppLifecycleState.resumed && showScannerFull) {
//       _startScanner();
//     }
//   }
//
//   /// ============================================================
//   /// SCANNER START
//   /// ============================================================
//
//   Future<void> _startScanner() async {
//     try {
//       await scannerController.start();
//
//       if (mounted) {
//         setState(() {
//           _scannerReady = true;
//         });
//       }
//     } catch (e) {
//       debugPrint("Scanner start error: $e");
//
//       await Future.delayed(const Duration(milliseconds: 400));
//
//       try {
//         await scannerController.start();
//
//         if (mounted) {
//           setState(() {
//             _scannerReady = true;
//           });
//         }
//       } catch (e2) {
//         debugPrint("Scanner retry failed: $e2");
//       }
//     }
//   }
//
//   Future<void> _stopScanner() async {
//     try {
//       if (scannerController.value.isInitialized) {
//         await scannerController.stop();
//       }
//     } catch (_) {}
//
//     _scannerReady = false;
//   }
//
//   /// ============================================================
//   /// DATE
//   /// ============================================================
//
//   Future<void> _selectDate(TextEditingController controller) async {
//     final DateTime? picked = await showDatePicker(
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
//   /// ============================================================
//   /// SEARCH CUSTOMER
//   /// ============================================================
//
//   void searchCustomer(String value) {
//     setState(() {
//       if (value.isEmpty) {
//         items = List.from(allItems);
//       } else {
//         items = allItems.where((item) {
//           return item["title"].toString().toLowerCase().contains(
//             value.toLowerCase(),
//           );
//         }).toList();
//       }
//     });
//   }
//
//   /// ============================================================
//   /// STABLE CONTROLLER KEY
//   /// ============================================================
//
//   String _controllerKey(Map item, String key) {
//     final dynamic rawId = item["itemset_id"] ?? item["id"] ?? item["cart_id"];
//
//     return "${rawId?.toString() ?? item.hashCode.toString()}_$key";
//   }
//
//   TextEditingController getController(Map item, String key) {
//     final String uniqueKey = _controllerKey(item, key);
//
//     final existing = controllers[uniqueKey];
//
//     if (existing != null) {
//       return existing;
//     }
//
//     final controller = TextEditingController(text: item[key]?.toString() ?? "");
//
//     controllers[uniqueKey] = controller;
//
//     return controller;
//   }
//
//   void updateController(Map item, String key) {
//     final String uniqueKey = _controllerKey(item, key);
//
//     final controller = controllers[uniqueKey];
//
//     if (controller == null) {
//       return;
//     }
//
//     final String newValue = item[key]?.toString() ?? "";
//
//     if (controller.text == newValue) {
//       return;
//     }
//
//     controller.value = TextEditingValue(
//       text: newValue,
//       selection: TextSelection.collapsed(offset: newValue.length),
//       composing: TextRange.empty,
//     );
//   }
//
//   void setController(Map<String, dynamic> item, String key, String value) {
//     final controller = getController(item, key);
//
//     if (controller.text != value) {
//       controller.value = TextEditingValue(
//         text: value,
//         selection: TextSelection.collapsed(offset: value.length),
//       );
//     }
//   }
//
//   double getValue(Map item, String key) {
//     final String uniqueKey = _controllerKey(item, key);
//
//     final controller = controllers[uniqueKey];
//
//     if (controller != null) {
//       return double.tryParse(controller.text) ?? 0;
//     }
//
//     return double.tryParse(item[key]?.toString() ?? "0") ?? 0;
//   }
//
//   /// ============================================================
//   /// LOAD EDIT DATA
//   /// ============================================================
//
//   Future<void> loadEditData(int id) async {
//     final response = await ApiHelper().getRequestWithId(
//       ApiConstants.Approval_dailog_list,
//       id,
//     );
//
//     debugPrint("DETAIL API => ${response?.data}");
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data["data"];
//
//       final List apiItems = data["items"] ?? [];
//
//       if (mounted) {
//         AppMessage.success(
//           context,
//           data["message"] ?? "Data Loaded Successfully",
//         );
//       }
//
//       items.clear();
//       uniqueItems.clear();
//
//       for (final controller in controllers.values) {
//         controller.dispose();
//       }
//
//       controllers.clear();
//
//       for (final e in apiItems) {
//         // 🔥 ONLY "pending" STATUS ITEMS
//         final String itemStatus =
//             e["status"]?.toString().trim().toLowerCase() ?? "";
//
//         debugPrint("ITEM ${e["qr_code"]} => status: '$itemStatus'");
//
//         if (itemStatus != "pending") {
//           continue;
//         }
//
//         final Map<String, dynamic> itemData = {
//           "id": e["id"],
//           "itemset_id": e["itemset_id"],
//           "item_name": e["item_name"] ?? "",
//           "huid": e["HUID"] ?? e["huid"] ?? "",
//           "qr_code": e["qr_code"] ?? "",
//           "gross_weight": e["gross_weight"] ?? "",
//           "other_weight": e["other_weight"] ?? "",
//           "net_weight": e["net_weight"] ?? "",
//           "purity": e["purity"] ?? "",
//           "waste": e["waste_percent"] ?? "",
//           "net_purity": e["net_purity"] ?? "",
//           "fine_weight": e["fine_weight"] ?? e["total_fine_weight"] ?? "",
//           "metal_rate": e["metal_rate"] ?? "",
//           "metal_amount": e["metal_amount"] ?? "",
//           "other_amount": e["other_amount"] ?? "",
//           "labour_rate": e["labour_rate"] ?? "",
//           "labour_amount": e["labour_amount"] ?? "",
//           "total_amount": e["total_amount"] ?? "",
//           "expanded": false,
//           "source": "manual",
//           "status": itemStatus,
//         };
//
//         items.insert(0, itemData);
//
//         _initializeItemControllers(itemData);
//       }
//
//       updateFinalItems();
//     }
//   }
//
//   void _initializeItemControllers(Map<String, dynamic> item) {
//     for (final key in [
//       "gross_weight",
//       "other_weight",
//       "net_weight",
//       "purity",
//       "waste",
//       "net_purity",
//       "fine_weight",
//       "metal_rate",
//       "metal_amount",
//       "labour_rate",
//       "labour_amount",
//       "other_amount",
//       "total_amount",
//     ]) {
//       getController(item, key);
//     }
//   }
//
//   /// ============================================================
//   /// OTHER CHARGE API
//   /// ============================================================
//
//   Future<void> getApprovalDetails(
//     dynamic id,
//     Map<String, dynamic> mainItem,
//   ) async {
//     FocusManager.instance.primaryFocus?.unfocus();
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final response = await ApiHelper().getRequest(ApiConstants.other_charge);
//
//     if (mounted && Navigator.canPop(context)) {
//       Navigator.pop(context);
//     }
//
//     if (response != null && response.statusCode == 200) {
//       final data = response.data;
//
//       final List apiList = data["data"] is List ? data["data"] : [];
//
//       showOtherChargesPopup(mainItem, apiList);
//     } else {
//       if (!mounted) return;
//
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
//     }
//   }
//
//   /// ============================================================
//   /// BUILD DISPLAY ITEMS
//   /// ============================================================
//
//   List<Map<String, dynamic>> _getDisplayItems() {
//     final List<Map<String, dynamic>> combinedItemsList = [
//       ...items,
//       ...cartItems.map<Map<String, dynamic>>((e) {
//         return {
//           "id": e["cart_id"] ?? e["id"],
//           "cart_id": e["cart_id"],
//           "itemset_id": e["itemset_id"],
//           "item_name": e["item_name"] ?? "",
//           "huid": e["huid"] ?? "-",
//           "qr_code": e["qr_code"] ?? "-",
//           "gross_weight": e["gross_weight"]?.toString() ?? "0",
//           "other_weight": e["other_weight"]?.toString() ?? "0",
//           "net_weight": e["net_weight"]?.toString() ?? "0",
//           "purity": e["purity"]?.toString() ?? "0",
//           "waste": e["waste"]?.toString() ?? "0",
//           "net_purity": e["net_purity"]?.toString() ?? "0",
//           "fine_weight": e["fine_weight"]?.toString() ?? "0",
//           "metal_rate": e["metal_rate"]?.toString() ?? "0",
//           "metal_amount": e["metal_amount"]?.toString() ?? "0",
//           "labour_rate": e["labour_rate"]?.toString() ?? "0",
//           "labour_amount": e["labour_amount"]?.toString() ?? "0",
//           "other_amount":
//               e["sale_other"]?.toString() ??
//               e["other_amount"]?.toString() ??
//               "0",
//           "total_amount": e["total_amount"]?.toString() ?? "0",
//           "expanded": false,
//           "source": "scan",
//         };
//       }),
//     ];
//
//     final map = <String, Map<String, dynamic>>{};
//
//     for (final item in combinedItemsList) {
//       final id = item["itemset_id"] ?? item["id"];
//
//       if (id == null) continue;
//
//       map[id.toString()] = item;
//     }
//
//     return map.values.toList().reversed.toList();
//   }
//
//   /// ============================================================
//   /// BUILD
//   /// ============================================================
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//
//     final width = size.width;
//
//     final isMobile = width < 600;
//
//     final List<Map<String, dynamic>> displayItems = _getDisplayItems();
//
//     return PopScope(
//       canPop: false,
//       onPopInvokedWithResult: (didPop, result) async {
//         if (didPop) return;
//
//         FocusManager.instance.primaryFocus?.unfocus();
//
//         await _stopScanner();
//
//         if (!mounted) return;
//
//         Navigator.pop(context, true);
//       },
//       child: Scaffold(
//         resizeToAvoidBottomInset: true,
//         backgroundColor: AppColors.white,
//         body: Stack(
//           children: [
//             /// ======================================================
//             /// MAIN UI
//             /// ======================================================
//             Column(
//               children: [
//                 SizedBox(height: MediaQuery.of(context).padding.top + 40),
//
//                 Expanded(
//                   child: showScannerFull
//                       ? Column(
//                           children: [
//                             const SizedBox(height: 10),
//
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 5,
//                               ),
//                               child: Consumer<ItemProvider>(
//                                 builder: (context, provider, child) {
//                                   final customers = provider.customers;
//
//                                   return DropdownButtonFormField<String>(
//                                     value:
//                                         (selectedItem != null &&
//                                             customers.any(
//                                               (e) =>
//                                                   e["id"].toString() ==
//                                                   selectedItem,
//                                             ))
//                                         ? selectedItem
//                                         : null,
//                                     icon: const Icon(
//                                       Icons.keyboard_arrow_down,
//                                       color: Colors.black,
//                                     ),
//                                     dropdownColor: Colors.white,
//                                     hint: Text(
//                                       "Select Customer",
//                                       style: TextStyle(
//                                         color: Colors.grey.shade600,
//                                       ),
//                                     ),
//                                     style: const TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 14,
//                                     ),
//                                     decoration: InputDecoration(
//                                       filled: true,
//                                       fillColor: Colors.white,
//                                       contentPadding:
//                                           const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 0,
//                                           ),
//                                       border: OutlineInputBorder(
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                         borderRadius: BorderRadius.circular(5),
//                                       ),
//                                       enabledBorder: OutlineInputBorder(
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                         borderRadius: BorderRadius.circular(5),
//                                       ),
//                                       focusedBorder: OutlineInputBorder(
//                                         borderSide: BorderSide(
//                                           color: AppColors.border,
//                                         ),
//                                         borderRadius: BorderRadius.circular(5),
//                                       ),
//                                     ),
//                                     items: customers
//                                         .map<DropdownMenuItem<String>>((item) {
//                                           return DropdownMenuItem<String>(
//                                             value: item["id"].toString(),
//                                             child: Text(
//                                               item["name"] ?? "",
//                                               style: const TextStyle(
//                                                 color: Colors.black,
//                                               ),
//                                             ),
//                                           );
//                                         })
//                                         .toList(),
//                                     onChanged: (value) {
//                                       setState(() {
//                                         selectedItem = value;
//
//                                         final selectedData = customers
//                                             .firstWhere(
//                                               (user) =>
//                                                   user["id"].toString() ==
//                                                   value,
//                                               orElse: () => {},
//                                             );
//
//                                         if (selectedData.isNotEmpty) {
//                                           selectedCompanyId =
//                                               selectedData["company_id"]
//                                                   ?.toString();
//
//                                           selectedUserId = selectedData["id"]
//                                               ?.toString();
//                                         }
//                                       });
//                                     },
//                                   );
//                                 },
//                               ),
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             /// SCANNER
//                             Center(
//                               child: Stack(
//                                 children: [
//                                   Container(
//                                     height: 150,
//                                     width: 150,
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(16),
//                                       color: Colors.black,
//                                       boxShadow: [
//                                         BoxShadow(
//                                           color: Colors.greenAccent.withOpacity(
//                                             0.4,
//                                           ),
//                                           blurRadius: 20,
//                                         ),
//                                       ],
//                                     ),
//                                     child: Stack(
//                                       children: [
//                                         _buildScannerSection(),
//                                         const _ScannerLineAnimation(),
//                                       ],
//                                     ),
//                                   ),
//
//                                   Positioned(
//                                     top: 6,
//                                     right: 6,
//                                     child: GestureDetector(
//                                       onTap: () async {
//                                         await _stopScanner();
//
//                                         if (!mounted) {
//                                           return;
//                                         }
//
//                                         setState(() {
//                                           showScannerFull = false;
//
//                                           lastCode = null;
//
//                                           isBusy = false;
//                                         });
//                                       },
//                                       child: Container(
//                                         padding: const EdgeInsets.all(4),
//                                         decoration: BoxDecoration(
//                                           color: Colors.black.withOpacity(0.5),
//                                           shape: BoxShape.circle,
//                                           border: Border.all(
//                                             color: Colors.white,
//                                             width: 1.5,
//                                           ),
//                                         ),
//                                         child: const Icon(
//                                           Icons.close,
//                                           size: 10,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//
//                             const SizedBox(height: 5),
//
//                             Container(
//                               margin: const EdgeInsets.only(top: 10),
//                               width: double.infinity,
//                               height: 2,
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark.withOpacity(0.1),
//                                     AppColors.primaryDark,
//                                     AppColors.secondaryDark.withOpacity(0.4),
//                                     AppColors.primaryDark.withOpacity(0.1),
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//
//                             Expanded(
//                               child: displayItems.isEmpty
//                                   ? const Center(child: Text("No Data Added"))
//                                   : ListView.builder(
//                                       padding: const EdgeInsets.fromLTRB(
//                                         12,
//                                         12,
//                                         12,
//                                         12,
//                                       ),
//                                       keyboardDismissBehavior:
//                                           ScrollViewKeyboardDismissBehavior
//                                               .manual,
//                                       itemCount: displayItems.length,
//                                       itemBuilder: (context, index) {
//                                         return approvalItemCard(
//                                           displayItems[index],
//                                           index,
//                                           displayItems.length,
//                                         );
//                                       },
//                                     ),
//                             ),
//                           ],
//                         )
//                       : Column(
//                           children: [
//                             const SizedBox(height: 0),
//
//                             Expanded(
//                               child: SingleChildScrollView(
//                                 physics: const BouncingScrollPhysics(),
//                                 keyboardDismissBehavior:
//                                     ScrollViewKeyboardDismissBehavior.manual,
//                                 child: Column(
//                                   children: [
//                                     filterWidget(),
//
//                                     Container(
//                                       margin: const EdgeInsets.only(top: 10),
//                                       width: double.infinity,
//                                       height: 2,
//                                       decoration: BoxDecoration(
//                                         gradient: LinearGradient(
//                                           colors: [
//                                             AppColors.primaryDark.withOpacity(
//                                               0.1,
//                                             ),
//                                             AppColors.primaryDark,
//                                             AppColors.secondaryDark.withOpacity(
//                                               0.4,
//                                             ),
//                                             AppColors.primaryDark.withOpacity(
//                                               0.1,
//                                             ),
//                                           ],
//                                         ),
//                                         borderRadius: BorderRadius.circular(10),
//                                       ),
//                                     ),
//
//                                     displayItems.isEmpty
//                                         ? const Padding(
//                                             padding: EdgeInsets.only(top: 50),
//                                             child: Center(
//                                               child: Text(
//                                                 "No Data Found",
//                                                 style: TextStyle(
//                                                   fontSize: 16,
//                                                   fontWeight: FontWeight.w500,
//                                                   color: Colors.grey,
//                                                 ),
//                                               ),
//                                             ),
//                                           )
//                                         : ListView.builder(
//                                             padding: const EdgeInsets.fromLTRB(
//                                               0,
//                                               12,
//                                               0,
//                                               12,
//                                             ),
//                                             shrinkWrap: true,
//                                             physics:
//                                                 const NeverScrollableScrollPhysics(),
//                                             keyboardDismissBehavior:
//                                                 ScrollViewKeyboardDismissBehavior
//                                                     .manual,
//                                             itemCount: displayItems.length,
//                                             itemBuilder: (context, index) {
//                                               return approvalItemCard(
//                                                 displayItems[index],
//                                                 index,
//                                                 displayItems.length,
//                                               );
//                                             },
//                                           ),
//
//                                     const SizedBox(height: 80),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                 ),
//
//                 /// SUMMARY
//                 buildSummaryRow(),
//
//                 /// SAVE BUTTON
//                 InkWell(
//                   onTap: isProcessing
//                       ? null
//                       : () async {
//                           FocusManager.instance.primaryFocus?.unfocus();
//
//                           _debounce?.cancel();
//
//                           setState(() {
//                             isProcessing = true;
//                           });
//
//                           try {
//                             if (showScannerFull) {
//                               await _stopScanner();
//                             }
//
//                             updateFinalItems(refreshUI: false);
//
//                             if (isEditMode) {
//                               await UpdateApproval();
//                             } else {
//                               await saveApproval();
//                             }
//                           } finally {
//                             if (mounted) {
//                               setState(() {
//                                 isProcessing = false;
//                               });
//                             }
//                           }
//                         },
//                   borderRadius: BorderRadius.circular(10),
//                   child: Padding(
//                     padding: const EdgeInsets.only(bottom: 8),
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
//                       child: Center(
//                         child: Text(
//                           isProcessing
//                               ? "Please Wait..."
//                               : isEditMode
//                               ? "Update Approval"
//                               : "Save Approval",
//                           style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             /// ======================================================
//             /// APPBAR
//             /// ======================================================
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
//                     Text(
//                       isEditMode ? "Update Approval" : "Create Approval",
//                       style: const TextStyle(
//                         color: Colors.black,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: InkWell(
//                         onTap: () async {
//                           FocusManager.instance.primaryFocus?.unfocus();
//
//                           await _stopScanner();
//
//                           if (!mounted) {
//                             return;
//                           }
//
//                           Navigator.pop(context, true);
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
//                     // Align(
//                     //   alignment: Alignment.centerRight,
//                     //   child: Container(
//                     //     padding: EdgeInsets.all(isMobile ? 6 : 8),
//                     //     decoration: BoxDecoration(
//                     //       color: Colors.white,
//                     //       borderRadius: BorderRadius.circular(8),
//                     //       boxShadow: [
//                     //         BoxShadow(
//                     //           color: AppColors.shadow,
//                     //           blurRadius: 20,
//                     //           offset: const Offset(5, 10),
//                     //         ),
//                     //       ],
//                     //     ),
//                     //     child: Stack(
//                     //       clipBehavior: Clip.none,
//                     //       children: [
//                     //         Icon(
//                     //           Icons.notifications_none,
//                     //           size: isMobile ? 22 : 24,
//                     //           color: Colors.red,
//                     //         ),
//                     //         Positioned(
//                     //           right: -2,
//                     //           top: -2,
//                     //           child: Container(
//                     //             height: 8,
//                     //             width: 8,
//                     //             decoration: const BoxDecoration(
//                     //               color: Colors.red,
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
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// EDITABLE FIELD
//   /// ============================================================
//
//   bool isEditableField(String key) {
//     return [
//       "gross_weight",
//       "other_weight",
//       "purity",
//       "waste",
//       "labour_rate",
//       "metal_rate",
//     ].contains(key);
//   }
//
//   /// ============================================================
//   /// ITEM CARD
//   /// ============================================================
//
//   Widget approvalItemCard(
//     Map<String, dynamic> item,
//     int index,
//     int totalCount,
//   ) {
//     final bool isExpanded = item["expanded"] ?? false;
//
//     final String itemName =
//         item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";
//
//     final String qrCode =
//         item["qr_code"]?.toString() ??
//         item["itemset"]?["qr_code"]?.toString() ??
//         item["code"]?.toString() ??
//         item["itemset"]?["barcode"]?.toString() ??
//         "-";
//
//     return Container(
//       key: ValueKey(item["itemset_id"] ?? item["id"]),
//       margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(5),
//         border: Border.all(color: AppColors.border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// HEADER
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//             decoration: BoxDecoration(
//               color: AppColors.primaryDark.withOpacity(0.10),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(5),
//                 topRight: Radius.circular(5),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   width: 26,
//                   height: 26,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: AppColors.gradientBlue,
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                   child: Text(
//                     "${totalCount - index}",
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 11,
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         "ITEM",
//                         style: TextStyle(
//                           color: Colors.black45,
//                           fontSize: 9,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 1),
//                       Text(
//                         itemName,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           color: Colors.black,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(width: 8),
//
//                 Container(
//                   constraints: const BoxConstraints(maxWidth: 130),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 5,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(5),
//                     border: Border.all(color: AppColors.border),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(
//                         Icons.qr_code_2,
//                         size: 14,
//                         color: AppColors.primaryDark,
//                       ),
//                       const SizedBox(width: 4),
//                       Flexible(
//                         child: Text(
//                           qrCode,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: Colors.black87,
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(width: 7),
//
//                 InkWell(
//                   onTap: () async {
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     final idToRemove = item["itemset_id"] ?? item["id"];
//
//                     items.removeWhere(
//                       (e) =>
//                           (e["itemset_id"] ?? e["id"])?.toString() ==
//                           idToRemove?.toString(),
//                     );
//
//                     if (item["source"] == "scan") {
//                       final cartId = item["cart_id"] ?? item["id"];
//
//                       cartItems.removeWhere(
//                         (e) =>
//                             (e["cart_id"] ?? e["id"])?.toString() ==
//                             cartId?.toString(),
//                       );
//
//                       if (cartId != null) {
//                         await deleteUser(cartId.toString());
//                       }
//                     }
//
//                     updateFinalItems();
//                   },
//                   borderRadius: BorderRadius.circular(5),
//                   child: Container(
//                     width: 27,
//                     height: 27,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xffFF8A80), Color(0xffD32F2F)],
//                       ),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: const Icon(
//                       Icons.delete_outline,
//                       color: Colors.white,
//                       size: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           if (!isExpanded)
//             Container(
//               padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 physics: const BouncingScrollPhysics(),
//                 keyboardDismissBehavior:
//                     ScrollViewKeyboardDismissBehavior.manual,
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     _miniField("Gross", item, "gross_weight",index),
//                     _miniField("Other", item, "other_weight",index),
//                     _miniField("Net", item, "net_weight",index),
//                     _miniField("Purity", item, "purity",index),
//                     _miniField("Waste", item, "waste",index),
//                     _miniField("Net Purity", item, "net_purity",index),
//                     _miniField("Fine", item, "fine_weight",index),
//                     _miniField("Metal Rate", item, "metal_rate",index),
//                     _miniField("Metal Amount", item, "metal_amount",index),
//                     _miniField("Labour Rate", item, "labour_rate",index),
//                     _miniField("Labour Amount", item, "labour_amount",index),
//                     _miniField("Other Amount", item, "other_amount",index),
//                     _miniField("Total Amount", item, "total_amount",index),
//                   ],
//                 ),
//               ),
//             ),
//
//           if (isExpanded)
//             Padding(
//               padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _inputField("Other Wt", item, "other_weight"),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(child: _inputField("Purity", item, "purity")),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Expanded(child: _inputField("Waste %", item, "waste")),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: _inputField("Net Purity", item, "net_purity"),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _inputField("Fine Wt", item, "fine_weight"),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: _inputField("Metal Rate", item, "metal_rate"),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// FILTER
//   /// ============================================================
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
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
//             decoration: BoxDecoration(
//               color: AppColors.background,
//               border: Border.all(color: AppColors.border),
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Consumer<ItemProvider>(
//               builder: (context, provider, child) {
//                 final List<Map<String, dynamic>> customers = provider.customers
//                     .map<Map<String, dynamic>>(
//                       (e) => Map<String, dynamic>.from(e),
//                     )
//                     .toList();
//
//                 Map<String, dynamic>? selectedCustomer;
//
//                 if (selectedItem != null) {
//                   try {
//                     selectedCustomer = customers.firstWhere(
//                       (e) => e["id"]?.toString() == selectedItem.toString(),
//                     );
//                   } catch (_) {
//                     selectedCustomer = null;
//                   }
//                 }
//
//                 return PremiumSearchableDropdown<Map<String, dynamic>>(
//                   label: "",
//                   hint: "Select Customer",
//                   items: customers,
//                   value: selectedCustomer,
//                   prefixIcon: Icons.person_outline_rounded,
//                   dropdownMaxHeight: 350,
//                   itemLabel: (customer) {
//                     return customer["name"]?.toString() ?? "";
//                   },
//                   searchText: (customer) {
//                     final name = customer["name"]?.toString() ?? "";
//
//                     final mobile =
//                         customer["mobile"]?.toString() ??
//                         customer["mobile_no"]?.toString() ??
//                         customer["phone"]?.toString() ??
//                         "";
//
//                     final code =
//                         customer["code"]?.toString() ??
//                         customer["customer_code"]?.toString() ??
//                         "";
//
//                     return "$name $mobile $code";
//                   },
//                   onChanged: (customer) {
//                     if (customer == null) {
//                       setState(() {
//                         selectedItem = null;
//
//                         selectedCompanyId = null;
//
//                         selectedUserId = null;
//                       });
//
//                       return;
//                     }
//
//                     setState(() {
//                       selectedItem = customer["id"]?.toString();
//
//                       selectedCompanyId = customer["company_id"]?.toString();
//
//                       selectedUserId = customer["id"]?.toString();
//                     });
//                   },
//                 );
//               },
//             ),
//           ),
//
//           const SizedBox(height: 5),
//
//           Column(
//             children: [
//               TextField(
//                 controller: searchController,
//                 focusNode: searchFocusNode,
//                 autofocus: false,
//                 keyboardType: TextInputType.text,
//                 textInputAction: TextInputAction.search,
//                 onChanged: (value) {
//                   _debounce?.cancel();
//
//                   final keyword = value.trim();
//
//                   if (keyword.isEmpty) {
//                     setState(() {
//                       searchResults.clear();
//                     });
//
//                     return;
//                   }
//
//                   _debounce = Timer(
//                     const Duration(milliseconds: 500),
//                     () async {
//                       if (!mounted) {
//                         return;
//                       }
//
//                       await searchItemsApi(keyword);
//                     },
//                   );
//                 },
//                 onSubmitted: (value) async {
//                   final keyword = value.trim();
//
//                   if (keyword.isEmpty) {
//                     return;
//                   }
//
//                   await searchItemsApi(keyword);
//                 },
//                 decoration: InputDecoration(
//                   hintText: "Search (HUID / QR)",
//                   hintStyle: TextStyle(color: Colors.grey.shade600),
//                   prefixIcon: const Icon(Icons.search, color: Colors.black54),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       Icons.search_rounded,
//                       color: AppColors.primaryDark,
//                     ),
//                     onPressed: () async {
//                       final keyword = searchController.text.trim();
//
//                       if (keyword.isEmpty) {
//                         return;
//                       }
//
//                       await searchItemsApi(keyword);
//                     },
//                   ),
//                   filled: true,
//                   fillColor: Colors.white,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 0),
//                   border: OutlineInputBorder(
//                     borderSide: BorderSide(color: AppColors.border),
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: AppColors.border),
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: AppColors.primaryDark),
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                 ),
//               ),
//
//               if (searchController.text.isNotEmpty)
//                 Container(
//                   margin: const EdgeInsets.only(top: 0),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.grey.shade300),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.08),
//                         blurRadius: 6,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   constraints: const BoxConstraints(maxHeight: 200),
//                   child: isLoading
//                       ? const Padding(
//                           padding: EdgeInsets.all(0),
//                           child: Center(child: CircularProgressIndicator()),
//                         )
//                       : searchResults.isEmpty
//                       ? const Padding(
//                           padding: EdgeInsets.all(12),
//                           child: Center(
//                             child: Text(
//                               "No items found",
//                               style: TextStyle(color: Colors.grey),
//                             ),
//                           ),
//                         )
//                       : ListView.builder(
//                           shrinkWrap: true,
//                           keyboardDismissBehavior:
//                               ScrollViewKeyboardDismissBehavior.manual,
//                           padding: EdgeInsets.zero,
//                           itemCount: searchResults.length,
//                           itemBuilder: (context, index) {
//                             final item = searchResults[index];
//
//                             final itemName =
//                                 item["item"]?["item_name"] ?? "Item";
//
//                             final huid = item["HUID"] ?? "-";
//
//                             final qr = item["qr_code"] ?? "-";
//
//                             return InkWell(
//                               onTap: () {
//                                 FocusManager.instance.primaryFocus?.unfocus();
//
//                                 addItemToCard(item);
//                               },
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 10,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   border: Border(
//                                     bottom: BorderSide(
//                                       color: index == searchResults.length - 1
//                                           ? Colors.transparent
//                                           : Colors.grey.shade200,
//                                     ),
//                                   ),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             itemName,
//                                             style: const TextStyle(
//                                               fontSize: 14,
//                                               fontWeight: FontWeight.w600,
//                                               color: Colors.black,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 2),
//                                           Text(
//                                             "HUID: $huid | QR: $qr",
//                                             style: const TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.grey,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     const Icon(
//                                       Icons.add_circle,
//                                       color: Color(0xffC8A96A),
//                                       size: 20,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                 ),
//             ],
//           ),
//
//           const SizedBox(height: 8),
//
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: remarksController,
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   decoration: InputDecoration(
//                     hintText: "Enter Remarks",
//                     hintStyle: TextStyle(color: Colors.grey.shade600),
//                     filled: true,
//                     fillColor: Colors.white,
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 14,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide(color: AppColors.border),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 8),
//
//           Row(
//             children: [
//               Expanded(
//                 flex: 1,
//                 child: InkWell(
//                   onTap: () async {
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     _debounce?.cancel();
//
//                     setState(() {
//                       showScannerFull = true;
//
//                       lastCode = null;
//
//                       isBusy = false;
//                     });
//
//                     await Future.delayed(const Duration(milliseconds: 150));
//
//                     if (!mounted) {
//                       return;
//                     }
//
//                     await _startScanner();
//                   },
//                   borderRadius: BorderRadius.circular(5),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppColors.primaryDark.withOpacity(0.7),
//                           AppColors.border.withOpacity(0.7),
//                           AppColors.secondaryDark.withOpacity(0.7),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: const Center(
//                       child: Icon(
//                         Icons.qr_code_scanner,
//                         color: Colors.black,
//                         size: 22,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// LOCAL FILTER
//   /// ============================================================
//
//   void applyLocalFilter() {
//     final search = searchController.text.toLowerCase();
//
//     final from = fromDateController.text;
//
//     final to = toDateController.text;
//
//     DateTime? fromDate = from.isNotEmpty
//         ? parseSafeDate(formatDateForApi(from))
//         : null;
//
//     DateTime? toDate = to.isNotEmpty
//         ? parseSafeDate(formatDateForApi(to))
//         : null;
//
//     setState(() {
//       userlist = allItems.where((item) {
//         final name = item["customer_name"]?.toString().toLowerCase() ?? "";
//
//         final matchesSearch = name.contains(search);
//
//         final dateStr = item["approval_date"];
//
//         if (dateStr == null) {
//           return false;
//         }
//
//         final itemDate = DateTime.parse(dateStr);
//
//         if (fromDate != null && itemDate.isBefore(fromDate)) {
//           return false;
//         }
//
//         if (toDate != null && itemDate.isAfter(toDate)) {
//           return false;
//         }
//
//         return matchesSearch;
//       }).toList();
//     });
//   }
//
//   DateTime parseSafeDate(String dateStr) {
//     final parts = dateStr.split("-");
//
//     final year = parts[0];
//
//     final month = parts[1].padLeft(2, '0');
//
//     final day = parts[2].padLeft(2, '0');
//
//     return DateTime.parse("$year-$month-$day");
//   }
//
//   String formatDateForApi(String input) {
//     if (input.isEmpty) {
//       return "";
//     }
//
//     final parts = input.split("-");
//
//     return "${parts[2]}-${parts[1]}-${parts[0]}";
//   }
//
//   /// ============================================================
//   /// MINI FIELD
//   /// ============================================================
//
//   Widget _miniField(String title, Map<String, dynamic> item, String key,int index,) {
//     final bool isOtherField = key == "other_amount";
//
//     final bool isMetalRateField = key == "metal_rate";
//
//     final bool isLabourRateField = key == "labour_rate";
//     final bool isPurityField = key == "purity";
//     final bool isWasteField = key == "waste";
//
//     final controller = getController(item, key);
//
//     final bool editable = key == "metal_rate"
//         ? (item["manual_metal"] ?? true)
//         : key == "labour_rate"
//         ? (item["manual_labour"] ?? true)
//         : isEditableField(key);
//
//     final bool canEdit = key == "metal_rate"
//         ? (item["manual_metal"] ?? true)
//         : key == "labour_rate"
//         ? (item["manual_labour"] ?? true)
//         : isEditableField(key);
//
//     return Container(
//       width: 105,
//       margin: const EdgeInsets.only(right: 7),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.only(
//               left: 2,
//               right: 2,
//               bottom: 4,
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     title,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 10,
//                       color: Colors.black54,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//
//                 // ========================================================
//                 // ONLY FIRST ROW + METAL/LABOUR RATE
//                 // ========================================================
//
//                 if (index == 0 &&
//                     (isMetalRateField ||
//                         isLabourRateField ||
//                         isOtherField ||
//                         isPurityField ||
//                         isWasteField))
//                   InkWell(
//                     onTap: () async {
//                       applyToAllItems(key, controller.text);
//                     },
//                     borderRadius: BorderRadius.circular(4),
//                     child: Container(
//                       height: 18,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 5,
//                       ),
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(
//                         color: const Color(0xffC8A96A),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: const Text(
//                         "All",
//                         style: TextStyle(
//                           fontSize: 8,
//                           color: Colors.white,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           Container(
//             height: 36,
//             decoration: BoxDecoration(
//               color: editable ? Colors.white : Colors.grey.shade50,
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(color: AppColors.border),
//             ),
//             child: Stack(
//               alignment: Alignment.centerRight,
//               children: [
//                 TextFormField(
//                   controller: controller,
//                   readOnly: !canEdit,
//                   keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true,
//                   ),
//                   textInputAction: TextInputAction.done,
//                   enableInteractiveSelection: canEdit,
//                   showCursor: canEdit,
//                   canRequestFocus: canEdit,
//                   textAlign: TextAlign.left,
//                   style: TextStyle(
//                     color: editable ? Colors.black : Colors.black54,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                   onTap: () {
//                     if (!canEdit) {
//                       return;
//                     }
//
//                     if (controller.text == "0" ||
//                         controller.text == "0.0" ||
//                         controller.text == "0.00" ||
//                         controller.text == "0.000") {
//                       controller.clear();
//                     } else {
//                       controller.selection = TextSelection(
//                         baseOffset: 0,
//                         extentOffset: controller.text.length,
//                       );
//                     }
//                   },
//                   onChanged: (val) {
//                     item[key] = val;
//
//                     calculateItem(item);
//                     setState(() {});
//                   },
//                   onEditingComplete: () {
//                     if (controller.text.trim().isEmpty) {
//                       controller.text = "0";
//
//                       item[key] = "0";
//                     }
//
//                     calculateItem(item);
//
//                     updateFinalItems();
//
//
//                     FocusScope.of(context).unfocus();
//                   },
//                   onTapOutside: (_) {
//                     if (!canEdit) {
//                       return;
//                     }
//
//                     if (controller.text.trim().isEmpty) {
//                       controller.text = "0";
//
//                       item[key] = "0";
//                     }
//
//                     calculateItem(item);
//
//                     // FocusScope.of(
//                     //   context,
//                     // ).unfocus();
//
//                     updateFinalItems();
//                   },
//                   decoration: InputDecoration(
//                     isDense: true,
//                     contentPadding: EdgeInsets.only(
//                       left: 8,
//                       right:
//                           (isOtherField ||
//                               isMetalRateField ||
//                               isLabourRateField)
//                           ? 30
//                           : 8,
//                       top: 9,
//                       bottom: 9,
//                     ),
//                     border: InputBorder.none,
//                     enabledBorder: InputBorder.none,
//                     focusedBorder: InputBorder.none,
//                   ),
//                 ),
//
//                 /// OTHER AMOUNT
//                 if (isOtherField)
//                   Positioned(
//                     right: 4,
//                     child: InkWell(
//                       onTap: () async {
//                         FocusManager.instance.primaryFocus?.unfocus();
//
//                         await getApprovalDetails(item["id"], item);
//                       },
//                       borderRadius: BorderRadius.circular(4),
//                       child: Container(
//                         width: 22,
//                         height: 22,
//                         alignment: Alignment.center,
//                         decoration: BoxDecoration(
//                           color: const Color(0xffC8A96A),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: const Icon(
//                           Icons.add,
//                           size: 15,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 /// METAL CHECKBOX
//                 if (isMetalRateField)
//                   Positioned(
//                     right: 3,
//                     child: SizedBox(
//                       height: 25,
//                       width: 25,
//                       child: Transform.scale(
//                         scale: 0.78,
//                         child: Checkbox(
//                           materialTapTargetSize:
//                               MaterialTapTargetSize.shrinkWrap,
//                           value:
//                               (double.tryParse(
//                                     controller.text.isEmpty
//                                         ? "0"
//                                         : controller.text,
//                                   ) ??
//                                   0) >
//                               0,
//                           onChanged: (val) {
//                             if (val == true) {
//                               if ((double.tryParse(
//                                         controller.text.isEmpty
//                                             ? "0"
//                                             : controller.text,
//                                       ) ??
//                                       0) ==
//                                   0) {
//                                 controller.text = "1";
//
//                                 item["metal_rate"] = "1";
//                               }
//                             } else {
//                               controller.text = "0.00";
//
//                               item["metal_rate"] = "0.00";
//                             }
//
//                             calculateItem(item);
//
//                             updateFinalItems();
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//
//
//
//
//                 /// LABOUR CHECKBOX
//                 if (isLabourRateField)
//                   Positioned(
//                     right: 3,
//                     child: SizedBox(
//                       height: 25,
//                       width: 25,
//                       child: Transform.scale(
//                         scale: 0.78,
//                         child: Checkbox(
//                           materialTapTargetSize:
//                               MaterialTapTargetSize.shrinkWrap,
//                           value:
//                               (double.tryParse(
//                                     controller.text.isEmpty
//                                         ? "0"
//                                         : controller.text,
//                                   ) ??
//                                   0) >
//                               0,
//                           onChanged: (val) {
//                             if (val == false) {
//                               controller.text = "0.00";
//
//                               item["labour_rate"] = "0.00";
//                             } else {
//                               if ((double.tryParse(
//                                         controller.text.isEmpty
//                                             ? "0"
//                                             : controller.text,
//                                       ) ??
//                                       0) ==
//                                   0) {
//                                 controller.text = "1";
//
//                                 item["labour_rate"] = "1";
//                               }
//                             }
//
//                             calculateItem(item);
//
//                             updateFinalItems();
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// CALCULATE ITEM
//   /// ============================================================
//
//   void calculateItem(Map<String, dynamic> item) {
//     final grossController = getController(item, "gross_weight");
//
//     final otherController = getController(item, "other_weight");
//
//     final purityController = getController(item, "purity");
//
//     final wasteController = getController(item, "waste");
//
//     final metalRateController = getController(item, "metal_rate");
//
//     final labourRateController = getController(item, "labour_rate");
//
//     final otherAmountController = getController(item, "other_amount");
//
//     final double gross = double.tryParse(grossController.text) ?? 0;
//
//     final double other = double.tryParse(otherController.text) ?? 0;
//
//     final double purity = double.tryParse(purityController.text) ?? 0;
//
//     final double waste = double.tryParse(wasteController.text) ?? 0;
//
//     final double metalRate = double.tryParse(metalRateController.text) ?? 0;
//
//     final double labourRate = double.tryParse(labourRateController.text) ?? 0;
//
//     final double otherAmount = double.tryParse(otherAmountController.text) ?? 0;
//
//     final double net = gross - other;
//
//     final double netPurity = purity + waste;
//
//     final double fineWeight = net * (netPurity / 100);
//
//     final double metalAmount = net * metalRate;
//
//     final double labourAmount = net * labourRate;
//
//     final double totalAmount = metalAmount + labourAmount + otherAmount;
//
//     item["gross_weight"] = grossController.text;
//
//     item["other_weight"] = otherController.text;
//
//     item["purity"] = purityController.text;
//
//     item["waste"] = wasteController.text;
//
//     item["metal_rate"] = metalRateController.text;
//
//     item["labour_rate"] = labourRateController.text;
//
//     item["other_amount"] = otherAmountController.text;
//
//     item["net_weight"] = net.toStringAsFixed(3);
//
//     item["net_purity"] = netPurity.toStringAsFixed(2);
//
//     item["fine_weight"] = fineWeight.toStringAsFixed(3);
//
//     item["metal_amount"] = metalAmount.toStringAsFixed(2);
//
//     item["labour_amount"] = labourAmount.toStringAsFixed(2);
//
//     item["total_amount"] = totalAmount.toStringAsFixed(2);
//
//     updateController(item, "net_weight");
//
//     updateController(item, "net_purity");
//
//     updateController(item, "fine_weight");
//
//     updateController(item, "metal_amount");
//
//     updateController(item, "labour_amount");
//
//     updateController(item, "total_amount");
//   }
//
//   // ============================================================
// // APPLY RATE TO ALL ITEMS (Metal Rate / Labour Rate)
// // ============================================================
//   void applyToAllItems(String key, String value) {
//     if (value.trim().isEmpty) return;
//
//     // 🔥 UPDATE ALL "items" (manual/search added)
//     for (final item in items) {
//       getController(item, key).text = value;
//       item[key] = value;
//       calculateItem(item);
//     }
//
//     // 🔥 UPDATE ALL "cartItems" (scanned items)
//     for (final item in cartItems) {
//       getController(item, key).text = value;
//       item[key] = value;
//       calculateItem(item);
//     }
//
//     updateFinalItems();
//
//     if (mounted) {
//       setState(() {});
//     }
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           "${key == "metal_rate" ? "Metal Rate" : "Labour Rate"} applied to all items",
//         ),
//         duration: const Duration(milliseconds: 900),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// BUILD ITEM DATA
//   /// ============================================================
//
//   Map<String, dynamic> buildItemData(Map item, String source) {
//     final double gross = getValue(item, "gross_weight");
//
//     final double other = getValue(item, "other_weight");
//
//     final double net = gross - other;
//
//     final double purity = getValue(item, "purity");
//
//     final double waste = getValue(item, "waste");
//
//     final double metalRate = getValue(item, "metal_rate");
//
//     final double labourRate = getValue(item, "labour_rate");
//
//     final double otherAmount = getValue(item, "other_amount");
//
//     final double netPurity = purity + waste;
//
//     final double fineWeight = net * (netPurity / 100);
//
//     final double metalAmount = net * metalRate;
//
//     final double labourAmount = net * labourRate;
//
//     final double totalAmount = metalAmount + labourAmount + otherAmount;
//
//     return {
//       "source": source,
//       "itemset_id": item["itemset_id"] ?? item["id"],
//       "approval_item_id": item["approval_item_id"],
//       "gross_weight": gross,
//       "other_weight": other,
//       "net_weight": net,
//       "purity": purity,
//       "waste_percent": waste,
//       "net_purity": netPurity,
//       "fine_weight": fineWeight,
//       "metal_rate": metalRate,
//       "labour_rate": labourRate,
//       "other_amount": otherAmount,
//       "metal_amount": metalAmount,
//       "labour_amount": labourAmount,
//       "total_amount": totalAmount,
//     };
//   }
//
//   /// ============================================================
//   /// FINAL ITEMS
//   /// ============================================================
//
//   void updateFinalItems({bool refreshUI = true}) {
//     final List<Map<String, dynamic>> updatedList = [];
//
//     for (final item in items) {
//       final id = item["itemset_id"] ?? item["id"];
//
//       if (id == null) continue;
//
//       updatedList.add(buildItemData(item, "manual"));
//     }
//
//     for (final item in cartItems) {
//       final currentId = item["itemset_id"] ?? item["id"];
//
//       if (currentId == null) {
//         continue;
//       }
//
//       final bool alreadyExists = updatedList.any(
//         (e) => e["itemset_id"]?.toString() == currentId.toString(),
//       );
//
//       if (!alreadyExists) {
//         updatedList.add(buildItemData(item, "scan"));
//       }
//     }
//
//     uniqueItems = updatedList.reversed.toList();
//
//     if (refreshUI && mounted) {
//       setState(() {});
//     }
//   }
//
//   /// ============================================================
//   /// SEARCH ITEM API
//   /// ============================================================
//
//   Future<void> searchItemsApi(String keyword) async {
//     if (keyword.isEmpty) {
//       if (mounted) {
//         setState(() {
//           searchResults.clear();
//         });
//       }
//
//       return;
//     }
//
//     if (mounted) {
//       setState(() {
//         isLoading = true;
//       });
//     }
//
//     final response = await ApiHelper().getRequest(
//       "${ApiConstants.Approval_search}?keyword=$keyword",
//       showLoading: false,
//     );
//
//     if (!mounted) {
//       return;
//     }
//
//     setState(() {
//       isLoading = false;
//     });
//
//     if (response != null && response.statusCode == 200) {
//       final List allResults = response.data["data"] ?? [];
//
//       final Set<String> addedIds = {
//         ...items
//             .map((e) => (e["itemset_id"] ?? e["id"])?.toString() ?? "")
//             .where((e) => e.isNotEmpty),
//         ...cartItems
//             .map((e) => (e["itemset_id"] ?? e["id"])?.toString() ?? "")
//             .where((e) => e.isNotEmpty),
//       };
//
//       setState(() {
//         searchResults = allResults.where((resItem) {
//           final id = resItem["itemset_id"] ?? resItem["id"];
//
//           if (id == null) {
//             return false;
//           }
//
//           return !addedIds.contains(id.toString());
//         }).toList();
//       });
//     }
//   }
//
//   /// ============================================================
//   /// ADD ITEM
//   /// ============================================================
//
//   void addItemToCard(dynamic e) {
//     final Map<String, dynamic> newItem = {
//       "id": e["id"],
//       "itemset_id": e["itemset_id"] ?? e["id"],
//       "item_name": e["item"]?["item_name"] ?? e["item_name"] ?? "",
//       "huid": e["HUID"] ?? e["huid"] ?? "",
//       "qr_code": e["qr_code"] ?? "",
//       "gross_weight": e["gross_weight"]?.toString() ?? "",
//       "other_weight": (e["other_weight"] ?? e["other"])?.toString() ?? "",
//       "net_weight": e["net_weight"]?.toString() ?? "",
//       "purity": (e["item"]?["outward_carat"] ?? e["purity"])?.toString() ?? "",
//       "waste": e["waste"]?.toString() ?? "",
//       "net_purity":
//           (e["item"]?["outward_carat"] ?? e["net_purity"])?.toString() ?? "",
//       "fine_weight": e["fine_weight"]?.toString() ?? "",
//       "metal_rate": e["metal_rate"]?.toString() ?? "",
//       "metal_amount": e["metal_amount"]?.toString() ?? "",
//       "labour_rate": e["labour_rate"]?.toString() ?? "",
//       "labour_amount": e["labour_amount"]?.toString() ?? "",
//       "other_amount": e["other_amount"]?.toString() ?? "0",
//       "total_amount": e["total_amount"]?.toString() ?? "",
//       "expanded": false,
//       "source": "manual",
//     };
//
//     items.add(newItem);
//
//     _initializeItemControllers(newItem);
//
//     calculateItem(newItem);
//
//     searchController.clear();
//     searchResults.clear();
//
//     updateFinalItems();
//   }
//
//   /// ============================================================
//   /// SAVE
//   /// ============================================================
//
//   Future<void> saveApproval() async {
//     if (selectedItem == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Please select customer")));
//
//       return;
//     }
//
//     if (items.isEmpty && cartItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please add at least one item")),
//       );
//
//       return;
//     }
//
//     final List<Map<String, dynamic>> finalItems = [];
//
//     final combinedForSave = [
//       ...items.map((e) => {...e, "source": "search"}),
//       ...cartItems.map(
//         (e) => {
//           ...Map<String, dynamic>.from(e),
//           "id": e["cart_id"] ?? e["id"],
//           "itemset_id": e["itemset_id"] ?? e["id"],
//           "source": "scan",
//         },
//       ),
//     ];
//
//     final Map<String, Map<String, dynamic>> uniqueMap = {};
//
//     for (final dynamic raw in combinedForSave) {
//       final item = Map<String, dynamic>.from(raw);
//
//       final id = item["itemset_id"] ?? item["id"];
//
//       if (id != null) {
//         uniqueMap[id.toString()] = item;
//       }
//     }
//
//     for (final item in uniqueMap.values) {
//       calculateItem(item);
//
//       final id = item["itemset_id"] ?? item["id"];
//
//       finalItems.add({
//         "itemset_id": id,
//         "huid": item["huid"],
//         "qr_code": item["qr_code"],
//         "gross_weight": getValue(item, "gross_weight"),
//         "other_weight": getValue(item, "other_weight"),
//         "net_weight": getValue(item, "net_weight"),
//         "purity": getValue(item, "purity"),
//         "waste_percent": getValue(item, "waste"),
//         "net_purity": getValue(item, "net_purity"),
//         "total_fine_weight": getValue(item, "fine_weight"),
//         "metal_rate": getValue(item, "metal_rate"),
//         "metal_amount": getValue(item, "metal_amount"),
//         "labour_rate": getValue(item, "labour_rate"),
//         "labour_amount": getValue(item, "labour_amount"),
//         "other_amount": getValue(item, "other_amount"),
//         "total_amount": getValue(item, "total_amount"),
//       });
//     }
//
//     final Map<String, dynamic> body = {
//       "customer_id": int.parse(selectedItem!),
//       "items": finalItems,
//       "remarks": remarksController.text,
//     };
//
//     debugPrint("FINAL BODY => ${jsonEncode(body)}");
//
//     final response = await OfflineApiHelper.instance.postRequest(
//       ApiConstants.Approval_store,
//       body,
//     );
//
//     if (!mounted) return;
//
//     if (response != null &&
//         (response.statusCode == 200 || response.statusCode == 202)) {
//       if (response.statusCode == 202) {
//         AppMessage.success(context, "No Internet. Data saved offline.");
//       } else {
//         AppMessage.success(
//           context,
//           response.data["message"] ?? "Data Saved Successfully",
//         );
//       }
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const InvoiceScreen()),
//         (route) => route.isFirst,
//       );
//     } else {
//       final String message = response?.data is Map
//           ? response?.data["message"]?.toString() ?? "Failed to save approval"
//           : "Failed to save approval";
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red),
//       );
//     }
//   }
//
//   /// ============================================================
//   /// UPDATE
//   /// ============================================================
//
//   Future<void> UpdateApproval() async {
//     if (selectedItem == null || widget.userData == null) {
//       return;
//     }
//
//     final userId = widget.userData!["id"];
//
//     final List<Map<String, dynamic>> finalItems = [];
//
//     final combinedForUpdate = [
//       ...items.map((e) => {...e, "source": "search"}),
//       ...cartItems.map(
//         (e) => {
//           ...Map<String, dynamic>.from(e),
//           "id": e["cart_id"] ?? e["id"],
//           "itemset_id": e["itemset_id"] ?? e["id"],
//           "source": "scan",
//         },
//       ),
//     ];
//
//     final Map<String, Map<String, dynamic>> uniqueMap = {};
//
//     for (final dynamic raw in combinedForUpdate) {
//       final item = Map<String, dynamic>.from(raw);
//
//       final id = item["itemset_id"] ?? item["id"];
//
//       if (id != null) {
//         uniqueMap[id.toString()] = item;
//       }
//     }
//
//     for (final item in uniqueMap.values) {
//       calculateItem(item);
//
//       final id = item["itemset_id"] ?? item["id"];
//
//       if (id == null) {
//         continue;
//       }
//
//       finalItems.add({
//         "itemset_id": id,
//         "gross_weight": getValue(item, "gross_weight"),
//         "other_weight": getValue(item, "other_weight"),
//         "net_weight": getValue(item, "net_weight"),
//         "purity": getValue(item, "purity"),
//         "waste_percent": getValue(item, "waste"),
//         "net_purity": getValue(item, "net_purity"),
//         "total_fine_weight": getValue(item, "fine_weight"),
//         "metal_rate": getValue(item, "metal_rate"),
//         "metal_amount": getValue(item, "metal_amount"),
//         "labour_rate": getValue(item, "labour_rate"),
//         "labour_amount": getValue(item, "labour_amount"),
//         "other_amount": getValue(item, "other_amount"),
//         "total_amount": getValue(item, "total_amount"),
//       });
//     }
//
//     final Map<String, dynamic> body = {
//       "customer_id": int.parse(selectedItem!),
//       "items": finalItems,
//       "remarks": remarksController.text,
//     };
//
//     debugPrint("UPDATE BODY => ${jsonEncode(body)}");
//
//     final response = await ApiHelper().putRequest(
//       "${ApiConstants.Approval_update}/$userId",
//       body,
//     );
//
//     if (!mounted) {
//       return;
//     }
//
//     if (response != null && response.statusCode == 200) {
//       AppMessage.success(
//         context,
//         response.data["message"] ?? "Data Update Successfully",
//       );
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const InvoiceScreen()),
//         (route) => route.isFirst,
//       );
//     } else {
//       final String message = response?.data is Map
//           ? response?.data["message"]?.toString() ?? "Failed to update approval"
//           : "Failed to update approval";
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red),
//       );
//     }
//   }
//
//   /// ============================================================
//   /// OTHER CHARGES POPUP
//   /// ============================================================
//
//   // void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
//   //   // ============================================================
//   //   // API DATA -> POPUP DATA
//   //   // ============================================================
//   //
//   //   final List<Map<String, dynamic>>
//   //   charges = apiList.map<Map<String, dynamic>>((e) {
//   //     final String weightFormula =
//   //         e["weight_formula"]?.toString().trim().toLowerCase() ?? "";
//   //
//   //     final String amountFormula =
//   //         e["other_amt_formula"]?.toString().trim().toLowerCase() ?? "";
//   //
//   //     // ==========================================================
//   //     // WEIGHT FORMULA
//   //     // ==========================================================
//   //
//   //     String wtFormula = "flat";
//   //
//   //     if (weightFormula == "per_quantity" || weightFormula == "per_qty") {
//   //       wtFormula = "per_qty";
//   //     } else if (weightFormula == "per_weight" || weightFormula == "per_wt") {
//   //       wtFormula = "per_weight";
//   //     }
//   //
//   //     // ==========================================================
//   //     // AMOUNT FORMULA
//   //     // ==========================================================
//   //
//   //     String amtFormulaType = "flat";
//   //
//   //     if (amountFormula == "per_quantity" || amountFormula == "per_qty") {
//   //       amtFormulaType = "per_qty";
//   //     } else if (amountFormula == "per_weight" || amountFormula == "per_wt") {
//   //       amtFormulaType = "per_weight";
//   //     } else if (amountFormula == "per_qty_weight" ||
//   //         amountFormula == "qty_weight") {
//   //       amtFormulaType = "per_qty_weight";
//   //     }
//   //
//   //     return {
//   //       "id": e["id"],
//   //
//   //       "charge": e["name"] ?? "",
//   //
//   //       "amount": (e["default_amount"] ?? 0).toString(),
//   //
//   //       "qty": (e["quantity_pcs"] ?? 1).toString(),
//   //
//   //       "weight": (e["default_weight"] ?? 0).toString(),
//   //
//   //       "wt_formula": wtFormula,
//   //
//   //       "amt_formula_type": amtFormulaType,
//   //
//   //       "amt_formula": "",
//   //
//   //       "total_weight": "0.00",
//   //
//   //       "total_amt": "0.00",
//   //
//   //       "is_selected": e["is_selected"] == true,
//   //     };
//   //   }).toList();
//   //
//   //   // ============================================================
//   //   // SHOW DIALOG
//   //   // ============================================================
//   //
//   //   showDialog(
//   //     context: context,
//   //
//   //     barrierColor: Colors.black.withOpacity(0.50),
//   //
//   //     builder: (dialogContext) {
//   //       final Size screenSize = MediaQuery.of(dialogContext).size;
//   //
//   //       final bool isTablet = screenSize.width >= 600;
//   //
//   //       return Dialog(
//   //         elevation: 0,
//   //
//   //         backgroundColor: Colors.transparent,
//   //
//   //         insetPadding: EdgeInsets.symmetric(
//   //           horizontal: isTablet ? 30 : 12,
//   //           vertical: 18,
//   //         ),
//   //
//   //         child: StatefulBuilder(
//   //           builder: (context, setStateDialog) {
//   //             // ==================================================
//   //             // CALCULATE CHARGES
//   //             // ==================================================
//   //
//   //             void calculateCharges() {
//   //               for (final c in charges) {
//   //                 final double amt =
//   //                     double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//   //
//   //                 final double qty =
//   //                     double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//   //
//   //                 final double weight =
//   //                     double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;
//   //
//   //                 final String amtFormula =
//   //                     c["amt_formula_type"]?.toString() ?? "flat";
//   //
//   //                 final String wtFormula =
//   //                     c["wt_formula"]?.toString() ?? "flat";
//   //
//   //                 double totalAmt = 0;
//   //                 double totalWeight = 0;
//   //
//   //                 // ==============================================
//   //                 // WEIGHT CALCULATION
//   //                 // ==============================================
//   //
//   //                 switch (wtFormula) {
//   //                   case "flat":
//   //                     totalWeight = weight;
//   //                     break;
//   //
//   //                   case "per_qty":
//   //                     totalWeight = weight * qty;
//   //                     break;
//   //
//   //                   case "per_weight":
//   //                     totalWeight = weight;
//   //                     break;
//   //
//   //                   default:
//   //                     totalWeight = weight;
//   //                 }
//   //
//   //                 c["total_weight"] = totalWeight.toStringAsFixed(2);
//   //
//   //                 // ==============================================
//   //                 // AMOUNT CALCULATION
//   //                 // ==============================================
//   //
//   //                 switch (amtFormula) {
//   //                   case "flat":
//   //                     totalAmt = amt;
//   //
//   //                     c["amt_formula"] = "$amt";
//   //
//   //                     break;
//   //
//   //                   case "per_qty":
//   //                     totalAmt = amt * qty;
//   //
//   //                     c["amt_formula"] = "$amt × $qty";
//   //
//   //                     break;
//   //
//   //                   case "per_weight":
//   //                     totalAmt = amt * totalWeight;
//   //
//   //                     c["amt_formula"] = "$amt × $totalWeight";
//   //
//   //                     break;
//   //
//   //                   case "per_qty_weight":
//   //                     totalAmt = amt * qty * weight;
//   //
//   //                     c["amt_formula"] = "$amt × $qty × $weight";
//   //
//   //                     break;
//   //
//   //                   default:
//   //                     totalAmt = amt;
//   //
//   //                     c["amt_formula"] = "$amt";
//   //                 }
//   //
//   //                 c["total_amt"] = totalAmt.toStringAsFixed(2);
//   //               }
//   //             }
//   //
//   //             calculateCharges();
//   //
//   //             // ==================================================
//   //             // SELECTED TOTAL
//   //             // ==================================================
//   //
//   //             final double total = charges.fold<double>(0, (sum, c) {
//   //               if (c["is_selected"] == true) {
//   //                 return sum +
//   //                     (double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0);
//   //               }
//   //
//   //               return sum;
//   //             });
//   //
//   //             final int selectedCount = charges
//   //                 .where((e) => e["is_selected"] == true)
//   //                 .length;
//   //
//   //             // ==================================================
//   //             // COMMON INPUT DECORATION
//   //             // ==================================================
//   //
//   //             InputDecoration inputDecoration() {
//   //               return InputDecoration(
//   //                 isDense: true,
//   //
//   //                 contentPadding: const EdgeInsets.symmetric(
//   //                   horizontal: 7,
//   //                   vertical: 9,
//   //                 ),
//   //
//   //                 filled: true,
//   //
//   //                 fillColor: Colors.white,
//   //
//   //                 border: OutlineInputBorder(
//   //                   borderRadius: BorderRadius.circular(6),
//   //
//   //                   borderSide: const BorderSide(color: AppColors.border),
//   //                 ),
//   //
//   //                 enabledBorder: OutlineInputBorder(
//   //                   borderRadius: BorderRadius.circular(6),
//   //
//   //                   borderSide: const BorderSide(color: AppColors.border),
//   //                 ),
//   //
//   //                 focusedBorder: OutlineInputBorder(
//   //                   borderRadius: BorderRadius.circular(6),
//   //
//   //                   borderSide: const BorderSide(
//   //                     color: AppColors.primaryDark,
//   //                     width: 1.4,
//   //                   ),
//   //                 ),
//   //               );
//   //             }
//   //
//   //             // ==================================================
//   //             // NUMBER FIELD
//   //             // ==================================================
//   //
//   //             Widget numberField({
//   //               required String value,
//   //               required ValueChanged<String> onChanged,
//   //             }) {
//   //               return Padding(
//   //                 padding: const EdgeInsets.symmetric(horizontal: 3),
//   //
//   //                 child: TextFormField(
//   //                   initialValue: value,
//   //
//   //                   style: const TextStyle(
//   //                     fontSize: 11,
//   //                     fontWeight: FontWeight.w600,
//   //                     color: AppColors.textPrimary,
//   //                   ),
//   //
//   //                   textAlign: TextAlign.center,
//   //
//   //                   keyboardType: const TextInputType.numberWithOptions(
//   //                     decimal: true,
//   //                   ),
//   //
//   //                   decoration: inputDecoration(),
//   //
//   //                   onChanged: onChanged,
//   //                 ),
//   //               );
//   //             }
//   //
//   //             // ==================================================
//   //             // HEADER CELL
//   //             // ==================================================
//   //
//   //             Widget headerCell(
//   //               String title,
//   //               double width, {
//   //               bool left = false,
//   //             }) {
//   //               return SizedBox(
//   //                 width: width,
//   //
//   //                 child: Padding(
//   //                   padding: const EdgeInsets.symmetric(horizontal: 5),
//   //
//   //                   child: Text(
//   //                     title,
//   //
//   //                     textAlign: left ? TextAlign.left : TextAlign.center,
//   //
//   //                     style: const TextStyle(
//   //                       color: AppColors.primaryDark,
//   //                       fontSize: 10.5,
//   //                       fontWeight: FontWeight.w700,
//   //                     ),
//   //                   ),
//   //                 ),
//   //               );
//   //             }
//   //
//   //             // ==================================================
//   //             // MAIN POPUP
//   //             // ==================================================
//   //
//   //             return Container(
//   //               width: isTablet ? 1050 : double.infinity,
//   //
//   //               constraints: BoxConstraints(
//   //                 maxHeight: screenSize.height * 0.88,
//   //               ),
//   //
//   //               decoration: BoxDecoration(
//   //                 color: AppColors.background,
//   //
//   //                 borderRadius: BorderRadius.circular(15),
//   //
//   //                 border: Border.all(
//   //                   color: AppColors.primaryDark.withOpacity(0.14),
//   //                 ),
//   //
//   //                 boxShadow: [
//   //                   BoxShadow(
//   //                     color: Colors.black.withOpacity(0.20),
//   //                     blurRadius: 28,
//   //                     offset: const Offset(0, 10),
//   //                   ),
//   //                 ],
//   //               ),
//   //
//   //               child: ClipRRect(
//   //                 borderRadius: BorderRadius.circular(15),
//   //
//   //                 child: Column(
//   //                   mainAxisSize: MainAxisSize.min,
//   //
//   //                   children: [
//   //                     // ===========================================
//   //                     // BLUE HEADER
//   //                     // ===========================================
//   //                     Container(
//   //                       width: double.infinity,
//   //
//   //                       padding: const EdgeInsets.symmetric(
//   //                         horizontal: 14,
//   //                         vertical: 12,
//   //                       ),
//   //
//   //                       decoration: const BoxDecoration(
//   //                         gradient: LinearGradient(
//   //                           colors: [
//   //                             AppColors.primaryDark,
//   //                             AppColors.gradientBlue,
//   //                           ],
//   //
//   //                           begin: Alignment.topLeft,
//   //
//   //                           end: Alignment.bottomRight,
//   //                         ),
//   //                       ),
//   //
//   //                       child: Row(
//   //                         children: [
//   //                           // ICON
//   //                           Container(
//   //                             width: 38,
//   //                             height: 38,
//   //
//   //                             alignment: Alignment.center,
//   //
//   //                             decoration: BoxDecoration(
//   //                               color: Colors.white.withOpacity(0.14),
//   //
//   //                               borderRadius: BorderRadius.circular(9),
//   //
//   //                               border: Border.all(
//   //                                 color: Colors.white.withOpacity(0.18),
//   //                               ),
//   //                             ),
//   //
//   //                             child: const Icon(
//   //                               Icons.receipt_long_outlined,
//   //                               color: Colors.white,
//   //                               size: 20,
//   //                             ),
//   //                           ),
//   //
//   //                           const SizedBox(width: 10),
//   //
//   //                           // TITLE
//   //                           const Expanded(
//   //                             child: Column(
//   //                               crossAxisAlignment: CrossAxisAlignment.start,
//   //
//   //                               children: [
//   //                                 Text(
//   //                                   "Other Charges",
//   //                                   style: TextStyle(
//   //                                     color: Colors.white,
//   //                                     fontSize: 16,
//   //                                     fontWeight: FontWeight.w700,
//   //                                   ),
//   //                                 ),
//   //
//   //                                 SizedBox(height: 2),
//   //
//   //                                 Text(
//   //                                   "Manage additional item charges",
//   //                                   style: TextStyle(
//   //                                     color: Colors.white70,
//   //                                     fontSize: 10,
//   //                                     fontWeight: FontWeight.w500,
//   //                                   ),
//   //                                 ),
//   //                               ],
//   //                             ),
//   //                           ),
//   //
//   //                           // TOTAL CHARGES
//   //                           Container(
//   //                             padding: const EdgeInsets.symmetric(
//   //                               horizontal: 9,
//   //                               vertical: 5,
//   //                             ),
//   //
//   //                             decoration: BoxDecoration(
//   //                               color: Colors.white.withOpacity(0.13),
//   //
//   //                               borderRadius: BorderRadius.circular(20),
//   //                             ),
//   //
//   //                             child: Text(
//   //                               "${charges.length} Charges",
//   //
//   //                               style: const TextStyle(
//   //                                 color: Colors.white,
//   //                                 fontSize: 10,
//   //                                 fontWeight: FontWeight.w600,
//   //                               ),
//   //                             ),
//   //                           ),
//   //
//   //                           const SizedBox(width: 8),
//   //
//   //                           // CLOSE
//   //                           InkWell(
//   //                             borderRadius: BorderRadius.circular(8),
//   //
//   //                             onTap: () {
//   //                               FocusManager.instance.primaryFocus?.unfocus();
//   //
//   //                               Navigator.pop(dialogContext);
//   //                             },
//   //
//   //                             child: Container(
//   //                               width: 36,
//   //                               height: 36,
//   //
//   //                               alignment: Alignment.center,
//   //
//   //                               decoration: BoxDecoration(
//   //                                 color: Colors.white.withOpacity(0.13),
//   //
//   //                                 borderRadius: BorderRadius.circular(8),
//   //                               ),
//   //
//   //                               child: const Icon(
//   //                                 Icons.close_rounded,
//   //                                 color: Colors.white,
//   //                                 size: 20,
//   //                               ),
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ),
//   //
//   //                     // ===========================================
//   //                     // BODY
//   //                     // ===========================================
//   //                     Flexible(
//   //                       child: SingleChildScrollView(
//   //                         padding: const EdgeInsets.all(12),
//   //
//   //                         child: Column(
//   //                           crossAxisAlignment: CrossAxisAlignment.start,
//   //
//   //                           children: [
//   //                             // ===================================
//   //                             // SECTION TITLE
//   //                             // ===================================
//   //                             Row(
//   //                               children: [
//   //                                 Container(
//   //                                   width: 29,
//   //                                   height: 29,
//   //
//   //                                   alignment: Alignment.center,
//   //
//   //                                   decoration: BoxDecoration(
//   //                                     color: AppColors.iconBg,
//   //
//   //                                     borderRadius: BorderRadius.circular(7),
//   //                                   ),
//   //
//   //                                   child: const Icon(
//   //                                     Icons.tune_rounded,
//   //                                     size: 16,
//   //                                     color: AppColors.primaryDark,
//   //                                   ),
//   //                                 ),
//   //
//   //                                 const SizedBox(width: 8),
//   //
//   //                                 const Text(
//   //                                   "Charge Details",
//   //                                   style: TextStyle(
//   //                                     fontSize: 13,
//   //                                     fontWeight: FontWeight.w700,
//   //                                     color: AppColors.textPrimary,
//   //                                   ),
//   //                                 ),
//   //
//   //                                 const Spacer(),
//   //
//   //                                 Container(
//   //                                   padding: const EdgeInsets.symmetric(
//   //                                     horizontal: 9,
//   //                                     vertical: 5,
//   //                                   ),
//   //
//   //                                   decoration: BoxDecoration(
//   //                                     color: AppColors.iconBg,
//   //
//   //                                     borderRadius: BorderRadius.circular(20),
//   //
//   //                                     border: Border.all(
//   //                                       color: AppColors.border,
//   //                                     ),
//   //                                   ),
//   //
//   //                                   child: Row(
//   //                                     mainAxisSize: MainAxisSize.min,
//   //
//   //                                     children: [
//   //                                       const Icon(
//   //                                         Icons.check_circle_outline_rounded,
//   //                                         size: 13,
//   //                                         color: AppColors.primaryDark,
//   //                                       ),
//   //
//   //                                       const SizedBox(width: 4),
//   //
//   //                                       Text(
//   //                                         "$selectedCount Selected",
//   //
//   //                                         style: const TextStyle(
//   //                                           color: AppColors.primaryDark,
//   //                                           fontSize: 9.5,
//   //                                           fontWeight: FontWeight.w600,
//   //                                         ),
//   //                                       ),
//   //                                     ],
//   //                                   ),
//   //                                 ),
//   //                               ],
//   //                             ),
//   //
//   //                             const SizedBox(height: 9),
//   //
//   //                             // ===================================
//   //                             // TABLE
//   //                             // ===================================
//   //                             SingleChildScrollView(
//   //                               scrollDirection: Axis.horizontal,
//   //
//   //                               keyboardDismissBehavior:
//   //                                   ScrollViewKeyboardDismissBehavior.manual,
//   //
//   //                               child: Container(
//   //                                 width: 900,
//   //
//   //                                 decoration: BoxDecoration(
//   //                                   color: Colors.white,
//   //
//   //                                   borderRadius: BorderRadius.circular(9),
//   //
//   //                                   border: Border.all(color: AppColors.border),
//   //
//   //                                   boxShadow: [
//   //                                     BoxShadow(
//   //                                       color: AppColors.shadow,
//   //                                       blurRadius: 8,
//   //                                       offset: const Offset(0, 2),
//   //                                     ),
//   //                                   ],
//   //                                 ),
//   //
//   //                                 child: Column(
//   //                                   children: [
//   //                                     // ===========================
//   //                                     // TABLE HEADER
//   //                                     // ===========================
//   //                                     Container(
//   //                                       height: 42,
//   //
//   //                                       padding: const EdgeInsets.symmetric(
//   //                                         horizontal: 4,
//   //                                       ),
//   //
//   //                                       decoration: BoxDecoration(
//   //                                         color: AppColors.iconBg,
//   //
//   //                                         borderRadius: const BorderRadius.only(
//   //                                           topLeft: Radius.circular(8),
//   //
//   //                                           topRight: Radius.circular(8),
//   //                                         ),
//   //                                       ),
//   //
//   //                                       child: Row(
//   //                                         children: [
//   //                                           headerCell(
//   //                                             "Charge",
//   //                                             110,
//   //                                             left: true,
//   //                                           ),
//   //
//   //                                           headerCell("Amt", 80),
//   //
//   //                                           headerCell("Qty", 70),
//   //
//   //                                           headerCell("Weight", 90),
//   //
//   //                                           headerCell("Wt Formula", 105),
//   //
//   //                                           headerCell("Total Wt", 105),
//   //
//   //                                           headerCell("Amt Formula", 110),
//   //
//   //                                           headerCell("Total Amt", 105),
//   //
//   //                                           const SizedBox(
//   //                                             width: 45,
//   //                                             child: Center(
//   //                                               child: Icon(
//   //                                                 Icons
//   //                                                     .check_circle_outline_rounded,
//   //                                                 color: AppColors.primaryDark,
//   //                                                 size: 16,
//   //                                               ),
//   //                                             ),
//   //                                           ),
//   //                                         ],
//   //                                       ),
//   //                                     ),
//   //
//   //                                     Divider(
//   //                                       height: 1,
//   //                                       thickness: 1,
//   //                                       color: AppColors.border,
//   //                                     ),
//   //
//   //                                     // ===========================
//   //                                     // CHARGE LIST
//   //                                     // ===========================
//   //                                     SizedBox(
//   //                                       height: 230,
//   //
//   //                                       child: charges.isEmpty
//   //                                           ? const Center(
//   //                                               child: Text(
//   //                                                 "No charges available",
//   //                                                 style: TextStyle(
//   //                                                   color:
//   //                                                       AppColors.textSecondary,
//   //                                                   fontSize: 12,
//   //                                                   fontWeight: FontWeight.w600,
//   //                                                 ),
//   //                                               ),
//   //                                             )
//   //                                           : ListView.separated(
//   //                                               keyboardDismissBehavior:
//   //                                                   ScrollViewKeyboardDismissBehavior
//   //                                                       .manual,
//   //
//   //                                               padding:
//   //                                                   const EdgeInsets.symmetric(
//   //                                                     vertical: 5,
//   //                                                   ),
//   //
//   //                                               itemCount: charges.length,
//   //
//   //                                               separatorBuilder:
//   //                                                   (context, index) {
//   //                                                     return Divider(
//   //                                                       height: 1,
//   //                                                       color: AppColors.border,
//   //                                                     );
//   //                                                   },
//   //
//   //                                               itemBuilder: (context, index) {
//   //                                                 final c = charges[index];
//   //
//   //                                                 final bool selected =
//   //                                                     c["is_selected"] == true;
//   //
//   //                                                 return AnimatedContainer(
//   //                                                   duration: const Duration(
//   //                                                     milliseconds: 150,
//   //                                                   ),
//   //
//   //                                                   padding:
//   //                                                       const EdgeInsets.symmetric(
//   //                                                         vertical: 6,
//   //                                                         horizontal: 4,
//   //                                                       ),
//   //
//   //                                                   decoration: BoxDecoration(
//   //                                                     color: selected
//   //                                                         ? AppColors
//   //                                                               .primaryDark
//   //                                                               .withOpacity(
//   //                                                                 0.035,
//   //                                                               )
//   //                                                         : Colors.white,
//   //
//   //                                                     border: Border(
//   //                                                       left: BorderSide(
//   //                                                         color: selected
//   //                                                             ? AppColors
//   //                                                                   .primaryDark
//   //                                                             : Colors
//   //                                                                   .transparent,
//   //                                                         width: 3,
//   //                                                       ),
//   //                                                     ),
//   //                                                   ),
//   //
//   //                                                   child: Row(
//   //                                                     children: [
//   //                                                       // ===================
//   //                                                       // CHARGE
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 106,
//   //
//   //                                                         child: Padding(
//   //                                                           padding:
//   //                                                               const EdgeInsets.symmetric(
//   //                                                                 horizontal: 5,
//   //                                                               ),
//   //
//   //                                                           child: Row(
//   //                                                             children: [
//   //                                                               Container(
//   //                                                                 width: 24,
//   //                                                                 height: 24,
//   //
//   //                                                                 alignment:
//   //                                                                     Alignment
//   //                                                                         .center,
//   //
//   //                                                                 decoration: BoxDecoration(
//   //                                                                   color:
//   //                                                                       selected
//   //                                                                       ? AppColors.primaryDark.withOpacity(
//   //                                                                           0.12,
//   //                                                                         )
//   //                                                                       : AppColors
//   //                                                                             .iconBg,
//   //
//   //                                                                   borderRadius:
//   //                                                                       BorderRadius.circular(
//   //                                                                         6,
//   //                                                                       ),
//   //                                                                 ),
//   //
//   //                                                                 child: Text(
//   //                                                                   "${index + 1}",
//   //
//   //                                                                   style: const TextStyle(
//   //                                                                     color: AppColors
//   //                                                                         .primaryDark,
//   //                                                                     fontSize:
//   //                                                                         9,
//   //                                                                     fontWeight:
//   //                                                                         FontWeight
//   //                                                                             .w700,
//   //                                                                   ),
//   //                                                                 ),
//   //                                                               ),
//   //
//   //                                                               const SizedBox(
//   //                                                                 width: 5,
//   //                                                               ),
//   //
//   //                                                               Expanded(
//   //                                                                 child: Text(
//   //                                                                   c["charge"]
//   //                                                                           ?.toString() ??
//   //                                                                       "",
//   //
//   //                                                                   maxLines: 1,
//   //
//   //                                                                   overflow:
//   //                                                                       TextOverflow
//   //                                                                           .ellipsis,
//   //
//   //                                                                   style: TextStyle(
//   //                                                                     fontSize:
//   //                                                                         10.5,
//   //
//   //                                                                     fontWeight:
//   //                                                                         selected
//   //                                                                         ? FontWeight.w700
//   //                                                                         : FontWeight.w600,
//   //
//   //                                                                     color: AppColors
//   //                                                                         .textPrimary,
//   //                                                                   ),
//   //                                                                 ),
//   //                                                               ),
//   //                                                             ],
//   //                                                           ),
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // AMOUNT
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 80,
//   //
//   //                                                         child: numberField(
//   //                                                           value:
//   //                                                               c["amount"]
//   //                                                                   ?.toString() ??
//   //                                                               "0",
//   //
//   //                                                           onChanged: (v) {
//   //                                                             c["amount"] = v;
//   //
//   //                                                             setStateDialog(
//   //                                                               () {},
//   //                                                             );
//   //                                                           },
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // QTY
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 70,
//   //
//   //                                                         child: numberField(
//   //                                                           value:
//   //                                                               c["qty"]
//   //                                                                   ?.toString() ??
//   //                                                               "1",
//   //
//   //                                                           onChanged: (v) {
//   //                                                             c["qty"] = v;
//   //
//   //                                                             setStateDialog(
//   //                                                               () {},
//   //                                                             );
//   //                                                           },
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // WEIGHT
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 90,
//   //
//   //                                                         child: numberField(
//   //                                                           value:
//   //                                                               c["weight"]
//   //                                                                   ?.toString() ??
//   //                                                               "0",
//   //
//   //                                                           onChanged: (v) {
//   //                                                             c["weight"] = v;
//   //
//   //                                                             setStateDialog(
//   //                                                               () {},
//   //                                                             );
//   //                                                           },
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // WT FORMULA
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 105,
//   //
//   //                                                         child: Padding(
//   //                                                           padding:
//   //                                                               const EdgeInsets.symmetric(
//   //                                                                 horizontal: 3,
//   //                                                               ),
//   //
//   //                                                           child: DropdownButtonFormField<String>(
//   //                                                             value:
//   //                                                                 c["wt_formula"],
//   //
//   //                                                             isExpanded: true,
//   //
//   //                                                             dropdownColor:
//   //                                                                 Colors.white,
//   //
//   //                                                             icon: const Icon(
//   //                                                               Icons
//   //                                                                   .keyboard_arrow_down_rounded,
//   //                                                               color: AppColors
//   //                                                                   .primaryDark,
//   //                                                               size: 17,
//   //                                                             ),
//   //
//   //                                                             style: const TextStyle(
//   //                                                               fontSize: 10,
//   //                                                               color: AppColors
//   //                                                                   .textPrimary,
//   //                                                               fontWeight:
//   //                                                                   FontWeight
//   //                                                                       .w600,
//   //                                                             ),
//   //
//   //                                                             decoration:
//   //                                                                 inputDecoration(),
//   //
//   //                                                             items: const [
//   //                                                               DropdownMenuItem(
//   //                                                                 value: "flat",
//   //                                                                 child: Text(
//   //                                                                   "Flat",
//   //                                                                 ),
//   //                                                               ),
//   //
//   //                                                               DropdownMenuItem(
//   //                                                                 value:
//   //                                                                     "per_qty",
//   //                                                                 child: Text(
//   //                                                                   "Per Qty",
//   //                                                                 ),
//   //                                                               ),
//   //
//   //                                                               DropdownMenuItem(
//   //                                                                 value:
//   //                                                                     "per_weight",
//   //                                                                 child: Text(
//   //                                                                   "Per Wt",
//   //                                                                 ),
//   //                                                               ),
//   //                                                             ],
//   //
//   //                                                             onChanged: (v) {
//   //                                                               if (v == null) {
//   //                                                                 return;
//   //                                                               }
//   //
//   //                                                               c["wt_formula"] =
//   //                                                                   v;
//   //
//   //                                                               setStateDialog(
//   //                                                                 () {},
//   //                                                               );
//   //                                                             },
//   //                                                           ),
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // TOTAL WEIGHT
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 105,
//   //
//   //                                                         child: Center(
//   //                                                           child: Container(
//   //                                                             constraints:
//   //                                                                 const BoxConstraints(
//   //                                                                   minWidth:
//   //                                                                       66,
//   //                                                                 ),
//   //
//   //                                                             padding:
//   //                                                                 const EdgeInsets.symmetric(
//   //                                                                   horizontal:
//   //                                                                       8,
//   //                                                                   vertical: 7,
//   //                                                                 ),
//   //
//   //                                                             decoration: BoxDecoration(
//   //                                                               color: AppColors
//   //                                                                   .iconBg,
//   //
//   //                                                               borderRadius:
//   //                                                                   BorderRadius.circular(
//   //                                                                     6,
//   //                                                                   ),
//   //
//   //                                                               border: Border.all(
//   //                                                                 color: AppColors
//   //                                                                     .border,
//   //                                                               ),
//   //                                                             ),
//   //
//   //                                                             child: Text(
//   //                                                               c["total_weight"]
//   //                                                                       ?.toString() ??
//   //                                                                   "0.00",
//   //
//   //                                                               textAlign:
//   //                                                                   TextAlign
//   //                                                                       .center,
//   //
//   //                                                               style: const TextStyle(
//   //                                                                 fontSize:
//   //                                                                     10.5,
//   //                                                                 fontWeight:
//   //                                                                     FontWeight
//   //                                                                         .w700,
//   //                                                                 color: AppColors
//   //                                                                     .primaryDark,
//   //                                                               ),
//   //                                                             ),
//   //                                                           ),
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // AMOUNT FORMULA
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 110,
//   //
//   //                                                         child: Padding(
//   //                                                           padding:
//   //                                                               const EdgeInsets.symmetric(
//   //                                                                 horizontal: 3,
//   //                                                               ),
//   //
//   //                                                           child: DropdownButtonFormField<String>(
//   //                                                             value:
//   //                                                                 c["amt_formula_type"] ??
//   //                                                                 "flat",
//   //
//   //                                                             isExpanded: true,
//   //
//   //                                                             dropdownColor:
//   //                                                                 Colors.white,
//   //
//   //                                                             icon: const Icon(
//   //                                                               Icons
//   //                                                                   .keyboard_arrow_down_rounded,
//   //                                                               color: AppColors
//   //                                                                   .primaryDark,
//   //                                                               size: 17,
//   //                                                             ),
//   //
//   //                                                             style: const TextStyle(
//   //                                                               fontSize: 9.8,
//   //                                                               color: AppColors
//   //                                                                   .textPrimary,
//   //                                                               fontWeight:
//   //                                                                   FontWeight
//   //                                                                       .w600,
//   //                                                             ),
//   //
//   //                                                             decoration:
//   //                                                                 inputDecoration(),
//   //
//   //                                                             items: const [
//   //                                                               DropdownMenuItem(
//   //                                                                 value: "flat",
//   //                                                                 child: Text(
//   //                                                                   "Flat",
//   //                                                                 ),
//   //                                                               ),
//   //
//   //                                                               DropdownMenuItem(
//   //                                                                 value:
//   //                                                                     "per_qty",
//   //                                                                 child: Text(
//   //                                                                   "Per Qty",
//   //                                                                 ),
//   //                                                               ),
//   //
//   //                                                               DropdownMenuItem(
//   //                                                                 value:
//   //                                                                     "per_weight",
//   //                                                                 child: Text(
//   //                                                                   "Per Wt",
//   //                                                                 ),
//   //                                                               ),
//   //
//   //                                                               DropdownMenuItem(
//   //                                                                 value:
//   //                                                                     "per_qty_weight",
//   //                                                                 child: Text(
//   //                                                                   "Qty × Wt",
//   //                                                                 ),
//   //                                                               ),
//   //                                                             ],
//   //
//   //                                                             onChanged: (v) {
//   //                                                               if (v == null) {
//   //                                                                 return;
//   //                                                               }
//   //
//   //                                                               c["amt_formula_type"] =
//   //                                                                   v;
//   //
//   //                                                               setStateDialog(
//   //                                                                 () {},
//   //                                                               );
//   //                                                             },
//   //                                                           ),
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // TOTAL AMOUNT
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 105,
//   //
//   //                                                         child: Center(
//   //                                                           child: Container(
//   //                                                             constraints:
//   //                                                                 const BoxConstraints(
//   //                                                                   minWidth:
//   //                                                                       70,
//   //                                                                 ),
//   //
//   //                                                             padding:
//   //                                                                 const EdgeInsets.symmetric(
//   //                                                                   horizontal:
//   //                                                                       8,
//   //                                                                   vertical: 7,
//   //                                                                 ),
//   //
//   //                                                             decoration: BoxDecoration(
//   //                                                               color:
//   //                                                                   const Color(
//   //                                                                     0xFFEAF1FF,
//   //                                                                   ),
//   //
//   //                                                               borderRadius:
//   //                                                                   BorderRadius.circular(
//   //                                                                     6,
//   //                                                                   ),
//   //
//   //                                                               border: Border.all(
//   //                                                                 color: AppColors
//   //                                                                     .primaryDark
//   //                                                                     .withOpacity(
//   //                                                                       0.12,
//   //                                                                     ),
//   //                                                               ),
//   //                                                             ),
//   //
//   //                                                             child: Text(
//   //                                                               c["total_amt"]
//   //                                                                       ?.toString() ??
//   //                                                                   "0.00",
//   //
//   //                                                               textAlign:
//   //                                                                   TextAlign
//   //                                                                       .center,
//   //
//   //                                                               style: const TextStyle(
//   //                                                                 fontSize:
//   //                                                                     10.5,
//   //                                                                 fontWeight:
//   //                                                                     FontWeight
//   //                                                                         .w800,
//   //                                                                 color: AppColors
//   //                                                                     .primaryDark,
//   //                                                               ),
//   //                                                             ),
//   //                                                           ),
//   //                                                         ),
//   //                                                       ),
//   //
//   //                                                       // ===================
//   //                                                       // CHECKBOX
//   //                                                       // ===================
//   //                                                       SizedBox(
//   //                                                         width: 45,
//   //
//   //                                                         child: Center(
//   //                                                           child: Transform.scale(
//   //                                                             scale: 0.88,
//   //
//   //                                                             child: Checkbox(
//   //                                                               value: selected,
//   //
//   //                                                               activeColor:
//   //                                                                   AppColors
//   //                                                                       .primaryDark,
//   //
//   //                                                               checkColor:
//   //                                                                   Colors
//   //                                                                       .white,
//   //
//   //                                                               side: const BorderSide(
//   //                                                                 color: AppColors
//   //                                                                     .primaryDark,
//   //                                                                 width: 1.3,
//   //                                                               ),
//   //
//   //                                                               shape: RoundedRectangleBorder(
//   //                                                                 borderRadius:
//   //                                                                     BorderRadius.circular(
//   //                                                                       4,
//   //                                                                     ),
//   //                                                               ),
//   //
//   //                                                               onChanged: (val) {
//   //                                                                 c["is_selected"] =
//   //                                                                     val ??
//   //                                                                     false;
//   //
//   //                                                                 setStateDialog(
//   //                                                                   () {},
//   //                                                                 );
//   //                                                               },
//   //                                                             ),
//   //                                                           ),
//   //                                                         ),
//   //                                                       ),
//   //                                                     ],
//   //                                                   ),
//   //                                                 );
//   //                                               },
//   //                                             ),
//   //                                     ),
//   //                                   ],
//   //                                 ),
//   //                               ),
//   //                             ),
//   //
//   //                             const SizedBox(height: 12),
//   //
//   //                             // ===================================
//   //                             // TOTAL SUMMARY
//   //                             // ===================================
//   //                             Container(
//   //                               width: double.infinity,
//   //
//   //                               padding: const EdgeInsets.symmetric(
//   //                                 horizontal: 13,
//   //                                 vertical: 11,
//   //                               ),
//   //
//   //                               decoration: BoxDecoration(
//   //                                 gradient: const LinearGradient(
//   //                                   colors: [
//   //                                     Color(0xFFF3F7FF),
//   //                                     Color(0xFFEAF1FF),
//   //                                   ],
//   //                                 ),
//   //
//   //                                 borderRadius: BorderRadius.circular(9),
//   //
//   //                                 border: Border.all(color: AppColors.border),
//   //                               ),
//   //
//   //                               child: Row(
//   //                                 children: [
//   //                                   Container(
//   //                                     width: 34,
//   //                                     height: 34,
//   //
//   //                                     alignment: Alignment.center,
//   //
//   //                                     decoration: const BoxDecoration(
//   //                                       color: Colors.white,
//   //                                       shape: BoxShape.circle,
//   //                                     ),
//   //
//   //                                     child: const Icon(
//   //                                       Icons.calculate_outlined,
//   //                                       size: 18,
//   //                                       color: AppColors.primaryDark,
//   //                                     ),
//   //                                   ),
//   //
//   //                                   const SizedBox(width: 9),
//   //
//   //                                   Expanded(
//   //                                     child: Column(
//   //                                       crossAxisAlignment:
//   //                                           CrossAxisAlignment.start,
//   //
//   //                                       children: [
//   //                                         const Text(
//   //                                           "Selected Charges Total",
//   //                                           style: TextStyle(
//   //                                             fontSize: 10.5,
//   //                                             color: AppColors.textSecondary,
//   //                                             fontWeight: FontWeight.w500,
//   //                                           ),
//   //                                         ),
//   //
//   //                                         const SizedBox(height: 2),
//   //
//   //                                         Text(
//   //                                           "$selectedCount of ${charges.length} charges selected",
//   //
//   //                                           style: const TextStyle(
//   //                                             fontSize: 9.5,
//   //                                             color: AppColors.textSecondary,
//   //                                           ),
//   //                                         ),
//   //                                       ],
//   //                                     ),
//   //                                   ),
//   //
//   //                                   Text(
//   //                                     total.toStringAsFixed(2),
//   //
//   //                                     style: const TextStyle(
//   //                                       fontSize: 18,
//   //                                       color: AppColors.primaryDark,
//   //                                       fontWeight: FontWeight.w800,
//   //                                     ),
//   //                                   ),
//   //                                 ],
//   //                               ),
//   //                             ),
//   //                           ],
//   //                         ),
//   //                       ),
//   //                     ),
//   //
//   //                     // ===========================================
//   //                     // BOTTOM ACTION BAR
//   //                     // ===========================================
//   //                     Container(
//   //                       width: double.infinity,
//   //
//   //                       padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
//   //
//   //                       decoration: const BoxDecoration(
//   //                         color: Colors.white,
//   //
//   //                         border: Border(
//   //                           top: BorderSide(color: AppColors.border),
//   //                         ),
//   //                       ),
//   //
//   //                       child: Row(
//   //                         children: [
//   //                           // ===============================
//   //                           // CANCEL
//   //                           // ===============================
//   //                           Expanded(
//   //                             child: SizedBox(
//   //                               height: 42,
//   //
//   //                               child: OutlinedButton(
//   //                                 onPressed: () {
//   //                                   FocusManager.instance.primaryFocus
//   //                                       ?.unfocus();
//   //
//   //                                   Navigator.pop(dialogContext);
//   //                                 },
//   //
//   //                                 style: OutlinedButton.styleFrom(
//   //                                   backgroundColor: Colors.white,
//   //
//   //                                   side: const BorderSide(
//   //                                     color: AppColors.border,
//   //                                   ),
//   //
//   //                                   shape: RoundedRectangleBorder(
//   //                                     borderRadius: BorderRadius.circular(7),
//   //                                   ),
//   //                                 ),
//   //
//   //                                 child: const Text(
//   //                                   "Cancel",
//   //                                   style: TextStyle(
//   //                                     color: AppColors.textPrimary,
//   //                                     fontSize: 12,
//   //                                     fontWeight: FontWeight.w600,
//   //                                   ),
//   //                                 ),
//   //                               ),
//   //                             ),
//   //                           ),
//   //
//   //                           const SizedBox(width: 10),
//   //
//   //                           // ===============================
//   //                           // APPLY
//   //                           // ===============================
//   //                           Expanded(
//   //                             flex: 2,
//   //
//   //                             child: SizedBox(
//   //                               height: 42,
//   //
//   //                               child: Material(
//   //                                 color: Colors.transparent,
//   //
//   //                                 child: InkWell(
//   //                                   borderRadius: BorderRadius.circular(7),
//   //
//   //                                   onTap: () {
//   //                                     double selectedTotal = 0;
//   //
//   //                                     for (final c in charges) {
//   //                                       if (c["is_selected"] == true) {
//   //                                         selectedTotal +=
//   //                                             double.tryParse(
//   //                                               c["total_amt"]?.toString() ??
//   //                                                   "0",
//   //                                             ) ??
//   //                                             0;
//   //                                       }
//   //                                     }
//   //
//   //                                     item["other_amount"] = selectedTotal
//   //                                         .toStringAsFixed(2);
//   //
//   //                                     updateController(item, "other_amount");
//   //
//   //                                     calculateItem(item);
//   //
//   //                                     updateFinalItems();
//   //
//   //                                     FocusManager.instance.primaryFocus
//   //                                         ?.unfocus();
//   //
//   //                                     Navigator.pop(dialogContext);
//   //
//   //                                     setState(() {});
//   //                                   },
//   //
//   //                                   child: Ink(
//   //                                     decoration: BoxDecoration(
//   //                                       gradient: const LinearGradient(
//   //                                         colors: [
//   //                                           AppColors.primaryDark,
//   //                                           AppColors.gradientBlue,
//   //                                         ],
//   //
//   //                                         begin: Alignment.centerLeft,
//   //
//   //                                         end: Alignment.centerRight,
//   //                                       ),
//   //
//   //                                       borderRadius: BorderRadius.circular(7),
//   //
//   //                                       boxShadow: [
//   //                                         BoxShadow(
//   //                                           color: AppColors.primaryDark
//   //                                               .withOpacity(0.22),
//   //
//   //                                           blurRadius: 8,
//   //
//   //                                           offset: const Offset(0, 3),
//   //                                         ),
//   //                                       ],
//   //                                     ),
//   //
//   //                                     child: const Row(
//   //                                       mainAxisAlignment:
//   //                                           MainAxisAlignment.center,
//   //
//   //                                       children: [
//   //                                         Icon(
//   //                                           Icons.check_circle_outline_rounded,
//   //                                           color: Colors.white,
//   //                                           size: 17,
//   //                                         ),
//   //
//   //                                         SizedBox(width: 6),
//   //
//   //                                         Text(
//   //                                           "Apply Charges",
//   //                                           style: TextStyle(
//   //                                             color: Colors.white,
//   //                                             fontSize: 12.5,
//   //                                             fontWeight: FontWeight.w700,
//   //                                           ),
//   //                                         ),
//   //                                       ],
//   //                                     ),
//   //                                   ),
//   //                                 ),
//   //                               ),
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ),
//   //                   ],
//   //                 ),
//   //               ),
//   //             );
//   //           },
//   //         ),
//   //       );
//   //     },
//   //   );
//   // }
//
//
//   void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
//     /// ============================================================
//     /// 🔥 EXISTING OTHER AMOUNT (list API thi aavel value)
//     /// item["other_amount"] / item["sale_other"] sathe charges na
//     /// default_amount ne match kari ne pre-select karvani che, kem
//     /// ke direct charge_id list API ma nathi.
//     /// ============================================================
//     final double existingOtherAmount = double.tryParse(
//       item["other_amount"]?.toString() ??
//           item["sale_other"]?.toString() ??
//           "0",
//     ) ??
//         0;
//
//     bool alreadyMatched = false;
//
//     // ============================================================
//     // API DATA -> POPUP DATA
//     // ============================================================
//
//     final List<Map<String, dynamic>> charges = apiList.map<Map<String, dynamic>>((e) {
//       final String weightFormula =
//           e["weight_formula"]?.toString().trim().toLowerCase() ?? "";
//
//       final String amountFormula =
//           e["other_amt_formula"]?.toString().trim().toLowerCase() ?? "";
//
//       String wtFormula = "flat";
//
//       if (weightFormula == "per_quantity" || weightFormula == "per_qty") {
//         wtFormula = "per_qty";
//       } else if (weightFormula == "per_weight" || weightFormula == "per_wt") {
//         wtFormula = "per_weight";
//       }
//
//       String amtFormulaType = "flat";
//
//       if (amountFormula == "per_quantity" || amountFormula == "per_qty") {
//         amtFormulaType = "per_qty";
//       } else if (amountFormula == "per_weight" || amountFormula == "per_wt") {
//         amtFormulaType = "per_weight";
//       } else if (amountFormula == "per_qty_weight" || amountFormula == "qty_weight") {
//         amtFormulaType = "per_qty_weight";
//       }
//
//       final double defaultAmount = double.tryParse(e["default_amount"]?.toString() ?? "0") ?? 0;
//
//       bool isSelected = false;
//
//       if (!alreadyMatched && existingOtherAmount > 0 && defaultAmount == existingOtherAmount) {
//         isSelected = true;
//         alreadyMatched = true;
//       }
//
//       return {
//         "id": e["id"],
//         "charge": e["name"] ?? "",
//         "amount": (e["default_amount"] ?? 0).toString(),
//         "qty": (e["quantity_pcs"] ?? 1).toString(),
//         "weight": (e["default_weight"] ?? 0).toString(),
//         "wt_formula": wtFormula,
//         "amt_formula_type": amtFormulaType,
//         "amt_formula": "",
//         "total_weight": "0.00",
//         "total_amt": "0.00",
//         "is_selected": isSelected,
//       };
//     }).toList();
//
//     /// ============================================================
//     /// 🔥 PERSISTENT CONTROLLERS
//     /// ============================================================
//     final Map<int, Map<String, TextEditingController>> rowControllers = {};
//
//     for (int i = 0; i < charges.length; i++) {
//       rowControllers[i] = {
//         "amount": TextEditingController(text: charges[i]["amount"]?.toString() ?? "0"),
//         "qty": TextEditingController(text: charges[i]["qty"]?.toString() ?? "1"),
//         "weight": TextEditingController(text: charges[i]["weight"]?.toString() ?? "0"),
//       };
//     }
//
//     /// ============================================================
//     /// SINGLE-CHARGE CALCULATION
//     /// ============================================================
//     void calculateSingleCharge(Map<String, dynamic> c) {
//       final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
//       final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
//       final double weight = double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;
//
//       final String amtFormula = c["amt_formula_type"]?.toString() ?? "flat";
//       final String wtFormula = c["wt_formula"]?.toString() ?? "flat";
//
//       double totalAmt = 0;
//       double totalWeight = 0;
//
//       switch (wtFormula) {
//         case "per_qty":
//           totalWeight = weight * qty;
//           break;
//         case "per_weight":
//           totalWeight = weight * qty;
//           break;
//         default:
//           totalWeight = weight;
//       }
//
//       c["total_weight"] = totalWeight.toStringAsFixed(2);
//
//       switch (amtFormula) {
//         case "per_qty":
//           totalAmt = amt * qty;
//           c["amt_formula"] = "$amt × $qty";
//           break;
//
//         case "per_weight":
//           totalAmt = amt * totalWeight;
//           c["amt_formula"] = "$amt × $totalWeight";
//           break;
//
//         case "per_qty_weight":
//           totalAmt = amt * qty * weight;
//           c["amt_formula"] = "$amt × $qty × $weight";
//           break;
//
//         default:
//           totalAmt = amt;
//           c["amt_formula"] = "$amt";
//       }
//
//       c["total_amt"] = totalAmt.toStringAsFixed(2);
//     }
//
//     for (final c in charges) {
//       calculateSingleCharge(c);
//     }
//
//     double calcTotal() {
//       double total = 0;
//       for (final c in charges) {
//         if (c["is_selected"] == true) {
//           total += double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
//         }
//       }
//       return total;
//     }
//
//     /// 🔥 SINGLE SELECT — Set<int> na badle int?
//     int? initialSelectedIndex() {
//       for (int i = 0; i < charges.length; i++) {
//         if (charges[i]["is_selected"] == true) {
//           return i;
//         }
//       }
//       return null;
//     }
//
//     final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
//     final ValueNotifier<int?> selectedIndexNotifier =
//     ValueNotifier<int?>(initialSelectedIndex());
//
//     void disposeControllers() {
//       for (final ctrls in rowControllers.values) {
//         for (final c in ctrls.values) {
//           c.dispose();
//         }
//       }
//     }
//
//     // ============================================================
//     // SHOW DIALOG
//     // ============================================================
//
//     showDialog(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.50),
//       builder: (dialogContext) {
//         final Size screenSize = MediaQuery.of(dialogContext).size;
//         final bool isTablet = screenSize.width >= 600;
//
//         InputDecoration inputDecoration() {
//           return InputDecoration(
//             isDense: true,
//             contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: AppColors.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: AppColors.border),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.4),
//             ),
//           );
//         }
//
//         Widget headerCell(String title, double width, {bool left = false}) {
//           return SizedBox(
//             width: width,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 5),
//               child: Text(
//                 title,
//                 textAlign: left ? TextAlign.left : TextAlign.center,
//                 style: const TextStyle(
//                   color: AppColors.primaryDark,
//                   fontSize: 10.5,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//           );
//         }
//
//         return Dialog(
//           elevation: 0,
//           backgroundColor: Colors.transparent,
//           insetPadding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 30 : 12,
//             vertical: 18,
//           ),
//           child: Container(
//             width: isTablet ? 1050 : double.infinity,
//             constraints: BoxConstraints(maxHeight: screenSize.height * 0.88),
//             decoration: BoxDecoration(
//               color: AppColors.background,
//               borderRadius: BorderRadius.circular(15),
//               border: Border.all(color: AppColors.primaryDark.withOpacity(0.14)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.20),
//                   blurRadius: 28,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(15),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // ===========================================
//                   // BLUE HEADER
//                   // ===========================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//                     decoration: const BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [AppColors.primaryDark, AppColors.gradientBlue],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 38,
//                           height: 38,
//                           alignment: Alignment.center,
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.14),
//                             borderRadius: BorderRadius.circular(9),
//                             border: Border.all(color: Colors.white.withOpacity(0.18)),
//                           ),
//                           child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
//                         ),
//                         const SizedBox(width: 10),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text("Other Charges",
//                                   style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
//                               SizedBox(height: 2),
//                               Text("Manage additional item charges",
//                                   style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
//                             ],
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.13),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text("${charges.length} Charges",
//                               style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
//                         ),
//                         const SizedBox(width: 8),
//                         InkWell(
//                           borderRadius: BorderRadius.circular(8),
//                           onTap: () {
//                             FocusManager.instance.primaryFocus?.unfocus();
//                             disposeControllers();
//                             Navigator.pop(dialogContext);
//                           },
//                           child: Container(
//                             width: 36,
//                             height: 36,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.13),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // ===========================================
//                   // BODY
//                   // ===========================================
//                   Flexible(
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // ===================================
//                           // SECTION TITLE
//                           // ===================================
//                           Row(
//                             children: [
//                               Container(
//                                 width: 29,
//                                 height: 29,
//                                 alignment: Alignment.center,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.iconBg,
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                                 child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryDark),
//                               ),
//                               const SizedBox(width: 8),
//                               const Text("Charge Details",
//                                   style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
//                               const Spacer(),
//                               ValueListenableBuilder<int?>(
//                                 valueListenable: selectedIndexNotifier,
//                                 builder: (context, selectedIndex, _) {
//                                   return Container(
//                                     padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.iconBg,
//                                       borderRadius: BorderRadius.circular(20),
//                                       border: Border.all(color: AppColors.border),
//                                     ),
//                                     child: Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primaryDark),
//                                         const SizedBox(width: 4),
//                                         Text(
//                                           "${selectedIndex != null ? 1 : 0} Selected",
//                                           style: const TextStyle(
//                                               color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w600),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//
//                           const SizedBox(height: 9),
//
//                           // ===================================
//                           // TABLE
//                           // ===================================
//                           SingleChildScrollView(
//                             scrollDirection: Axis.horizontal,
//                             keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
//                             child: Container(
//                               width: 685,
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(9),
//                                 border: Border.all(color: AppColors.border),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.shadow,
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 children: [
//                                   // ===========================
//                                   // TABLE HEADER
//                                   // ===========================
//                                   Container(
//                                     height: 42,
//                                     padding: const EdgeInsets.symmetric(horizontal: 4),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.iconBg,
//                                       borderRadius: const BorderRadius.only(
//                                         topLeft: Radius.circular(8),
//                                         topRight: Radius.circular(8),
//                                       ),
//                                     ),
//                                     child: Row(
//                                       children: [
//                                         headerCell("Charge", 110, left: true),
//                                         headerCell("Amount", 90),
//                                         headerCell("Qty", 70),
//                                         headerCell("Wt Formula", 105),
//                                         headerCell("Amt Formula", 115),
//                                         headerCell("Total Amt", 105),
//                                         const SizedBox(
//                                           width: 45,
//                                           child: Center(
//                                             child: Icon(
//                                               Icons.check_circle_outline_rounded,
//                                               color: AppColors.primaryDark,
//                                               size: 16,
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//
//                                   Divider(height: 1, thickness: 1, color: AppColors.border),
//
//                                   // ===========================
//                                   // CHARGE LIST
//                                   // ===========================
//                                   SizedBox(
//                                     height: 230,
//                                     child: charges.isEmpty
//                                         ? const Center(
//                                       child: Text(
//                                         "No charges available",
//                                         style: TextStyle(
//                                           color: AppColors.textSecondary,
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w600,
//                                         ),
//                                       ),
//                                     )
//                                         : ListView.separated(
//                                       keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
//                                       padding: const EdgeInsets.symmetric(vertical: 5),
//                                       itemCount: charges.length,
//                                       separatorBuilder: (context, index) {
//                                         return Divider(height: 1, color: AppColors.border);
//                                       },
//                                       itemBuilder: (context, index) {
//                                         final c = charges[index];
//
//                                         return StatefulBuilder(
//                                           builder: (context, setStateRow) {
//                                             void onFieldChanged() {
//                                               c["amount"] = rowControllers[index]!["amount"]!.text;
//                                               c["qty"] = rowControllers[index]!["qty"]!.text;
//                                               c["weight"] = rowControllers[index]!["weight"]!.text;
//
//                                               calculateSingleCharge(c);
//
//                                               setStateRow(() {});
//
//                                               totalNotifier.value = calcTotal();
//                                             }
//
//                                             return ValueListenableBuilder<int?>(
//                                               valueListenable: selectedIndexNotifier,
//                                               builder: (context, selectedIndex, _) {
//                                                 final bool selected = selectedIndex == index;
//
//                                                 return AnimatedContainer(
//                                                   duration: const Duration(milliseconds: 150),
//                                                   padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//                                                   decoration: BoxDecoration(
//                                                     color: selected
//                                                         ? AppColors.primaryDark.withOpacity(0.035)
//                                                         : Colors.white,
//                                                     border: Border(
//                                                       left: BorderSide(
//                                                         color: selected ? AppColors.primaryDark : Colors.transparent,
//                                                         width: 3,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                   child: Row(
//                                                     children: [
//                                                       // ===================
//                                                       // CHARGE
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 110,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 5),
//                                                           child: Row(
//                                                             children: [
//                                                               Container(
//                                                                 width: 24,
//                                                                 height: 24,
//                                                                 alignment: Alignment.center,
//                                                                 decoration: BoxDecoration(
//                                                                   color: selected
//                                                                       ? AppColors.primaryDark.withOpacity(0.12)
//                                                                       : AppColors.iconBg,
//                                                                   borderRadius: BorderRadius.circular(6),
//                                                                 ),
//                                                                 child: Text(
//                                                                   "${index + 1}",
//                                                                   style: const TextStyle(
//                                                                     color: AppColors.primaryDark,
//                                                                     fontSize: 9,
//                                                                     fontWeight: FontWeight.w700,
//                                                                   ),
//                                                                 ),
//                                                               ),
//                                                               const SizedBox(width: 5),
//                                                               Expanded(
//                                                                 child: Text(
//                                                                   c["charge"]?.toString() ?? "",
//                                                                   maxLines: 1,
//                                                                   overflow: TextOverflow.ellipsis,
//                                                                   style: TextStyle(
//                                                                     fontSize: 10.5,
//                                                                     fontWeight:
//                                                                     selected ? FontWeight.w700 : FontWeight.w600,
//                                                                     color: AppColors.textPrimary,
//                                                                   ),
//                                                                 ),
//                                                               ),
//                                                             ],
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // ===================
//                                                       // AMOUNT
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 90,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: TextFormField(
//                                                             controller: rowControllers[index]!["amount"],
//                                                             style: const TextStyle(
//                                                               fontSize: 11,
//                                                               fontWeight: FontWeight.w600,
//                                                               color: AppColors.textPrimary,
//                                                             ),
//                                                             textAlign: TextAlign.center,
//                                                             keyboardType:
//                                                             const TextInputType.numberWithOptions(decimal: true),
//                                                             decoration: inputDecoration(),
//                                                             onChanged: (_) => onFieldChanged(),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // ===================
//                                                       // QTY
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 70,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: TextFormField(
//                                                             controller: rowControllers[index]!["qty"],
//                                                             style: const TextStyle(
//                                                               fontSize: 11,
//                                                               fontWeight: FontWeight.w600,
//                                                               color: AppColors.textPrimary,
//                                                             ),
//                                                             textAlign: TextAlign.center,
//                                                             keyboardType:
//                                                             const TextInputType.numberWithOptions(decimal: true),
//                                                             decoration: inputDecoration(),
//                                                             onChanged: (_) => onFieldChanged(),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // ===================
//                                                       // WT FORMULA
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 105,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: DropdownButtonFormField<String>(
//                                                             value: c["wt_formula"],
//                                                             isExpanded: true,
//                                                             dropdownColor: Colors.white,
//                                                             icon: const Icon(
//                                                               Icons.keyboard_arrow_down_rounded,
//                                                               color: AppColors.primaryDark,
//                                                               size: 17,
//                                                             ),
//                                                             style: const TextStyle(
//                                                               fontSize: 10,
//                                                               color: AppColors.textPrimary,
//                                                               fontWeight: FontWeight.w600,
//                                                             ),
//                                                             decoration: inputDecoration(),
//                                                             items: const [
//                                                               DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                                               DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                                               DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                                             ],
//                                                             onChanged: (v) {
//                                                               if (v == null) return;
//                                                               c["wt_formula"] = v;
//                                                               onFieldChanged();
//                                                             },
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // ===================
//                                                       // AMOUNT FORMULA
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 115,
//                                                         child: Padding(
//                                                           padding: const EdgeInsets.symmetric(horizontal: 3),
//                                                           child: DropdownButtonFormField<String>(
//                                                             value: c["amt_formula_type"] ?? "flat",
//                                                             isExpanded: true,
//                                                             dropdownColor: Colors.white,
//                                                             icon: const Icon(
//                                                               Icons.keyboard_arrow_down_rounded,
//                                                               color: AppColors.primaryDark,
//                                                               size: 17,
//                                                             ),
//                                                             style: const TextStyle(
//                                                               fontSize: 9.8,
//                                                               color: AppColors.textPrimary,
//                                                               fontWeight: FontWeight.w600,
//                                                             ),
//                                                             decoration: inputDecoration(),
//                                                             items: const [
//                                                               DropdownMenuItem(value: "flat", child: Text("Flat")),
//                                                               DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
//                                                               DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
//                                                               DropdownMenuItem(
//                                                                   value: "per_qty_weight", child: Text("Qty × Wt")),
//                                                             ],
//                                                             onChanged: (v) {
//                                                               if (v == null) return;
//                                                               c["amt_formula_type"] = v;
//                                                               onFieldChanged();
//                                                             },
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // ===================
//                                                       // TOTAL AMOUNT
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 105,
//                                                         child: Center(
//                                                           child: Container(
//                                                             constraints: const BoxConstraints(minWidth: 70),
//                                                             padding:
//                                                             const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
//                                                             decoration: BoxDecoration(
//                                                               color: const Color(0xFFEAF1FF),
//                                                               borderRadius: BorderRadius.circular(6),
//                                                               border: Border.all(
//                                                                 color: AppColors.primaryDark.withOpacity(0.12),
//                                                               ),
//                                                             ),
//                                                             child: Text(
//                                                               c["total_amt"]?.toString() ?? "0.00",
//                                                               textAlign: TextAlign.center,
//                                                               style: const TextStyle(
//                                                                 fontSize: 10.5,
//                                                                 fontWeight: FontWeight.w800,
//                                                                 color: AppColors.primaryDark,
//                                                               ),
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ),
//
//                                                       // ===================
//                                                       // CHECKBOX (SINGLE-SELECT)
//                                                       // ===================
//                                                       SizedBox(
//                                                         width: 45,
//                                                         child: Center(
//                                                           child: Transform.scale(
//                                                             scale: 0.88,
//                                                             child: Checkbox(
//                                                               value: selected,
//                                                               activeColor: AppColors.primaryDark,
//                                                               checkColor: Colors.white,
//                                                               side: const BorderSide(
//                                                                 color: AppColors.primaryDark,
//                                                                 width: 1.3,
//                                                               ),
//                                                               shape: RoundedRectangleBorder(
//                                                                 borderRadius: BorderRadius.circular(4),
//                                                               ),
//                                                               onChanged: (val) {
//                                                                 if (selectedIndexNotifier.value != null) {
//                                                                   charges[selectedIndexNotifier.value!]
//                                                                   ["is_selected"] = false;
//                                                                 }
//
//                                                                 if (val == true) {
//                                                                   c["is_selected"] = true;
//                                                                   selectedIndexNotifier.value = index;
//                                                                 } else {
//                                                                   c["is_selected"] = false;
//                                                                   selectedIndexNotifier.value = null;
//                                                                 }
//
//                                                                 totalNotifier.value = calcTotal();
//                                                               },
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 );
//                                               },
//                                             );
//                                           },
//                                         );
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//
//                           const SizedBox(height: 12),
//
//                           // ===================================
//                           // TOTAL SUMMARY
//                           // ===================================
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
//                             decoration: BoxDecoration(
//                               gradient: const LinearGradient(
//                                 colors: [Color(0xFFF3F7FF), Color(0xFFEAF1FF)],
//                               ),
//                               borderRadius: BorderRadius.circular(9),
//                               border: Border.all(color: AppColors.border),
//                             ),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 34,
//                                   height: 34,
//                                   alignment: Alignment.center,
//                                   decoration: const BoxDecoration(
//                                     color: Colors.white,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primaryDark),
//                                 ),
//                                 const SizedBox(width: 9),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const Text(
//                                         "Selected Charges Total",
//                                         style: TextStyle(
//                                           fontSize: 10.5,
//                                           color: AppColors.textSecondary,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 2),
//                                       ValueListenableBuilder<int?>(
//                                         valueListenable: selectedIndexNotifier,
//                                         builder: (context, selectedIndex, _) {
//                                           return Text(
//                                             "${selectedIndex != null ? 1 : 0} of ${charges.length} charges selected",
//                                             style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
//                                           );
//                                         },
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 ValueListenableBuilder<double>(
//                                   valueListenable: totalNotifier,
//                                   builder: (context, total, _) {
//                                     return Text(
//                                       total.toStringAsFixed(2),
//                                       style: const TextStyle(
//                                         fontSize: 18,
//                                         color: AppColors.primaryDark,
//                                         fontWeight: FontWeight.w800,
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//
//                   // ===========================================
//                   // BOTTOM ACTION BAR
//                   // ===========================================
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       border: Border(top: BorderSide(color: AppColors.border)),
//                     ),
//                     child: Row(
//                       children: [
//                         // ===============================
//                         // CANCEL
//                         // ===============================
//                         Expanded(
//                           child: SizedBox(
//                             height: 42,
//                             child: OutlinedButton(
//                               onPressed: () {
//                                 FocusManager.instance.primaryFocus?.unfocus();
//                                 disposeControllers();
//                                 Navigator.pop(dialogContext);
//                               },
//                               style: OutlinedButton.styleFrom(
//                                 backgroundColor: Colors.white,
//                                 side: const BorderSide(color: AppColors.border),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
//                               ),
//                               child: const Text(
//                                 "Cancel",
//                                 style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(width: 10),
//
//                         // ===============================
//                         // APPLY
//                         // ===============================
//                         Expanded(
//                           flex: 2,
//                           child: SizedBox(
//                             height: 42,
//                             child: Material(
//                               color: Colors.transparent,
//                               child: InkWell(
//                                 borderRadius: BorderRadius.circular(7),
//                                 onTap: () {
//                                   item["other_amount"] = totalNotifier.value.toStringAsFixed(2);
//
//                                   updateController(item, "other_amount");
//
//                                   calculateItem(item);
//
//                                   updateFinalItems();
//
//                                   FocusManager.instance.primaryFocus?.unfocus();
//
//                                   disposeControllers();
//
//                                   Navigator.pop(dialogContext);
//
//                                   setState(() {});
//                                 },
//                                 child: Ink(
//                                   decoration: BoxDecoration(
//                                     gradient: const LinearGradient(
//                                       colors: [AppColors.primaryDark, AppColors.gradientBlue],
//                                       begin: Alignment.centerLeft,
//                                       end: Alignment.centerRight,
//                                     ),
//                                     borderRadius: BorderRadius.circular(7),
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: AppColors.primaryDark.withOpacity(0.22),
//                                         blurRadius: 8,
//                                         offset: const Offset(0, 3),
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 17),
//                                       SizedBox(width: 6),
//                                       Text(
//                                         "Apply Charges",
//                                         style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
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
//   /// ============================================================
//   /// SCANNER WIDGET
//   /// ============================================================
//
//   Widget _buildScannerSection() {
//     double scannerSize = MediaQuery.of(context).size.width * 0.4;
//
//     if (MediaQuery.of(context).size.width > 600) {
//       scannerSize = 350;
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
//           controller: scannerController,
//           errorBuilder: (context, error) {
//             Future.delayed(const Duration(milliseconds: 500), () {
//               if (mounted && showScannerFull) {
//                 _startScanner();
//               }
//             });
//
//             return const Center(
//               child: Text(
//                 "Initializing camera...",
//                 style: TextStyle(color: Colors.white70, fontSize: 12),
//               ),
//             );
//           },
//           onDetect: (barcodeCapture) {
//             if (isBusy) {
//               return;
//             }
//
//             if (barcodeCapture.barcodes.isEmpty) {
//               return;
//             }
//
//             final barcode = barcodeCapture.barcodes.first;
//
//             final String? code = barcode.rawValue;
//
//             if (code == null || code.trim().isEmpty) {
//               return;
//             }
//
//             if (lastCode == code) {
//               return;
//             }
//
//             lastCode = code;
//
//             isBusy = true;
//
//             scanApiCall(code).whenComplete(() {
//               Future.delayed(const Duration(milliseconds: 600), () {
//                 isBusy = false;
//               });
//             });
//           },
//         ),
//       ),
//     );
//   }
//
//   /// ============================================================
//   /// SCAN API
//   /// ============================================================
//
//   Future<void> scanApiCall(String code) async {
//     final userId = widget.userData?["customer_id"] ?? 0;
//
//     final int customerId = isEditMode
//         ? int.tryParse(userId.toString()) ?? 0
//         : int.tryParse(selectedUserId ?? selectedItem ?? "") ?? 0;
//
//     if (customerId <= 0) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Please select customer first"),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//
//       lastCode = null;
//
//       return;
//     }
//
//     final Map<String, dynamic> body = {
//       "qr_code": code,
//       "customer_id": customerId,
//     };
//
//     debugPrint("SCAN BODY => $body");
//
//     final response = await ApiHelper().postRequest(
//       ApiConstants.Approval_scan_qr,
//       body,
//     );
//
//     if (!mounted) {
//       return;
//     }
//
//     if (response != null &&
//         response.statusCode == 200 &&
//         response.data["success"] == true) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Item Scan Successfully"),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 1),
//         ),
//       );
//
//       await getCartItems();
//     } else {
//       final String message = response?.data is Map
//           ? response?.data["message"]?.toString() ?? "Scan Failed"
//           : "Scan Failed";
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//
//       lastCode = null;
//     }
//   }
//
//   /// ============================================================
//   /// GET CART
//   /// ============================================================
//
//   Future<void> getCartItems() async {
//     final response = await ApiHelper().getRequest(
//       ApiConstants.Approval_scan_list,
//     );
//
//     if (response != null && response.statusCode == 200) {
//       final List rawData = response.data["data"] ?? [];
//
//       final List data = rawData.reversed.toList();
//
//       cartItems = List.from(data);
//
//       for (final dynamic raw in cartItems) {
//         final item = raw as Map<String, dynamic>;
//
//         item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";
//
//         item["other_weight"] = item["other_weight"]?.toString() ?? "0";
//
//         item["net_weight"] = item["net_weight"]?.toString() ?? "0";
//
//         item["purity"] = item["purity"]?.toString() ?? "0";
//
//         item["waste"] = item["waste"]?.toString() ?? "0";
//
//         item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";
//
//         item["labour_rate"] = item["labour_rate"]?.toString() ?? "0";
//
//         item["other_amount"] =
//             item["sale_other"]?.toString() ??
//             item["other_amount"]?.toString() ??
//             "0";
//
//         _initializeItemControllers(item);
//
//         setController(item, "gross_weight", item["gross_weight"]);
//
//         setController(item, "other_weight", item["other_weight"]);
//
//         setController(item, "purity", item["purity"]);
//
//         setController(item, "waste", item["waste"]);
//
//         setController(item, "metal_rate", item["metal_rate"]);
//
//         setController(item, "labour_rate", item["labour_rate"]);
//
//         setController(item, "other_amount", item["other_amount"]);
//
//         calculateItem(item);
//       }
//
//       updateFinalItems();
//     } else {
//       cartItems = [];
//
//       updateFinalItems();
//     }
//   }
//
//   /// ============================================================
//   /// DELETE CART
//   /// ============================================================
//
//   Future<void> deleteUser(String ID) async {
//     try {
//       final response = await ApiHelper().deleteRequest(
//         "${ApiConstants.Approval_cart_remove}/$ID",
//       );
//
//       if (response?.statusCode == 200) {
//         debugPrint("Deleted Successfully");
//       }
//     } catch (e) {
//       debugPrint("Delete exception: $e");
//     }
//   }
//
//   /// ============================================================
//   /// SUMMARY
//   /// ============================================================
//
//   Widget buildSummaryRow() {
//     final totals = calculateTotals();
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
//       decoration: BoxDecoration(
//         color: AppColors.background,
//         border: Border.all(color: AppColors.border, width: 1.5),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//             _summaryBox("Items", "${uniqueItems.length}"),
//             _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
//             _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
//             _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),
//             _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Map<String, double> calculateTotals() {
//     double gross = 0;
//
//     double other = 0;
//
//     double net = 0;
//
//     double total = 0;
//
//     for (final item in uniqueItems) {
//       gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;
//
//       other += double.tryParse(item["other_weight"]?.toString() ?? "0") ?? 0;
//
//       net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;
//
//       total += double.tryParse(item["total_amount"]?.toString() ?? "0") ?? 0;
//     }
//
//     return {"gross": gross, "other": other, "net": net, "total": total};
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
//   /// ============================================================
//   /// EXPANDED INPUT FIELD
//   /// ============================================================
//
//   Widget _inputField(String title, Map<String, dynamic> item, String key) {
//     final controller = getController(item, key);
//
//     final bool editable = isEditableField(key);
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: TextStyle(
//             fontSize: 11,
//             color: Colors.grey.shade700,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//
//         const SizedBox(height: 4),
//
//         TextFormField(
//           controller: controller,
//           readOnly: !editable,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//           textInputAction: TextInputAction.done,
//           style: TextStyle(
//             color: editable ? Colors.black : Colors.black54,
//             fontSize: 13,
//             fontWeight: FontWeight.w500,
//           ),
//           onTap: () {
//             if (!editable) {
//               return;
//             }
//
//             if (controller.text == "0" ||
//                 controller.text == "0.0" ||
//                 controller.text == "0.00" ||
//                 controller.text == "0.000") {
//               controller.clear();
//             }
//           },
//           onChanged: (val) {
//             item[key] = val;
//
//             calculateItem(item);
//           },
//           onEditingComplete: () {
//             if (controller.text.trim().isEmpty) {
//               controller.text = "0";
//
//               item[key] = "0";
//             }
//
//             calculateItem(item);
//
//             updateFinalItems();
//
//             FocusScope.of(context).unfocus();
//           },
//           onTapOutside: (_) {
//             if (!editable) {
//               return;
//             }
//
//             if (controller.text.trim().isEmpty) {
//               controller.text = "0";
//
//               item[key] = "0";
//             }
//
//             calculateItem(item);
//
//             FocusScope.of(context).unfocus();
//
//             updateFinalItems();
//           },
//           decoration: InputDecoration(
//             isDense: true,
//             filled: true,
//             fillColor: editable ? Colors.white : Colors.grey.shade50,
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 8,
//               vertical: 9,
//             ),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(5),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(5),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(5),
//               borderSide: BorderSide(color: AppColors.primaryDark, width: 1.2),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   /// ============================================================
//   /// OPTIONAL OLD UI HELPERS
//   /// ============================================================
//
//   Widget buildUserCard(Map item) {
//     final size = MediaQuery.of(context).size;
//
//     final isTablet = size.width >= 600;
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       padding: EdgeInsets.all(isTablet ? 16 : 12),
//       decoration: BoxDecoration(
//         color: const Color(0xffFAF7F2).withOpacity(0.9),
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               statusChip(item["metal"].toString()),
//               const Spacer(),
//               Row(
//                 children: [
//                   premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),
//                   SizedBox(width: isTablet ? 10 : 8),
//                   premiumIconBtn(
//                     Icons.delete,
//                     Colors.red,
//                     onTap: () {
//                       _showDeleteDialog(item);
//                     },
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           SizedBox(height: isTablet ? 10 : 8),
//           Row(
//             children: [
//               SizedBox(
//                 width: 80,
//                 child: Text(
//                   item["item_name"] ?? "",
//                   maxLines: 2,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     color: Colors.black,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 item["qr_code"] ?? "",
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color: Colors.black,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               border: Border.all(color: Colors.grey.shade200, width: 1.5),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Column(
//               children: [
//                 _erpRow(
//                   "Gross",
//                   item["gross_weight"]?.toString() ?? "-",
//                   "Net",
//                   item["net_weight"]?.toString() ?? "-",
//                 ),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 _erpRow(
//                   "Purity",
//                   item["purity"]?.toString() ?? "-",
//                   "Amount",
//                   "₹ ${item["amount"]?.toString() ?? "0"}",
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget statusChip(String status) {
//     Color startColor;
//     Color endColor;
//     String label;
//
//     switch (status.toLowerCase()) {
//       case "gold":
//         startColor = const Color(0xffC8A96A);
//
//         endColor = const Color(0xffE6C58A);
//
//         label = "Gold";
//         break;
//
//       case "silver":
//         startColor = const Color(0xffD9534F);
//
//         endColor = const Color(0xffF28B82);
//
//         label = "Silver";
//         break;
//
//       case "platinum":
//         startColor = const Color(0xffB07A3F);
//
//         endColor = const Color(0xffE0A96D);
//
//         label = "Platinum";
//         break;
//
//       case "other":
//         startColor = const Color(0xff7B5E57);
//
//         endColor = const Color(0xffBCAAA4);
//
//         label = "Other";
//         break;
//
//       default:
//         startColor = const Color(0xff9E9E9E);
//
//         endColor = const Color(0xffCFCFCF);
//
//         label = "Unknown";
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: [startColor, endColor]),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 6,
//             height: 6,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 6),
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
//   Widget _erpRow(String t1, String v1, String t2, String v2) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//       child: Row(
//         children: [
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 3,
//                   child: Text(
//                     t1,
//                     style: const TextStyle(fontSize: 12, color: Colors.black),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 4,
//                   child: Text(
//                     v1,
//                     style: const TextStyle(
//                       fontSize: 12,
//                       color: Colors.black,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     t2,
//                     style: const TextStyle(fontSize: 12, color: Colors.black),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: Text(
//                     v2,
//                     style: const TextStyle(
//                       fontSize: 12,
//                       overflow: TextOverflow.ellipsis,
//                       color: Colors.black,
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
//   void _showDeleteDialog(Map user) {
//     showGeneralDialog(
//       context: context,
//       barrierLabel: "Delete",
//       barrierDismissible: true,
//       barrierColor: Colors.black.withOpacity(0.4),
//       transitionDuration: const Duration(milliseconds: 300),
//       pageBuilder: (context, anim1, anim2) {
//         final screenWidth = MediaQuery.of(context).size.width;
//
//         return BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//           child: Center(
//             child: Container(
//               width: screenWidth * 0.85,
//               padding: const EdgeInsets.all(22),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(25),
//                 color: Colors.white.withOpacity(0.1),
//                 border: Border.all(color: Colors.white.withOpacity(0.2)),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//                     blurRadius: 20,
//                     offset: const Offset(0, 10),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: LinearGradient(
//                         colors: [Color(0xffff4e50), Color(0xfff00000)],
//                       ),
//                     ),
//                     child: const Icon(
//                       Icons.delete,
//                       size: 32,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 18),
//                   const Text(
//                     "Delete User?",
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                       decoration: TextDecoration.none,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     "Are you sure you want to delete ${user["name"]}?",
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       color: Colors.white70,
//                       decoration: TextDecoration.none,
//                     ),
//                   ),
//                   const SizedBox(height: 25),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.grey.shade800,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           onPressed: () {
//                             Navigator.pop(context);
//                           },
//                           child: const Text(
//                             "Cancel",
//                             style: TextStyle(color: Colors.white),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xfff00000),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           onPressed: () async {
//                             Navigator.pop(context);
//
//                             final id = user["cart_id"];
//
//                             if (id != null) {
//                               await deleteUser(id.toString());
//                             }
//                           },
//                           child: const Text(
//                             "Delete",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//       transitionBuilder: (context, anim, _, child) {
//         return FadeTransition(
//           opacity: anim,
//           child: ScaleTransition(
//             scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
//             child: child,
//           ),
//         );
//       },
//     );
//   }
// }
//
// /// ============================================================
// /// SCANNER LINE
// /// ============================================================
//
// class _ScannerLineAnimation extends StatefulWidget {
//   const _ScannerLineAnimation({super.key});
//
//   @override
//   State<_ScannerLineAnimation> createState() => _ScannerLineAnimationState();
// }
//
// class _ScannerLineAnimationState extends State<_ScannerLineAnimation>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController controller;
//
//   late final Animation<double> animation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat(reverse: true);
//
//     animation = Tween<double>(
//       begin: 0,
//       end: 1,
//     ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: animation,
//       builder: (context, child) {
//         return Align(
//           alignment: Alignment(0, animation.value * 2 - 1),
//           child: Container(
//             width: double.infinity,
//             height: 3,
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [
//                   Colors.transparent,
//                   Colors.greenAccent,
//                   Colors.transparent,
//                 ],
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.greenAccent.withOpacity(0.6),
//                   blurRadius: 10,
//                   spreadRadius: 1,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     controller.dispose();
//
//     super.dispose();
//   }
//
//
// }


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import '../Offline Data/offline_api_helper.dart';
import 'ApproveListScreen.dart';

class Createapprovalscreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const Createapprovalscreen({Key? key, this.userData}) : super(key: key);

  @override
  State<Createapprovalscreen> createState() => _CreateapprovalscreenState();
}

class _CreateapprovalscreenState extends State<Createapprovalscreen>
    with WidgetsBindingObserver {
  /// ============================================================
  /// SCANNER
  /// ============================================================

  late final MobileScannerController scannerController =
  MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
    autoStart: false,
  );

  bool _scannerReady = false;

  String? lastCode;
  bool isBusy = false;

  /// ============================================================
  /// CONTROLLERS
  /// ============================================================

  final TextEditingController searchController = TextEditingController();

  final TextEditingController fromDateController = TextEditingController();

  final TextEditingController toDateController = TextEditingController();

  final TextEditingController remarksController = TextEditingController();

  final FocusNode searchFocusNode = FocusNode();

  final Map<String, TextEditingController> controllers = {};

  Timer? _debounce;

  /// ============================================================
  /// STATE
  /// ============================================================

  List userlist = [];

  bool isLoading = false;
  bool isProcessing = false;
  bool isSearchEnabled = false;

  String? selectedItem;
  String? selectedCompanyId;
  String? selectedUserId;

  List cartItems = [];

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];

  List searchResults = [];

  bool showScannerFull = false;

  bool get isEditMode => widget.userData != null;

  List<Map<String, dynamic>> uniqueItems = [];

  /// 🔥 SOLD / RETURNED itemset_ids — list ma kabhi display na thay
  Set<String> nonPendingItemsetIds = {};

  /// ============================================================
  /// INIT
  /// ============================================================
  ///


  /// ============================================================
  /// 🔥 DEVICE / SESSION TRACKING
  /// ============================================================

  /// Device ma ek j vaar generate thay, SharedPreferences ma save rahe
  String? deviceId;

  /// Aa screen khule tyare j ek vaar generate thay (session unique)
  String? voucherSessionId;

  /// 🔥 Jo alag "Approval Person" dropdown hoy to e select thata j
  /// set karo. Nahi to null rahese ane API request ma skip thashe.
  String? approvalPersonId;
  Set<String> selectedManualItemKeys = {};
  final Set<String> addingManualSearchItemIds = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).refreshCustomers();
    });

    /// 🔥 voucher_session_id — screen khule tyare j ek vaar generate
    voucherSessionId = 'APP-${DateTime.now().millisecondsSinceEpoch}';



    if (isEditMode) {
      final user = widget.userData!;

      selectedItem = user["customer_id"]?.toString();

      selectedUserId = user["customer_id"]?.toString();

      remarksController.text = user["remarks"]?.toString() ?? "";

      final id = int.tryParse(user["id"]?.toString() ?? "");

      if (id != null) {
        /// 🔥 Edit mode ma pehla thi j customer nakki che, etle
        /// e customer nu scan-cart load karo.
        getCartItems(customerId: selectedUserId);

        loadEditData(id);
      }
    }
  }

  /// ============================================================
  /// DISPOSE
  /// ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _debounce?.cancel();

    scannerController.dispose();

    searchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    remarksController.dispose();

    searchFocusNode.dispose();

    for (final controller in controllers.values) {
      controller.dispose();
    }

    controllers.clear();

    super.dispose();
  }

  /// ============================================================
  /// APP LIFECYCLE
  /// ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!scannerController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      scannerController.stop();
      _scannerReady = false;
    } else if (state == AppLifecycleState.resumed && showScannerFull) {
      _startScanner();
    }
  }

  /// ============================================================
  /// SCANNER START
  /// ============================================================

  Future<void> _startScanner() async {
    try {
      await scannerController.start();

      if (mounted) {
        setState(() {
          _scannerReady = true;
        });
      }
    } catch (e) {
      debugPrint("Scanner start error: $e");

      await Future.delayed(const Duration(milliseconds: 400));

      try {
        await scannerController.start();

        if (mounted) {
          setState(() {
            _scannerReady = true;
          });
        }
      } catch (e2) {
        debugPrint("Scanner retry failed: $e2");
      }
    }
  }

  Future<void> _stopScanner() async {
    try {
      if (scannerController.value.isInitialized) {
        await scannerController.stop();
      }
    } catch (_) {}

    _scannerReady = false;
  }

  /// ============================================================
  /// DATE
  /// ============================================================

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text = "${picked.day}-${picked.month}-${picked.year}";
    }
  }

  /// ============================================================
  /// SEARCH CUSTOMER
  /// ============================================================

  void searchCustomer(String value) {
    setState(() {
      if (value.isEmpty) {
        items = List.from(allItems);
      } else {
        items = allItems.where((item) {
          return item["title"].toString().toLowerCase().contains(
            value.toLowerCase(),
          );
        }).toList();
      }
    });
  }

  /// ============================================================
  /// STABLE CONTROLLER KEY
  /// ============================================================

  String _controllerKey(Map item, String key) {
    final dynamic rawId = item["itemset_id"] ?? item["id"] ?? item["cart_id"];

    return "${rawId?.toString() ?? item.hashCode.toString()}_$key";
  }

  TextEditingController getController(Map item, String key) {
    final String uniqueKey = _controllerKey(item, key);

    final existing = controllers[uniqueKey];

    if (existing != null) {
      return existing;
    }

    final controller = TextEditingController(text: item[key]?.toString() ?? "");

    controllers[uniqueKey] = controller;

    return controller;
  }

  void updateController(Map item, String key) {
    final String uniqueKey = _controllerKey(item, key);

    final controller = controllers[uniqueKey];

    if (controller == null) {
      return;
    }

    final String newValue = item[key]?.toString() ?? "";

    if (controller.text == newValue) {
      return;
    }

    controller.value = TextEditingValue(
      text: newValue,
      selection: TextSelection.collapsed(offset: newValue.length),
      composing: TextRange.empty,
    );
  }

  void setController(Map<String, dynamic> item, String key, String value) {
    final controller = getController(item, key);

    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  double getValue(Map item, String key) {
    final String uniqueKey = _controllerKey(item, key);

    final controller = controllers[uniqueKey];

    if (controller != null) {
      return double.tryParse(controller.text) ?? 0;
    }

    return double.tryParse(item[key]?.toString() ?? "0") ?? 0;
  }

  /// ============================================================
  /// LOAD EDIT DATA
  /// ============================================================

  Future<void> loadEditData(int id) async {
    final response = await ApiHelper().getRequestWithId(
      ApiConstants.Approval_dailog_list,
      id,
    );

    debugPrint("DETAIL API => ${response?.data}");

    if (response != null && response.statusCode == 200) {
      final data = response.data["data"];

      final List apiItems = data["items"] ?? [];

      if (mounted) {
        AppMessage.success(
          context,
          data["message"] ?? "Data Loaded Successfully",
        );
      }

      items.clear();
      uniqueItems.clear();
      nonPendingItemsetIds.clear(); // 🔥 RESET every load

      for (final controller in controllers.values) {
        controller.dispose();
      }

      controllers.clear();

      for (final e in apiItems) {
        // 🔥 ONLY "pending" STATUS ITEMS ALLOWED IN LIST
        final String itemStatus =
            e["status"]?.toString().trim().toLowerCase() ?? "";

        final String itemsetId =
            (e["itemset_id"] ?? e["id"])?.toString() ?? "";

        debugPrint("ITEM ${e["qr_code"]} => status: '$itemStatus'");

        if (itemStatus != "pending") {
          // 🔥 sold / returned itemset_id record kari lo, jethi
          // scan-cart (cartItems) mathi pan hide thai jay
          if (itemsetId.isNotEmpty) {
            nonPendingItemsetIds.add(itemsetId);
          }

          continue;
        }

        final Map<String, dynamic> itemData = {
          "id": e["id"],
          "itemset_id": e["itemset_id"],
          "item_name": e["item_name"] ?? "",
          "huid": e["HUID"] ?? e["huid"] ?? "",
          "qr_code": e["qr_code"] ?? "",
          "gross_weight": e["gross_weight"] ?? "",
          "other_weight": e["other_weight"] ?? "",
          "net_weight": e["net_weight"] ?? "",
          "purity": e["purity"] ?? "",
          "waste": e["waste_percent"] ?? "",
          "net_purity": e["net_purity"] ?? "",
          "fine_weight": e["fine_weight"] ?? e["total_fine_weight"] ?? "",
          "metal_rate": e["metal_rate"] ?? "",
          "metal_amount": e["metal_amount"] ?? "",
          "other_amount": e["other_amount"] ?? "",
          "labour_rate": e["labour_rate"] ?? "",
          "labour_amount": e["labour_amount"] ?? "",
          "total_amount": e["total_amount"] ?? "",
          "expanded": false,
          "source": "manual",
          "status": itemStatus,
        };

        items.insert(0, itemData);

        _initializeItemControllers(itemData);
      }

      updateFinalItems();

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _initializeItemControllers(Map<String, dynamic> item) {
    for (final key in [
      "gross_weight",
      "other_weight",
      "net_weight",
      "purity",
      "waste",
      "net_purity",
      "fine_weight",
      "metal_rate",
      "metal_amount",
      "labour_rate",
      "labour_amount",
      "other_amount",
      "total_amount",
    ]) {
      getController(item, key);
    }
  }

  /// ============================================================
  /// OTHER CHARGE API
  /// ============================================================

  Future<void> getApprovalDetails(
      dynamic id,
      Map<String, dynamic> mainItem,
      ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiHelper().getRequest(ApiConstants.other_charge);

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      final List apiList = data["data"] is List ? data["data"] : [];

      showOtherChargesPopup(mainItem, apiList);
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load details")));
    }
  }

  /// ============================================================
  /// BUILD DISPLAY ITEMS
  /// ============================================================

  List<Map<String, dynamic>> _getDisplayItems() {
    final List<Map<String, dynamic>> combinedItemsList = [
      ...items,
      ...cartItems.map<Map<String, dynamic>>((e) {
        return {
          "id": e["cart_id"] ?? e["id"],
          "cart_id": e["cart_id"],
          "itemset_id": e["itemset_id"],
          "item_name": e["item_name"] ?? "",
          "huid": e["huid"] ?? "-",
          "qr_code": e["qr_code"] ?? "-",
          "gross_weight": e["gross_weight"]?.toString() ?? "0",
          "other_weight": e["other_weight"]?.toString() ?? "0",
          "net_weight": e["net_weight"]?.toString() ?? "0",
          "purity": e["purity"]?.toString() ?? "0",
          "waste": e["waste"]?.toString() ?? "0",
          "net_purity": e["net_purity"]?.toString() ?? "0",
          "fine_weight": e["fine_weight"]?.toString() ?? "0",
          "metal_rate": e["metal_rate"]?.toString() ?? "0",
          "metal_amount": e["metal_amount"]?.toString() ?? "0",
          "labour_rate": e["labour_rate"]?.toString() ?? "0",
          "labour_amount": e["labour_amount"]?.toString() ?? "0",
          "other_amount":
          e["sale_other"]?.toString() ??
              e["other_amount"]?.toString() ??
              "0",
          "total_amount": e["total_amount"]?.toString() ?? "0",
          "expanded": false,
          "source": "scan",
        };
      }),
    ];

    final map = <String, Map<String, dynamic>>{};

    for (final item in combinedItemsList) {
      final id = item["itemset_id"] ?? item["id"];

      if (id == null) continue;

      // 🔥 FINAL SAFETY FILTER — sold / returned itemset kabhi
      // display ma na aave, chahe e "items" mathi hoy ke stale
      // "cartItems" (scan cart) mathi hoy.
      if (nonPendingItemsetIds.contains(id.toString())) {
        continue;
      }

      map[id.toString()] = item;
    }

    return map.values.toList().reversed.toList();
  }

  /// ============================================================
  /// BUILD
  /// ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final width = size.width;

    final isMobile = width < 600;

    final List<Map<String, dynamic>> displayItems = _getDisplayItems();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        FocusManager.instance.primaryFocus?.unfocus();

        await _stopScanner();

        if (!mounted) return;

        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ======================================================
            /// MAIN UI
            /// ======================================================
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 40),

                Expanded(
                  child: showScannerFull
                      ? Column(
                    children: [
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Consumer<ItemProvider>(
                          builder: (context, provider, child) {
                            final customers = provider.customers;

                            return DropdownButtonFormField<String>(
                              value:
                              (selectedItem != null &&
                                  customers.any(
                                        (e) =>
                                    e["id"].toString() ==
                                        selectedItem,
                                  ))
                                  ? selectedItem
                                  : null,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.black,
                              ),
                              dropdownColor: Colors.white,
                              hint: Text(
                                "Select Customer",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              items: customers
                                  .map<DropdownMenuItem<String>>((item) {
                                return DropdownMenuItem<String>(
                                  value: item["id"].toString(),
                                  child: Text(
                                    item["name"] ?? "",
                                    style: const TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                              })
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedItem = value;

                                  final selectedData = customers
                                      .firstWhere(
                                        (user) =>
                                    user["id"].toString() ==
                                        value,
                                    orElse: () => {},
                                  );

                                  if (selectedData.isNotEmpty) {
                                    selectedCompanyId =
                                        selectedData["company_id"]
                                            ?.toString();

                                    selectedUserId = selectedData["id"]
                                        ?.toString();
                                  }
                                });

                                /// 🔥 Customer badlyo — e customer nu
                                /// pehla thi scan thayelu cart load karo
                                getCartItems(customerId: selectedUserId);
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 5),

                      /// ======================================
                      /// 🔥 PREMIUM SCANNER FRAME
                      /// ======================================
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.center,
                          //   children: [
                          //     Container(
                          //       padding: const EdgeInsets.all(6),
                          //       decoration: BoxDecoration(
                          //         gradient: LinearGradient(
                          //           colors: [
                          //             AppColors.primaryDark,
                          //             AppColors.secondaryDark,
                          //           ],
                          //         ),
                          //         borderRadius: BorderRadius.circular(8),
                          //         boxShadow: [
                          //           BoxShadow(
                          //             color: AppColors.primaryDark
                          //                 .withOpacity(0.35),
                          //             blurRadius: 10,
                          //             offset: const Offset(0, 3),
                          //           ),
                          //         ],
                          //       ),
                          //       child: const Icon(
                          //         Icons.qr_code_scanner_rounded,
                          //         color: Colors.white,
                          //         size: 15,
                          //       ),
                          //     ),
                          //     const SizedBox(width: 8),
                          //     const Text(
                          //       "Scan QR Code",
                          //       style: TextStyle(
                          //         fontSize: 14,
                          //         fontWeight: FontWeight.w700,
                          //         color: Colors.black87,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          //
                          // const SizedBox(height: 14),

                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              /// 🔥 Soft glow behind the frame
                              // Container(
                              //   height: 210,
                              //   width: 210,
                              //   decoration: BoxDecoration(
                              //     shape: BoxShape.circle,
                              //     gradient: RadialGradient(
                              //       colors: [
                              //         Colors.greenAccent.withOpacity(
                              //           0.18,
                              //         ),
                              //         Colors.transparent,
                              //       ],
                              //     ),
                              //   ),
                              // ),

                              /// 🔥 Gradient-border scanner card
                              Container(
                                height: 150,
                                width: 150,
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark,
                                      Colors.greenAccent.withOpacity(
                                        0.65,
                                      ),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        0.22,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.greenAccent
                                          .withOpacity(0.30),
                                      blurRadius: 26,
                                      spreadRadius: -6,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  child: Container(
                                    color: Colors.black,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Center(
                                          child: _buildScannerSection(),
                                        ),
                                        const _ScannerLineAnimation(),

                                        /// 🔥 Corner brackets overlay
                                        _scannerCorner(
                                          top: 10,
                                          left: 10,
                                          borderTop: true,
                                          borderLeft: true,
                                        ),
                                        _scannerCorner(
                                          top: 10,
                                          right: 10,
                                          borderTop: true,
                                          borderRight: true,
                                        ),
                                        _scannerCorner(
                                          bottom: 10,
                                          left: 10,
                                          borderBottom: true,
                                          borderLeft: true,
                                        ),
                                        _scannerCorner(
                                          bottom: 10,
                                          right: 10,
                                          borderBottom: true,
                                          borderRight: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              /// 🔥 Premium glass close button
                              Positioned(
                                top: -8,
                                right: -8,
                                child: GestureDetector(
                                  onTap: () async {
                                    await _stopScanner();

                                    if (!mounted) {
                                      return;
                                    }

                                    setState(() {
                                      showScannerFull = false;

                                      lastCode = null;

                                      isBusy = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(
                                        0.80,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.6,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.30),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // const SizedBox(height: 10),
                          //
                          // Text(
                          //   "Position the QR code within the frame",
                          //   style: TextStyle(
                          //     fontSize: 11,
                          //     color: Colors.grey.shade600,
                          //     fontWeight: FontWeight.w500,
                          //   ),
                          // ),
                        ],
                      ),

                      const SizedBox(height: 0),

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

                      Expanded(
                        child: displayItems.isEmpty
                            ? const Center(child: Text("No Data Added"))
                            : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            0,
                            12,
                            0,
                            12,
                          ),
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior
                              .manual,
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            return approvalItemCard(
                              displayItems[index],
                              index,
                              displayItems.length,
                            );
                          },
                        ),
                      ),
                    ],
                  )
                      : Column(
                    children: [
                      const SizedBox(height: 0),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
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
                                      AppColors.primaryDark.withOpacity(
                                        0.1,
                                      ),
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark.withOpacity(
                                        0.4,
                                      ),
                                      AppColors.primaryDark.withOpacity(
                                        0.1,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),

                              displayItems.isEmpty
                                  ? const Padding(
                                padding: EdgeInsets.only(top: 50),
                                child: Center(
                                  child: Text(
                                    "No Data Found",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                                  : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  12,
                                  0,
                                  12,
                                ),
                                shrinkWrap: true,
                                physics:
                                const NeverScrollableScrollPhysics(),
                                keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior
                                    .manual,
                                itemCount: displayItems.length,
                                itemBuilder: (context, index) {
                                  return approvalItemCard(
                                    displayItems[index],
                                    index,
                                    displayItems.length,
                                  );
                                },
                              ),

                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// SUMMARY
                buildSummaryRow(),

                /// SAVE BUTTON
                InkWell(
                  onTap: isProcessing
                      ? null
                      : () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    _debounce?.cancel();

                    setState(() {
                      isProcessing = true;
                    });

                    try {
                      if (showScannerFull) {
                        await _stopScanner();
                      }

                      updateFinalItems(refreshUI: false);

                      if (isEditMode) {
                        await UpdateApproval();
                      } else {
                        await saveApproval();
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          isProcessing = false;
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark.withOpacity(0.7),
                            AppColors.secondaryDark.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          isProcessing
                              ? "Please Wait..."
                              : isEditMode
                              ? "Update Approval"
                              : "Save Approval",
                          style: const TextStyle(
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

            /// ======================================================
            /// APPBAR
            /// ======================================================
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
                    Text(
                      isEditMode ? "Update Approval" : "Create Approval",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();

                          await _stopScanner();

                          if (!mounted) {
                            return;
                          }

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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// 🔥 SCANNER CORNER BRACKET (premium overlay, purely visual)
  /// ============================================================

  Widget _scannerCorner({
    double? top,
    double? left,
    double? right,
    double? bottom,
    bool borderTop = false,
    bool borderLeft = false,
    bool borderRight = false,
    bool borderBottom = false,
  }) {
    const double size = 20;
    const double thickness = 2.6;
    const Color color = Colors.greenAccent;

    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: borderTop
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
            left: borderLeft
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
            right: borderRight
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
            bottom: borderBottom
                ? const BorderSide(color: color, width: thickness)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// EDITABLE FIELD
  /// ============================================================

  bool isEditableField(String key) {
    return [
      "gross_weight",
      "other_weight",
      "purity",
      "waste",
      "labour_rate",
      "metal_rate",
    ].contains(key);
  }

  /// ============================================================
  /// ITEM CARD
  /// ============================================================

  Widget approvalItemCard(
      Map<String, dynamic> item,
      int index,
      int totalCount,
      ) {
    final bool isExpanded = item["expanded"] ?? false;

    final String itemName =
        item["name"]?.toString() ?? item["item_name"]?.toString() ?? "Item";

    final String qrCode =
        item["qr_code"]?.toString() ??
            item["itemset"]?["qr_code"]?.toString() ??
            item["code"]?.toString() ??
            item["itemset"]?["barcode"]?.toString() ??
            "-";

    return Container(
      key: ValueKey(item["itemset_id"] ?? item["id"]),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
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
                    color: AppColors.gradientBlue,
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
                        itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  constraints: const BoxConstraints(maxWidth: 130),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_2,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          qrCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 7),

                /// 🔥 DELETE — backend delete confirm thaya pachi j
                /// local state update thay, ane pachi cart re-sync
                /// thay + lastCode reset jethi same QR tarat j
                /// fri scan thai shake.
                InkWell(
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    final idToRemove = item["itemset_id"] ?? item["id"];

                    if (item["source"] == "scan") {
                      final cartId = item["cart_id"] ?? item["id"];

                      if (cartId != null) {
                        final bool deleted = await deleteUser(
                          cartId.toString(),
                        );

                        if (!deleted) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Failed to remove item. Try again.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }

                          return; // 🔥 fail thay to list mathi remove j na karo
                        }
                      }

                      cartItems.removeWhere(
                            (e) =>
                        (e["cart_id"] ?? e["id"])?.toString() ==
                            (item["cart_id"] ?? item["id"])?.toString(),
                      );

                      // 🔥 backend sathe cart re-sync (same customer)
                      await getCartItems(
                        customerId: selectedUserId ?? selectedItem,
                      );

                      // 🔥 IMPORTANT: reset karo jethi have j delete
                      // thayelo barcode tarat j fri scan thai shake.
                      lastCode = null;
                      isBusy = false;
                    } else {
                      items.removeWhere(
                            (e) =>
                        (e["itemset_id"] ?? e["id"])?.toString() ==
                            idToRemove?.toString(),
                      );
                    }

                    updateFinalItems();
                  },
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

          if (!isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.manual,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _miniField("Gross", item, "gross_weight",index),
                    _miniField("Other", item, "other_weight",index),
                    _miniField("Net", item, "net_weight",index),
                    _miniField("Purity", item, "purity",index),
                    _miniField("Waste", item, "waste",index),
                    _miniField("Net Purity", item, "net_purity",index),
                    _miniField("Fine", item, "fine_weight",index),
                    _miniField("Metal Rate", item, "metal_rate",index),
                    _miniField("Metal Amount", item, "metal_amount",index),
                    _miniField("Labour Rate", item, "labour_rate",index),
                    _miniField("Labour Amount", item, "labour_amount",index),
                    _miniField("Other Amount", item, "other_amount",index),
                    _miniField("Total Amount", item, "total_amount",index),
                  ],
                ),
              ),
            ),

          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _inputField("Other Wt", item, "other_weight"),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _inputField("Purity", item, "purity")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _inputField("Waste %", item, "waste")),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _inputField("Net Purity", item, "net_purity"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _inputField("Fine Wt", item, "fine_weight"),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _inputField("Metal Rate", item, "metal_rate"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ============================================================
  /// FILTER
  /// ============================================================

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
          Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Consumer<ItemProvider>(
              builder: (context, provider, child) {
                final List<Map<String, dynamic>> customers = provider.customers
                    .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                    .toList();

                Map<String, dynamic>? selectedCustomer;

                if (selectedItem != null) {
                  try {
                    selectedCustomer = customers.firstWhere(
                          (e) => e["id"]?.toString() == selectedItem.toString(),
                    );
                  } catch (_) {
                    selectedCustomer = null;
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
                      itemLabel: (customer) => customer["name"]?.toString() ?? "",
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
                      onChanged: (customer) => _setCustomer(customer),
                    ),

                    /// ❌ CLEAR — dropdown ની અંદર, arrow ની ડાબી બાજુ
                    if (selectedCustomer != null)
                      Positioned(
                        right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
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
          ),

          const SizedBox(height: 5),

          Column(
            children: [
              TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                autofocus: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  _debounce?.cancel();

                  final keyword = value.trim();

                  if (keyword.isEmpty) {
                    setState(() {
                      searchResults.clear();
                    });

                    return;
                  }

                  _debounce = Timer(
                    const Duration(milliseconds: 500),
                        () async {
                      if (!mounted) {
                        return;
                      }

                      await searchItemsApi(keyword);
                    },
                  );
                },
                onSubmitted: (value) async {
                  final keyword = value.trim();

                  if (keyword.isEmpty) {
                    return;
                  }

                  await searchItemsApi(keyword);
                },
                decoration: InputDecoration(
                  hintText: "Search (HUID / QR)",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryDark,
                    ),
                    onPressed: () async {
                      final keyword = searchController.text.trim();

                      if (keyword.isEmpty) {
                        return;
                      }

                      await searchItemsApi(keyword);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryDark),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),

              if (searchController.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : searchResults.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        "No items found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                    padding: EdgeInsets.zero,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final item = searchResults[index];

                      final itemName =
                          item["item"]?["item_name"] ?? "Item";

                      final huid = item["HUID"] ?? "-";

                      final qr = item["qr_code"] ?? "-";

                      final String itemKey =
                          (item["itemset_id"] ?? item["id"])?.toString() ??
                              "";

                      final bool isAdding =
                      addingManualSearchItemIds.contains(itemKey);

                      return InkWell(
                        onTap: isAdding
                            ? null
                            : () async {
                          FocusManager.instance.primaryFocus
                              ?.unfocus();

                          final String? qrCode = item["qr_code"]
                              ?.toString();

                          if (qrCode == null ||
                              qrCode.trim().isEmpty) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "This item has no QR code",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            addingManualSearchItemIds.add(itemKey);
                          });

                          /// 🔥 IMPORTANT: existing scanApiCall()
                          /// flow reuse karo — server par cart
                          /// add + getCartItems() refresh +
                          /// delete-ready state (source: "scan")
                          /// automatically male che.
                          await addManualSearchItemToCart(item);

                          if (!mounted) return;

                          setState(() {
                            addingManualSearchItemIds.remove(
                              itemKey,
                            );

                            /// 🔥 Add thaya pachi (success ke
                            /// fail) search results mathi
                            /// hatavi do
                            searchResults.removeWhere(
                                  (e) =>
                              (e["itemset_id"] ?? e["id"])
                                  ?.toString() ==
                                  itemKey,
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == searchResults.length - 1
                                    ? Colors.transparent
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "HUID: $huid | QR: $qr",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAdding)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.add_circle,
                                  color: Color(0xffC8A96A),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: remarksController,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter Remarks",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    _debounce?.cancel();

                    setState(() {
                      showScannerFull = true;

                      lastCode = null;

                      isBusy = false;
                    });

                    await Future.delayed(const Duration(milliseconds: 150));

                    if (!mounted) {
                      return;
                    }

                    await _startScanner();
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// LOCAL FILTER
  /// ============================================================

  void applyLocalFilter() {
    final search = searchController.text.toLowerCase();

    final from = fromDateController.text;

    final to = toDateController.text;

    DateTime? fromDate = from.isNotEmpty
        ? parseSafeDate(formatDateForApi(from))
        : null;

    DateTime? toDate = to.isNotEmpty
        ? parseSafeDate(formatDateForApi(to))
        : null;

    setState(() {
      userlist = allItems.where((item) {
        final name = item["customer_name"]?.toString().toLowerCase() ?? "";

        final matchesSearch = name.contains(search);

        final dateStr = item["approval_date"];

        if (dateStr == null) {
          return false;
        }

        final itemDate = DateTime.parse(dateStr);

        if (fromDate != null && itemDate.isBefore(fromDate)) {
          return false;
        }

        if (toDate != null && itemDate.isAfter(toDate)) {
          return false;
        }

        return matchesSearch;
      }).toList();
    });
  }

  DateTime parseSafeDate(String dateStr) {
    final parts = dateStr.split("-");

    final year = parts[0];

    final month = parts[1].padLeft(2, '0');

    final day = parts[2].padLeft(2, '0');

    return DateTime.parse("$year-$month-$day");
  }

  String formatDateForApi(String input) {
    if (input.isEmpty) {
      return "";
    }

    final parts = input.split("-");

    return "${parts[2]}-${parts[1]}-${parts[0]}";
  }

  /// ============================================================
  /// MINI FIELD
  /// ============================================================

  Widget _miniField(String title, Map<String, dynamic> item, String key,int index,) {
    final bool isOtherField = key == "other_amount";

    final bool isMetalRateField = key == "metal_rate";

    final bool isLabourRateField = key == "labour_rate";
    final bool isPurityField = key == "purity";
    final bool isWasteField = key == "waste";

    final controller = getController(item, key);

    final bool editable = key == "metal_rate"
        ? (item["manual_metal"] ?? true)
        : key == "labour_rate"
        ? (item["manual_labour"] ?? true)
        : isEditableField(key);

    final bool canEdit = key == "metal_rate"
        ? (item["manual_metal"] ?? true)
        : key == "labour_rate"
        ? (item["manual_labour"] ?? true)
        : isEditableField(key);

    return Container(
      width: 105,
      margin: const EdgeInsets.only(right: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 2,
              right: 2,
              bottom: 4,
            ),
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

                // ========================================================
                // ONLY FIRST ROW + METAL/LABOUR RATE
                // ========================================================

                if (index == 0 &&
                    (isMetalRateField ||
                        isLabourRateField ||
                        isOtherField ||
                        isPurityField ||
                        isWasteField))
                  InkWell(
                    onTap: () async {
                      applyToAllItems(key, controller.text);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                      ),
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
                  readOnly: !canEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  enableInteractiveSelection: canEdit,
                  showCursor: canEdit,
                  canRequestFocus: canEdit,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: editable ? Colors.black : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () {
                    if (!canEdit) {
                      return;
                    }

                    if (controller.text == "0" ||
                        controller.text == "0.0" ||
                        controller.text == "0.00" ||
                        controller.text == "0.000") {
                      controller.clear();
                    } else {
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      );
                    }
                  },
                  onChanged: (val) {
                    item[key] = val;

                    calculateItem(item);
                    setState(() {});
                  },
                  onEditingComplete: () {
                    if (controller.text.trim().isEmpty) {
                      controller.text = "0";

                      item[key] = "0";
                    }

                    calculateItem(item);

                    updateFinalItems();


                    FocusScope.of(context).unfocus();
                  },
                  onTapOutside: (_) {
                    if (!canEdit) {
                      return;
                    }

                    if (controller.text.trim().isEmpty) {
                      controller.text = "0";

                      item[key] = "0";
                    }

                    calculateItem(item);

                    updateFinalItems();
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: 8,
                      right:
                      (isOtherField ||
                          isMetalRateField ||
                          isLabourRateField)
                          ? 30
                          : 8,
                      top: 9,
                      bottom: 9,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),

                /// OTHER AMOUNT
                if (isOtherField)
                  Positioned(
                    right: 4,
                    child: InkWell(
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();

                        await getApprovalDetails(item["id"], item);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xffC8A96A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                /// METAL CHECKBOX
                if (isMetalRateField)
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
                          value:
                          (double.tryParse(
                            controller.text.isEmpty
                                ? "0"
                                : controller.text,
                          ) ??
                              0) >
                              0,
                          onChanged: (val) {
                            if (val == true) {
                              if ((double.tryParse(
                                controller.text.isEmpty
                                    ? "0"
                                    : controller.text,
                              ) ??
                                  0) ==
                                  0) {
                                controller.text = "1";

                                item["metal_rate"] = "1";
                              }
                            } else {
                              controller.text = "0.00";

                              item["metal_rate"] = "0.00";
                            }

                            calculateItem(item);

                            updateFinalItems();
                          },
                        ),
                      ),
                    ),
                  ),

                /// LABOUR CHECKBOX
                if (isLabourRateField)
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
                          value:
                          (double.tryParse(
                            controller.text.isEmpty
                                ? "0"
                                : controller.text,
                          ) ??
                              0) >
                              0,
                          onChanged: (val) {
                            if (val == false) {
                              controller.text = "0.00";

                              item["labour_rate"] = "0.00";
                            } else {
                              if ((double.tryParse(
                                controller.text.isEmpty
                                    ? "0"
                                    : controller.text,
                              ) ??
                                  0) ==
                                  0) {
                                controller.text = "1";

                                item["labour_rate"] = "1";
                              }
                            }

                            calculateItem(item);

                            updateFinalItems();
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

  /// ============================================================
  /// CALCULATE ITEM
  /// ============================================================

  void calculateItem(Map<String, dynamic> item) {
    final grossController = getController(item, "gross_weight");

    final otherController = getController(item, "other_weight");

    final purityController = getController(item, "purity");

    final wasteController = getController(item, "waste");

    final metalRateController = getController(item, "metal_rate");

    final labourRateController = getController(item, "labour_rate");

    final otherAmountController = getController(item, "other_amount");

    final double gross = double.tryParse(grossController.text) ?? 0;

    final double other = double.tryParse(otherController.text) ?? 0;

    final double purity = double.tryParse(purityController.text) ?? 0;

    final double waste = double.tryParse(wasteController.text) ?? 0;

    final double metalRate = double.tryParse(metalRateController.text) ?? 0;

    final double labourRate = double.tryParse(labourRateController.text) ?? 0;

    final double otherAmount = double.tryParse(otherAmountController.text) ?? 0;

    final double net = gross - other;

    final double netPurity = purity + waste;

    final double fineWeight = net * (netPurity / 100);

    final double metalAmount = net * metalRate;

    final double labourAmount = net * labourRate;

    final double totalAmount = metalAmount + labourAmount + otherAmount;

    item["gross_weight"] = grossController.text;

    item["other_weight"] = otherController.text;

    item["purity"] = purityController.text;

    item["waste"] = wasteController.text;

    item["metal_rate"] = metalRateController.text;

    item["labour_rate"] = labourRateController.text;

    item["other_amount"] = otherAmountController.text;

    item["net_weight"] = net.toStringAsFixed(3);

    item["net_purity"] = netPurity.toStringAsFixed(2);

    item["fine_weight"] = fineWeight.toStringAsFixed(3);

    item["metal_amount"] = metalAmount.toStringAsFixed(2);

    item["labour_amount"] = labourAmount.toStringAsFixed(2);

    item["total_amount"] = totalAmount.toStringAsFixed(2);

    updateController(item, "net_weight");

    updateController(item, "net_purity");

    updateController(item, "fine_weight");

    updateController(item, "metal_amount");

    updateController(item, "labour_amount");

    updateController(item, "total_amount");
  }

  // ============================================================
// APPLY RATE TO ALL ITEMS (Metal Rate / Labour Rate)
// ============================================================
  void applyToAllItems(String key, String value) {
    if (value.trim().isEmpty) return;

    // 🔥 UPDATE ALL "items" (manual/search added)
    for (final item in items) {
      getController(item, key).text = value;
      item[key] = value;
      calculateItem(item);
    }

    // 🔥 UPDATE ALL "cartItems" (scanned items)
    for (final item in cartItems) {
      getController(item, key).text = value;
      item[key] = value;
      calculateItem(item);
    }

    updateFinalItems();

    if (mounted) {
      setState(() {});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${key == "metal_rate" ? "Metal Rate" : "Labour Rate"} applied to all items",
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  /// ============================================================
  /// BUILD ITEM DATA
  /// ============================================================

  Map<String, dynamic> buildItemData(Map item, String source) {
    final double gross = getValue(item, "gross_weight");

    final double other = getValue(item, "other_weight");

    final double net = gross - other;

    final double purity = getValue(item, "purity");

    final double waste = getValue(item, "waste");

    final double metalRate = getValue(item, "metal_rate");

    final double labourRate = getValue(item, "labour_rate");

    final double otherAmount = getValue(item, "other_amount");

    final double netPurity = purity + waste;

    final double fineWeight = net * (netPurity / 100);

    final double metalAmount = net * metalRate;

    final double labourAmount = net * labourRate;

    final double totalAmount = metalAmount + labourAmount + otherAmount;

    return {
      "source": source,
      "itemset_id": item["itemset_id"] ?? item["id"],
      "approval_item_id": item["approval_item_id"],
      "gross_weight": gross,
      "other_weight": other,
      "net_weight": net,
      "purity": purity,
      "waste_percent": waste,
      "net_purity": netPurity,
      "fine_weight": fineWeight,
      "metal_rate": metalRate,
      "labour_rate": labourRate,
      "other_amount": otherAmount,
      "metal_amount": metalAmount,
      "labour_amount": labourAmount,
      "total_amount": totalAmount,
    };
  }

  /// ============================================================
  /// FINAL ITEMS
  /// ============================================================

  void updateFinalItems({bool refreshUI = true}) {
    final List<Map<String, dynamic>> updatedList = [];

    for (final item in items) {
      final id = item["itemset_id"] ?? item["id"];

      if (id == null) continue;

      updatedList.add(buildItemData(item, "manual"));
    }

    for (final item in cartItems) {
      final currentId = item["itemset_id"] ?? item["id"];

      if (currentId == null) {
        continue;
      }

      final bool alreadyExists = updatedList.any(
            (e) => e["itemset_id"]?.toString() == currentId.toString(),
      );

      if (!alreadyExists) {
        updatedList.add(buildItemData(item, "scan"));
      }
    }

    uniqueItems = updatedList.reversed.toList();

    if (refreshUI && mounted) {
      setState(() {});
    }
  }

  /// ============================================================
  /// SEARCH ITEM API
  /// ============================================================

  Future<void> searchItemsApi(String keyword) async {
    if (keyword.isEmpty) {
      if (mounted) {
        setState(() {
          searchResults.clear();
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final response = await ApiHelper().getRequest(
      "${ApiConstants.Approval_search}?keyword=$keyword",
      showLoading: false,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    if (response != null && response.statusCode == 200) {
      final List allResults = response.data["data"] ?? [];

      final Set<String> addedIds = {
        ...items
            .map((e) => (e["itemset_id"] ?? e["id"])?.toString() ?? "")
            .where((e) => e.isNotEmpty),
        ...cartItems
            .map((e) => (e["itemset_id"] ?? e["id"])?.toString() ?? "")
            .where((e) => e.isNotEmpty),
      };

      setState(() {
        searchResults = allResults.where((resItem) {
          final id = resItem["itemset_id"] ?? resItem["id"];

          if (id == null) {
            return false;
          }

          return !addedIds.contains(id.toString());
        }).toList();
      });
    }
  }

  /// ============================================================
  /// ADD ITEM
  /// ============================================================

  void addItemToCard(dynamic e) {
    final Map<String, dynamic> newItem = {
      "id": e["id"],
      "itemset_id": e["itemset_id"] ?? e["id"],
      "item_name": e["item"]?["item_name"] ?? e["item_name"] ?? "",
      "huid": e["HUID"] ?? e["huid"] ?? "",
      "qr_code": e["qr_code"] ?? "",
      "gross_weight": e["gross_weight"]?.toString() ?? "",
      "other_weight": (e["other_weight"] ?? e["other"])?.toString() ?? "",
      "net_weight": e["net_weight"]?.toString() ?? "",
      "purity": (e["item"]?["outward_carat"] ?? e["purity"])?.toString() ?? "",
      "waste": e["waste"]?.toString() ?? "",
      "net_purity":
      (e["item"]?["outward_carat"] ?? e["net_purity"])?.toString() ?? "",
      "fine_weight": e["fine_weight"]?.toString() ?? "",
      "metal_rate": e["metal_rate"]?.toString() ?? "",
      "metal_amount": e["metal_amount"]?.toString() ?? "",
      "labour_rate": e["labour_rate"]?.toString() ?? "",
      "labour_amount": e["labour_amount"]?.toString() ?? "",
      "other_amount": e["other_amount"]?.toString() ?? "0",
      "total_amount": e["total_amount"]?.toString() ?? "",
      "expanded": false,
      "source": "manual",
    };

    items.add(newItem);

    _initializeItemControllers(newItem);

    calculateItem(newItem);

    searchController.clear();
    searchResults.clear();

    updateFinalItems();
  }

  /// ============================================================
  /// SAVE
  /// ============================================================

  Future<void> saveApproval() async {
    if (selectedItem == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select customer")));

      return;
    }

    if (items.isEmpty && cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one item")),
      );

      return;
    }

    final List<Map<String, dynamic>> finalItems = [];

    final combinedForSave = [
      ...items.map((e) => {...e, "source": "search"}),
      ...cartItems.map(
            (e) => {
          ...Map<String, dynamic>.from(e),
          "id": e["cart_id"] ?? e["id"],
          "itemset_id": e["itemset_id"] ?? e["id"],
          "source": "scan",
        },
      ),
    ];

    final Map<String, Map<String, dynamic>> uniqueMap = {};

    for (final dynamic raw in combinedForSave) {
      final item = Map<String, dynamic>.from(raw);

      final id = item["itemset_id"] ?? item["id"];

      if (id != null) {
        uniqueMap[id.toString()] = item;
      }
    }

    for (final item in uniqueMap.values) {
      calculateItem(item);

      final id = item["itemset_id"] ?? item["id"];

      finalItems.add({
        "itemset_id": id,
        "huid": item["huid"],
        "qr_code": item["qr_code"],
        "gross_weight": getValue(item, "gross_weight"),
        "other_weight": getValue(item, "other_weight"),
        "net_weight": getValue(item, "net_weight"),
        "purity": getValue(item, "purity"),
        "waste_percent": getValue(item, "waste"),
        "net_purity": getValue(item, "net_purity"),
        "total_fine_weight": getValue(item, "fine_weight"),
        "metal_rate": getValue(item, "metal_rate"),
        "metal_amount": getValue(item, "metal_amount"),
        "labour_rate": getValue(item, "labour_rate"),
        "labour_amount": getValue(item, "labour_amount"),
        "other_amount": getValue(item, "other_amount"),
        "total_amount": getValue(item, "total_amount"),
      });
    }

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      //deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "";
      // deviceName = iosInfo.name;
    }
    final String entryId = _generateDeviceEntryId();
    final Map<String, dynamic> body = {
      "customer_id": int.parse(selectedItem!),
      "items": finalItems,
      "remarks": remarksController.text,
      "device_id":deviceId,
      "voucher_session_id": voucherSessionId,
      "device_entry_id": entryId,
    };

    debugPrint("FINAL BODY => ${jsonEncode(body)}");

    final response = await OfflineApiHelper.instance.postRequest(
      ApiConstants.Approval_store,
      body,
    );

    if (!mounted) return;

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 202)) {
      if (response.statusCode == 202) {
        AppMessage.success(context, "No Internet. Data saved offline.");
      } else {
        AppMessage.success(
          context,
          response.data["message"] ?? "Data Saved Successfully",
        );
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InvoiceScreen()),
            (route) => route.isFirst,
      );
    } else {
      final String message = response?.data is Map
          ? response?.data["message"]?.toString() ?? "Failed to save approval"
          : "Failed to save approval";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// ============================================================
  /// UPDATE
  /// ============================================================

  Future<void> UpdateApproval() async {
    if (selectedItem == null || widget.userData == null) {
      return;
    }

    final userId = widget.userData!["id"];

    final List<Map<String, dynamic>> finalItems = [];

    final combinedForUpdate = [
      ...items.map((e) => {...e, "source": "search"}),
      ...cartItems.map(
            (e) => {
          ...Map<String, dynamic>.from(e),
          "id": e["cart_id"] ?? e["id"],
          "itemset_id": e["itemset_id"] ?? e["id"],
          "source": "scan",
        },
      ),
    ];

    final Map<String, Map<String, dynamic>> uniqueMap = {};

    for (final dynamic raw in combinedForUpdate) {
      final item = Map<String, dynamic>.from(raw);

      final id = item["itemset_id"] ?? item["id"];

      if (id != null) {
        uniqueMap[id.toString()] = item;
      }
    }

    for (final item in uniqueMap.values) {
      calculateItem(item);

      final id = item["itemset_id"] ?? item["id"];

      if (id == null) {
        continue;
      }

      finalItems.add({
        "itemset_id": id,
        "gross_weight": getValue(item, "gross_weight"),
        "other_weight": getValue(item, "other_weight"),
        "net_weight": getValue(item, "net_weight"),
        "purity": getValue(item, "purity"),
        "waste_percent": getValue(item, "waste"),
        "net_purity": getValue(item, "net_purity"),
        "total_fine_weight": getValue(item, "fine_weight"),
        "metal_rate": getValue(item, "metal_rate"),
        "metal_amount": getValue(item, "metal_amount"),
        "labour_rate": getValue(item, "labour_rate"),
        "labour_amount": getValue(item, "labour_amount"),
        "other_amount": getValue(item, "other_amount"),
        "total_amount": getValue(item, "total_amount"),
      });
    }
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      //deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "";
      // deviceName = iosInfo.name;
    }
    final String entryId = _generateDeviceEntryId();
    final Map<String, dynamic> body = {
      "customer_id": int.parse(selectedItem!),
      "items": finalItems,
      "remarks": remarksController.text,
      "device_id":deviceId,
      "voucher_session_id": voucherSessionId,
      "device_entry_id": entryId,
    };

    debugPrint("UPDATE BODY => ${jsonEncode(body)}");

    final response = await ApiHelper().putRequest(
      "${ApiConstants.Approval_update}/$userId",
      body,
    );

    if (!mounted) {
      return;
    }

    if (response != null && response.statusCode == 200) {
      AppMessage.success(
        context,
        response.data["message"] ?? "Data Update Successfully",
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InvoiceScreen()),
            (route) => route.isFirst,
      );
    } else {
      final String message = response?.data is Map
          ? response?.data["message"]?.toString() ?? "Failed to update approval"
          : "Failed to update approval";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// ============================================================
  /// OTHER CHARGES POPUP
  /// ============================================================

  void showOtherChargesPopup(Map<String, dynamic> item, List apiList) {
    /// ============================================================
    /// 🔥 EXISTING OTHER AMOUNT (list API thi aavel value)
    /// item["other_amount"] / item["sale_other"] sathe charges na
    /// default_amount ne match kari ne pre-select karvani che, kem
    /// ke direct charge_id list API ma nathi.
    /// ============================================================
    final double existingOtherAmount = double.tryParse(
      item["other_amount"]?.toString() ??
          item["sale_other"]?.toString() ??
          "0",
    ) ??
        0;

    bool alreadyMatched = false;

    // ============================================================
    // API DATA -> POPUP DATA
    // ============================================================

    final List<Map<String, dynamic>> charges = apiList.map<Map<String, dynamic>>((e) {
      final String weightFormula =
          e["weight_formula"]?.toString().trim().toLowerCase() ?? "";

      final String amountFormula =
          e["other_amt_formula"]?.toString().trim().toLowerCase() ?? "";

      String wtFormula = "flat";

      if (weightFormula == "per_quantity" || weightFormula == "per_qty") {
        wtFormula = "per_qty";
      } else if (weightFormula == "per_weight" || weightFormula == "per_wt") {
        wtFormula = "per_weight";
      }

      String amtFormulaType = "flat";

      if (amountFormula == "per_quantity" || amountFormula == "per_qty") {
        amtFormulaType = "per_qty";
      } else if (amountFormula == "per_weight" || amountFormula == "per_wt") {
        amtFormulaType = "per_weight";
      } else if (amountFormula == "per_qty_weight" || amountFormula == "qty_weight") {
        amtFormulaType = "per_qty_weight";
      }

      final double defaultAmount = double.tryParse(e["default_amount"]?.toString() ?? "0") ?? 0;

      bool isSelected = false;

      if (!alreadyMatched && existingOtherAmount > 0 && defaultAmount == existingOtherAmount) {
        isSelected = true;
        alreadyMatched = true;
      }

      return {
        "id": e["id"],
        "charge": e["name"] ?? "",
        "amount": (e["default_amount"] ?? 0).toString(),
        "qty": (e["quantity_pcs"] ?? 1).toString(),
        "weight": (e["default_weight"] ?? 0).toString(),
        "wt_formula": wtFormula,
        "amt_formula_type": amtFormulaType,
        "amt_formula": "",
        "total_weight": "0.00",
        "total_amt": "0.00",
        "is_selected": isSelected,
      };
    }).toList();

    /// ============================================================
    /// 🔥 PERSISTENT CONTROLLERS
    /// ============================================================
    final Map<int, Map<String, TextEditingController>> rowControllers = {};

    for (int i = 0; i < charges.length; i++) {
      rowControllers[i] = {
        "amount": TextEditingController(text: charges[i]["amount"]?.toString() ?? "0"),
        "qty": TextEditingController(text: charges[i]["qty"]?.toString() ?? "1"),
        "weight": TextEditingController(text: charges[i]["weight"]?.toString() ?? "0"),
      };
    }

    /// ============================================================
    /// SINGLE-CHARGE CALCULATION
    /// ============================================================
    void calculateSingleCharge(Map<String, dynamic> c) {
      final double amt = double.tryParse(c["amount"]?.toString() ?? "0") ?? 0;
      final double qty = double.tryParse(c["qty"]?.toString() ?? "1") ?? 1;
      final double weight = double.tryParse(c["weight"]?.toString() ?? "0") ?? 0;

      final String amtFormula = c["amt_formula_type"]?.toString() ?? "flat";
      final String wtFormula = c["wt_formula"]?.toString() ?? "flat";

      double totalAmt = 0;
      double totalWeight = 0;

      switch (wtFormula) {
        case "per_qty":
          totalWeight = weight * qty;
          break;
        case "per_weight":
          totalWeight = weight * qty;
          break;
        default:
          totalWeight = weight;
      }

      c["total_weight"] = totalWeight.toStringAsFixed(2);

      switch (amtFormula) {
        case "per_qty":
          totalAmt = amt * qty;
          c["amt_formula"] = "$amt × $qty";
          break;

        case "per_weight":
          totalAmt = amt * totalWeight;
          c["amt_formula"] = "$amt × $totalWeight";
          break;

        case "per_qty_weight":
          totalAmt = amt * qty * weight;
          c["amt_formula"] = "$amt × $qty × $weight";
          break;

        default:
          totalAmt = amt;
          c["amt_formula"] = "$amt";
      }

      c["total_amt"] = totalAmt.toStringAsFixed(2);
    }

    for (final c in charges) {
      calculateSingleCharge(c);
    }

    double calcTotal() {
      double total = 0;
      for (final c in charges) {
        if (c["is_selected"] == true) {
          total += double.tryParse(c["total_amt"]?.toString() ?? "0") ?? 0;
        }
      }
      return total;
    }

    /// 🔥 SINGLE SELECT — Set<int> na badle int?
    int? initialSelectedIndex() {
      for (int i = 0; i < charges.length; i++) {
        if (charges[i]["is_selected"] == true) {
          return i;
        }
      }
      return null;
    }

    final ValueNotifier<double> totalNotifier = ValueNotifier<double>(calcTotal());
    final ValueNotifier<int?> selectedIndexNotifier =
    ValueNotifier<int?>(initialSelectedIndex());

    void disposeControllers() {
      for (final ctrls in rowControllers.values) {
        for (final c in ctrls.values) {
          c.dispose();
        }
      }
    }

    // ============================================================
    // SHOW DIALOG
    // ============================================================

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.50),
      builder: (dialogContext) {
        final Size screenSize = MediaQuery.of(dialogContext).size;
        final bool isTablet = screenSize.width >= 600;

        InputDecoration inputDecoration() {
          return InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.4),
            ),
          );
        }

        Widget headerCell(String title, double width, {bool left = false}) {
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                title,
                textAlign: left ? TextAlign.left : TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 30 : 12,
            vertical: 18,
          ),
          child: Container(
            width: isTablet ? 1050 : double.infinity,
            constraints: BoxConstraints(maxHeight: screenSize.height * 0.88),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.primaryDark.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ===========================================
                  // BLUE HEADER
                  // ===========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.gradientBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Other Charges",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text("Manage additional item charges",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text("${charges.length} Charges",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            disposeControllers();
                            Navigator.pop(dialogContext);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===========================================
                  // BODY
                  // ===========================================
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===================================
                          // SECTION TITLE
                          // ===================================
                          Row(
                            children: [
                              Container(
                                width: 29,
                                height: 29,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.iconBg,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryDark),
                              ),
                              const SizedBox(width: 8),
                              const Text("Charge Details",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const Spacer(),
                              ValueListenableBuilder<int?>(
                                valueListenable: selectedIndexNotifier,
                                builder: (context, selectedIndex, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primaryDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${selectedIndex != null ? 1 : 0} Selected",
                                          style: const TextStyle(
                                              color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 9),

                          // ===================================
                          // TABLE
                          // ===================================
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                            child: Container(
                              width: 685,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // ===========================
                                  // TABLE HEADER
                                  // ===========================
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBg,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        headerCell("Charge", 110, left: true),
                                        headerCell("Amount", 90),
                                        headerCell("Qty", 70),
                                        headerCell("Wt Formula", 105),
                                        headerCell("Amt Formula", 115),
                                        headerCell("Total Amt", 105),
                                        const SizedBox(
                                          width: 45,
                                          child: Center(
                                            child: Icon(
                                              Icons.check_circle_outline_rounded,
                                              color: AppColors.primaryDark,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Divider(height: 1, thickness: 1, color: AppColors.border),

                                  // ===========================
                                  // CHARGE LIST
                                  // ===========================
                                  SizedBox(
                                    height: 230,
                                    child: charges.isEmpty
                                        ? const Center(
                                      child: Text(
                                        "No charges available",
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                        : ListView.separated(
                                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      itemCount: charges.length,
                                      separatorBuilder: (context, index) {
                                        return Divider(height: 1, color: AppColors.border);
                                      },
                                      itemBuilder: (context, index) {
                                        final c = charges[index];

                                        return StatefulBuilder(
                                          builder: (context, setStateRow) {
                                            void onFieldChanged() {
                                              c["amount"] = rowControllers[index]!["amount"]!.text;
                                              c["qty"] = rowControllers[index]!["qty"]!.text;
                                              c["weight"] = rowControllers[index]!["weight"]!.text;

                                              calculateSingleCharge(c);

                                              setStateRow(() {});

                                              totalNotifier.value = calcTotal();
                                            }

                                            return ValueListenableBuilder<int?>(
                                              valueListenable: selectedIndexNotifier,
                                              builder: (context, selectedIndex, _) {
                                                final bool selected = selectedIndex == index;

                                                return AnimatedContainer(
                                                  duration: const Duration(milliseconds: 150),
                                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? AppColors.primaryDark.withOpacity(0.035)
                                                        : Colors.white,
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: selected ? AppColors.primaryDark : Colors.transparent,
                                                        width: 3,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // ===================
                                                      // CHARGE
                                                      // ===================
                                                      SizedBox(
                                                        width: 110,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 24,
                                                                height: 24,
                                                                alignment: Alignment.center,
                                                                decoration: BoxDecoration(
                                                                  color: selected
                                                                      ? AppColors.primaryDark.withOpacity(0.12)
                                                                      : AppColors.iconBg,
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  "${index + 1}",
                                                                  style: const TextStyle(
                                                                    color: AppColors.primaryDark,
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 5),
                                                              Expanded(
                                                                child: Text(
                                                                  c["charge"]?.toString() ?? "",
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontSize: 10.5,
                                                                    fontWeight:
                                                                    selected ? FontWeight.w700 : FontWeight.w600,
                                                                    color: AppColors.textPrimary,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // AMOUNT
                                                      // ===================
                                                      SizedBox(
                                                        width: 90,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["amount"],
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            decoration: inputDecoration(),
                                                            onChanged: (_) => onFieldChanged(),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // QTY
                                                      // ===================
                                                      SizedBox(
                                                        width: 70,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: TextFormField(
                                                            controller: rowControllers[index]!["qty"],
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                            keyboardType:
                                                            const TextInputType.numberWithOptions(decimal: true),
                                                            decoration: inputDecoration(),
                                                            onChanged: (_) => onFieldChanged(),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // WT FORMULA
                                                      // ===================
                                                      SizedBox(
                                                        width: 105,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: DropdownButtonFormField<String>(
                                                            value: c["wt_formula"],
                                                            isExpanded: true,
                                                            dropdownColor: Colors.white,
                                                            icon: const Icon(
                                                              Icons.keyboard_arrow_down_rounded,
                                                              color: AppColors.primaryDark,
                                                              size: 17,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              color: AppColors.textPrimary,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            decoration: inputDecoration(),
                                                            items: const [
                                                              DropdownMenuItem(value: "flat", child: Text("Flat")),
                                                              DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
                                                              DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
                                                            ],
                                                            onChanged: (v) {
                                                              if (v == null) return;
                                                              c["wt_formula"] = v;
                                                              onFieldChanged();
                                                            },
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // AMOUNT FORMULA
                                                      // ===================
                                                      SizedBox(
                                                        width: 115,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: DropdownButtonFormField<String>(
                                                            value: c["amt_formula_type"] ?? "flat",
                                                            isExpanded: true,
                                                            dropdownColor: Colors.white,
                                                            icon: const Icon(
                                                              Icons.keyboard_arrow_down_rounded,
                                                              color: AppColors.primaryDark,
                                                              size: 17,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 9.8,
                                                              color: AppColors.textPrimary,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            decoration: inputDecoration(),
                                                            items: const [
                                                              DropdownMenuItem(value: "flat", child: Text("Flat")),
                                                              DropdownMenuItem(value: "per_qty", child: Text("Per Qty")),
                                                              DropdownMenuItem(value: "per_weight", child: Text("Per Wt")),
                                                              DropdownMenuItem(
                                                                  value: "per_qty_weight", child: Text("Qty × Wt")),
                                                            ],
                                                            onChanged: (v) {
                                                              if (v == null) return;
                                                              c["amt_formula_type"] = v;
                                                              onFieldChanged();
                                                            },
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // TOTAL AMOUNT
                                                      // ===================
                                                      SizedBox(
                                                        width: 105,
                                                        child: Center(
                                                          child: Container(
                                                            constraints: const BoxConstraints(minWidth: 70),
                                                            padding:
                                                            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFEAF1FF),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: AppColors.primaryDark.withOpacity(0.12),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              c["total_amt"]?.toString() ?? "0.00",
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(
                                                                fontSize: 10.5,
                                                                fontWeight: FontWeight.w800,
                                                                color: AppColors.primaryDark,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // ===================
                                                      // CHECKBOX (SINGLE-SELECT)
                                                      // ===================
                                                      SizedBox(
                                                        width: 45,
                                                        child: Center(
                                                          child: Transform.scale(
                                                            scale: 0.88,
                                                            child: Checkbox(
                                                              value: selected,
                                                              activeColor: AppColors.primaryDark,
                                                              checkColor: Colors.white,
                                                              side: const BorderSide(
                                                                color: AppColors.primaryDark,
                                                                width: 1.3,
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              onChanged: (val) {
                                                                if (selectedIndexNotifier.value != null) {
                                                                  charges[selectedIndexNotifier.value!]
                                                                  ["is_selected"] = false;
                                                                }

                                                                if (val == true) {
                                                                  c["is_selected"] = true;
                                                                  selectedIndexNotifier.value = index;
                                                                } else {
                                                                  c["is_selected"] = false;
                                                                  selectedIndexNotifier.value = null;
                                                                }

                                                                totalNotifier.value = calcTotal();
                                                              },
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
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ===================================
                          // TOTAL SUMMARY
                          // ===================================
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF3F7FF), Color(0xFFEAF1FF)],
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primaryDark),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Selected Charges Total",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ValueListenableBuilder<int?>(
                                        valueListenable: selectedIndexNotifier,
                                        builder: (context, selectedIndex, _) {
                                          return Text(
                                            "${selectedIndex != null ? 1 : 0} of ${charges.length} charges selected",
                                            style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: totalNotifier,
                                  builder: (context, total, _) {
                                    return Text(
                                      total.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===========================================
                  // BOTTOM ACTION BAR
                  // ===========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        // ===============================
                        // CANCEL
                        // ===============================
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                disposeControllers();
                                Navigator.pop(dialogContext);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ===============================
                        // APPLY
                        // ===============================
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 42,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(7),
                                onTap: () {
                                  item["other_amount"] = totalNotifier.value.toStringAsFixed(2);

                                  updateController(item, "other_amount");

                                  calculateItem(item);

                                  updateFinalItems();

                                  FocusManager.instance.primaryFocus?.unfocus();

                                  disposeControllers();

                                  Navigator.pop(dialogContext);

                                  setState(() {});
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primaryDark, AppColors.gradientBlue],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryDark.withOpacity(0.22),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 17),
                                      SizedBox(width: 6),
                                      Text(
                                        "Apply Charges",
                                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  /// ============================================================
  /// SCANNER WIDGET
  /// ============================================================

  Widget _buildScannerSection() {
    double scannerSize = MediaQuery.of(context).size.width * 0.4;

    if (MediaQuery.of(context).size.width > 600) {
      scannerSize = 350;
    }

    return Container(
      width: scannerSize,
      height: scannerSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: MobileScanner(
          controller: scannerController,
          errorBuilder: (context, error) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && showScannerFull) {
                _startScanner();
              }
            });

            return const Center(
              child: Text(
                "Initializing camera...",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          },
          onDetect: (barcodeCapture) {
            if (isBusy) {
              return;
            }

            if (barcodeCapture.barcodes.isEmpty) {
              return;
            }

            final barcode = barcodeCapture.barcodes.first;

            final String? code = barcode.rawValue;

            if (code == null || code.trim().isEmpty) {
              return;
            }

            if (lastCode == code) {
              return;
            }

            lastCode = code;

            isBusy = true;

            scanApiCall(code).whenComplete(() {
              Future.delayed(const Duration(milliseconds: 600), () {
                isBusy = false;
                lastCode = null;   // 🔥 have same/alag koi pan QR fari scan thai shake
              });
            });
          },
        ),
      ),
    );
  }

  /// ============================================================
  /// SCAN API
  /// ============================================================

  Future<void> scanApiCall(String code) async {
    final userId = widget.userData?["customer_id"] ?? 0;

    final int customerId = isEditMode
        ? int.tryParse(userId.toString()) ?? 0
        : int.tryParse(selectedUserId ?? selectedItem ?? "") ?? 0;

    if (customerId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select customer first"),
            backgroundColor: Colors.red,
          ),
        );
      }

      lastCode = null;

      return;
    }

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      //deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "";
     // deviceName = iosInfo.name;
    }
   // deviceId ??= await getOrCreateDeviceId();

    final String entryId = _generateDeviceEntryId();
    final Map<String, dynamic> body = {
      "qr_code": code,
      "customer_id": customerId,
      "device_id":deviceId,
      "voucher_session_id": voucherSessionId,
      "device_entry_id": entryId,
    };

    debugPrint("SCAN BODY => $body");

    final response = await ApiHelper().postRequest(
      ApiConstants.Approval_scan_qr,
      body,
    );

    if (!mounted) {
      return;
    }

    if (response != null &&
        response.statusCode == 200 &&
        response.data["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item Scan Successfully"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      await getCartItems(customerId: selectedUserId ?? selectedItem);
    } else {
      final String message = response?.data is Map
          ? response?.data["message"]?.toString() ?? "Scan Failed"
          : "Scan Failed";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );

      lastCode = null;
    }
  }

  /// ============================================================
  /// GET CART
  ///
  /// 🔥 IMPORTANT: `customerId` optional parameter add karyu che.
  /// Jo pass thay to backend ne "${Approval_scan_list}?customer_id=X"
  /// rite call thay, jethi e customer nu pending scan-cart j
  /// pacho aave. Jo pass na thay to jyare selectedUserId/selectedItem
  /// available hoy e use thay, nahi to backward-compatible rite
  /// plain endpoint call thay (jaino existing behavior tuto na jay).
  /// ============================================================

  Future<void> getCartItems({String? customerId}) async {
    final String effectiveCustomerId =
    (customerId ?? selectedUserId ?? selectedItem ?? "").toString();

    final String url = effectiveCustomerId.isNotEmpty
        ? "${ApiConstants.Approval_scan_list}?customer_id=$effectiveCustomerId"
        : ApiConstants.Approval_scan_list;

    final response = await ApiHelper().getRequest(url);

    if (response != null && response.statusCode == 200) {
      final List rawData = response.data["data"] ?? [];

      final List data = rawData.reversed.toList();

      cartItems = List.from(data);

      for (final dynamic raw in cartItems) {
        final item = raw as Map<String, dynamic>;

        item["gross_weight"] = item["gross_weight"]?.toString() ?? "0";

        item["other_weight"] = item["other_weight"]?.toString() ?? "0";

        item["net_weight"] = item["net_weight"]?.toString() ?? "0";

        item["purity"] = item["purity"]?.toString() ?? "0";

        item["waste"] = item["waste"]?.toString() ?? "0";

        item["metal_rate"] = item["metal_rate"]?.toString() ?? "0";

        item["labour_rate"] = item["labour_rate"]?.toString() ?? "0";

        item["other_amount"] =
            item["sale_other"]?.toString() ??
                item["other_amount"]?.toString() ??
                "0";

        _initializeItemControllers(item);

        setController(item, "gross_weight", item["gross_weight"]);

        setController(item, "other_weight", item["other_weight"]);

        setController(item, "purity", item["purity"]);

        setController(item, "waste", item["waste"]);

        setController(item, "metal_rate", item["metal_rate"]);

        setController(item, "labour_rate", item["labour_rate"]);

        setController(item, "other_amount", item["other_amount"]);

        calculateItem(item);
      }

      updateFinalItems();

      if (mounted) {
        setState(() {});
      }
    } else {
      cartItems = [];

      updateFinalItems();

      if (mounted) {
        setState(() {});
      }
    }
  }

  /// ============================================================
  /// DELETE CART
  /// 🔥 Return type bool — success/fail upar caller decide karto
  /// ke local state update karvu ke nai.
  /// ============================================================

  Future<bool> deleteUser(String ID) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.Approval_cart_remove}/$ID",
      );

      if (response?.statusCode == 200) {
        debugPrint("Deleted Successfully");
        return true;
      }

      debugPrint("Delete failed with status: ${response?.statusCode}");
      return false;
    } catch (e) {
      debugPrint("Delete exception: $e");
      return false;
    }
  }

  /// ============================================================
  /// SUMMARY
  /// ============================================================

  Widget buildSummaryRow() {
    final totals = calculateTotals();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryBox("Items", "${uniqueItems.length}"),
            _summaryBox("Gross", totals["gross"]!.toStringAsFixed(3)),
            _summaryBox("Other", totals["other"]!.toStringAsFixed(3)),
            _summaryBox("Net", totals["net"]!.toStringAsFixed(3)),
            _summaryBox("Total", totals["total"]!.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Map<String, double> calculateTotals() {
    double gross = 0;

    double other = 0;

    double net = 0;

    double total = 0;

    for (final item in uniqueItems) {
      gross += double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0;

      other += double.tryParse(item["other_weight"]?.toString() ?? "0") ?? 0;

      net += double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;

      total += double.tryParse(item["total_amount"]?.toString() ?? "0") ?? 0;
    }

    return {"gross": gross, "other": other, "net": net, "total": total};
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

  /// ============================================================
  /// EXPANDED INPUT FIELD
  /// ============================================================

  Widget _inputField(String title, Map<String, dynamic> item, String key) {
    final controller = getController(item, key);

    final bool editable = isEditableField(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 4),

        TextFormField(
          controller: controller,
          readOnly: !editable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          style: TextStyle(
            color: editable ? Colors.black : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          onTap: () {
            if (!editable) {
              return;
            }

            if (controller.text == "0" ||
                controller.text == "0.0" ||
                controller.text == "0.00" ||
                controller.text == "0.000") {
              controller.clear();
            }
          },
          onChanged: (val) {
            item[key] = val;

            calculateItem(item);
          },
          onEditingComplete: () {
            if (controller.text.trim().isEmpty) {
              controller.text = "0";

              item[key] = "0";
            }

            calculateItem(item);

            updateFinalItems();

            FocusScope.of(context).unfocus();
          },
          onTapOutside: (_) {
            if (!editable) {
              return;
            }

            if (controller.text.trim().isEmpty) {
              controller.text = "0";

              item[key] = "0";
            }

            calculateItem(item);

            FocusScope.of(context).unfocus();

            updateFinalItems();
          },
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: editable ? Colors.white : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 9,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AppColors.primaryDark, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// OPTIONAL OLD UI HELPERS
  /// ============================================================

  Widget buildUserCard(Map item) {
    final size = MediaQuery.of(context).size;

    final isTablet = size.width >= 600;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: const Color(0xffFAF7F2).withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              statusChip(item["metal"].toString()),
              const Spacer(),
              Row(
                children: [
                  premiumIconBtn(Icons.edit, Colors.blue, onTap: () {}),
                  SizedBox(width: isTablet ? 10 : 8),
                  premiumIconBtn(
                    Icons.delete,
                    Colors.red,
                    onTap: () {
                      _showDeleteDialog(item);
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  item["item_name"] ?? "",
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item["qr_code"] ?? "",
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                _erpRow(
                  "Gross",
                  item["gross_weight"]?.toString() ?? "-",
                  "Net",
                  item["net_weight"]?.toString() ?? "-",
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _erpRow(
                  "Purity",
                  item["purity"]?.toString() ?? "-",
                  "Amount",
                  "₹ ${item["amount"]?.toString() ?? "0"}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        startColor = const Color(0xff9E9E9E);

        endColor = const Color(0xffCFCFCF);

        label = "Unknown";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
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
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _erpRow(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    t1,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    v1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
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

  void _showDeleteDialog(Map user) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final screenWidth = MediaQuery.of(context).size.width;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              width: screenWidth * 0.85,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xffff4e50), Color(0xfff00000)],
                      ),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Delete User?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Are you sure you want to delete ${user["name"]}?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff00000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);

                            final id = user["cart_id"];

                            if (id != null) {
                              await deleteUser(id.toString());
                            }
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 🔥 DEVICE ID — SharedPreferences ma ek vaar generate + save
  /// ============================================================

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString('device_id');

    if (id == null || id.trim().isEmpty) {
      id =
      "android-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch % 100000}";

      await prefs.setString('device_id', id);
    }

    return id;
  }

  String _generateDeviceEntryId() {
    final String base = deviceId ?? 'unknown-device';

    return "$base-${DateTime.now().microsecondsSinceEpoch}";
  }

  /// ============================================================
  /// MANUAL SEARCH -> APPROVAL CART ADD
  /// (Approval_cart_add API, scanApiCall na badle)
  /// ============================================================

  Future<void> addManualSearchItemToCart(dynamic item) async {
    final int customerId = int.tryParse(
      selectedUserId ?? selectedItem ?? "",
    ) ?? 0;

    if (customerId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select customer first"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    /// 🔥 device_id fetch (already fetched hoy to skip)
    if (deviceId == null || deviceId!.trim().isEmpty) {
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

        if (Platform.isAndroid) {
          final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? "";
        }
      } catch (e) {
        debugPrint("DeviceInfo Error: $e");
      }
    }

    voucherSessionId ??= 'APP-${DateTime.now().millisecondsSinceEpoch}';

    final String entryId = _generateDeviceEntryId();

    final dynamic itemsetId = item["itemset_id"] ?? item["id"];

    final Map<String, dynamic> body = {
      "customer_id": customerId,
      "itemset_id": itemsetId,
      "device_id": deviceId,
      "voucher_session_id": voucherSessionId,
      "device_entry_id": entryId,
    };

    debugPrint("📤 APPROVAL CART ADD BODY => $body");

    final response = await ApiHelper().postRequest(
      ApiConstants.Approval_cart_add,
      body,
    );

    if (!mounted) return;

    if (response != null &&
        response.statusCode == 200 &&
        response.data["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item added successfully"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      /// 🔥 IMPORTANT: existing getCartItems() flow reuse — item
      /// cartItems ma (source: "scan") add thai jay, delete pan
      /// existing cart_id-based flow thi j kaam kare.
      await getCartItems(customerId: selectedUserId ?? selectedItem);
    } else {
      final String message = response?.data is Map
          ? response?.data["message"]?.toString() ?? "Failed to add item"
          : "Failed to add item";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 🔥 Customer select / clear
  void _setCustomer(Map<String, dynamic>? customer) {
    setState(() {
      selectedItem = customer?["id"]?.toString();
      selectedCompanyId = customer?["company_id"]?.toString();
      selectedUserId = customer?["id"]?.toString();

      /// જૂના customer નો cart તરત સાફ, નવો નીચે load થશે
      cartItems = [];
    });

    updateFinalItems();

    if (customer == null) return;

    /// 🔥 આ customer નો pending (પહેલાં scan થયેલો) cart load
    getCartItems(customerId: selectedUserId);
  }

}

/// ============================================================
/// SCANNER LINE
/// ============================================================

class _ScannerLineAnimation extends StatefulWidget {
  const _ScannerLineAnimation({super.key});

  @override
  State<_ScannerLineAnimation> createState() => _ScannerLineAnimationState();
}

class _ScannerLineAnimationState extends State<_ScannerLineAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, animation.value * 2 - 1),
          child: Container(
            width: double.infinity,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.greenAccent,
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }
}

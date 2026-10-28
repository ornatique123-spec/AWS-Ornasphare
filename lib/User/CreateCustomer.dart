



// import 'dart:ui';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_colorpicker/flutter_colorpicker.dart';
// import 'package:pecifician_sysytem/User/UserScreen.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import '../Extra/ItemProvider.dart';
// import '../Extra/PremiumSearchableDropdown.dart';
// import '../Offline Data/offline_api_helper.dart';
// import 'CustomerScreen.dart';
//
// class Createcustomer extends StatefulWidget {
//   final Map? userData;
//
//   /// 🔥 GST Search mathi aavelo data (Add Customer dabavya pachhi)
//   final Map? gstData;
//
//   const Createcustomer({super.key, this.userData, this.gstData});
//
//   @override
//   State<Createcustomer> createState() => _CreatecustomerState();
// }
//
// class _CreatecustomerState extends State<Createcustomer> {
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController personCodeController = TextEditingController();
//   final TextEditingController cityController = TextEditingController();
//   final TextEditingController addressController = TextEditingController();
//   final TextEditingController areaController = TextEditingController();
//   final TextEditingController landmarkController = TextEditingController();
//   final TextEditingController pincodeController = TextEditingController();
//   final TextEditingController mobileController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController contact1NameController = TextEditingController();
//   final TextEditingController contact1PhoneController = TextEditingController();
//   final TextEditingController contact2NameController = TextEditingController();
//   final TextEditingController contact2PhoneController = TextEditingController();
//   final TextEditingController gstController = TextEditingController();
//   final TextEditingController panController = TextEditingController();
//   final TextEditingController aadhaarController = TextEditingController();
//   final TextEditingController hallmarkController = TextEditingController();
//   final TextEditingController referenceController = TextEditingController();
//   final TextEditingController remarksController = TextEditingController();
//   final TextEditingController birthDateController = TextEditingController();
//   final TextEditingController anniversaryDateController = TextEditingController();
//
//   List<Map<String, dynamic>> _addressSuggestions = [];
//   bool _showAddressSuggestions = false;
//   bool _isAddressLoading = false;
//   final LayerLink _layerLink = LayerLink();
//   OverlayEntry? _overlayEntry;
//
//   static const String _googleApiKey = 'AIzaSyBJ9-wGDcXiPPZeqpUZIHt-BTgVcW429yE';
//   bool get isEditMode => widget.userData != null;
//
//   String? selectedRole = "Active";
//   DateTime? birthDate;
//   DateTime? anniversaryDate;
//   String? selectedcategoryId;   // ✅ only ID
//   String? selected_category_name;
//   @override
//   void initState() {
//     super.initState();
//     Future.microtask(() {
//       Provider.of<ItemProvider>(context, listen: false).refreshcategorylist();
//     });
//
//     if (isEditMode) {
//       final user = widget.userData!;
//
//       nameController.text = user["name"] ?? "";
//       emailController.text = user["email"] ?? "";
//       personCodeController.text = user["person_code"] ?? "";
//       cityController.text = user["city"] ?? "";
//       addressController.text = user["address"] ?? "";
//       areaController.text = user["area"] ?? "";
//       landmarkController.text = user["landmark"] ?? "";
//       pincodeController.text = user["pincode"] ?? "";
//       mobileController.text = user["mobile_no"] ?? "";
//       phoneController.text = user["phone_no"] ?? "";
//       contact1NameController.text = user["contact_person1_name"] ?? "";
//       contact1PhoneController.text = user["contact_person1_phone"] ?? "";
//       contact2NameController.text = user["contact_person2_name"] ?? "";
//       contact2PhoneController.text = user["contact_person2_phone"] ?? "";
//       gstController.text = user["gst_no"] ?? "";
//       panController.text = user["pan_no"] ?? "";
//       aadhaarController.text = user["aadhaar_no"] ?? "";
//       hallmarkController.text = user["hallmark_license_no"] ?? "";
//       referenceController.text = user["reference"] ?? "";
//
//       bool isActive = user["is_active"] == true || user["is_active"].toString() == "1";
//
//       selectedRole = isActive ? "Active" : "Inactive";
//       // Category Set Here
//       if (user["category_person"] != null) {
//         selectedcategoryId =
//             user["category_person"]["id"].toString();
//
//         selected_category_name =
//         user["category_person"]["category_name"];
//       }
//
//       if (user["birth_date"] != null) {
//         birthDateController.text = user["birth_date"];
//       }
//
//       if (user["anniversary_date"] != null) {
//         anniversaryDateController.text = user["anniversary_date"];
//       }
//     }
//
//     // 🔥 GST Search mathi aavelo data form ma set karo
//     if (!isEditMode && widget.gstData != null) {
//       _fillFromGst(widget.gstData!);
//     }
//   }
//
//   /// GST Search na data → form fields
//   /// (API nu "customer_form" pehla, nahi to business details)
//   void _fillFromGst(Map gst) {
//     final Map form =
//     gst["customer_form"] is Map ? gst["customer_form"] : const {};
//
//     String pick(List<dynamic> values) {
//       for (final v in values) {
//         final s = v?.toString().trim() ?? "";
//         if (s.isNotEmpty && s != "null") return s;
//       }
//       return "";
//     }
//
//     nameController.text =
//         pick([form["name"], gst["business_name"], gst["name"], gst["legal_name"]]);
//     emailController.text = pick([form["email"], gst["email"]]);
//     mobileController.text = pick([form["mobile_no"], gst["mobile_no"]]);
//     cityController.text = pick([form["city"], gst["city"]]);
//     areaController.text = pick([form["area"], gst["area"]]);
//     landmarkController.text = pick([form["landmark"], gst["landmark"]]);
//     pincodeController.text = pick([form["pincode"], gst["pincode"]]);
//     addressController.text = pick([form["address"], gst["address"]]);
//     gstController.text = pick([form["gst_no"], gst["gstin"], gst["gst_no"]]);
//     panController.text = pick([form["pan_no"], gst["pan"], gst["pan_no"]]);
//     remarksController.text = pick([
//       form["remarks"],
//       gst["legal_name"] != null && pick([gst["legal_name"]]).isNotEmpty
//           ? "Legal name: ${gst["legal_name"]}"
//           : null,
//     ]);
//
//     // Category (API ma category_person_id = Customer)
//     final String categoryId = pick([form["category_person_id"]]);
//     if (categoryId.isNotEmpty) selectedcategoryId = categoryId;
//
//     // Status
//     if (form["is_active"] != null) {
//       final bool active = form["is_active"] == true ||
//           form["is_active"].toString() == "1";
//       selectedRole = active ? "Active" : "Inactive";
//     }
//
//     debugPrint("✅ GST data form ma set: ${gstController.text}");
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     final size = MediaQuery.of(context).size;
//     final height = size.height;
//     final width = size.width;
//     final isMobile = width < 600;
//     return Scaffold(
//       resizeToAvoidBottomInset: false,
//       backgroundColor: AppColors.white,
//       body: Stack(
//         children: [
//
//
//
//           /// ✅ Main Content
//           Column(
//             children: [
//               /// IMPORTANT: top padding space leave karvu (AppBar mate)
//               SizedBox(
//                 height: MediaQuery.of(context).padding.top + 40,
//               ),
//
//               /// 🔥 Dynamic Bottom Section
//               Expanded(
//                 child: _buildRecentScansList(context),
//               ),
//
//               InkWell(
//                 onTap: () {
//                   if (isEditMode) {
//                     update_user();
//                   } else {
//                     create_user();
//                   }
//                 },
//                 borderRadius: BorderRadius.circular(10),
//                 child: Container(
//                   margin: const EdgeInsets.all(16),
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         AppColors.primaryDark.withOpacity(0.7),
//                         AppColors.secondaryDark.withOpacity(0.7),
//                       ],
//                     ),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Center(
//                     child: Text(
//                       isEditMode?"Update Person":"Save Person",
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           /// ✅ APPBAR (OVERLAY)
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.only(
//                 top: 30,
//                 left: 16,
//                 right: 16,
//                 bottom: 16,
//               ),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//
//                   /// ✅ CENTER TITLE
//                   const Text(
//                     "Create Person",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//
//                   /// ✅ LEFT BACK ICON
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: InkWell(
//                       onTap: () => Navigator.pop(context),
//                       child: Container(
//                         padding: EdgeInsets.all(isMobile ? 6 : 8),
//                         decoration: BoxDecoration(
//                           color:AppColors.primaryDark,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         child: Icon(
//                           Icons.arrow_back,
//                           color: Colors.white,
//                           size: isMobile ? 20 : 24,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                   /// RIGHT NOTIFICATION ICON
//                   // Align(
//                   //   alignment: Alignment.centerRight,
//                   //
//                   //   child: Container(
//                   //     padding: EdgeInsets.all(isMobile ? 6 : 8),
//                   //
//                   //     decoration: BoxDecoration(
//                   //       color: Colors.white,
//                   //
//                   //       borderRadius: BorderRadius.circular(8),
//                   //
//                   //       boxShadow: [
//                   //         BoxShadow(
//                   //           color: AppColors.shadow,
//                   //
//                   //           blurRadius: 20,
//                   //
//                   //           offset: const Offset(5, 10),
//                   //         ),
//                   //       ],
//                   //     ),
//                   //
//                   //     child: Stack(
//                   //       clipBehavior: Clip.none,
//                   //
//                   //       children: [
//                   //         Icon(
//                   //           Icons.notifications_none,
//                   //
//                   //           size: isMobile ? 22 : 24,
//                   //
//                   //           color: Colors.red,
//                   //         ),
//                   //
//                   //         Positioned(
//                   //           right: -2,
//                   //
//                   //           top: -2,
//                   //
//                   //           child: Container(
//                   //             height: 8,
//                   //
//                   //             width: 8,
//                   //
//                   //             decoration: const BoxDecoration(
//                   //               color: Colors.red,
//                   //
//                   //               shape: BoxShape.circle,
//                   //             ),
//                   //           ),
//                   //         ),
//                   //       ],
//                   //     ),
//                   //   ),
//                   // ),
//                 ],
//               ),
//             ),
//           )
//
//
//
//
//         ],
//       ),
//
//     );
//   }
//
//
//   /// ✅ Recent Scan List
//   Widget _buildRecentScansList(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//     final isTablet = width > 700;
//
//     Widget responsiveRow(List<Widget> children) {
//       if (children.length == 1) {
//         return Padding(
//           padding: EdgeInsets.only(bottom: height * 0.015),
//           child: children.first,
//         );
//       }
//
//       if (!isTablet) {
//         return Column(
//           children: children.map((e) => Padding(
//             padding: EdgeInsets.only(bottom: height * 0.015),
//             child: e,
//           )).toList(),
//         );
//       }
//
//       return Padding(
//         padding: EdgeInsets.only(bottom: height * 0.015),
//         child: Row(
//           children: children.map((e) => Expanded(
//             child: Padding(
//               padding: EdgeInsets.only(right: width * 0.015),
//               child: e,
//             ),
//           )).toList(),
//         ),
//       );
//     }
//
//     return SingleChildScrollView(
//       child: Column(
//         children: [
//
//           /// ================= BASIC INFO =================
//           Container(
//             margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: AppColors.cardBackground,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: AppColors.border),
//             ),
//
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//
//                 Text(
//                   "Basic Information",
//                   style: TextStyle(
//                     fontSize: isTablet ? 16 : 15,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
//                   ),
//                 ),
//
//                 SizedBox(height: height * 0.015),
//
//                 twoFieldRow(
//                   _buildTextField(
//                     context,
//                     "Name",
//                     controller: nameController,
//                     isRequired: true, // 🔥 show *
//                   ),
//
//                   _buildTextField(
//                     context,
//                     "Email",
//                     controller: emailController,
//                     isRequired: true, // 🔥 show *
//                   ),
//                 ),
//
//                 Consumer<ItemProvider>(
//                   builder: (context, provider, child) {
//                     if (provider.isLoading) {
//                       return const CircularProgressIndicator();
//                     }
//
//                     final List<Map<String, dynamic>> categoryItems =
//                     provider.category
//                         .map<Map<String, dynamic>>(
//                           (e) => {
//                         ...Map<String, dynamic>.from(e),
//
//                         /// Global premium dropdown mate
//                         "item_name":
//                         e["category_name"]?.toString() ?? "",
//                       },
//                     )
//                         .toList();
//
//                     Map<String, dynamic>? selectedCategory;
//
//                     if (selectedcategoryId != null) {
//                       for (final item in categoryItems) {
//                         if (item["id"].toString() ==
//                             selectedcategoryId.toString()) {
//                           selectedCategory = item;
//                           break;
//                         }
//                       }
//                     }
//
//                     return twoFieldRow1(
//                       _buildTextField(
//                         context,
//                         "Remarks",
//                         controller: remarksController,
//                       ),
//
//                       PremiumItemSearchDropdown(
//                         label: "Category",
//                         hint: "Select Category",
//                         items: categoryItems,
//                         value: selectedCategory,
//                         requiredField: true,
//                         onChanged: (selected) {
//                           setState(() {
//                             if (selected == null) {
//                               selectedcategoryId = null;
//                               selected_category_name = null;
//                               return;
//                             }
//
//                             selectedcategoryId =
//                                 selected["id"]?.toString();
//
//                             selected_category_name =
//                                 selected["category_name"]
//                                     ?.toString() ??
//                                     selected["item_name"]
//                                         ?.toString() ??
//                                     "";
//                           });
//
//                           debugPrint(
//                             "Category ID => $selectedcategoryId",
//                           );
//
//                           debugPrint(
//                             "Category Name => $selected_category_name",
//                           );
//                         },
//                       ),
//                     );
//                   },
//                 ),
//
//                 twoFieldRow(
//                   _buildTextField(
//                     context,
//                     "Mobile",
//                     controller: mobileController,
//                     isRequired: true, // 🔥 show *
//                     isNumber: true,
//                   ),
//
//                   _buildTextField(
//                     context,
//                     "City",
//                     controller: cityController,
//                     isRequired: true, // 🔥 show *
//                   ),
//                 ),
//
//                 twoFieldRow(
//                   _buildTextField(
//                     context,
//                     "Area",
//                     controller: areaController,
//                   ),
//
//                   _buildTextField(
//                     context,
//                     "Landmark",
//                     controller: landmarkController,
//                   ),
//                 ),
//
//                 twoFieldRow(
//                   _buildTextField(
//                     context,
//                     "Pincode",
//                     controller: pincodeController,
//                     isNumber: true,
//                   ),
//                   _buildAddressField(context),
//                 ),
//
//                 twoFieldRow(
//
//                   _buildTextField(
//                     context,
//                     "Contact 1 Name",
//                     controller: contact1NameController,
//                   ),
//                   _buildTextField(
//                     context,
//                     "Contact 1 Phone",
//                     controller: contact1PhoneController,
//                     isNumber: true,
//                   ),
//
//                 ),
//
//                 twoFieldRow(
//
//
//                   _buildTextField(
//                     context,
//                     "Contact 2 Name",
//                     controller: contact2NameController,
//                   ),
//
//                   _buildTextField(
//                     context,
//                     "Contact 2 Phone",
//                     controller: contact2PhoneController,
//                     isNumber: true,
//                   ),
//                 ),
//
//                 twoFieldRow(
//                   _buildTextField(
//                     context,
//                     "Gst",
//                     controller: gstController,
//                   ),
//
//                   _buildTextField(
//                     context,
//                     "Pan No",
//                     controller: panController,
//                   ),
//                 ),
//
//                 twoFieldRow(
//                   _buildTextField(
//                     context,
//                     "Aadhar No",
//                     controller: aadhaarController,
//                     isNumber: true,
//                   ),
//
//                   _buildTextField(
//                     context,
//                     "Refrence",
//                     controller: referenceController,
//                   ),
//                 ),
//                 twoFieldRow(
//                   _buildDateFieldNew(context, "Birth Date", birthDateController),
//                   _buildDateFieldNew(context, "Anniversary", anniversaryDateController),
//                 ),
//
//                 twoFieldRow(
//                   _buildTextField(context, "Remarks", controller: remarksController),
//
//                   _buildDropdown(
//                     context,
//                     "Status",
//                     ["Active", "Inactive"],
//                     selectedRole,
//                         (val) {
//                       setState(() {
//                         selectedRole = val;
//                         print("STATUS SELECTED => $selectedRole");
//                       });
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//   Widget twoFieldRow(Widget left, Widget right) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Row(
//         children: [
//
//           Expanded(child: left),
//
//           const SizedBox(width: 10),
//
//           Expanded(child: right),
//         ],
//       ),
//     );
//   }
//
//   Widget twoFieldRow1(Widget left, Widget right) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Row(
//         children: [
//
//           Expanded(child: right),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTextField(
//       BuildContext context,
//       String label, {
//         String? hint,
//         TextEditingController? controller,
//         bool isRequired = false,
//         bool isNumber = false,
//         int? maxLength,
//       }) {
//     final width = MediaQuery.of(context).size.width;
//
//     final isTablet = width >= 600;
//     final isDesktop = width >= 1000;
//
//     double fontSize = isDesktop
//         ? 16
//         : isTablet
//         ? 14
//         : 13;
//
//     // PAN field
//     final bool isPanField = label.toLowerCase().contains("pan");
//
//     // Aadhaar field
//     final bool isAadhaarField =
//         label.toLowerCase().contains("aadhar") ||
//             label.toLowerCase().contains("aadhaar");
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         RichText(
//           text: TextSpan(
//             text: label,
//             style: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w600,
//               color: Colors.black,
//             ),
//             children: [
//               if (isRequired)
//                 TextSpan(
//                   text: " *",
//                   style: TextStyle(
//                     color: Colors.red,
//                     fontSize: fontSize,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//             ],
//           ),
//         ),
//
//         SizedBox(height: isTablet ? 8 : 6),
//
//         Container(
//           padding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 14 : 10,
//             vertical: isTablet ? 4 : 2,
//           ),
//           decoration: BoxDecoration(
//             color: AppColors.background,
//             border: Border.all(
//               color: AppColors.border,
//               width: 1.5,
//             ),
//             borderRadius: BorderRadius.circular(6),
//           ),
//           child: TextField(
//             controller: controller,
//
//             keyboardType: isPanField
//                 ? TextInputType.text
//                 : isNumber
//                 ? TextInputType.number
//                 : TextInputType.text,
//
//             inputFormatters: isPanField
//                 ? [
//               FilteringTextInputFormatter.allow(
//                 RegExp(r'[a-zA-Z0-9]'),
//               ),
//               LengthLimitingTextInputFormatter(10),
//               UpperCaseTextFormatter(),
//             ]
//                 : isAadhaarField
//                 ? [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(12),
//             ]
//                 : isNumber
//                 ? [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(
//                 maxLength ?? 10,
//               ),
//             ]
//                 : null,
//
//             style: TextStyle(
//               fontSize: fontSize,
//               color: Colors.black,
//             ),
//
//             decoration: InputDecoration(
//               hintText: hint ?? "Enter $label",
//               hintStyle: TextStyle(
//                 color: Colors.grey.shade600,
//                 fontSize: fontSize,
//               ),
//               border: InputBorder.none,
//               isDense: true,
//               contentPadding: const EdgeInsets.symmetric(
//                 vertical: 10,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDropdown(
//       BuildContext context,
//       String label,
//       List list,
//       String? selectedValue,
//       Function(String?) onChanged, {
//         bool isRequired = false, // 🔥 ADD THIS
//       }) {
//     final width = MediaQuery.of(context).size.width;
//
//     final isTablet = width >= 600;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//
//         /// 🔹 LABEL WITH *
//         RichText(
//           text: TextSpan(
//             text: label,
//             style: TextStyle(
//               fontSize: isTablet ? 14 : 13,
//               fontWeight: FontWeight.w600,
//               color: Colors.black,
//             ),
//             children: [
//               if (isRequired)
//                 TextSpan(
//                   text: " *",
//                   style: TextStyle(
//                     color: Colors.red,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         SizedBox(height: isTablet ? 10 : 12),
//         /// 🔹 Dropdown Container
//         Container(
//           height: 46,
//           padding: EdgeInsets.symmetric(
//             horizontal: isTablet ? 14 : 10,
//           ),
//           decoration: BoxDecoration(
//             color:AppColors.background,
//             border: Border.all(color: AppColors.border,width: 1.5),
//             borderRadius: BorderRadius.circular(6),
//           ),
//
//           child: DropdownButtonHideUnderline(
//             child: DropdownButton<String>(
//               value: selectedValue,
//               isExpanded: true,
//               icon: const Icon(Icons.keyboard_arrow_down,color: Colors.black,),
//               dropdownColor: Colors.white, // 🔥 ADD THIS
//
//               /// 🔥 Hint
//               hint: Text(
//                 "Select $label",
//                 style: TextStyle(
//                   color: Colors.grey.shade600,
//                   fontSize: isTablet ? 14 : 13,
//                 ),
//               ),
//
//               /// 🔥 Selected Value Style
//               style: TextStyle(
//                 color: Colors.black,
//                 fontSize: isTablet ? 14 : 13,
//                 fontWeight: FontWeight.w500,
//               ),
//
//               items: list.map<DropdownMenuItem<String>>((item) {
//
//                 /// 🔥 If String list
//                 if (item is String) {
//                   return DropdownMenuItem<String>(
//                     value: item,
//                     child: Text(item),
//                   );
//                 }
//
//                 /// 🔥 If Map (API data)
//                 else if (item is Map) {
//                   return DropdownMenuItem<String>(
//                     value: item["id"].toString(), // ✅ store ID
//                     child: Text(item["category_name"].toString()), // ✅ show name
//                   );
//                 }
//
//                 /// fallback
//                 return DropdownMenuItem<String>(
//                   value: item.toString(),
//                   child: Text(item.toString()),
//                 );
//
//               }).toList(),
//
//               onChanged: onChanged,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Future<void> create_user() async {
//
//     /// 🔴 VALIDATION START
//
//     if (nameController.text.trim().isEmpty) {
//       showError("Name is required");
//       return;
//     }
//
//     if (emailController.text.trim().isEmpty) {
//       showError("Email is required");
//       return;
//     }
//
//     final emailRegex =
//     RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//
//     if (!emailRegex.hasMatch(emailController.text.trim())) {
//       showError("Enter valid email address");
//       return;
//     }
//
//     if (cityController.text.trim().isEmpty) {
//       showError("City is required");
//       return;
//     }
//
//     if (addressController.text.trim().isEmpty) {
//       showError("Address is required");
//       return;
//     }
//
//     if (mobileController.text.trim().isEmpty) {
//       showError("Mobile is required");
//       return;
//     }
//
//     if (selectedcategoryId == null ||
//         selectedcategoryId.toString().isEmpty) {
//       showError("Category is required");
//       return;
//     }
//
// // PAN
//     final pan = panController.text.trim().toUpperCase();
//
//     if (pan.isNotEmpty && !isValidPan(pan)) {
//       showError("Enter valid PAN number (Example: ABCDE1234F)");
//       return;
//     }
//
// // Aadhaar
//     final aadhaar = aadhaarController.text.trim();
//
//     if (aadhaar.isNotEmpty && !isValidAadhaar(aadhaar)) {
//       showError("Enter valid 12 digit Aadhaar number");
//       return;
//     }
//
//     /// 🔴 VALIDATION END
//
//
//     try {
//       final body = {
//         "name": nameController.text.trim(),
//         "email": emailController.text.trim(),
//         "category_person_id": selectedcategoryId,
//         "city": cityController.text.trim(),
//         "address": addressController.text.trim(),
//         "area": areaController.text.trim(),
//         "landmark": landmarkController.text.trim(),
//         "pincode": pincodeController.text.trim(),
//         "mobile_no": mobileController.text.trim(),
//         "contact_person1_name": contact1NameController.text.trim(),
//         "contact_person1_phone": contact1PhoneController.text.trim(),
//         "contact_person2_name": contact2NameController.text.trim(),
//         "contact_person2_phone": contact2PhoneController.text.trim(),
//         "gst_no": gstController.text.trim(),
//         "pan_no": panController.text.trim(),
//         "aadhaar_no": aadhaarController.text.trim(),
//         "birth_date": convertToApiDate(birthDateController.text),
//         "anniversary_date": convertToApiDate(anniversaryDateController.text),
//         "reference": referenceController.text.trim(),
//         "remarks": remarksController.text.trim(),
//         "is_active": (selectedRole ?? "").toLowerCase() == "Active" ? 0 : 1,
//       };
//
//       print("Customer Request: $body");
//       print("Customer API URL: ${ApiConstants.create_customer}");
//
//       final response =
//       await OfflineApiHelper.instance.postRequest(ApiConstants.create_customer, body);
//
//       if (response == null) {
//         showError("No response from server");
//         return;
//       }
//
//       final data = response.data;
//       print("Customer Response: $data");
//
//       /// ✅ SUCCESS
//       if (response.statusCode == 200 ||
//           response.statusCode == 202) {
//
//         if (response.statusCode == 202) {
//           AppMessage.success(
//             context,
//             "No Internet. Update saved offline.",
//           );
//         }
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(
//             builder: (_) => const Customerscreen(),
//           ),
//               (route) => route.isFirst,
//         );
//       }
//
//       /// 🔴 INVALID
//       else if (response.statusCode == 401) {
//         showError(data['message'] ?? "Invalid credentials");
//       }
//
//       /// 🔴 VALIDATION ERROR
//       else if (response.statusCode == 422) {
//         String errorMessage = "";
//
//         if (data['errors'] != null) {
//           Map<String, dynamic> errors = data['errors'];
//
//           errors.forEach((key, value) {
//             errorMessage += "${value[0]}\n";
//           });
//         } else {
//           errorMessage = data['message'] ?? "Validation error";
//         }
//
//         showError(errorMessage);
//       }
//
//       /// 🔴 OTHER
//       else {
//         showError(data['message'] ??
//             "Server error (${response.statusCode})");
//       }
//
//     } catch (e) {
//       print("Exception: $e");
//       showError("Something went wrong. Please try again.");
//     }
//   }
//
//
//   Future<void> update_user() async {
//
//     final String status =
//     (selectedRole ?? "Active").trim().toLowerCase();
//
//     final int isActive = status == "active" ? 1 : 0;
//
//     print("Selected Status => $selectedRole");
//     print("is_active => $isActive");
//     try {
//       final userId = widget.userData!["id"];
//       final body = {
//         "name":nameController.text.trim(),
//         "email":emailController.text.trim(),
//         "category_person_id": selectedcategoryId,
//         //"role":selectedRole ?? "",
//         //"person_code":personCodeController.text.trim(),
//         "city":cityController.text.trim(),
//         "address":addressController.text.trim(),
//         "area":areaController.text.trim(),
//         "landmark":landmarkController.text.trim(),
//         "pincode":pincodeController.text.trim(),
//         "mobile_no":mobileController.text.trim(),
//         //"phone_no":phoneController.text.trim(),
//         "contact_person1_name":contact1NameController.text.trim(),
//         "contact_person1_phone":contact1PhoneController.text.trim(),
//         "contact_person2_name":contact2NameController.text.trim(),
//         "contact_person2_phone":contact2PhoneController.text.trim(),
//         "gst_no":gstController.text.trim(),
//         "pan_no":panController.text.trim(),
//         "aadhaar_no":aadhaarController.text.trim(),
//         //"hallmark_license_no":hallmarkController.text.trim(),
//         "birth_date": convertToApiDate(birthDateController.text),
//         "anniversary_date": convertToApiDate(anniversaryDateController.text),
//         "reference":referenceController.text.trim(),
//         "remarks":remarksController.text.trim(),
//         "is_active": isActive,
//       };
//
//       print("Update Customer Request: $body");
//       print("Update Customer API URL: ${ApiConstants.update_customer}");
//
//       final response = await ApiHelper()
//           .putRequest("${ApiConstants.update_customer}/$userId", body);
//
//       if (response == null) {
//         showError("No response from server");
//         return;
//       }
//
//       final data = response.data;
//       print("Update Customer Response: $data");
//
//       // ✅ SUCCESS
//       if (response.statusCode == 200) {
//
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(
//             builder: (_) => const Customerscreen(),
//           ),
//               (route) => route.isFirst,
//         );
//       }
//
//
//       // 🔴 INVALID CREDENTIALS
//       else if (response.statusCode == 401) {
//         showError(data['message'] ?? "Invalid credentials");
//       }
//
//       // 🔴 VALIDATION ERROR
//       else if (response.statusCode == 422) {
//         String errorMessage = "";
//
//         if (data['errors'] != null) {
//           Map<String, dynamic> errors = data['errors'];
//
//           errors.forEach((key, value) {
//             errorMessage += "${value[0]}\n";
//           });
//         } else {
//           errorMessage = data['message'] ?? "Validation error";
//         }
//
//         showError(errorMessage);
//       }
//
//       // 🔴 OTHER ERRORS
//       else {
//         showError(data['message'] ??
//             "Server error (${response.statusCode})");
//       }
//     } catch (e) {
//       print("Login Exception: $e");
//       showError("Something went wrong. Please try again.");
//     }
//   }
//
//   String formatDate(DateTime? date) {
//     if (date == null) return "";
//     return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
//   }
//
//   void showError(String? message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message ?? "Something went wrong"),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildDateFieldNew(
//       BuildContext context,
//       String label,
//       TextEditingController controller,
//       ) {
//     final width = MediaQuery.of(context).size.width;
//
//     final isTablet = width >= 600;
//     final isDesktop = width >= 1000;
//
//     double fontSize = isDesktop
//         ? 16
//         : isTablet
//         ? 14
//         : 13;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//
//         /// 🔹 LABEL
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: fontSize,
//             fontWeight: FontWeight.w600,
//             color: Colors.black,
//           ),
//         ),
//
//         SizedBox(height: isTablet ? 8 : 6),
//
//         /// 🔹 DATE FIELD (Same UI as TextField)
//         InkWell(
//           onTap: () async {
//             DateTime now = DateTime.now();
//
//             final pickedDate = await showDatePicker(
//               context: context,
//               initialDate: now,
//               firstDate: DateTime(1900),
//               lastDate: DateTime(2100),
//             );
//
//             if (pickedDate != null) {
//               setState(() { // 🔥 IMPORTANT
//                 controller.text =
//                 "${pickedDate.day.toString().padLeft(2, '0')}-"
//                     "${pickedDate.month.toString().padLeft(2, '0')}-"
//                     "${pickedDate.year}";
//               });
//             }
//           },
//           child: Container(
//             padding: EdgeInsets.symmetric(
//               horizontal: isTablet ? 14 : 10,
//               vertical: isTablet ? 12 : 10,
//             ),
//             decoration: BoxDecoration(
//               color:AppColors.background,
//               border: Border.all(color: AppColors.border,width: 1.5),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 SizedBox(
//                   width: 100,
//                   child: Text(
//                     controller.text.isEmpty
//                         ? "Select $label"
//                         : controller.text,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                       fontSize: fontSize,
//                       color: controller.text.isEmpty
//                           ? Colors.grey
//                           : Colors.black,
//                     ),
//                   ),
//                 ),
//                 const Icon(Icons.calendar_today, size: 18),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   String convertToApiDate(String input) {
//     try {
//       if (input.trim().isEmpty) return "";
//
//       String clean = input.trim();
//
//       // support both "-" and "/" formats
//       clean = clean.replaceAll("/", "-");
//
//       final parts = clean.split("-");
//
//       if (parts.length != 3) return "";
//
//       int day = int.parse(parts[0]);
//       int month = int.parse(parts[1]);
//       int year = int.parse(parts[2]);
//
//       final date = DateTime(year, month, day);
//
//       return "${date.year}-"
//           "${date.month.toString().padLeft(2, '0')}-"
//           "${date.day.toString().padLeft(2, '0')}";
//     } catch (e) {
//       print("DATE ERROR: $e");
//       return "";
//     }
//   }
//
//   Widget _buildAddressField(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final isTablet = width >= 600;
//     final fontSize = isTablet ? 14.0 : 13.0;
//
//     return CompositedTransformTarget(
//       link: _layerLink,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           RichText(
//             text: TextSpan(
//               text: "Address",
//               style: TextStyle(
//                 fontSize: fontSize,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black,
//               ),
//               children: const [
//                 TextSpan(
//                   text: " *",
//                   style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(height: isTablet ? 8 : 6),
//           Container(
//             padding: EdgeInsets.symmetric(
//               horizontal: isTablet ? 14 : 10,
//               vertical: isTablet ? 4 : 2,
//             ),
//             decoration: BoxDecoration(
//               color:AppColors.background,
//               border: Border.all(color: AppColors.border,width: 1.5),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: addressController,
//                     style: TextStyle(fontSize: fontSize, color: Colors.black),
//                     decoration: InputDecoration(
//                       hintText: "Enter a location",
//                       hintStyle: TextStyle(
//                         color: Colors.grey.shade600,
//                         fontSize: fontSize,
//                       ),
//                       border: InputBorder.none,
//                       isDense: true,
//                       contentPadding: const EdgeInsets.symmetric(vertical: 10),
//                     ),
//                     onChanged: (val) => _searchAddress(val),
//                     onTap: () {
//                       if (addressController.text.length >= 3) {
//                         _searchAddress(addressController.text);
//                       }
//                     },
//                   ),
//                 ),
//                 if (_isAddressLoading)
//                   const SizedBox(
//                     width: 16,
//                     height: 16,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _searchAddress(String input) async {
//     if (input.length < 3) {
//       _removeOverlay();
//       return;
//     }
//
//     setState(() => _isAddressLoading = true);
//
//     try {
//       final dio = Dio();
//       final response = await dio.get(
//         'https://maps.googleapis.com/maps/api/place/autocomplete/json',
//         queryParameters: {
//           'input': input,
//           'key': _googleApiKey,
//           'language': 'en',
//           'components': 'country:in',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final predictions = response.data['predictions'] as List;
//         _addressSuggestions = predictions.map((p) => {
//           'place_id': p['place_id'],
//           'description': p['description'],
//           'main_text': p['structured_formatting']?['main_text'] ?? p['description'],
//           'secondary_text': p['structured_formatting']?['secondary_text'] ?? '',
//         }).toList();
//
//         if (_addressSuggestions.isNotEmpty) {
//           _showOverlay();
//         } else {
//           _removeOverlay();
//         }
//       }
//     } catch (e) {
//       debugPrint('Address search error: $e');
//     }
//
//     setState(() => _isAddressLoading = false);
//   }
//
//   Future<void> _selectAddress(Map<String, dynamic> prediction) async {
//     _removeOverlay();
//     addressController.text = prediction['description'];
//
//     try {
//       final dio = Dio();
//       final response = await dio.get(
//         'https://maps.googleapis.com/maps/api/place/details/json',
//         queryParameters: {
//           'place_id': prediction['place_id'],
//           'key': _googleApiKey,
//           'fields': 'address_components,geometry',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final components = response.data['result']['address_components'] as List;
//         print(response.data['result']['address_components']);
//         for (var component in components) {
//           final types = component['types'] as List;
//
//           // City auto-fill
//           if (types.contains('locality')) {
//             cityController.text = component['long_name'];
//           }
//           // Pincode auto-fill
//           if (types.contains('postal_code')) {
//             pincodeController.text = component['long_name'].toString();
//           }
//           // Area auto-fill
//           if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
//             areaController.text = component['long_name'];
//           }
//         }
//         setState(() {});
//       }
//     } catch (e) {
//       debugPrint('Place details error: $e');
//     }
//   }
//
//   void _showOverlay() {
//     _removeOverlay();
//     _overlayEntry = OverlayEntry(
//       builder: (context) => Positioned(
//         width: _getAddressFieldWidth(context),
//         child: CompositedTransformFollower(
//           link: _layerLink,
//           showWhenUnlinked: false,
//           offset: const Offset(0, 58),
//           child: Material(
//             elevation: 8,
//             borderRadius: BorderRadius.circular(10),
//             child: Container(
//               constraints: const BoxConstraints(maxHeight: 220),
//               decoration: BoxDecoration(
//                 color: const Color(0xffFAF7F2),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: const Color(0xffE5DDD0)),
//               ),
//               child: ListView.separated(
//                 shrinkWrap: true,
//                 padding: EdgeInsets.zero,
//                 itemCount: _addressSuggestions.length,
//                 separatorBuilder: (_, __) => Divider(
//                   height: 1,
//                   color: const Color(0xffE5DDD0),
//                 ),
//                 itemBuilder: (context, index) {
//                   final item = _addressSuggestions[index];
//                   return InkWell(
//                     onTap: () => _selectAddress(item),
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 10,
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(
//                             Icons.location_on,
//                             color: Color(0xffC8A96A),
//                             size: 20,
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   item['main_text'],
//                                   style: const TextStyle(
//                                     color: Colors.black,
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 13,
//                                   ),
//                                 ),
//                                 if (item['secondary_text'].isNotEmpty)
//                                   Text(
//                                     item['secondary_text'],
//                                     style: TextStyle(
//                                       color: Colors.grey.shade600,
//                                       fontSize: 11,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//     Overlay.of(context).insert(_overlayEntry!);
//   }
//
//   void _removeOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }
//
//   double _getAddressFieldWidth(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     // twoFieldRow → Expanded → half width with padding
//     return (width - 20 - 10) / 2; // margin(10+10) + spacing(10)
//   }
//
//   @override
//   void dispose() {
//     _removeOverlay();
//     // ... existing dispose
//     super.dispose();
//   }
//
//   bool isValidAadhaar(String value) {
//     final aadhaar = value.trim();
//
//     // Exactly 12 digits
//     if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
//       return false;
//     }
//
//     // Aadhaar should not start with 0 or 1
//     if (aadhaar.startsWith('0') || aadhaar.startsWith('1')) {
//       return false;
//     }
//
//     return true;
//   }
//
//   bool isValidPan(String value) {
//     final pan = value.trim().toUpperCase();
//
//     // PAN format: ABCDE1234F
//     return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan);
//   }
//
// }


import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pecifician_sysytem/User/UserScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import '../Offline Data/offline_api_helper.dart';
import 'CustomerScreen.dart';

class Createcustomer extends StatefulWidget {
  final Map? userData;

  /// 🔥 GST Search mathi aavelo data (Add Customer dabavya pachhi)
  final Map? gstData;

  const Createcustomer({super.key, this.userData, this.gstData});

  @override
  State<Createcustomer> createState() => _CreatecustomerState();
}

class _CreatecustomerState extends State<Createcustomer> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController personCodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController contact1NameController = TextEditingController();
  final TextEditingController contact1PhoneController = TextEditingController();
  final TextEditingController contact2NameController = TextEditingController();
  final TextEditingController contact2PhoneController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController panController = TextEditingController();
  final TextEditingController aadhaarController = TextEditingController();
  final TextEditingController hallmarkController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController anniversaryDateController = TextEditingController();

  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _showAddressSuggestions = false;
  bool _isAddressLoading = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  static const String _googleApiKey = 'AIzaSyBJ9-wGDcXiPPZeqpUZIHt-BTgVcW429yE';
  bool get isEditMode => widget.userData != null;

  String? selectedRole = "Active";
  DateTime? birthDate;
  DateTime? anniversaryDate;
  String? selectedcategoryId;   // ✅ only ID
  String? selected_category_name;

  /// ================= 💰 OPENING BALANCES =================
  DateTime openingDate = DateTime.now();
  final TextEditingController openingCashController = TextEditingController(text: "0");
  final TextEditingController openingGoldController = TextEditingController(text: "0");
  final TextEditingController openingSilverController = TextEditingController(text: "0");
  final TextEditingController openingOtherController = TextEditingController(text: "0");

  /// "dr" = Person owes us, "cr" = We owe the person
  String cashSide = "dr";
  String goldSide = "dr";
  String silverSide = "dr";
  String otherSide = "dr";

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).refreshcategorylist();
    });

    if (isEditMode) {
      final user = widget.userData!;

      nameController.text = user["name"] ?? "";
      emailController.text = user["email"] ?? "";
      personCodeController.text = user["person_code"] ?? "";
      cityController.text = user["city"] ?? "";
      addressController.text = user["address"] ?? "";
      areaController.text = user["area"] ?? "";
      landmarkController.text = user["landmark"] ?? "";
      pincodeController.text = user["pincode"] ?? "";
      mobileController.text = user["mobile_no"] ?? "";
      phoneController.text = user["phone_no"] ?? "";
      contact1NameController.text = user["contact_person1_name"] ?? "";
      contact1PhoneController.text = user["contact_person1_phone"] ?? "";
      contact2NameController.text = user["contact_person2_name"] ?? "";
      contact2PhoneController.text = user["contact_person2_phone"] ?? "";
      gstController.text = user["gst_no"] ?? "";
      panController.text = user["pan_no"] ?? "";
      aadhaarController.text = user["aadhaar_no"] ?? "";
      hallmarkController.text = user["hallmark_license_no"] ?? "";
      referenceController.text = user["reference"] ?? "";

      bool isActive = user["is_active"] == true || user["is_active"].toString() == "1";

      selectedRole = isActive ? "Active" : "Inactive";
      // Category Set Here
      if (user["category_person"] != null) {
        selectedcategoryId =
            user["category_person"]["id"].toString();

        selected_category_name =
        user["category_person"]["category_name"];
      }

      if (user["birth_date"] != null) {
        birthDateController.text = user["birth_date"];
      }

      if (user["anniversary_date"] != null) {
        anniversaryDateController.text = user["anniversary_date"];
      }

      // 💰 Opening balance (edit ma juno data set)
      _fillOpening(user);
    }

    // 🔥 GST Search mathi aavelo data form ma set karo
    if (!isEditMode && widget.gstData != null) {
      _fillFromGst(widget.gstData!);
    }
  }

  // ======================================================================
  // 💰 OPENING BALANCE HELPERS
  // ======================================================================

  /// Edit mode: response ma "opening" {date, cash, cash_side, ...} hoy to set.
  /// (fallback: "opening_balance" map athva flat "opening_cash" jevi keys)
  void _fillOpening(Map user) {
    Map? o;
    if (user["opening"] is Map) {
      o = user["opening"];
    } else if (user["opening_balance"] is Map) {
      o = user["opening_balance"];
    }

    dynamic read(String key) =>
        o != null ? o[key] : user["opening_$key"];

    String numText(dynamic v) {
      final d = double.tryParse(v?.toString() ?? "") ?? 0;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }

    String side(dynamic v) =>
        v?.toString().toLowerCase().trim() == "cr" ? "cr" : "dr";

    final dateRaw = read("date") ?? user["opening_balance_date"];
    final parsed = DateTime.tryParse(dateRaw?.toString() ?? "");
    if (parsed != null) openingDate = parsed;

    openingCashController.text = numText(read("cash"));
    openingGoldController.text = numText(read("gold"));
    openingSilverController.text = numText(read("silver"));
    openingOtherController.text = numText(read("other"));

    cashSide = side(read("cash_side"));
    goldSide = side(read("gold_side"));
    silverSide = side(read("silver_side"));
    otherSide = side(read("other_side"));
  }

  double _amount(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  /// API body: { "opening": {...} }
  Map<String, dynamic> _openingBody() {
    return {
      "date": formatDate(openingDate),
      "cash": _amount(openingCashController),
      "cash_side": cashSide,
      "gold": _amount(openingGoldController),
      "gold_side": goldSide,
      "silver": _amount(openingSilverController),
      "silver_side": silverSide,
      "other": _amount(openingOtherController),
      "other_side": otherSide,
    };
  }

  /// GST Search na data → form fields
  /// (API nu "customer_form" pehla, nahi to business details)
  void _fillFromGst(Map gst) {
    final Map form =
    gst["customer_form"] is Map ? gst["customer_form"] : const {};

    String pick(List<dynamic> values) {
      for (final v in values) {
        final s = v?.toString().trim() ?? "";
        if (s.isNotEmpty && s != "null") return s;
      }
      return "";
    }

    nameController.text =
        pick([form["name"], gst["business_name"], gst["name"], gst["legal_name"]]);
    emailController.text = pick([form["email"], gst["email"]]);
    mobileController.text = pick([form["mobile_no"], gst["mobile_no"]]);
    cityController.text = pick([form["city"], gst["city"]]);
    areaController.text = pick([form["area"], gst["area"]]);
    landmarkController.text = pick([form["landmark"], gst["landmark"]]);
    pincodeController.text = pick([form["pincode"], gst["pincode"]]);
    addressController.text = pick([form["address"], gst["address"]]);
    gstController.text = pick([form["gst_no"], gst["gstin"], gst["gst_no"]]);
    panController.text = pick([form["pan_no"], gst["pan"], gst["pan_no"]]);
    remarksController.text = pick([
      form["remarks"],
      gst["legal_name"] != null && pick([gst["legal_name"]]).isNotEmpty
          ? "Legal name: ${gst["legal_name"]}"
          : null,
    ]);

    // Category (API ma category_person_id = Customer)
    final String categoryId = pick([form["category_person_id"]]);
    if (categoryId.isNotEmpty) selectedcategoryId = categoryId;

    // Status
    if (form["is_active"] != null) {
      final bool active = form["is_active"] == true ||
          form["is_active"].toString() == "1";
      selectedRole = active ? "Active" : "Inactive";
    }

    debugPrint("✅ GST data form ma set: ${gstController.text}");
  }

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final isMobile = width < 600;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.white,
      body: Stack(
        children: [



          /// ✅ Main Content
          Column(
            children: [
              /// IMPORTANT: top padding space leave karvu (AppBar mate)
              SizedBox(
                height: MediaQuery.of(context).padding.top + 40,
              ),

              /// 🔥 Dynamic Bottom Section
              Expanded(
                child: _buildRecentScansList(context),
              ),

              InkWell(
                onTap: () {
                  if (isEditMode) {
                    update_user();
                  } else {
                    create_user();
                  }
                },
                borderRadius: BorderRadius.circular(10),
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
                      isEditMode?"Update Person":"Save Person",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
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

                  /// ✅ CENTER TITLE
                  const Text(
                    "Create Person",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  /// ✅ LEFT BACK ICON
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color:AppColors.primaryDark,
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

                  /// RIGHT NOTIFICATION ICON
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //
                  //   child: Container(
                  //     padding: EdgeInsets.all(isMobile ? 6 : 8),
                  //
                  //     decoration: BoxDecoration(
                  //       color: Colors.white,
                  //
                  //       borderRadius: BorderRadius.circular(8),
                  //
                  //       boxShadow: [
                  //         BoxShadow(
                  //           color: AppColors.shadow,
                  //
                  //           blurRadius: 20,
                  //
                  //           offset: const Offset(5, 10),
                  //         ),
                  //       ],
                  //     ),
                  //
                  //     child: Stack(
                  //       clipBehavior: Clip.none,
                  //
                  //       children: [
                  //         Icon(
                  //           Icons.notifications_none,
                  //
                  //           size: isMobile ? 22 : 24,
                  //
                  //           color: Colors.red,
                  //         ),
                  //
                  //         Positioned(
                  //           right: -2,
                  //
                  //           top: -2,
                  //
                  //           child: Container(
                  //             height: 8,
                  //
                  //             width: 8,
                  //
                  //             decoration: const BoxDecoration(
                  //               color: Colors.red,
                  //
                  //               shape: BoxShape.circle,
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          )




        ],
      ),

    );
  }


  /// ✅ Recent Scan List
  Widget _buildRecentScansList(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isTablet = width > 700;

    Widget responsiveRow(List<Widget> children) {
      if (children.length == 1) {
        return Padding(
          padding: EdgeInsets.only(bottom: height * 0.015),
          child: children.first,
        );
      }

      if (!isTablet) {
        return Column(
          children: children.map((e) => Padding(
            padding: EdgeInsets.only(bottom: height * 0.015),
            child: e,
          )).toList(),
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: height * 0.015),
        child: Row(
          children: children.map((e) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: width * 0.015),
              child: e,
            ),
          )).toList(),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [

          /// ================= BASIC INFO =================
          Container(
            margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  "Basic Information",
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                SizedBox(height: height * 0.015),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Name",
                    controller: nameController,
                    isRequired: true, // 🔥 show *
                  ),

                  _buildTextField(
                    context,
                    "Email",
                    controller: emailController,
                    isRequired: true, // 🔥 show *
                  ),
                ),

                Consumer<ItemProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const CircularProgressIndicator();
                    }

                    final List<Map<String, dynamic>> categoryItems =
                    provider.category
                        .map<Map<String, dynamic>>(
                          (e) => {
                        ...Map<String, dynamic>.from(e),

                        /// Global premium dropdown mate
                        "item_name":
                        e["category_name"]?.toString() ?? "",
                      },
                    )
                        .toList();

                    Map<String, dynamic>? selectedCategory;

                    if (selectedcategoryId != null) {
                      for (final item in categoryItems) {
                        if (item["id"].toString() ==
                            selectedcategoryId.toString()) {
                          selectedCategory = item;
                          break;
                        }
                      }
                    }

                    return twoFieldRow1(
                      _buildTextField(
                        context,
                        "Remarks",
                        controller: remarksController,
                      ),

                      PremiumItemSearchDropdown(
                        label: "Category",
                        hint: "Select Category",
                        items: categoryItems,
                        value: selectedCategory,
                        requiredField: true,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == null) {
                              selectedcategoryId = null;
                              selected_category_name = null;
                              return;
                            }

                            selectedcategoryId =
                                selected["id"]?.toString();

                            selected_category_name =
                                selected["category_name"]
                                    ?.toString() ??
                                    selected["item_name"]
                                        ?.toString() ??
                                    "";
                          });

                          debugPrint(
                            "Category ID => $selectedcategoryId",
                          );

                          debugPrint(
                            "Category Name => $selected_category_name",
                          );
                        },
                      ),
                    );
                  },
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Mobile",
                    controller: mobileController,
                    isRequired: true, // 🔥 show *
                    isNumber: true,
                  ),

                  _buildTextField(
                    context,
                    "City",
                    controller: cityController,
                    isRequired: true, // 🔥 show *
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Area",
                    controller: areaController,
                  ),

                  _buildTextField(
                    context,
                    "Landmark",
                    controller: landmarkController,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Pincode",
                    controller: pincodeController,
                    isNumber: true,
                  ),
                  _buildAddressField(context),
                ),

                twoFieldRow(

                  _buildTextField(
                    context,
                    "Contact 1 Name",
                    controller: contact1NameController,
                  ),
                  _buildTextField(
                    context,
                    "Contact 1 Phone",
                    controller: contact1PhoneController,
                    isNumber: true,
                  ),

                ),

                twoFieldRow(


                  _buildTextField(
                    context,
                    "Contact 2 Name",
                    controller: contact2NameController,
                  ),

                  _buildTextField(
                    context,
                    "Contact 2 Phone",
                    controller: contact2PhoneController,
                    isNumber: true,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Gst",
                    controller: gstController,
                  ),

                  _buildTextField(
                    context,
                    "Pan No",
                    controller: panController,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Aadhar No",
                    controller: aadhaarController,
                    isNumber: true,
                  ),

                  _buildTextField(
                    context,
                    "Refrence",
                    controller: referenceController,
                  ),
                ),
                twoFieldRow(
                  _buildDateFieldNew(context, "Birth Date", birthDateController),
                  _buildDateFieldNew(context, "Anniversary", anniversaryDateController),
                ),

                twoFieldRow(
                  _buildTextField(context, "Remarks", controller: remarksController),

                  _buildDropdown(
                    context,
                    "Status",
                    ["Active", "Inactive"],
                    selectedRole,
                        (val) {
                      setState(() {
                        selectedRole = val;
                        print("STATUS SELECTED => $selectedRole");
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          /// ================= 💰 OPENING BALANCES =================
          _buildOpeningBalanceCard(context),
        ],
      ),
    );
  }

  // ======================================================================
  // 💰 OPENING BALANCES CARD
  // ======================================================================
  Widget _buildOpeningBalanceCard(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;

    final cash = _openingItem(
      context,
      label: "Cash Amount (Rs)",
      icon: Icons.currency_rupee_rounded,
      color: const Color(0xFF2E7D32),
      controller: openingCashController,
      decimals: 2,
      side: cashSide,
      onSide: (v) => setState(() => cashSide = v),
    );
    final gold = _openingItem(
      context,
      label: "Gold (g)",
      icon: Icons.circle,
      color: const Color(0xFFD4A017),
      controller: openingGoldController,
      decimals: 3,
      side: goldSide,
      onSide: (v) => setState(() => goldSide = v),
    );
    final silver = _openingItem(
      context,
      label: "Silver (g)",
      icon: Icons.circle,
      color: const Color(0xFF9AA5B1),
      controller: openingSilverController,
      decimals: 3,
      side: silverSide,
      onSide: (v) => setState(() => silverSide = v),
    );
    final other = _openingItem(
      context,
      label: "Other Metal (g)",
      icon: Icons.circle,
      color: const Color(0xFF8D6E63),
      controller: openingOtherController,
      decimals: 3,
      side: otherSide,
      onSide: (v) => setState(() => otherSide = v),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TITLE
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                "Opening Balances",
                style: TextStyle(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          /// INFO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Enter balances brought forward, not new payments. "
                  "Dr: person owes us. Cr: we owe the person. "
                  "Worker metal is net grams; customer metal is fine grams.",
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 12),

          /// OPENING DATE
          SizedBox(
            width: isTablet ? 300 : double.infinity,
            child: _openingDateField(context),
          ),
          const SizedBox(height: 12),

          /// FIELDS: tablet = 4 ek line ma, mobile = 2 x 2
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cash),
                const SizedBox(width: 10),
                Expanded(child: gold),
                const SizedBox(width: 10),
                Expanded(child: silver),
                const SizedBox(width: 10),
                Expanded(child: other),
              ],
            )
          else ...[
            twoFieldRow(cash, gold),
            twoFieldRow(silver, other),
          ],
        ],
      ),
    );
  }

  /// Opening Date picker (same UI as other fields)
  Widget _openingDateField(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final fontSize = isTablet ? 14.0 : 13.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Opening Date",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            FocusManager.instance.primaryFocus?.unfocus();
            final picked = await showDatePicker(
              context: context,
              initialDate: openingDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => openingDate = picked);
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 14 : 10,
              vertical: isTablet ? 12 : 11,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${openingDate.day.toString().padLeft(2, '0')}/"
                        "${openingDate.month.toString().padLeft(2, '0')}/"
                        "${openingDate.year}",
                    style: TextStyle(fontSize: fontSize, color: Colors.black),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Ek opening item = label + amount + Dr/Cr dropdown
  Widget _openingItem(
      BuildContext context, {
        required String label,
        required IconData icon,
        required Color color,
        required TextEditingController controller,
        required int decimals,
        required String side,
        required ValueChanged<String> onSide,
      }) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final fontSize = isTablet ? 14.0 : 13.0;
    final isCr = side == "cr";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// LABEL
        Row(
          children: [
            Icon(icon, size: icon == Icons.circle ? 9 : 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 8 : 6),

        /// AMOUNT
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
            vertical: isTablet ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp('^\\d*\\.?\\d{0,$decimals}'),
              ),
            ],
            onTap: () {
              // "0" hoy to tap karta j select thai jay
              if (controller.text == "0") {
                controller.selection = TextSelection(
                    baseOffset: 0, extentOffset: controller.text.length);
              }
            },
            style: TextStyle(fontSize: fontSize, color: Colors.black),
            decoration: InputDecoration(
              hintText: "0",
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: fontSize,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),

        /// Dr / Cr
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isCr
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            border: Border.all(
              color: isCr
                  ? const Color(0xFF66BB6A).withOpacity(0.6)
                  : const Color(0xFFE57373).withOpacity(0.6),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: side,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.black, size: 18),
              style: TextStyle(
                color: Colors.black,
                fontSize: isTablet ? 13 : 11.5,
                fontWeight: FontWeight.w600,
              ),
              selectedItemBuilder: (_) => [
                _sideText("Dr — Person owes us", const Color(0xFFC62828)),
                _sideText("Cr — We owe the person", const Color(0xFF2E7D32)),
              ],
              items: const [
                DropdownMenuItem(
                    value: "dr", child: Text("Dr — Person owes us")),
                DropdownMenuItem(
                    value: "cr", child: Text("Cr — We owe the person")),
              ],
              onChanged: (v) {
                if (v != null) onSide(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _sideText(String text, Color color) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
  Widget twoFieldRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [

          Expanded(child: left),

          const SizedBox(width: 10),

          Expanded(child: right),
        ],
      ),
    );
  }

  Widget twoFieldRow1(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [

          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context,
      String label, {
        String? hint,
        TextEditingController? controller,
        bool isRequired = false,
        bool isNumber = false,
        int? maxLength,
      }) {
    final width = MediaQuery.of(context).size.width;

    final isTablet = width >= 600;
    final isDesktop = width >= 1000;

    double fontSize = isDesktop
        ? 16
        : isTablet
        ? 14
        : 13;

    // PAN field
    final bool isPanField = label.toLowerCase().contains("pan");

    // Aadhaar field
    final bool isAadhaarField =
        label.toLowerCase().contains("aadhar") ||
            label.toLowerCase().contains("aadhaar");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            children: [
              if (isRequired)
                TextSpan(
                  text: " *",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: isTablet ? 8 : 6),

        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
            vertical: isTablet ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(
              color: AppColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,

            keyboardType: isPanField
                ? TextInputType.text
                : isNumber
                ? TextInputType.number
                : TextInputType.text,

            inputFormatters: isPanField
                ? [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z0-9]'),
              ),
              LengthLimitingTextInputFormatter(10),
              UpperCaseTextFormatter(),
            ]
                : isAadhaarField
                ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ]
                : isNumber
                ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                maxLength ?? 10,
              ),
            ]
                : null,

            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black,
            ),

            decoration: InputDecoration(
              hintText: hint ?? "Enter $label",
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: fontSize,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
      BuildContext context,
      String label,
      List list,
      String? selectedValue,
      Function(String?) onChanged, {
        bool isRequired = false, // 🔥 ADD THIS
      }) {
    final width = MediaQuery.of(context).size.width;

    final isTablet = width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔹 LABEL WITH *
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            children: [
              if (isRequired)
                TextSpan(
                  text: " *",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 10 : 12),
        /// 🔹 Dropdown Container
        Container(
          height: 46,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
          ),
          decoration: BoxDecoration(
            color:AppColors.background,
            border: Border.all(color: AppColors.border,width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),

          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down,color: Colors.black,),
              dropdownColor: Colors.white, // 🔥 ADD THIS

              /// 🔥 Hint
              hint: Text(
                "Select $label",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 14 : 13,
                ),
              ),

              /// 🔥 Selected Value Style
              style: TextStyle(
                color: Colors.black,
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
              ),

              items: list.map<DropdownMenuItem<String>>((item) {

                /// 🔥 If String list
                if (item is String) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }

                /// 🔥 If Map (API data)
                else if (item is Map) {
                  return DropdownMenuItem<String>(
                    value: item["id"].toString(), // ✅ store ID
                    child: Text(item["category_name"].toString()), // ✅ show name
                  );
                }

                /// fallback
                return DropdownMenuItem<String>(
                  value: item.toString(),
                  child: Text(item.toString()),
                );

              }).toList(),

              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> create_user() async {

    /// 🔴 VALIDATION START

    if (nameController.text.trim().isEmpty) {
      showError("Name is required");
      return;
    }

    if (emailController.text.trim().isEmpty) {
      showError("Email is required");
      return;
    }

    final emailRegex =
    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(emailController.text.trim())) {
      showError("Enter valid email address");
      return;
    }

    if (cityController.text.trim().isEmpty) {
      showError("City is required");
      return;
    }

    if (addressController.text.trim().isEmpty) {
      showError("Address is required");
      return;
    }

    if (mobileController.text.trim().isEmpty) {
      showError("Mobile is required");
      return;
    }

    if (selectedcategoryId == null ||
        selectedcategoryId.toString().isEmpty) {
      showError("Category is required");
      return;
    }

// PAN
    final pan = panController.text.trim().toUpperCase();

    if (pan.isNotEmpty && !isValidPan(pan)) {
      showError("Enter valid PAN number (Example: ABCDE1234F)");
      return;
    }

// Aadhaar
    final aadhaar = aadhaarController.text.trim();

    if (aadhaar.isNotEmpty && !isValidAadhaar(aadhaar)) {
      showError("Enter valid 12 digit Aadhaar number");
      return;
    }

    /// 🔴 VALIDATION END


    try {
      final body = {
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "category_person_id": selectedcategoryId,
        "city": cityController.text.trim(),
        "address": addressController.text.trim(),
        "area": areaController.text.trim(),
        "landmark": landmarkController.text.trim(),
        "pincode": pincodeController.text.trim(),
        "mobile_no": mobileController.text.trim(),
        "contact_person1_name": contact1NameController.text.trim(),
        "contact_person1_phone": contact1PhoneController.text.trim(),
        "contact_person2_name": contact2NameController.text.trim(),
        "contact_person2_phone": contact2PhoneController.text.trim(),
        "gst_no": gstController.text.trim(),
        "pan_no": panController.text.trim(),
        "aadhaar_no": aadhaarController.text.trim(),
        "birth_date": convertToApiDate(birthDateController.text),
        "anniversary_date": convertToApiDate(anniversaryDateController.text),
        "reference": referenceController.text.trim(),
        "remarks": remarksController.text.trim(),
        "is_active": (selectedRole ?? "Active").toLowerCase() == "active" ? 1 : 0,

        /// 💰 Opening balances
        "opening": _openingBody(),
      };

      print("Customer Request: $body");
      print("Customer API URL: ${ApiConstants.create_customer}");

      final response =
      await OfflineApiHelper.instance.postRequest(ApiConstants.create_customer, body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Customer Response: $data");

      /// ✅ SUCCESS
      if (response.statusCode == 200 ||
          response.statusCode == 202) {

        if (response.statusCode == 202) {
          AppMessage.success(
            context,
            "No Internet. Update saved offline.",
          );
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Customerscreen(),
          ),
              (route) => route.isFirst,
        );
      }

      /// 🔴 INVALID
      else if (response.statusCode == 401) {
        showError(data['message'] ?? "Invalid credentials");
      }

      /// 🔴 VALIDATION ERROR
      else if (response.statusCode == 422) {
        String errorMessage = "";

        if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];

          errors.forEach((key, value) {
            errorMessage += "${value[0]}\n";
          });
        } else {
          errorMessage = data['message'] ?? "Validation error";
        }

        showError(errorMessage);
      }

      /// 🔴 OTHER
      else {
        showError(data['message'] ??
            "Server error (${response.statusCode})");
      }

    } catch (e) {
      print("Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }


  Future<void> update_user() async {

    final String status =
    (selectedRole ?? "Active").trim().toLowerCase();

    final int isActive = status == "active" ? 1 : 0;

    print("Selected Status => $selectedRole");
    print("is_active => $isActive");
    try {
      final userId = widget.userData!["id"];
      final body = {
        "name":nameController.text.trim(),
        "email":emailController.text.trim(),
        "category_person_id": selectedcategoryId,
        //"role":selectedRole ?? "",
        //"person_code":personCodeController.text.trim(),
        "city":cityController.text.trim(),
        "address":addressController.text.trim(),
        "area":areaController.text.trim(),
        "landmark":landmarkController.text.trim(),
        "pincode":pincodeController.text.trim(),
        "mobile_no":mobileController.text.trim(),
        //"phone_no":phoneController.text.trim(),
        "contact_person1_name":contact1NameController.text.trim(),
        "contact_person1_phone":contact1PhoneController.text.trim(),
        "contact_person2_name":contact2NameController.text.trim(),
        "contact_person2_phone":contact2PhoneController.text.trim(),
        "gst_no":gstController.text.trim(),
        "pan_no":panController.text.trim(),
        "aadhaar_no":aadhaarController.text.trim(),
        //"hallmark_license_no":hallmarkController.text.trim(),
        "birth_date": convertToApiDate(birthDateController.text),
        "anniversary_date": convertToApiDate(anniversaryDateController.text),
        "reference":referenceController.text.trim(),
        "remarks":remarksController.text.trim(),
        "is_active": isActive,

        /// 💰 Opening balances
        "opening": _openingBody(),
      };

      print("Update Customer Request: $body");
      print("Update Customer API URL: ${ApiConstants.update_customer}");

      final response = await ApiHelper()
          .putRequest("${ApiConstants.update_customer}/$userId", body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Update Customer Response: $data");

      // ✅ SUCCESS
      if (response.statusCode == 200) {

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Customerscreen(),
          ),
              (route) => route.isFirst,
        );
      }


      // 🔴 INVALID CREDENTIALS
      else if (response.statusCode == 401) {
        showError(data['message'] ?? "Invalid credentials");
      }

      // 🔴 VALIDATION ERROR
      else if (response.statusCode == 422) {
        String errorMessage = "";

        if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];

          errors.forEach((key, value) {
            errorMessage += "${value[0]}\n";
          });
        } else {
          errorMessage = data['message'] ?? "Validation error";
        }

        showError(errorMessage);
      }

      // 🔴 OTHER ERRORS
      else {
        showError(data['message'] ??
            "Server error (${response.statusCode})");
      }
    } catch (e) {
      print("Login Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void showError(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? "Something went wrong"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }


  Widget _buildDateFieldNew(
      BuildContext context,
      String label,
      TextEditingController controller,
      ) {
    final width = MediaQuery.of(context).size.width;

    final isTablet = width >= 600;
    final isDesktop = width >= 1000;

    double fontSize = isDesktop
        ? 16
        : isTablet
        ? 14
        : 13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔹 LABEL
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        SizedBox(height: isTablet ? 8 : 6),

        /// 🔹 DATE FIELD (Same UI as TextField)
        InkWell(
          onTap: () async {
            DateTime now = DateTime.now();

            final pickedDate = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );

            if (pickedDate != null) {
              setState(() { // 🔥 IMPORTANT
                controller.text =
                "${pickedDate.day.toString().padLeft(2, '0')}-"
                    "${pickedDate.month.toString().padLeft(2, '0')}-"
                    "${pickedDate.year}";
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 14 : 10,
              vertical: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color:AppColors.background,
              border: Border.all(color: AppColors.border,width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    controller.text.isEmpty
                        ? "Select $label"
                        : controller.text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: controller.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String convertToApiDate(String input) {
    try {
      if (input.trim().isEmpty) return "";

      String clean = input.trim();

      // support both "-" and "/" formats
      clean = clean.replaceAll("/", "-");

      final parts = clean.split("-");

      if (parts.length != 3) return "";

      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);

      final date = DateTime(year, month, day);

      return "${date.year}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.day.toString().padLeft(2, '0')}";
    } catch (e) {
      print("DATE ERROR: $e");
      return "";
    }
  }

  Widget _buildAddressField(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final fontSize = isTablet ? 14.0 : 13.0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: "Address",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              children: const [
                TextSpan(
                  text: " *",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 14 : 10,
              vertical: isTablet ? 4 : 2,
            ),
            decoration: BoxDecoration(
              color:AppColors.background,
              border: Border.all(color: AppColors.border,width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addressController,
                    style: TextStyle(fontSize: fontSize, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Enter a location",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: fontSize,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => _searchAddress(val),
                    onTap: () {
                      if (addressController.text.length >= 3) {
                        _searchAddress(addressController.text);
                      }
                    },
                  ),
                ),
                if (_isAddressLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAddress(String input) async {
    if (input.length < 3) {
      _removeOverlay();
      return;
    }

    setState(() => _isAddressLoading = true);

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': input,
          'key': _googleApiKey,
          'language': 'en',
          'components': 'country:in',
        },
      );

      if (response.statusCode == 200) {
        final predictions = response.data['predictions'] as List;
        _addressSuggestions = predictions.map((p) => {
          'place_id': p['place_id'],
          'description': p['description'],
          'main_text': p['structured_formatting']?['main_text'] ?? p['description'],
          'secondary_text': p['structured_formatting']?['secondary_text'] ?? '',
        }).toList();

        if (_addressSuggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      debugPrint('Address search error: $e');
    }

    setState(() => _isAddressLoading = false);
  }

  Future<void> _selectAddress(Map<String, dynamic> prediction) async {
    _removeOverlay();
    addressController.text = prediction['description'];

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': prediction['place_id'],
          'key': _googleApiKey,
          'fields': 'address_components,geometry',
        },
      );

      if (response.statusCode == 200) {
        final components = response.data['result']['address_components'] as List;
        print(response.data['result']['address_components']);
        for (var component in components) {
          final types = component['types'] as List;

          // City auto-fill
          if (types.contains('locality')) {
            cityController.text = component['long_name'];
          }
          // Pincode auto-fill
          if (types.contains('postal_code')) {
            pincodeController.text = component['long_name'].toString();
          }
          // Area auto-fill
          if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
            areaController.text = component['long_name'];
          }
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getAddressFieldWidth(context),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 58),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: const Color(0xffFAF7F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xffE5DDD0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _addressSuggestions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: const Color(0xffE5DDD0),
                ),
                itemBuilder: (context, index) {
                  final item = _addressSuggestions[index];
                  return InkWell(
                    onTap: () => _selectAddress(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xffC8A96A),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['main_text'],
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (item['secondary_text'].isNotEmpty)
                                  Text(
                                    item['secondary_text'],
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getAddressFieldWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // twoFieldRow → Expanded → half width with padding
    return (width - 20 - 10) / 2; // margin(10+10) + spacing(10)
  }

  @override
  void dispose() {
    _removeOverlay();
    openingCashController.dispose();
    openingGoldController.dispose();
    openingSilverController.dispose();
    openingOtherController.dispose();
    super.dispose();
  }

  bool isValidAadhaar(String value) {
    final aadhaar = value.trim();

    // Exactly 12 digits
    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      return false;
    }

    // Aadhaar should not start with 0 or 1
    if (aadhaar.startsWith('0') || aadhaar.startsWith('1')) {
      return false;
    }

    return true;
  }

  bool isValidPan(String value) {
    final pan = value.trim().toUpperCase();

    // PAN format: ABCDE1234F
    return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan);
  }

}
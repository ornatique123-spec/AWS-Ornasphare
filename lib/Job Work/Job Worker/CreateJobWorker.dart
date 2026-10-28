import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Worker/JobWorkerScreen.dart';
import 'package:pecifician_sysytem/User/UserScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Offline Data/offline_api_helper.dart';
class Createjobworker extends StatefulWidget {
  final Map? userData;

  const Createjobworker({super.key, this.userData});

  @override
  State<Createjobworker> createState() => _CreatejobworkerState();
}

class _CreatejobworkerState extends State<Createjobworker> {
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

  final LayerLink _layerLink = LayerLink();
  bool get isEditMode => widget.userData != null;
  //String? selectedRole;
  DateTime? birthDate;
  DateTime? anniversaryDate;
  String? selectedRole = "Active";
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _showAddressSuggestions = false;
  bool _isAddressLoading = false;

  static const String _googleApiKey = 'AIzaSyBJ9-wGDcXiPPZeqpUZIHt-BTgVcW429yE';

  @override
  void initState() {
    super.initState();

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
      remarksController.text = user["remarks"] ?? "";
      bool isActive = user["is_active"] == true || user["is_active"].toString() == "1";

      selectedRole = isActive ? "Active" : "Inactive";

      if (user["birth_date"] != null) {
        DateTime date = DateTime.parse(user["birth_date"]);
        birthDateController.text = formatDate(date);
      }

      if (user["anniversary_date"] != null) {
        DateTime date = DateTime.parse(user["anniversary_date"]);
        anniversaryDateController.text = formatDate(date);
      }

    }
  }

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
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
                        isEditMode?"Update Job Worker":"Save Job Worker",
                        style: TextStyle(
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
                    "Create Job Worker",
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

                  // /// RIGHT NOTIFICATION ICON
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
                  ),

                  _buildTextField(
                    context,
                    "Email",
                    controller: emailController,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Mobile",
                    controller: mobileController,
                  ),

                  _buildTextField(
                    context,
                    "City",
                    controller: cityController,
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
                  ),

                  _buildAddressField(context),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Contact 1 Phone",
                    controller: contact1PhoneController,
                  ),

                  _buildTextField(
                    context,
                    "Contact 2 Phone",
                    controller: contact2PhoneController,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Contact 1 Name",
                    controller: contact1NameController,
                  ),

                  _buildTextField(
                    context,
                    "Contact 2 Name",
                    controller: contact2NameController,
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
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

  Widget _buildTextField(
      BuildContext context,
      String label, {
        String? hint,
        TextEditingController? controller,
      }) {
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
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (label == "Name") // 🔥 only for required field
              const Text(
                " *",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),

        SizedBox(height: isTablet ? 8 : 6),

        /// 🔹 TEXTFIELD
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

          child: TextField(
            controller: controller,
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

              /// 🔥 FIX HEIGHT ISSUE
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
      BuildContext context,
      String label,
      List<String> items,
      String? value,
      Function(String?) onChanged,
      ) {
    final width = MediaQuery.of(context).size.width;

    final isTablet = width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔹 Label (optional but recommended)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),

        /// 🔹 Dropdown Container
        Container(
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
              value: value,
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

              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    /// 🔴 VALIDATION
    if (nameController.text.trim().isEmpty) {
      showError("Name is required");
      return; // 🚫 STOP API CALL
    }
    try {
      final body = {
        "name":nameController.text.trim(),
        "email":emailController.text.trim(),
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
        "remarks":remarksController.text.toString(),
        "is_active": (selectedRole ?? "").toLowerCase() == "Active" ? 0 : 1,
      };

      print("Customer Request: $body");
      print("Customer API URL: ${ApiConstants.Add_job_worker}");

      final response =
      await OfflineApiHelper.instance.postRequest(ApiConstants.Add_job_worker, body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Customer Response: $data");

      // ✅ SUCCESS
      if (response != null && response.statusCode == 200 ||
          response!.statusCode == 202) {

        if (response.statusCode == 202) {
          AppMessage.success(
            context,
            "No Internet. Update saved offline.",
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Jobworkerscreen()),
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

  Future<void> update_user() async {
    /// 🔴 VALIDATION
    if (nameController.text.trim().isEmpty) {
      showError("Name is required");
      return; // 🚫 STOP API CALL
    }
    try {
      final userId = widget.userData!["id"];
      final body = {
        "name":nameController.text.trim(),
        "email":emailController.text.trim(),
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
        "remarks":remarksController.text.toString(),
        "is_active":  (selectedRole ?? "").toLowerCase() == "Active" ? true : false,
      };

      print("Update Customer Request: $body");
      print("Update Customer API URL: ${ApiConstants.Update_job_worker}");

      final response = await ApiHelper()
          .putRequest("${ApiConstants.Update_job_worker}/$userId", body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Update Customer Response: $data");

      // ✅ SUCCESS
      if (response.statusCode == 200) {

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Jobworkerscreen()),
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

    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";
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
    // ... existing dispose
    super.dispose();
  }

}

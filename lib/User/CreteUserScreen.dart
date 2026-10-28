import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import '../Offline Data/offline_api_helper.dart';
import '../User/UserScreen.dart';

class Creteuserscreen extends StatefulWidget {
  final Map? userData;

  const Creteuserscreen({super.key, this.userData});

  @override
  State<Creteuserscreen> createState() => _CreteuserscreenState();
}

class _CreteuserscreenState extends State<Creteuserscreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================
  bool isDeviceSectionExpanded = false;
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

  final TextEditingController anniversaryDateController =
      TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  // ============================================================
  // USER
  // ============================================================

  bool get isEditMode => widget.userData != null;

  String? selectedRole;

  List<String> roleList = [];

  List userlist = [];

  List allUsers = [];

  File? selectedImage;

  // ============================================================
  // LOGIN / ADMIN
  // ============================================================

  bool isAdmin = false;
  String loginRole = "";

  // ============================================================
  // DEVICE
  // ============================================================

  List<Map<String, dynamic>> deviceList = [];
  List<Map<String, dynamic>> validUsers = [];

  bool isDeviceLoading = false;

  // ============================================================
  // DEVICE ACTION API
  // ============================================================

  String deviceApproveApi(int id) => "office-access/devices/$id/approve";

  String deviceRejectApi(int id) => "office-access/devices/$id/reject";

  String deviceInactiveApi(int id) => "office-access/devices/$id/inactive";

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      _fillEditData();
    }

    Future.microtask(() async {
      await category();
      await checkAdminAndLoadDevices();
    });
  }

  // ============================================================
  // EDIT DATA
  // ============================================================

  void _fillEditData() {
    final user = widget.userData!;

    nameController.text = user["name"]?.toString() ?? "";

    emailController.text = user["email"]?.toString() ?? "";

    personCodeController.text = user["person_code"]?.toString() ?? "";

    cityController.text = user["city"]?.toString() ?? "";

    addressController.text = user["address"]?.toString() ?? "";

    areaController.text = user["area"]?.toString() ?? "";

    landmarkController.text = user["landmark"]?.toString() ?? "";

    pincodeController.text = user["pincode"]?.toString() ?? "";

    mobileController.text = user["mobile_no"]?.toString() ?? "";

    phoneController.text = user["phone_no"]?.toString() ?? "";

    contact1NameController.text =
        user["contact_person1_name"]?.toString() ?? "";

    contact1PhoneController.text =
        user["contact_person1_phone"]?.toString() ?? "";

    contact2NameController.text =
        user["contact_person2_name"]?.toString() ?? "";

    contact2PhoneController.text =
        user["contact_person2_phone"]?.toString() ?? "";

    gstController.text = user["gst_no"]?.toString() ?? "";

    panController.text = user["pan_no"]?.toString() ?? "";

    aadhaarController.text = user["aadhaar_no"]?.toString() ?? "";

    hallmarkController.text = user["hallmark_license_no"]?.toString() ?? "";

    referenceController.text = user["reference"]?.toString() ?? "";

    remarksController.text = user["remarks"]?.toString() ?? "";

    // ==========================================================
    // IMPORTANT
    // Edit user nu role ahi set thase
    // Example: QA / casting / Manager
    // ==========================================================

    selectedRole = user["role"]?.toString().trim();

    debugPrint("EDIT USER ID => ${user["id"]}");

    debugPrint("EDIT USER NAME => ${user["name"]}");

    debugPrint("EDIT USER ROLE => [$selectedRole]");

    if (user["birth_date"] != null) {
      birthDateController.text = formatDateForDisplay(
        user["birth_date"].toString(),
      );
    }

    if (user["anniversary_date"] != null) {
      anniversaryDateController.text = formatDateForDisplay(
        user["anniversary_date"].toString(),
      );
    }
  }

  // ============================================================
  // CHECK LOGIN ADMIN
  // ============================================================

  Future<void> checkAdminAndLoadDevices() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    debugPrint("PREF KEYS => ${prefs.getKeys()}");

    final String savedRole =
        prefs.getString("role")?.toString().trim().toLowerCase() ?? "";

    debugPrint("LOGIN USER ROLE => [$savedRole]");

    if (!mounted) return;

    setState(() {
      loginRole = savedRole;

      isAdmin = savedRole == "admin";
    });

    debugPrint("IS LOGIN USER ADMIN => $isAdmin");

    // ==========================================================
    // ONLY ADMIN CAN LOAD DEVICE MANAGEMENT
    // ==========================================================

    if (!isAdmin) {
      if (!mounted) return;

      setState(() {
        deviceList = [];
      });

      return;
    }

    // ==========================================================
    // VALID USERS LOAD
    // ==========================================================

    await getValidUsers();

    // ==========================================================
    // EDIT USER ROLE AVAILABLE HOY TO DEVICE LOAD
    // ==========================================================

    final String role = selectedRole?.trim().toLowerCase() ?? "";

    if (role.isNotEmpty && role != "admin") {
      await getDeviceList();
    }
  }

  // ============================================================
  // GET VALID USERS
  // ============================================================

  Future<void> getValidUsers() async {
    try {
      final response = await ApiHelper().getRequest(
        ApiConstants.create_users,
        showLoading: false,
      );

      debugPrint("VALID USERS API => ${response?.data}");

      if (response == null || response.statusCode != 200) {
        return;
      }

      dynamic rawData = response.data;

      if (rawData is Map) {
        rawData = rawData["data"];
      }

      if (rawData is! List) {
        return;
      }

      final List<Map<String, dynamic>> tempUsers = [];

      for (final raw in rawData) {
        if (raw is Map) {
          tempUsers.add(Map<String, dynamic>.from(raw));
        }
      }

      if (!mounted) return;

      setState(() {
        validUsers = tempUsers;
      });

      debugPrint("VALID USER COUNT => ${validUsers.length}");
    } catch (e) {
      debugPrint("VALID USER ERROR => $e");
    }
  }

  // ============================================================
  // GET DEVICE LIST
  //
  // IMPORTANT:
  //
  // LOGIN ADMIN che ke nai e authorization mate chhe.
  //
  // DEVICE FILTER:
  // selectedRole par thase.
  //
  // Example:
  //
  // Edit Dishank
  // selectedRole = QA
  //
  // => ONLY QA DEVICES
  //
  // Edit Devang
  // selectedRole = casting
  //
  // => ONLY CASTING DEVICES
  // ============================================================

  Future<void> getDeviceList() async {
    try {
      // ========================================================
      // ONLY ADMIN
      // ========================================================

      if (!isAdmin) {
        debugPrint("DEVICE LIST BLOCKED => LOGIN USER NOT ADMIN");

        if (!mounted) return;

        setState(() {
          deviceList = [];
          isDeviceLoading = false;
        });

        return;
      }

      // ========================================================
      // ROLE TO FILTER
      // ========================================================

      final String filterRole =
          selectedRole?.toString().trim().toLowerCase() ?? "";

      debugPrint("========================================");

      debugPrint("LOGIN ROLE => [$loginRole]");

      debugPrint("SELECTED/EDIT ROLE => [$selectedRole]");

      debugPrint("FILTER ROLE => [$filterRole]");

      debugPrint("EDIT MODE => $isEditMode");

      debugPrint("========================================");

      // ========================================================
      // NO ROLE
      // ========================================================

      if (filterRole.isEmpty) {
        if (!mounted) return;

        setState(() {
          deviceList = [];
          isDeviceLoading = false;
        });

        return;
      }

      // ========================================================
      // ADMIN ROLE DEVICE NEVER SHOW
      // ========================================================

      if (filterRole == "admin") {
        debugPrint("ADMIN ROLE SELECTED => DEVICE LIST HIDDEN");

        if (!mounted) return;

        setState(() {
          deviceList = [];
          isDeviceLoading = false;
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        isDeviceLoading = true;
      });

      // ========================================================
      // DEVICE API
      // ========================================================

      final response = await ApiHelper().getRequest(
        ApiConstants.deviceAccessSettings,
      );

      debugPrint("DEVICE API RESPONSE => ${response?.data}");

      if (response == null ||
          response.statusCode != 200 ||
          response.data["success"] != true) {
        if (!mounted) return;

        setState(() {
          deviceList = [];
          isDeviceLoading = false;
        });

        return;
      }

      final List<dynamic> rawList = response.data["data"] ?? [];

      final List<Map<String, dynamic>> filteredList = [];

      // ========================================================
      // LOOP ALL DEVICES
      // ========================================================

      for (final rawDevice in rawList) {
        if (rawDevice is! Map) {
          continue;
        }

        final Map<String, dynamic> device = Map<String, dynamic>.from(
          rawDevice,
        );

        // ======================================================
        // USER OBJECT REQUIRED
        // ======================================================

        if (device["user"] is! Map) {
          debugPrint("❌ DEVICE WITHOUT USER SKIPPED");

          continue;
        }

        final Map<String, dynamic> user = Map<String, dynamic>.from(
          device["user"],
        );

        final String deviceUserRole =
            user["role"]?.toString().trim().toLowerCase() ?? "";

        final String deviceUserName = user["name"]?.toString().trim() ?? "";

        final int deviceUserId =
            int.tryParse(
              device["user_id"]?.toString() ?? user["id"]?.toString() ?? "0",
            ) ??
            0;

        debugPrint("----------------------------------------");

        debugPrint("DEVICE USER => $deviceUserName");

        debugPrint("DEVICE USER ID => $deviceUserId");

        debugPrint("DEVICE ROLE => [$deviceUserRole]");

        debugPrint("REQUIRED ROLE => [$filterRole]");

        // ======================================================
        // ADMIN DEVICE ALWAYS HIDE
        // ======================================================

        if (deviceUserRole == "admin") {
          debugPrint("❌ ADMIN DEVICE HIDE => $deviceUserName");

          continue;
        }

        // ======================================================
        // EXACT ROLE MATCH
        // ======================================================

        if (deviceUserRole != filterRole) {
          debugPrint(
            "❌ ROLE MISMATCH => "
            "$deviceUserName "
            "[$deviceUserRole]",
          );

          continue;
        }

        // ======================================================
        // CHECK USER STILL EXISTS
        //
        // Device table ma old/deleted user hoy
        // to device hide thase.
        // ======================================================

        if (validUsers.isNotEmpty) {
          final bool userStillExists = validUsers.any((validUser) {
            final int validUserId =
                int.tryParse(validUser["id"]?.toString() ?? "0") ?? 0;

            return validUserId == deviceUserId;
          });

          if (!userStillExists) {
            debugPrint(
              "❌ INVALID/DELETED USER => "
              "$deviceUserName "
              "ID=$deviceUserId",
            );

            continue;
          }
        }

        // ======================================================
        // ADD DEVICE
        // ======================================================

        filteredList.add(device);

        debugPrint(
          "✅ DEVICE ADDED => "
          "$deviceUserName "
          "[$deviceUserRole]",
        );
      }

      if (!mounted) return;

      setState(() {
        deviceList = filteredList;

        isDeviceLoading = false;
      });

      debugPrint("========================================");

      debugPrint("FINAL FILTER ROLE => [$filterRole]");

      debugPrint("FINAL DEVICE COUNT => ${deviceList.length}");

      for (final device in deviceList) {
        debugPrint(
          "FINAL DEVICE => "
          "${device["user"]?["name"]} | "
          "${device["user"]?["role"]}",
        );
      }

      debugPrint("========================================");
    } catch (e, stackTrace) {
      debugPrint("DEVICE LIST ERROR => $e");

      debugPrint("DEVICE STACK => $stackTrace");

      if (!mounted) return;

      setState(() {
        deviceList = [];
        isDeviceLoading = false;
      });
    }
  }

  // ============================================================
  // ROLE API
  // ============================================================

  Future<void> category() async {
    try {
      final response = await ApiHelper().getRequest(ApiConstants.Rolelist);

      debugPrint("ROLE API => ${response?.data}");

      if (response == null || response.statusCode != 200) {
        return;
      }

      final List categories = response.data["data"] ?? [];

      final List<String> tempRoles = [];

      // ========================================================
      // UNIQUE ROLE LIST
      // ========================================================

      for (final raw in categories) {
        if (raw is! Map) {
          continue;
        }

        final String roleName = raw["name"]?.toString().trim() ?? "";

        if (roleName.isEmpty) {
          continue;
        }

        final bool exists = tempRoles.any(
          (role) => role.trim().toLowerCase() == roleName.trim().toLowerCase(),
        );

        if (!exists) {
          tempRoles.add(roleName);
        }
      }

      // ========================================================
      // EDIT ROLE
      // ========================================================

      final String editRole = selectedRole?.trim() ?? "";

      // Edit role API list ma na hoy
      // to manually add
      if (editRole.isNotEmpty) {
        final bool exists = tempRoles.any(
          (role) => role.trim().toLowerCase() == editRole.trim().toLowerCase(),
        );

        if (!exists) {
          tempRoles.insert(0, editRole);
        }
      }

      // ========================================================
      // SAFE SELECTED ROLE
      // ========================================================

      String? safeSelectedRole;

      if (editRole.isNotEmpty) {
        for (final role in tempRoles) {
          if (role.trim().toLowerCase() == editRole.trim().toLowerCase()) {
            safeSelectedRole = role;

            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        userlist = categories;

        allUsers = categories;

        roleList = tempRoles;

        if (safeSelectedRole != null) {
          selectedRole = safeSelectedRole;
        }
      });

      debugPrint("FINAL ROLE LIST => $roleList");

      debugPrint("FINAL SELECTED ROLE => [$selectedRole]");
    } catch (e) {
      debugPrint("ROLE ERROR => $e");
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    final bool isMobile = size.width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 45),

              Expanded(child: _buildRecentScansList(context)),

              // ===============================================
              // SAVE / UPDATE
              // ===============================================
              InkWell(
                onTap: () async {
                  FocusManager.instance.primaryFocus?.unfocus();

                  await Future.delayed(const Duration(milliseconds: 50));

                  if (isEditMode) {
                    await update_user();
                  } else {
                    await create_user();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      isEditMode ? "Update User" : "Save User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),

          // ===============================================
          // APP BAR
          // ===============================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.white,
              padding: const EdgeInsets.only(
                top: 30,
                left: 16,
                right: 16,
                bottom: 14,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    isEditMode ? "Edit User" : "Create User",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();

                        Navigator.pop(context,true);
                      },
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(8),
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
    );
  }

  // ============================================================
  // MAIN FORM
  // ============================================================

  Widget _buildRecentScansList(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // ====================================================
          // BASIC INFORMATION
          // ====================================================
          _formCard(
            title: "Basic Information",
            child: Column(
              children: [
                _fieldBottom(
                  _buildTextField(context, "Name", controller: nameController),
                ),
                SizedBox(height: 0,),
                _buildDropdown(
                  context,
                  "Role",
                  roleList,
                  selectedRole,
                      (value) async {
                    if (!mounted) return;

                    setState(() {
                      selectedRole = value;
                      deviceList = [];
                    });

                    debugPrint("ROLE CHANGED => [$selectedRole]");

                    if (!isAdmin) return;

                    final String role =
                        selectedRole?.trim().toLowerCase() ?? "";

                    if (role.isEmpty || role == "admin") {
                      return;
                    }

                    await getDeviceList();
                  },
                ),
                SizedBox(height: 10,),
                twoFieldRow(
                  _buildDateFieldNew(
                    context,
                    "Birth Date",
                    birthDateController,
                  ),
                  _buildDateFieldNew(
                    context,
                    "Anniversary",
                    anniversaryDateController,
                  ),
                ),

                _fieldBottom(
                  _buildTextField(
                    context,
                    "Email",
                    controller: emailController,
                    isRequired: true, // 🔥
                  ),
                ),


                twoFieldRow(
                  _buildTextField(
                    context,
                    "Password",
                    controller: passwordController,
                    isPassword: true,
                    isRequired: !isEditMode, // 🔥 Create માં required
                  ),
                  _buildTextField(
                    context,
                    "Confirm Password",
                    controller: confirmPasswordController,
                    isPassword: true,
                    isRequired: !isEditMode, // 🔥
                  ),
                ),

                _imagePickerField(),
              ],
            ),
          ),

          // ====================================================
          // PERSON DETAILS
          // ====================================================
          _formCard(
            title: "Person Details",
            child: Column(
              children: [
                twoFieldRow(
                  _buildTextField(
                    context,
                    "Person Code",
                    controller: personCodeController,
                  ),
                  _buildTextField(context, "GST No", controller: gstController),
                ),

                twoFieldRow(
                  _buildTextField(context, "Area", controller: areaController),
                  _buildTextField(context, "City", controller: cityController),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Pincode",
                    controller: pincodeController,
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
                    "Phone No",
                    controller: phoneController,
                    isNumber: true,
                  ),
                  _buildTextField(
                    context,
                    "Mobile No",
                    controller: mobileController,
                    isNumber: true,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Contact Person1 Name",
                    controller: contact1NameController,
                  ),
                  _buildTextField(
                    context,
                    "Contact Person1 Phone",
                    controller: contact1PhoneController,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Contact Person2 Name",
                    controller: contact2NameController,
                  ),
                  _buildTextField(
                    context,
                    "Contact Person2 Phone",
                    controller: contact2PhoneController,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(context, "PAN No", controller: panController),
                  _buildTextField(
                    context,
                    "Aadhaar No",
                    controller: aadhaarController,
                    isNumber: true,
                  ),
                ),

                twoFieldRow(
                  _buildTextField(
                    context,
                    "Hallmark License No",
                    controller: hallmarkController,
                  ),
                  _buildTextField(
                    context,
                    "Reference",
                    controller: referenceController,
                  ),
                ),

                _fieldBottom(
                  _buildTextField(
                    context,
                    "Address",
                    controller: addressController,
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // DEVICE MANAGEMENT
          //
          // Conditions:
          //
          // 1. Login user admin hovo joie
          // 2. Role selected hovo joie
          // 3. Selected/Edit role admin na hovo joie
          // ====================================================
          if (isAdmin &&
              selectedRole != null &&
              selectedRole!.trim().isNotEmpty &&
              selectedRole!.trim().toLowerCase() != "admin")
            _buildDeviceSection(),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ============================================================
  // FORM CARD
  // ============================================================

  Widget _formCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _fieldBottom(Widget child) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: child);
  }

  // ============================================================
  // TWO FIELD ROW
  // ============================================================

  Widget twoFieldRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField(
      BuildContext context,
      String label, {
        String? hint,
        TextEditingController? controller,
        bool isRequired = false,
        bool isNumber = false,
        bool isPassword = false,
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

    // Password visibility
    bool obscurePassword = isPassword;

    return StatefulBuilder(
      builder: (context, setState) {
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

                // Password hide/show
                obscureText: isPassword ? obscurePassword : false,

                keyboardType: label.toLowerCase().contains("email")
                    ? TextInputType.emailAddress
                    : isPanField
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

                  // Password eye icon
                  suffixIcon: isPassword
                      ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: isTablet ? 21 : 19,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ROLE DROPDOWN
  // ============================================================

  Widget _buildDropdown(
      BuildContext context,
      String label,
      List<String> items,
      String? value,
      Function(String?) onChanged,
      ) {
    final bool isTablet =
        MediaQuery.of(context).size.width >= 600;

    // ==========================================================
    // UNIQUE ITEMS
    // ==========================================================

    final List<String> uniqueItems = [];

    for (final raw in items) {
      final String clean = raw.trim();

      if (clean.isEmpty) continue;

      final bool exists = uniqueItems.any(
            (item) =>
        item.trim().toLowerCase() ==
            clean.toLowerCase(),
      );

      if (!exists) {
        uniqueItems.add(clean);
      }
    }

    // ==========================================================
    // SAFE SELECTED VALUE
    // ==========================================================

    String? safeValue;

    final String currentValue =
        value?.trim() ?? "";

    if (currentValue.isNotEmpty) {
      for (final item in uniqueItems) {
        if (item.toLowerCase() ==
            currentValue.toLowerCase()) {
          safeValue = item;
          break;
        }
      }
    }

    // ==========================================================
    // CONVERT STRING LIST -> PREMIUM DROPDOWN LIST
    // ==========================================================

    final List<Map<String, dynamic>> premiumItems =
    uniqueItems.map((item) {
      return <String, dynamic>{
        "id": item,
        "item_name": item,
        "name": item,
      };
    }).toList();

    // ==========================================================
    // FIND SELECTED OBJECT
    // ==========================================================

    Map<String, dynamic>? selectedItem;

    if (safeValue != null) {
      for (final item in premiumItems) {
        if (item["item_name"]
            .toString()
            .toLowerCase() ==
            safeValue.toLowerCase()) {
          selectedItem = item;
          break;
        }
      }
    }

    // ==========================================================
    // PREMIUM SEARCH DROPDOWN
    // ==========================================================

    return PremiumItemSearchDropdown(
      label: label,
      hint: "Select $label",

      items: premiumItems,

      value: selectedItem,

      requiredField: false,

      onChanged: (selected) {
        if (selected == null) {
          onChanged(null);
          return;
        }

        final String selectedValue =
            selected["item_name"]
                ?.toString()
                .trim() ??
                "";

        onChanged(
          selectedValue.isEmpty
              ? null
              : selectedValue,
        );
      },
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _buildDateFieldNew(
    BuildContext context,
    String label,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 6),

        InkWell(
          onTap: () async {
            FocusManager.instance.primaryFocus?.unfocus();

            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );

            if (picked == null || !mounted) {
              return;
            }

            setState(() {
              controller.text =
                  "${picked.day.toString().padLeft(2, '0')}-"
                  "${picked.month.toString().padLeft(2, '0')}-"
                  "${picked.year}";
            });
          },
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? "Select $label" : controller.text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: controller.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 17,
                  color: AppColors.gradientBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // IMAGE PICKER FIELD
  // ============================================================

  Widget _imagePickerField() {
    return InkWell(
      onTap: _showImagePickerDialog,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_rounded, color: AppColors.gradientBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedImage == null
                    ? "Upload Profile Image"
                    : path.basename(selectedImage!.path),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DEVICE SECTION
  // ============================================================

  Widget _buildDeviceSection() {
    final String currentRole = selectedRole?.trim() ?? "";

    final int totalDevices = deviceList.length;

    final int approvedCount = deviceList.where((device) {
      return device["status"]?.toString().trim().toLowerCase() == "approved";
    }).length;

    final int pendingCount = deviceList.where((device) {
      return device["status"]?.toString().trim().toLowerCase() == "pending";
    }).length;

    final int inactiveCount = deviceList.where((device) {
      return device["status"]?.toString().trim().toLowerCase() == "inactive";
    }).length;

    final int rejectedCount = deviceList.where((device) {
      return device["status"]?.toString().trim().toLowerCase() == "rejected";
    }).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // ====================================================
            // PREMIUM HEADER
            // ====================================================
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    isDeviceSectionExpanded = !isDeviceSectionExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryDark.withOpacity(0.10),
                        AppColors.secondaryDark.withOpacity(0.04),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // ==========================================
                      // ICON
                      // ==========================================
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryDark,
                              AppColors.secondaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withOpacity(0.20),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.devices_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ==========================================
                      // TITLE
                      // ==========================================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Device Management",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark.withOpacity(
                                      0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    currentRole.isEmpty
                                        ? "No Role"
                                        : currentRole,
                                    style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 6),

                                Flexible(
                                  child: Text(
                                    "$totalDevices registered device"
                                    "${totalDevices == 1 ? "" : "s"}",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ==========================================
                      // REFRESH
                      // ==========================================
                      InkWell(
                        onTap: isDeviceLoading
                            ? null
                            : () async {
                                await getValidUsers();

                                await getDeviceList();
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: isDeviceLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  size: 19,
                                  color: AppColors.primaryDark,
                                ),
                        ),
                      ),

                      const SizedBox(width: 7),

                      // ==========================================
                      // EXPAND BUTTON
                      // ==========================================
                      AnimatedRotation(
                        turns: isDeviceSectionExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 23,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ====================================================
            // EXPANDABLE BODY
            // ====================================================
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),

              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ============================================
                    // STATUS SUMMARY
                    // ============================================
                    if (!isDeviceLoading && deviceList.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _deviceSummaryItem(
                                title: "Total",
                                value: totalDevices,
                                icon: Icons.devices_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),

                            _deviceSummaryDivider(),

                            Expanded(
                              child: _deviceSummaryItem(
                                title: "Approved",
                                value: approvedCount,
                                icon: Icons.verified_rounded,
                                color: Colors.green,
                              ),
                            ),

                            _deviceSummaryDivider(),

                            Expanded(
                              child: _deviceSummaryItem(
                                title: "Pending",
                                value: pendingCount,
                                icon: Icons.schedule_rounded,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!isDeviceLoading && deviceList.isNotEmpty)
                      const SizedBox(height: 10),

                    // ============================================
                    // SECOND STATUS ROW
                    // ============================================
                    if (!isDeviceLoading &&
                        (inactiveCount > 0 || rejectedCount > 0))
                      Row(
                        children: [
                          if (inactiveCount > 0)
                            Expanded(
                              child: _smallStatusChip(
                                icon: Icons.pause_circle_rounded,
                                title: "Inactive",
                                count: inactiveCount,
                                color: Colors.orange,
                              ),
                            ),

                          if (inactiveCount > 0 && rejectedCount > 0)
                            const SizedBox(width: 8),

                          if (rejectedCount > 0)
                            Expanded(
                              child: _smallStatusChip(
                                icon: Icons.cancel_rounded,
                                title: "Rejected",
                                count: rejectedCount,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),

                    if (!isDeviceLoading &&
                        (inactiveCount > 0 || rejectedCount > 0))
                      const SizedBox(height: 12),

                    // ============================================
                    // ROLE INFO
                    // ============================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              currentRole.isEmpty
                                  ? "Select a role to view registered devices."
                                  : "Only $currentRole role devices are shown here.",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ============================================
                    // LOADING
                    // ============================================
                    if (isDeviceLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Loading devices...",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    // ============================================
                    // EMPTY
                    // ============================================
                    else if (deviceList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phonelink_off_rounded,
                                size: 27,
                                color: Colors.grey.shade500,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              "No Devices Found",
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              currentRole.isEmpty
                                  ? "No registered devices are available."
                                  : "No registered device found for $currentRole role.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                            ),

                            const SizedBox(height: 12),

                            InkWell(
                              onTap: () async {
                                await getValidUsers();
                                await getDeviceList();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withOpacity(
                                    0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 15,
                                      color: AppColors.primaryDark,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Refresh",
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    // ============================================
                    // DEVICE LIST
                    // ============================================
                    else
                      ListView.separated(
                        itemCount: deviceList.length,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          return _deviceCard(deviceList[index]);
                        },
                      ),
                  ],
                ),
              ),

              crossFadeState: isDeviceSectionExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,

              duration: const Duration(milliseconds: 280),

              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DEVICE CARD
  // ============================================================

  Widget _deviceCard(Map<String, dynamic> device) {
    final Map<String, dynamic> user = device["user"] is Map
        ? Map<String, dynamic>.from(device["user"])
        : {};

    final String status =
        device["status"]?.toString().trim().toLowerCase() ?? "pending";

    Color statusColor;

    IconData statusIcon;

    switch (status) {
      case "approved":
        statusColor = Colors.green.shade700;

        statusIcon = Icons.verified_rounded;

        break;

      case "rejected":
        statusColor = Colors.red.shade700;

        statusIcon = Icons.cancel_rounded;

        break;

      case "inactive":
        statusColor = Colors.orange.shade700;

        statusIcon = Icons.pause_circle;

        break;

      default:
        statusColor = Colors.amber.shade800;

        statusIcon = Icons.schedule_rounded;
    }

    final int deviceId = int.tryParse(device["id"]?.toString() ?? "0") ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ====================================================
          // USER
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user["name"]?.toString() ?? "-",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      user["email"]?.toString() ?? "-",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      "Role: ${user["role"] ?? "-"}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // STATUS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _capitalize(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: Colors.grey.shade200),

          const SizedBox(height: 10),

          // ====================================================
          // DEVICE INFO
          // ====================================================
          _deviceInfoRow(
            Icons.phone_android_rounded,
            "Device",
            device["device_name"]?.toString() ?? "-",
          ),

          _deviceInfoRow(
            Icons.fingerprint,
            "Device ID",
            device["device_id"]?.toString() ?? "-",
          ),

          _deviceInfoRow(
            Icons.system_update_alt,
            "App Version",
            device["app_version"]?.toString() ?? "-",
          ),

          _deviceInfoRow(
            Icons.access_time,
            "Last Seen",
            device["last_seen_at"]?.toString() ?? "-",
          ),

          if (device["last_latitude"] != null &&
              device["last_longitude"] != null)
            _deviceInfoRow(
              Icons.location_on_outlined,
              "Location",
              "${device["last_latitude"]}, ${device["last_longitude"]}",
            ),

          const SizedBox(height: 12),

          // ====================================================
          // ACTION BUTTONS
          // ====================================================
          Row(
            children: [
              // APPROVE
              if (status != "approved")
                Expanded(
                  child: _deviceActionButton(
                    title: "Approve",
                    icon: Icons.check,
                    color: Colors.green,
                    onTap: () async {
                      final response = await ApiHelper().postRequest(
                        ApiConstants.deviceApproveAccessSettings,
                        {
                          "user_id": device["user_id"],
                          "device_id": device["device_id"],
                        },
                      );

                      debugPrint(
                        "APPROVE RESPONSE => ${response?.data}",
                      );

                      if (!mounted) return;

                      if (response != null &&
                          (response.statusCode == 200 ||
                              response.statusCode == 201)) {
                        AppMessage.success(
                          context,
                          response.data["message"] ??
                              "Device approved successfully",
                        );

                        await getDeviceList();
                      } else {
                        showError(
                          response?.data?["message"]?.toString() ??
                              "Unable to approve device",
                        );
                      }
                    },
                  ),
                ),

              if (status != "approved" && status != "rejected")
                const SizedBox(width: 6),

              // REJECT
              if (status != "rejected")
                Expanded(
                  child: _deviceActionButton(
                    title: "Reject",
                    icon: Icons.close,
                    color: Colors.red,
                    onTap: () async {
                      final response = await ApiHelper().postRequest(
                        ApiConstants.devicerejectAccessSettings,
                        {
                          "user_id": device["user_id"],
                          "device_id": device["device_id"],
                        },
                      );

                      debugPrint(
                        "APPROVE RESPONSE => ${response?.data}",
                      );

                      if (!mounted) return;

                      if (response != null &&
                          (response.statusCode == 200 ||
                              response.statusCode == 201)) {
                        AppMessage.success(
                          context,
                          response.data["message"] ??
                              "Device approved successfully",
                        );

                        await getDeviceList();
                      } else {
                        showError(
                          response?.data?["message"]?.toString() ??
                              "Unable to approve device",
                        );
                      }
                    },
                  ),
                ),

              // INACTIVE
              if (status == "approved") ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _deviceActionButton(
                    title: "Inactive",
                    icon: Icons.pause_rounded,
                    color: Colors.orange,
                    onTap: () async {
                      final response = await ApiHelper().postRequest(
                        ApiConstants.deviceinactiveAccessSettings,
                        {
                          "user_id": device["user_id"],
                          "device_id": device["device_id"],
                        },
                      );

                      debugPrint(
                        "APPROVE RESPONSE => ${response?.data}",
                      );

                      if (!mounted) return;

                      if (response != null &&
                          (response.statusCode == 200 ||
                              response.statusCode == 201)) {
                        AppMessage.success(
                          context,
                          response.data["message"] ??
                              "Device approved successfully",
                        );

                        await getDeviceList();
                      } else {
                        showError(
                          response?.data?["message"]?.toString() ??
                              "Unable to approve device",
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DEVICE INFO ROW
  // ============================================================

  Widget _deviceInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade600),

          const SizedBox(width: 7),

          SizedBox(
            width: 74,
            child: Text(
              title,
              style: const TextStyle(color: Colors.black54, fontSize: 10),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DEVICE ACTION BUTTON
  // ============================================================

  Widget _deviceActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONFIRM DEVICE ACTION
  // ============================================================

  Future<void> _confirmDeviceAction({
    required String title,
    required String message,
    required String action,
    required int deviceId,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await updateDeviceStatus(deviceId: deviceId, action: action);
  }

  // ============================================================
  // DEVICE STATUS API
  // ============================================================

  Future<void> updateDeviceStatus({
    required int deviceId,
    required String action,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    String endpoint;

    if (action == "approve") {
      endpoint = deviceApproveApi(deviceId);
    } else if (action == "reject") {
      endpoint = deviceRejectApi(deviceId);
    } else {
      endpoint = deviceInactiveApi(deviceId);
    }

    try {
      final response = await ApiHelper().postRequest(endpoint, {});

      debugPrint("DEVICE ACTION => $action");

      debugPrint("DEVICE ACTION RESPONSE => ${response?.data}");

      if (!mounted) {
        return;
      }

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        AppMessage.success(
          context,
          response.data["message"] ?? "Device updated successfully",
        );

        // Same role devices reload
        await getDeviceList();

        return;
      }

      showError(
        response?.data?["message"]?.toString() ?? "Unable to update device.",
      );
    } catch (e) {
      debugPrint("DEVICE ACTION ERROR => $e");

      if (!mounted) return;

      showError("Unable to update device.");
    }
  }

  // ============================================================
  // CREATE USER
  // ============================================================

  Future<void> create_user() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateEmailPassword()) return; // 🔥


    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      showError("Password and Confirm Password do not match.");

      return;
    }

    if (selectedRole == null || selectedRole!.trim().isEmpty) {
      showError("Please select role.");

      return;
    }

    try {
      final FormData formData = FormData.fromMap({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "role": selectedRole!.trim(),
        "person_code": personCodeController.text.trim(),
        "city": cityController.text.trim(),
        "address": addressController.text.trim(),
        "area": areaController.text.trim(),
        "landmark": landmarkController.text.trim(),
        "pincode": pincodeController.text.trim(),
        "mobile_no": mobileController.text.trim(),
        "phone_no": phoneController.text.trim(),
        "contact_person1_name": contact1NameController.text.trim(),
        "contact_person1_phone": contact1PhoneController.text.trim(),
        "contact_person2_name": contact2NameController.text.trim(),
        "contact_person2_phone": contact2PhoneController.text.trim(),
        "gst_no": gstController.text.trim(),
        "pan_no": panController.text.trim(),
        "aadhaar_no": aadhaarController.text.trim(),
        "hallmark_license_no": hallmarkController.text.trim(),
        "birth_date": formatDateForApi(birthDateController.text),
        "anniversary_date": formatDateForApi(anniversaryDateController.text),
        "password": passwordController.text.trim(),
        "reference": referenceController.text.trim(),
        "remarks": remarksController.text.trim(),
      });

      if (selectedImage != null) {
        formData.files.add(
          MapEntry(
            "profile_image",
            await MultipartFile.fromFile(
              selectedImage!.path,
              filename: path.basename(selectedImage!.path),
            ),
          ),
        );
      }

      final response = await OfflineApiHelper.instance.postFormData(
        ApiConstants.create_users,
        formData,
      );

      if (!mounted) return;

      if (response == null) {
        showError("No response from server");

        return;
      }

      final dynamic data = response.data;

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        if (response.statusCode == 202) {
          AppMessage.success(context, "No Internet. User saved offline.");
        } else {
          AppMessage.success(
            context,
            data is Map
                ? data["message"] ?? "User created successfully"
                : "User created successfully",
          );
        }

        FocusManager.instance.primaryFocus?.unfocus();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Userscreen(),
          ),
              (route) => route.isFirst,
        );

        return;
      }

      _handleApiError(response);
    } catch (e) {
      debugPrint("CREATE USER ERROR => $e");

      if (!mounted) return;

      showError("Something went wrong. Please try again.");
    }
  }

  // ============================================================
  // UPDATE USER
  // ============================================================

  Future<void> update_user() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateEmailPassword()) return; // 🔥
    final String password = passwordController.text.trim();

    final String confirmPassword = confirmPasswordController.text.trim();

    // Edit mode ma password optional
    if (password.isNotEmpty || confirmPassword.isNotEmpty) {
      if (password != confirmPassword) {
        showError("Password and Confirm Password do not match.");

        return;
      }
    }

    if (selectedRole == null || selectedRole!.trim().isEmpty) {
      showError("Please select role.");

      return;
    }

    try {
      final int userId =
          int.tryParse(widget.userData!["id"]?.toString() ?? "0") ?? 0;

      final FormData formData = FormData.fromMap({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "role": selectedRole!.trim(),
        "person_code": personCodeController.text.trim(),
        "city": cityController.text.trim(),
        "address": addressController.text.trim(),
        "area": areaController.text.trim(),
        "landmark": landmarkController.text.trim(),
        "pincode": pincodeController.text.trim(),
        "mobile_no": mobileController.text.trim(),
        "phone_no": phoneController.text.trim(),
        "contact_person1_name": contact1NameController.text.trim(),
        "contact_person1_phone": contact1PhoneController.text.trim(),
        "contact_person2_name": contact2NameController.text.trim(),
        "contact_person2_phone": contact2PhoneController.text.trim(),
        "gst_no": gstController.text.trim(),
        "pan_no": panController.text.trim(),
        "aadhaar_no": aadhaarController.text.trim(),
        "hallmark_license_no": hallmarkController.text.trim(),
        "birth_date": formatDateForApi(birthDateController.text),
        "anniversary_date": formatDateForApi(anniversaryDateController.text),
        "reference": referenceController.text.trim(),
        "remarks": remarksController.text.trim(),
      });

      if (password.isNotEmpty) {
        formData.fields.add(MapEntry("password", password));
      }

      if (selectedImage != null) {
        formData.files.add(
          MapEntry(
            "profile_image",
            await MultipartFile.fromFile(
              selectedImage!.path,
              filename: path.basename(selectedImage!.path),
            ),
          ),
        );
      }

      final response = await ApiHelper().postFormData(
        "${ApiConstants.update_users}/$userId",
        formData,
      );

      if (!mounted) return;

      if (response == null) {
        showError("No response from server");

        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppMessage.success(
          context,
          response.data["message"] ?? "User updated successfully",
        );

        FocusManager.instance.primaryFocus?.unfocus();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Userscreen(),
          ),
              (route) => route.isFirst,
        );

        return;
      }

      _handleApiError(response);
    } catch (e) {
      debugPrint("UPDATE USER ERROR => $e");

      if (!mounted) return;

      showError("Something went wrong. Please try again.");
    }
  }

  // ============================================================
  // API ERROR
  // ============================================================

  void _handleApiError(dynamic response) {
    final dynamic data = response.data;

    if (response.statusCode == 422 && data is Map && data["errors"] is Map) {
      String message = "";

      final Map errors = data["errors"];

      errors.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          message += "${value.first}\n";
        }
      });

      showError(message.trim());

      return;
    }

    if (data is Map && data["message"] != null) {
      showError(data["message"].toString());

      return;
    }

    showError("Server error (${response.statusCode})");
  }

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  void _showImagePickerDialog() {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Image",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 15),

                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
                  title: const Text("Camera"),
                  subtitle: const Text("Capture a new photo"),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    pickFromCamera();
                  },
                ),

                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.photo_library)),
                  title: const Text("Gallery"),
                  subtitle: const Text("Choose from gallery"),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    pickFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> pickFromCamera() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      selectedImage = File(image.path);
    });
  }

  Future<void> pickFromGallery() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      selectedImage = File(image.path);
    });
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String formatDateForApi(String date) {
    if (date.trim().isEmpty) {
      return "";
    }

    final RegExp apiFormat = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (apiFormat.hasMatch(date.trim())) {
      return date.trim();
    }

    final List<String> parts = date.split("-");

    if (parts.length != 3) {
      return "";
    }

    return "${parts[2]}-"
        "${parts[1].padLeft(2, '0')}-"
        "${parts[0].padLeft(2, '0')}";
  }

  String formatDateForDisplay(String date) {
    if (date.trim().isEmpty) {
      return "";
    }

    final List<String> parts = date.split("-");

    if (parts.length != 3) {
      return date;
    }

    if (parts[0].length == 4) {
      final String day = parts[2].length >= 2
          ? parts[2].substring(0, 2)
          : parts[2];

      return "$day-${parts[1]}-${parts[0]}";
    }

    return date;
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void showError(String? message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message ?? "Something went wrong",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return "";
    }

    return "${value[0].toUpperCase()}${value.substring(1)}";
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();

    personCodeController.dispose();

    cityController.dispose();

    addressController.dispose();

    areaController.dispose();

    landmarkController.dispose();

    pincodeController.dispose();

    mobileController.dispose();

    phoneController.dispose();

    contact1NameController.dispose();

    contact1PhoneController.dispose();

    contact2NameController.dispose();

    contact2PhoneController.dispose();

    gstController.dispose();

    panController.dispose();

    aadhaarController.dispose();

    hallmarkController.dispose();

    referenceController.dispose();

    remarksController.dispose();

    birthDateController.dispose();

    anniversaryDateController.dispose();

    passwordController.dispose();

    confirmPasswordController.dispose();

    super.dispose();
  }

  Widget _deviceSummaryItem({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _deviceSummaryDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.grey.shade200,
    );
  }

  Widget _smallStatusChip({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            "$title  $count",
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
// 🔥 EMAIL + PASSWORD VALIDATION
// ============================================================

  bool _validateEmailPassword() {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    /// EMAIL REQUIRED
    if (email.isEmpty) {
      showError("Please enter email.");
      return false;
    }

    /// EMAIL FORMAT
    final RegExp emailRegex = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$');
    if (!emailRegex.hasMatch(email)) {
      showError("Please enter a valid email.");
      return false;
    }

    /// CREATE MODE → PASSWORD REQUIRED
    if (!isEditMode) {
      if (password.isEmpty) {
        showError("Please enter password.");
        return false;
      }

      if (confirmPassword.isEmpty) {
        showError("Please enter confirm password.");
        return false;
      }
    }

    /// PASSWORD MATCH (ભર્યો હોય ત્યારે)
    if ((password.isNotEmpty || confirmPassword.isNotEmpty) &&
        password != confirmPassword) {
      showError("Password and Confirm Password do not match.");
      return false;
    }

    return true;
  }
}

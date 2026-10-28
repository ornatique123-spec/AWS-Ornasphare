import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pecifician_sysytem/User/UserScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Offline Data/offline_api_helper.dart';
import 'ItemScreen.dart';

class Createitemscreen extends StatefulWidget {
  final Map? userData;

  const Createitemscreen({super.key, this.userData});

  @override
  State<Createitemscreen> createState() => _CreateitemscreenState();
}

class _CreateitemscreenState extends State<Createitemscreen> {
  final TextEditingController item_nameController = TextEditingController();
  final TextEditingController item_codeController = TextEditingController();
  final TextEditingController OutwardController = TextEditingController();
  final TextEditingController InwardController = TextEditingController();
  final TextEditingController Outward_purity_Controller =
      TextEditingController();
  final TextEditingController Inward_purity_Controller =
      TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController HsnController = TextEditingController();
  final TextEditingController Export_hsn_Controller = TextEditingController();
  final TextEditingController numericLengthController = TextEditingController();
  final TextEditingController contact2NameController = TextEditingController();
  final TextEditingController contact2PhoneController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController panController = TextEditingController();
  final TextEditingController aadhaarController = TextEditingController();
  final TextEditingController hallmarkController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  bool get isEditMode => widget.userData != null;
  bool autoLoadPurity = false;
  bool autoCreateLabelPurchase = false;
  bool autoCreateLabelConfig = false;

  String? selectedItemGroup;
  String? selectedRole;
  String? selectedmetal_formula;
  String? selected_labour;
  String? selected_labour_unit;
  String? selected_job_work;
  DateTime? birthDate;
  DateTime? anniversaryDate;
  final _formKey = GlobalKey<FormState>();
  static const Map<String, String> _metals = {
    "gold": "Gold",
    "silver": "Silver",
    "platinum": "Platinum",
    "others": "Others",
  };
  static const Map<String, String> _formulas = {
    "per_netweight": "Per Netweight",
    "per_fineweight": "Per Fineweight",
    "per_grossweight": "Per Grossweight",
    "per_quantity": "Per Quantity",
    "flat": "Flat",
  };
  static const Map<String, String> _labourUnits = {
    "per_gram": "Per Gram",
    "per_10_gram": "Per 10 Gram",
    "per_kg": "Per Kg",
    "per_quantity": "Per Quantity",
  };
  static const Map<String, String> _jobWorkTypes = {
    "finish": "Finish",
    "raw": "Raw",
  };

  static const Map<String, String> _itemGroups = {
    "finish": "Finish",
    "raw": "Raw",
  };

  String? _matchOption(dynamic apiValue, Map<String, String> options) {
    final raw = apiValue?.toString().trim() ?? "";
    if (raw.isEmpty || raw == "null") return null;

    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), "");
    final target = norm(raw);

    for (final e in options.entries) {
      /// "per_netweight" અથવા "Per Netweight" બંને match થાય
      if (norm(e.key) == target || norm(e.value) == target) return e.key;
    }
    debugPrint("⚠️ Dropdown match નથી થયું: '$raw'");
    return null;
  }

  /// null / number → safe String (TextField માટે)
  String _str(dynamic v) {
    final s = v?.toString().trim() ?? "";
    return s == "null" ? "" : s;
  }
  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      final user = widget.userData!;
      debugPrint("✏️ EDIT ITEM DATA => $user"); // API શું આપે છે એ જુઓ

      item_nameController.text = _str(user["item_name"]);
      item_codeController.text = _str(user["item_code"]);
      OutwardController.text = _str(user["outward_carat"]);
      InwardController.text = _str(user["inward_carat"]);
      Outward_purity_Controller.text = _str(user["outward_purity"]);
      Inward_purity_Controller.text = _str(user["inward_purity"]);
      HsnController.text = _str(user["hsn"]);
      Export_hsn_Controller.text = _str(user["export_hsn"]);
      numericLengthController.text = _str(user["numeric_length"]);
      remarksController.text = _str(user["remarks"]);

      selectedRole = _matchOption(user["metal"], _metals);
      selectedmetal_formula = _matchOption(user["metal_formula"], _formulas);
      selected_labour = _matchOption(user["labour_type"], _formulas);
      selected_labour_unit = _matchOption(user["labour_unit"], _labourUnits);
      selected_job_work = _matchOption(user["jobwork_item_type"], _jobWorkTypes);
      selectedItemGroup = _matchOption(user["item_group"], _itemGroups);

      autoLoadPurity = _str(user["auto_load_purity"]) == "1";
      autoCreateLabelConfig = _str(user["auto_create_label_config"]) == "1";
      autoCreateLabelPurchase = _str(user["auto_create_label_purchase"]) == "1";
    }
    OutwardController.addListener(() {
      String value = OutwardController.text;

      if (InwardController.text != value) {
        InwardController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }

      if (Outward_purity_Controller.text != value) {
        Outward_purity_Controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }

      if (Inward_purity_Controller.text != value) {
        Inward_purity_Controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    });
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
              SizedBox(height: MediaQuery.of(context).padding.top + 40),

              /// 🔥 Dynamic Bottom Section
              Expanded(child: _buildRecentScansList(context)),

              InkWell(
                onTap: () {
                  if (isEditMode) {
                    update_item();
                  } else {
                    create_item();
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
                        isEditMode ? "Update Item" : "Save Item",
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
                    "Create Item",
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
          ),
        ],
      ),

      //bottomNavigationBar: _buildSaveButton(),
    );
  }

  /// ✅ Header Section
  Widget topHeaderSectionGlass(double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), // Glass transparency
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Row (Avatar + Notification)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: AssetImage("assets/static/img.png"),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "OrnaSphere",
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => const Userscreen(),
                          //   ),
                          // );
                        },
                        child: Icon(
                          Icons.notifications_none,
                          color: AppColors.white,
                          size: 26,
                        ),
                      ),
                      SizedBox(width: 15),
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(
                          "https://i.pravatar.cc/150?img=3",
                        ),
                      ),
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

  /// ✅ Recent Scan List
  Widget _buildRecentScansList(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isTablet = width > 700;

    Widget responsiveRow(List<Widget> children) {
      // Single widget → just return with padding
      if (children.length == 1) {
        return Padding(
          padding: EdgeInsets.only(bottom: height * 0.01),
          child: children.first,
        );
      }

      // Mobile
      if (!isTablet) {
        return Column(
          children: children
              .map(
                (e) => Padding(
                  padding: EdgeInsets.only(bottom: height * 0.018),
                  child: e,
                ),
              )
              .toList(),
        );
      }

      // Tablet / Desktop
      return Padding(
        padding: EdgeInsets.only(bottom: height * 0.01),
        child: Row(
          children: children
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: width * 0.01),
                    child: e,
                  ),
                ),
              )
              .toList(),
        ),
      );
    }


    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),

      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: height * 0.01),

            responsiveRow([
              _buildTextField(
                context,
                "Item Name",
                controller: item_nameController,
                isRequired: true, // 🔥 show *
              ),
              _buildTextField(
                context,
                "Item Code",
                controller: item_codeController,
                isRequired: true, // 🔥 show *
              ),
            ]),

            responsiveRow([
              _buildDropdown(
                context,
                "Metal",
                _metals,
                selectedRole,               // 🔥 Metal નો પોતાનો variable
                    (val) {
                  setState(() => selectedRole = val);
                },
                isRequired: true,
              ),
            ]),

            SizedBox(height: height * 0.01),

            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.01,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Outward Carat",
                      controller: OutwardController,
                      isRequired: true, // 🔥 show *
                      isNumber: true, // 🔥 only number
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Inward Carat",
                      controller: InwardController,
                      isNumber: true, // 🔥 only number
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.01,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Outward Purity",
                      controller: Outward_purity_Controller,
                      isNumber: true, // 🔥 only number
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Inward Purity",
                      controller: Inward_purity_Controller,
                      isNumber: true, // 🔥 only number
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.01,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDropdown(context, "Metal Formula", _formulas, selectedmetal_formula, (val) {
                      setState(() => selectedmetal_formula = val);
                    }),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child:_buildDropdown(context, "Labour", _formulas, selected_labour, (val) {
                      setState(() => selected_labour = val);
                    }),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.01,
              ),
              child: Row(
                children: [
                  Expanded(
                    child:_buildDropdown(context, "Labour Unit", _labourUnits, selected_labour_unit, (val) {
                      setState(() => selected_labour_unit = val);
                    }),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildDropdown(context, "Jobwork  Type", _jobWorkTypes, selected_job_work, (val) {
                      setState(() => selected_job_work = val);
                    }),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.01,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      context,
                      "HSN Code",
                      controller: HsnController,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Export HSN",
                      controller: Export_hsn_Controller,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: height * 0.005),

            /// ✅ Checkboxes Row
            Wrap(
              spacing: width * 0.05,
              //runSpacing: height * 0.01,
              children: [
                _buildCheckbox(
                  "Auto Load Purity From Prod. in JobWork",
                  autoLoadPurity,
                  (val) {
                    setState(() => autoLoadPurity = val ?? false);
                  },
                ),
                _buildCheckbox(
                  "Auto Create Label In Purchase",
                  autoCreateLabelPurchase,
                  (val) {
                    setState(() => autoCreateLabelPurchase = val ?? false);
                  },
                ),
                _buildCheckbox(
                  "Auto Create Label Config",
                  autoCreateLabelConfig,
                  (val) {
                    setState(() => autoCreateLabelConfig = val ?? false);
                  },
                ),
              ],
            ),

            /// ✅ Numeric Length + Item Group Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    "Numeric Length",
                    controller: numericLengthController,
                  ),
                ),
                SizedBox(width: width * 0.03),
                Expanded(
                  child: _buildDropdown(context, "Item Group", _itemGroups, selectedItemGroup, (val) {
                    setState(() => selectedItemGroup = val);
                  }),
                ),
              ],
            ),

            SizedBox(height: height * 0.02),

            /// ✅ Remarks Full Width
            _buildTextField(context, "Remarks", controller: remarksController),

            //SizedBox(height: height * 0.03),
          ],
        ),
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
      }) {
    final width = MediaQuery.of(context).size.width;

    final isTablet = width > 700;
    final isDesktop = width >= 1000;

    double fontSize = isDesktop
        ? 16
        : isTablet
        ? 14
        : 13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LABEL WITH *
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

        // TEXTFIELD
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

            // 🔥 Number keyboard
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(
              decimal: true,
            )
                : TextInputType.text,

            // 🔥 Only numbers + decimal
            inputFormatters: isNumber
                ? [
                FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d*'),
              ),
            ]
                : null,

            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black,
            ),

            decoration: InputDecoration(
              hintText: hint ?? "Enter $label",
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
      Map<String, String> options, // value → label
      String? value,
      Function(String?) onChanged, {
        bool isRequired = false,
      }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                const TextSpan(
                  text: " *",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Container(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              /// value → per_netweight (map માં હોય તો જ)
              value: options.containsKey(value) ? value : null,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              dropdownColor: Colors.white,
              hint: Text(
                "Select $label",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 14 : 13,
                ),
              ),
              style: TextStyle(
                color: Colors.black,
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
              ),
              items: options.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                  value: e.key,          // save થાય: per_netweight
                  child: Text(e.value),  // દેખાય: Per Netweight
                ),
              )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }


  Future<void> create_item() async {

    /// 🔥 VALIDATION FIRST
    if (!validateFields()) return;
    try {
      final body = {
        "item_name": item_nameController.text.trim(),
        "item_code": item_codeController.text.trim(),
        "metal": selectedRole ?? "",
        "metal_formula": selectedmetal_formula ?? "",
        "outward_carat": OutwardController.text.trim(),
        "inward_carat": InwardController.text.trim(),
        "outward_purity": Outward_purity_Controller.text.trim(),
        "inward_purity": Inward_purity_Controller.text.trim(),
        "labour_type": selected_labour ?? "",
        "labour_unit": selected_labour_unit ?? "",
        "jobwork_item_type": selected_job_work ?? "",
        "hsn": HsnController.text.trim(),
        "export_hsn": Export_hsn_Controller.text.trim(),
        "numeric_length": numericLengthController.text.trim(),
        "item_group": selectedItemGroup ?? "",
        "remarks": remarksController.text.trim(),
        "auto_load_purity": autoLoadPurity ? 1 : 0,
        "auto_create_label_purchase": autoCreateLabelPurchase ? 1 : 0,
        "auto_create_label_config": autoCreateLabelConfig ? 1 : 0,
      };

      print("Login Request: $body");
      print("Login API URL: ${ApiConstants.create_item}");

      final response = await OfflineApiHelper.instance.postRequest(
        ApiConstants.create_item,
        body,
      );

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Login Response: $data");

      // ✅ SUCCESS
      if (response != null && response.statusCode == 200 ||
          response!.statusCode == 202) {

        if (response.statusCode == 202) {
          AppMessage.success(
            context,
            "No Internet. Update saved offline.",
          );
        }
        AppMessage.success(
          context,
          data["message"] ?? "Data Loaded Successfully",
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Itemscreen(),
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
        showError(data['message'] ?? "Server error (${response.statusCode})");
      }
    } catch (e) {
      print("Login Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  Future<void> update_item() async {
    try {
      final userId = widget.userData!["id"];
      final body = {
        "item_name": item_nameController.text.trim(),
        "item_code": item_codeController.text.trim(),
        "metal": selectedRole ?? "",
        "metal_formula": selectedmetal_formula ?? "",
        "outward_carat": OutwardController.text.trim(),
        "inward_carat": InwardController.text.trim(),
        "outward_purity": Outward_purity_Controller.text.trim(),
        "inward_purity": Inward_purity_Controller.text.trim(),
        "labour_type": selected_labour ?? "",
        "labour_unit": selected_labour_unit ?? "",
        "jobwork_item_type": selected_job_work ?? "",
        "hsn": HsnController.text.trim(),
        "export_hsn": Export_hsn_Controller.text.trim(),
        "numeric_length": numericLengthController.text.trim(),
        "item_group": selectedItemGroup ?? "",
        "remarks": remarksController.text.trim(),
        "auto_load_purity": autoLoadPurity ? 1 : 0,
        "auto_create_label_purchase": autoCreateLabelPurchase ? 1 : 0,
        "auto_create_label_config": autoCreateLabelConfig ? 1 : 0,
      };

      print("Update Item Request: $body");
      print("Update Item API URL: ${ApiConstants.create_users}");

      final response = await ApiHelper().putRequest(
        "${ApiConstants.update_items}/$userId",
        body,
      );

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Update User Response: $data");

      // ✅ SUCCESS
      if (response.statusCode == 200) {
        AppMessage.success(
          context,
          data["message"] ?? "Data Update Successfully",
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Itemscreen(),
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
        showError(data['message'] ?? "Server error (${response.statusCode})");
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.amberAccent,
        ),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black),
          ),
        ),
      ],
    );
  }


  bool validateFields() {
    if (item_nameController.text.trim().isEmpty) {
      showError("Item Name is required");
      return false;
    }

    if (item_codeController.text.trim().isEmpty) {
      showError("Item Code is required");
      return false;
    }

    if (selectedRole == null || selectedRole!.isEmpty) {
      showError("Please select Metal");
      return false;
    }

    if (selectedmetal_formula == null || selectedmetal_formula!.isEmpty) {
      showError("Please select Metal Formula");
      return false;
    }

    if (OutwardController.text.trim().isEmpty) {
      showError("Outward Carat is required");
      return false;
    }

    if (InwardController.text.trim().isEmpty) {
      showError("Inward Carat is required");
      return false;
    }


    return true; // ✅ All valid
  }

}


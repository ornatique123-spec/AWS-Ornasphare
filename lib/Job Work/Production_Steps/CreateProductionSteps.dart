import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pecifician_sysytem/Job%20Work/Labour_Formula/Job_labourformula_Screen.dart';
import 'package:pecifician_sysytem/User/UserScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/offline_api_helper.dart';
import 'ProoductionStepScreen.dart';


class Createproductionsteps extends StatefulWidget {
  final Map? userData;

  const Createproductionsteps({super.key, this.userData});

  @override
  State<Createproductionsteps> createState() => _CreateproductionstepsState();
}

class _CreateproductionstepsState extends State<Createproductionsteps> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController RemarksController = TextEditingController();


  bool get isEditMode => widget.userData != null;
  String? selectedRole = "Active";
  String? selected_labour_fprmula;
  String? selected_production_costs;
  DateTime? birthDate;
  DateTime? anniversaryDate;
  bool autoCreatePost = false;
  bool  recivebleloss = false;
  String? selectedLabourId;   // ✅ only ID
  String? selectedProductionId;    // ✅ ID mate
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).refreshLabourformula();
      Provider.of<ItemProvider>(context, listen: false).refreshProductioncosts();
    });

    if (isEditMode) {
      final user = widget.userData!;

      nameController.text = user["name"] ?? "tes";
      RemarksController.text = user["remarks"] ?? "";

      // selectedRole = user["status"];
      /// 🔥 FIX HERE
      bool isActive = user["status"] == true || user["status"].toString() == "1";

      selectedRole = isActive ? "Active" : "Inactive";

      /// ✅ DROPDOWN IDS (🔥 MOST IMPORTANT)
      selectedLabourId = user["labour_formula_id"]?.toString();
      selectedProductionId = user["production_cost_id"]?.toString();

      /// ✅ CHECKBOX
      autoCreatePost = user["auto_create_cost"] == true;
      recivebleloss = user["receivable_loss"] == true;

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
                        isEditMode?"Update Production Steps":"Save Production Steps",
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
                    "Create Production Steps",
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
                  "Production Steps ",
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
                    isRequired: true, // 🔥 SHOW *
                  ),
                ),





                Consumer<ItemProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    /// Selected Labour
                    Map<String, dynamic>? selectedLabour;

                    if (selectedLabourId != null) {
                      try {
                        selectedLabour = provider.labour_formula.firstWhere(
                              (e) => e["id"].toString() == selectedLabourId.toString(),
                        );
                      } catch (_) {
                        selectedLabour = null;
                      }
                    }

                    /// Selected Production Cost
                    Map<String, dynamic>? selectedProduction;

                    if (selectedProductionId != null) {
                      try {
                        selectedProduction = provider.Production_cost.firstWhere(
                              (e) => e["id"].toString() == selectedProductionId.toString(),
                        );
                      } catch (_) {
                        selectedProduction = null;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// ============================================
                        /// LABOUR FORMULA
                        /// ============================================
                        _dropdownLabel("Labour Formula"),

                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            PremiumItemSearchDropdown(
                              label: "", // 🔥 label upar bahar chhe
                              hint: "Select Labour Formula",
                              requiredField: true,
                              items: List<Map<String, dynamic>>.from(
                                provider.labour_formula,
                              ),
                              value: selectedLabour,
                              onChanged: (item) {
                                setState(() {
                                  if (item == null) {
                                    selectedLabourId = null;
                                    selected_labour_fprmula = null;
                                    return;
                                  }

                                  selectedLabourId = item["id"]?.toString();
                                  selected_labour_fprmula = item["name"]?.toString();

                                  print("Labour ID: $selectedLabourId");
                                  print("Labour Name: $selected_labour_fprmula");
                                });
                              },
                            ),

                            /// ❌ CLEAR
                            if (selectedLabour != null)
                              _clearIcon(() {
                                setState(() {
                                  selectedLabourId = null;
                                  selected_labour_fprmula = null;
                                });
                              }),
                          ],
                        ),

                        const SizedBox(height: 10),

                        /// ============================================
                        /// PRODUCTION COST
                        /// ============================================
                        _dropdownLabel("Production Cost"),

                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            PremiumItemSearchDropdown(
                              label: "",
                              hint: "Select Production Cost",
                              requiredField: true,
                              items: List<Map<String, dynamic>>.from(
                                provider.Production_cost,
                              ),
                              value: selectedProduction,
                              onChanged: (item) {
                                setState(() {
                                  if (item == null) {
                                    selectedProductionId = null;
                                    selected_production_costs = null;
                                    return;
                                  }

                                  selectedProductionId = item["id"]?.toString();
                                  selected_production_costs = item["name"]?.toString();

                                  print("Production ID: $selectedProductionId");
                                  print("Production Name: $selected_production_costs");
                                });
                              },
                            ),

                            /// ❌ CLEAR
                            if (selectedProduction != null)
                              _clearIcon(() {
                                setState(() {
                                  selectedProductionId = null;
                                  selected_production_costs = null;
                                });
                              }),
                          ],
                        ),

                        const SizedBox(height: 5),
                      ],
                    );
                  },
                ),


                _buildTextField(
                  context,
                  "Remarks",
                  controller: RemarksController,
                ),


                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCheckbox(
                      "Auto Create Cost",
                      autoCreatePost,
                          (val) {
                        setState(() => autoCreatePost = val ?? false);
                      },
                    ),

                    _buildCheckbox("Receivable Loss", recivebleloss, (val) {
                      setState(() => recivebleloss = val ?? false);
                    }),

                  ],
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
        bool isRequired = false, // 🔥 ADD THIS
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
                    child: Text(item["name"].toString()), // ✅ show name
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

    /// 🔴 VALIDATION
    if (nameController.text.trim().isEmpty) {
      showError("Name is required");
      return; // 🚫 STOP API CALL
    }

    if (selectedLabourId == null || selectedLabourId.toString().isEmpty) {
      showError("Please select labour formula");
      return;
    }

    if (selectedProductionId == null || selectedProductionId.toString().isEmpty) {
      showError("Please select production cost");
      return;
    }
    try {
      final body = {
        "name":nameController.text.trim(),
        "labour_formula_id":selectedLabourId,
        "receivable_loss":recivebleloss,
        "auto_create_cost":autoCreatePost,
        "production_cost_id":selectedProductionId,
        "remarks":RemarksController.text.trim(),
        "status": (selectedRole ?? "").toLowerCase() == "active" ? true : false,
      };

      print("Customer Request: $body");
      print("Customer API URL: ${ApiConstants.add_Production_steps}");

      final response =
      await OfflineApiHelper.instance.postRequest(ApiConstants.add_Production_steps, body);

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


        Navigator.pop(context,true);
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
        "labour_formula_id":selectedLabourId,
        "receivable_loss":recivebleloss,
        "auto_create_cost":autoCreatePost,
        "production_cost_id":selectedProductionId,
        "remarks":RemarksController.text.trim(),
        "status": (selectedRole ?? "").toLowerCase() == "active" ? true : false,
      };

      print("Update Customer Request: $body");
      print("Update Customer API URL: ${ApiConstants.Update_Production_steps}");

      final response = await ApiHelper()
          .putRequest("${ApiConstants.Update_Production_steps}/$userId", body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      print("Update Customer Response: $data");

      // ✅ SUCCESS
      if (response.statusCode == 200) {

        Navigator.pop(context,true);
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

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor:AppColors.border,
        ),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 🔹 Dropdown label (widget ni andar jevu j)
  Widget _dropdownLabel(String label, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (required)
            const Text(
              " *",
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  /// ❌ CLEAR ICON — dropdown ni andar, arrow ni dabi baju
  Widget _clearIcon(VoidCallback onClear) {
    return Positioned(
      right: 37, // 🔥 search icon ni upar aave — jarur mujab 35–42 karo
      top: 0,
      bottom: 0,
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            onClear();
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
    );
  }
}

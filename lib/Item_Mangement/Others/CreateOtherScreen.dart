import 'dart:ui';
import 'package:flutter/material.dart';
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
import 'Othersscreen.dart';

class Createotherscreen extends StatefulWidget {
  final Map? userData;

  const Createotherscreen({super.key, this.userData});

  @override
  State<Createotherscreen> createState() => _CreateotherscreenState();
}

class _CreateotherscreenState extends State<Createotherscreen> {
  final TextEditingController otherchargeController = TextEditingController();
  final TextEditingController other_codeController = TextEditingController();
  final TextEditingController other_amount_Controller = TextEditingController();
  final TextEditingController other_weight_Controller = TextEditingController();
  final TextEditingController other_qtypcs_Controller = TextEditingController();
  final TextEditingController other_weight_formula_Controller =
      TextEditingController();
  final TextEditingController other_weight_percentage_Controller =
      TextEditingController();
  final TextEditingController other_sale_weight_Controller =
      TextEditingController();
  final TextEditingController other_purchase_weight_Controller =
      TextEditingController();
  final TextEditingController other_charge_Controller = TextEditingController();
  final TextEditingController other_purchase_weight_p_Controller =
      TextEditingController();
  final TextEditingController other_amount_formula_Controller =
      TextEditingController();
  final TextEditingController other_required_purity_Controller =
      TextEditingController();
  final TextEditingController other_purity_Controller = TextEditingController();
  final TextEditingController other_sequence_no_Controller =
      TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  bool get isEditMode => widget.userData != null;
  bool autoLoadPurity = false;
  bool autoCreatediamond = false;
  bool autoCreateStone = false;
  bool autoCreate_stock_effect = false;
  bool autoCreate_party_effect = false;

  bool defaultSequence = false;
  bool selectedSequence = false;

  String? selectedItemGroup;

  String? selectedRole;
  String? selecte_weight_formula;
  String? selected_amount_formula;
  String? selected_labour;
  String? selected_wt_operation;
  String? selected_job_work;
  String? selected_merge_other_charge;
  DateTime? birthDate;
  DateTime? anniversaryDate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
    });

    if (isEditMode) {
      final user = widget.userData!;

      otherchargeController.text = user["other_charge"] ?? "";
      other_codeController.text = user["code"] ?? "";
      other_amount_Controller.text =  user["default_amount"]?.toString() ?? "";
      other_weight_Controller.text = user["default_weight"]?.toString() ?? "";
      other_qtypcs_Controller.text = user["quantity_pcs"]?.toString() ?? "";
      selecte_weight_formula = user["weight_formula"] ?? "";
      other_weight_percentage_Controller.text = user["weight_percent"]?.toString() ?? "";
      other_sale_weight_Controller.text = user["sale_weight_percent"] ?? "";
      other_purchase_weight_p_Controller.text =
          user["purchase_weight_percent"] ?? "";
      selected_amount_formula = user["other_amt_formula"] ?? "";
      remarksController.text = user["remarks"] ?? "";
      other_sequence_no_Controller.text = user["sequence_no"]?.toString() ?? "";
      other_charge_Controller.text = user["other_charge_ol"]?.toString() ?? "";
      other_purity_Controller.text = user["purity"] ?? "";
      other_required_purity_Controller.text = user["required_purity"] ?? "";

      selectedRole = user["item_id"].toString();
      selected_merge_other_charge = user["merge_other_charge"]?.toString();
      selected_wt_operation = user["wt_operation"];
      selected_labour = user["labour_type"];
      selected_job_work = user["jobwork_item_type"];
      selectedItemGroup = user["item_group"];
      defaultSequence = (user["is_default"] ?? 0).toString() == "1";
      selectedSequence = (user["is_selected"] ?? 0).toString() == "1";
      autoLoadPurity =
          (user["carat_weight_auto_conversion"] ?? 0).toString() == "1";
      autoCreatediamond = (user["diamond"] ?? 0).toString() == "1";
      autoCreateStone = (user["stone"] ?? 0).toString() == "1";
      autoCreate_stock_effect = (user["stock_effect"] ?? 0).toString() == "1";
      autoCreate_party_effect =
          (user["party_account_effect"] ?? 0).toString() == "1";
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false, // 🔥 IMPORTANT
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
                    margin: const EdgeInsets.only(left: 16,bottom: 16),
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
                        isEditMode
                            ? "Update Other Charge"
                            : "Save Other Charge",
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
                    "Create Other Charge",
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Othersscreen(),
                          ),
                        );
                      },
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

  /// ✅ Recent Scan List
  Widget _buildRecentScansList(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isTablet = width > 700;

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
            /// Title
            Text(
              "Create Other Charge",
              style: TextStyle(
                fontSize: isTablet ? width * 0.03 : width * 0.04,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            SizedBox(height: height * 0.01),

            Consumer<ItemProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const CircularProgressIndicator();
                }

                final List<Map<String, dynamic>> itemList =
                provider.items
                    .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e),
                )
                    .toList();

                Map<String, dynamic>? selectedItem;

                if (selectedRole != null &&
                    selectedRole!.isNotEmpty) {
                  try {
                    selectedItem = itemList.firstWhere(
                          (item) =>
                      item["id"]?.toString() ==
                          selectedRole,
                    );
                  } catch (_) {
                    selectedItem = null;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ITEM - ONLY DROPDOWN UI CHANGED
                    PremiumItemSearchDropdown(
                      label: "Item",
                      hint: "Select Item",
                      items: itemList,
                      value: selectedItem,
                      requiredField: true,
                      width: double.infinity,

                      onChanged: (item) {
                        setState(() {
                          selectedRole =
                              item?["id"]?.toString();
                        });
                      },
                    ),

                    const SizedBox(height: 5),


                    /// SAME AS YOUR OLD CODE
                    _buildTextField(
                      context,
                      "Other Charge",
                      controller: otherchargeController,
                      isRequired: true,
                    ),
                    SizedBox(height: height * 0.01),
                  ],
                );
              },
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
                      "Code",
                      controller: other_codeController,
                      isRequired: true, // 🔥 SHOW *
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Default Amount",
                      controller: other_amount_Controller,
                      isRequired: true, // 🔥 SHOW *
                      isNumber: true, // 🔥 NUMBER KEYBOARD
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
                      "Default Weight",
                      controller: other_weight_Controller,
                      isRequired: true, // 🔥 SHOW *
                      isNumber: true, // 🔥 NUMBER KEYBOARD
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Quantity Pcs",
                      controller: other_qtypcs_Controller,
                      isRequired: true, // 🔥 SHOW *
                      isNumber: true, // 🔥 NUMBER KEYBOARD
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
                    child: _buildDropdown(
                      context,
                      "Weight Formula",
                      ["Per Quntity", "Flat", "Per Weight"],
                      selecte_weight_formula,
                      (val) {
                        setState(() {
                          selecte_weight_formula = val;
                        });
                      },
                      isRequired: true, // 🔥 SHOW *
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Weight %",
                      controller: other_weight_percentage_Controller,
                      isRequired: true, // 🔥 SHOW *
                      isNumber: true, // 🔥 NUMBER KEYBOARD
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
                      "Sale Weight %",
                      controller: other_sale_weight_Controller,
                      isNumber: true, // 🔥 NUMBER KEYBOARD
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Purchase Weight %",
                      controller: other_purchase_weight_p_Controller,
                      isNumber: true, // 🔥 NUMBER KEYBOARD
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
                      "Other Charge OL",
                      controller: other_charge_Controller,
                      isNumber: true, // 🔥 NUMBER KEYBOARD
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildDropdown(
                      context,
                      "WT Operation",
                      ["Add", "Less"],
                      selected_wt_operation,
                      (val) {
                        setState(() {
                          selected_wt_operation = val;
                        });
                      },
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
                    child: _buildDropdown(
                      context,
                      "Other Amount Formula",
                      [
                        "Per Netweight",
                        "Per Fineweight",
                        "Per Grossweight",
                        "Per Quntity",
                        "Flat",
                      ],
                      selected_amount_formula,
                      (val) {
                        setState(() {
                          selected_amount_formula = val;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildTextField(
                      context,
                      "Required Purity",
                      controller: other_required_purity_Controller,
                      isNumber: true, // 🔥 NUMBER KEYBOARD
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
                      "Purity",
                      controller: other_purity_Controller,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Expanded(
                    child: _buildDropdown(
                      context,
                      "Merge Other Charge",
                      ["Per Quntity", "Flat"],
                      selected_merge_other_charge,
                      (val) {
                        setState(() {
                          selected_merge_other_charge = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: height * 0.005),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.01,
              ),
              child: Row(
                children: [
                  /// Sequence Field
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      context,
                      "Sequence No",
                      controller: other_sequence_no_Controller,
                    ),
                  ),

                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),

                  /// Checkboxes
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        /// Default
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: defaultSequence,
                                activeColor: const Color(0xffC9A44A),
                                onChanged: (val) {
                                  setState(() {
                                    defaultSequence = val ?? false;
                                  });
                                },
                              ),
                              const Text(
                                "Default",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        /// Selected
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: selectedSequence,
                                activeColor: const Color(0xffC9A44A),
                                onChanged: (val) {
                                  setState(() {
                                    selectedSequence = val ?? false;
                                  });
                                },
                              ),
                              const Text(
                                "Selected",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: height * 0.005),

            /// ✅ Checkboxes Row
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCheckbox(
                        "Carat Weight auto Conversion",
                        autoLoadPurity,
                        (val) {
                          setState(() => autoLoadPurity = val ?? false);
                        },
                      ),

                      _buildCheckbox("Diamond", autoCreatediamond, (val) {
                        setState(() => autoCreatediamond = val ?? false);
                      }),

                      _buildCheckbox("Stone", autoCreateStone, (val) {
                        setState(() => autoCreateStone = val ?? false);
                      }),

                      _buildCheckbox("Stock Effect", autoCreate_stock_effect, (
                          val,
                          ) {
                        setState(() => autoCreate_stock_effect = val ?? false);
                      }),

                      _buildCheckbox(
                        "Party Account Effect",
                        autoCreate_party_effect,
                            (val) {
                          setState(
                                () => autoCreate_party_effect = val ?? false,
                          );
                        },
                      ),
                    ],
                  ),
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
        bool isRequired = false, // 🔥 ADD THIS
        bool isNumber = false, // 🔥 ADD THIS
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
        /// 🔹 LABEL WITH *
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
            style: TextStyle(fontSize: fontSize, color: Colors.black),
            keyboardType:
            isNumber ? TextInputType.number : TextInputType.text, // 🔥 KEY
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
    List items,
    String? value,
      Function(String?) onChanged, {
        bool isRequired = false, // 🔥 ADD THIS
      }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
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
        SizedBox(height: screenHeight * 0.01),

        Container(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
          decoration: BoxDecoration(
            color:AppColors.background,
            border: Border.all(color: AppColors.border,width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:
                  items.any(
                    (item) => item is Map
                        ? item["id"].toString() == value
                        : item.toString() == value,
                  )
                  ? value
                  : null,

              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              dropdownColor: Colors.white, // 🔥 ADD THIS
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

              items: items.map<DropdownMenuItem<String>>((item) {
                /// API Map Data
                if (item is Map) {
                  return DropdownMenuItem<String>(
                    value: item["id"].toString(),
                    child: Text(item["item_name"] ?? ""),
                  );
                }
                /// Normal String List
                else {
                  return DropdownMenuItem<String>(
                    value: item.toString(),
                    child: Text(item.toString()),
                  );
                }
              }).toList(),

              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> create_item() async {
    /// 🔴 VALIDATION
    if (otherchargeController.text.trim().isEmpty) {
      showError("Other Charge Name is required");
      return;
    }

    /// 🔥 VALIDATION FIRST
    if (!validateFields()) return;
    try {
      final body = {
        "other_charge": otherchargeController.text.trim(),
        "code": other_codeController.text.trim(),
        "default_amount": other_amount_Controller.text.trim(),
        "default_weight": other_weight_Controller.text.trim(),
        "quantity_pcs": other_qtypcs_Controller.text.trim(),
        "weight_formula": selecte_weight_formula ?? "",
        "weight_percent": other_weight_percentage_Controller.text.trim(),
        "sale_weight_percent": other_sale_weight_Controller.text.trim(),
        "purchase_weight_percent": other_purchase_weight_p_Controller.text
            .trim(),
        "sequence_no": other_sequence_no_Controller.text.trim(),
        "item_id": selectedRole,
        "remarks": remarksController.text.trim(),
        "is_default": defaultSequence ? 1 : 0,
        "is_selected": selectedSequence ? 1 : 0,
        "diamond": autoCreatediamond ? 1 : 0,
        "stone": autoCreateStone ? 1 : 0,
        "stock_effect": autoCreate_stock_effect ? 1 : 0,
        "other_amt_formula": selected_amount_formula ?? "",
        "other_charge_ol": other_charge_Controller.text.trim(),
        "purity": other_purity_Controller.text.trim(),
        "required_purity": other_required_purity_Controller.text.trim(),
        "merge_other_charge": "no",
        "wt_operation": selected_wt_operation ?? "",
        "carat_weight_auto_conversion": autoLoadPurity ? 1 : 0,
        "party_account_effect": autoCreate_party_effect ? 1 : 0,
      };

      print("Login Request: $body");
      print("Login API URL: ${ApiConstants.add_others_charges}");

      final response = await OfflineApiHelper.instance.postRequest(
        ApiConstants.add_others_charges,
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
            builder: (_) => const Othersscreen(),
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
        "other_charge": otherchargeController.text.trim(),
        "code": other_codeController.text.trim(),
        "default_amount": other_amount_Controller.text.trim(),
        "default_weight": other_weight_Controller.text.trim(),
        "quantity_pcs": other_qtypcs_Controller.text.trim(),
        "weight_formula": selecte_weight_formula ?? "",
        "weight_percent": other_weight_percentage_Controller.text.trim(),
        "sale_weight_percent": other_sale_weight_Controller.text.trim(),
        "purchase_weight_percent": other_purchase_weight_p_Controller.text
            .trim(),
        "sequence_no": other_sequence_no_Controller.text.trim(),
        "item_id": selectedRole,
        "remarks": remarksController.text.trim(),
        "is_default": defaultSequence ? 1 : 0,
        "is_selected": selectedSequence ? 1 : 0,
        "diamond": autoCreatediamond ? 1 : 0,
        "stone": autoCreateStone ? 1 : 0,
        "stock_effect": autoCreate_stock_effect ? 1 : 0,
        "other_amt_formula": selected_amount_formula ?? "",
        "other_charge_ol": other_charge_Controller.text.trim(),
        "purity": other_purity_Controller.text.trim(),
        "required_purity": other_required_purity_Controller.text.trim(),
        "merge_other_charge": "no",
        "wt_operation": selected_wt_operation ?? "",
        "carat_weight_auto_conversion": autoLoadPurity ? 1 : 0,
        "party_account_effect": autoCreate_party_effect ? 1 : 0,
      };

      print("Update Item Request: $body");
      print("Update Item API URL: ${ApiConstants.update_other_charges}");

      final response = await ApiHelper().putRequest(
        "${ApiConstants.update_other_charges}/$userId",
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
            builder: (_) => const Othersscreen(),
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

  bool validateFields() {
    if (otherchargeController.text.trim().isEmpty) {
      showError("Other Charge required");
      return false;
    }

    if (other_codeController.text.trim().isEmpty) {
      showError("Code required");
      return false;
    }

    if (other_amount_Controller.text.trim().isEmpty) {
      showError("Default Amount required");
      return false;
    }

    if (other_weight_Controller.text.trim().isEmpty) {
      showError("Default Weight required");
      return false;
    }

    if (other_qtypcs_Controller.text.trim().isEmpty) {
      showError("Quantity required");
      return false;
    }

    if (selecte_weight_formula == null ||
        selecte_weight_formula!.isEmpty) {
      showError("Please select Weight Formula");
      return false;
    }

    if (other_weight_percentage_Controller.text.trim().isEmpty) {
      showError("Weight Percent required");
      return false;
    }

    if (selectedRole == null || selectedRole!.isEmpty) {
      showError("Please select Item");
      return false;
    }

    return true;
  }


}


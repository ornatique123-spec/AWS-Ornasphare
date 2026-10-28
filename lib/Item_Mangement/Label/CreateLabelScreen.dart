import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Extra/PremiumSearchableDropdown.dart';
import '../../Offline Data/offline_api_helper.dart';
import 'LabelScreen.dart';

class Createlabelscreen extends StatefulWidget {
  final Map? userData;

  const Createlabelscreen({super.key, this.userData});

  @override
  State<Createlabelscreen> createState() => _CreatelabelscreenState();
}

class _CreatelabelscreenState extends State<Createlabelscreen> {
  final TextEditingController prefixController = TextEditingController();
  final TextEditingController numericlengthController = TextEditingController();
  final TextEditingController lastnoController = TextEditingController();
  final TextEditingController minimum_no_Controller = TextEditingController();
  final TextEditingController max_no_Controller = TextEditingController();

  bool get isEditMode => widget.userData != null;

  String? selectedRole; // selected item id
  int? selectedItemId;

  bool _isSaving = false;

  /// =========================================================
  /// 🔥 LOCK — Labels બની ચૂક્યા છે (reuse = 1)
  /// Item / Prefix બદલી ના શકાય, Last No ફક્ત વધે
  /// =========================================================
  bool _isLocked = false;
  int _originalLastNo = 0;
  String? _originalItemId;
  String _originalPrefix = "";

  String _str(dynamic v) {
    final s = v?.toString().trim() ?? "";
    return s == "null" ? "" : s;
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
    });

    if (isEditMode) {
      final user = widget.userData!;

      prefixController.text = _str(user["prefix"]);
      numericlengthController.text = _str(user["numeric_length"]);
      lastnoController.text = _str(user["last_no"]);
      minimum_no_Controller.text = _str(user["min_no"]);
      max_no_Controller.text = _str(user["max_no"]);

      selectedRole = _str(user["item_id"]).isEmpty ? null : _str(user["item_id"]);
      selectedItemId = int.tryParse(selectedRole ?? "");

      /// 🔥 LOCK INFO
      _isLocked = user["reuse"]?.toString() == "1" || user["reuse"] == true;
      _originalLastNo = int.tryParse(_str(user["last_no"])) ?? 0;
      _originalItemId = selectedRole;
      _originalPrefix = _str(user["prefix"]);
    }
  }

  @override
  void dispose() {
    prefixController.dispose();
    numericlengthController.dispose();
    lastnoController.dispose();
    minimum_no_Controller.dispose();
    max_no_Controller.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          /// ✅ MAIN CONTENT
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 40),

              Expanded(
                child: SingleChildScrollView(
                  child: _buildForm(context),
                ),
              ),

              /// SAVE / UPDATE BUTTON
              InkWell(
                onTap: _isSaving
                    ? null
                    : () {
                  FocusManager.instance.primaryFocus?.unfocus();
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
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      isEditMode ? "Update Label" : "Save Label",
                      style: const TextStyle(
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
              color: AppColors.white,
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
                    isEditMode ? "Edit Label" : "Create Label",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      /// 🔥 FIX: નવી screen push નહીં, પાછા જાઓ
                      onTap: () => Navigator.pop(context),
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
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _buildForm(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TITLE
          Text(
            isEditMode ? "Edit Label Config" : "Add Label Config",
            style: TextStyle(
              fontSize: isTablet ? width * 0.03 : width * 0.04,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          SizedBox(height: height * 0.01),

          /// 🔥 LOCK NOTE
          if (_isLocked) _lockNote(),

          /// ITEM + PREFIX
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final List<Map<String, dynamic>> itemList = provider.items
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                  .toList();

              Map<String, dynamic>? selectedItem;

              if (selectedRole != null && selectedRole!.isNotEmpty) {
                for (final item in itemList) {
                  if (item["id"]?.toString() == selectedRole) {
                    selectedItem = item;
                    break;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ITEM — lock હોય તો બદલી ના શકાય
                  Stack(
                    children: [
                      IgnorePointer(
                        ignoring: _isLocked,
                        child: Opacity(
                          opacity: _isLocked ? 0.6 : 1,
                          child: PremiumItemSearchDropdown(
                            label: "Item",
                            hint: "Select Item",
                            items: itemList,
                            value: selectedItem,
                            requiredField: true,
                            width: double.infinity,
                            onChanged: (item) => _setItem(item),
                          ),
                        ),
                      ),

                      /// ❌ CLEAR — item select હોય અને lock ના હોય ત્યારે જ
                      if (selectedItem != null && !_isLocked)
                        Positioned(
                          right: 40, // 🔥 arrow થી અંતર — જરૂર મુજબ 32–48 કરો
                          bottom: 0,
                          child: SizedBox(
                            height: 48, // 🔥 dropdown box ની ઊંચાઈ જેટલું
                            child: Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _setItem(null);
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
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// PREFIX — lock હોય તો read-only
                  _buildTextField(
                    context,
                    "Prefix",
                    controller: prefixController,
                    isRequired: true,
                    readOnly: _isLocked,
                  ),

                  const SizedBox(height: 10),
                ],
              );
            },
          ),

          /// NUMERIC LENGTH + LAST NO
          Padding(
            padding: EdgeInsets.only(bottom: height * 0.01),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    "Numeric Length",
                    controller: numericlengthController,
                    isNumber: true,
                  ),
                ),
                SizedBox(width: width * 0.03),
                Expanded(
                  child: _buildTextField(
                    context,
                    "Last No",
                    controller: lastnoController,
                    isNumber: true,
                    helperText:
                    _isLocked ? "Minimum: $_originalLastNo" : null,
                  ),
                ),
              ],
            ),
          ),

          /// MIN NO + MAX NO
          Padding(
            padding: EdgeInsets.only(bottom: height * 0.01),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    "Min No",
                    controller: minimum_no_Controller,
                    isNumber: true,
                  ),
                ),
                SizedBox(width: width * 0.03),
                Expanded(
                  child: _buildTextField(
                    context,
                    "Max No",
                    controller: max_no_Controller,
                    isNumber: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCK NOTE
  // ============================================================

  Widget _lockNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Label items already created for this item. "
                  "Item and prefix cannot be changed. "
                  "Last No can only be increased.",
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
        bool readOnly = false,
        String? helperText,
      }) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;
    final isDesktop = width >= 1000;

    final double fontSize = isDesktop
        ? 16
        : isTablet
        ? 14
        : 13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// LABEL WITH *
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

        /// FIELD
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
            vertical: isTablet ? 4 : 2,
          ),
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade200 : AppColors.background,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            enableInteractiveSelection: !readOnly,
            style: TextStyle(
              fontSize: fontSize,
              color: readOnly ? Colors.black54 : Colors.black,
            ),
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              hintText: hint ?? "Enter $label",
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: fontSize,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: readOnly
                  ? const Icon(
                Icons.lock_outline,
                size: 16,
                color: Colors.black38,
              )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 24),
            ),
          ),
        ),

        /// HELPER TEXT (દા.ત. Minimum: 14)
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Map<String, dynamic> _buildBody() {
    return {
      /// 🔥 Lock હોય તો જૂનું Item / Prefix જ જાય
      "item_id": _isLocked ? _originalItemId : selectedRole,
      "prefix": _isLocked ? _originalPrefix : prefixController.text.trim(),
      "numeric_length": numericlengthController.text.trim(),
      "last_no": lastnoController.text.trim(),
      "reuse": true,
      "random": false,
      "min_no": minimum_no_Controller.text.trim(),
      "max_no": max_no_Controller.text.trim(),
      "from_date": _str(widget.userData?["from_date"]),
      "to_date": _str(widget.userData?["to_date"]),
    };
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<void> create_user() async {
    if (!validateFields()) return;

    setState(() => _isSaving = true);

    try {
      final body = _buildBody();
      debugPrint("📤 CREATE LABEL CONFIG => $body");

      final response = await OfflineApiHelper.instance.postRequest(
        ApiConstants.create_label_configs,
        body,
      );

      if (!mounted) return;

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("📥 CREATE RESPONSE => $data");

      /// ✅ SUCCESS / OFFLINE
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        AppMessage.success(
          context,
          response.statusCode == 202
              ? "No Internet. Update saved offline."
              : (data is Map ? data["message"]?.toString() : null) ??
              "Label config created successfully",
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Labelscreen()),
              (route) => route.isFirst,
        );
        return;
      }

      _handleError(response.statusCode, data);
    } catch (e) {
      debugPrint("❌ CREATE LABEL ERROR => $e");
      if (mounted) showError("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<void> update_user() async {
    if (!validateFields()) return;

    setState(() => _isSaving = true);

    try {
      final id = widget.userData!["id"];
      final body = _buildBody();
      debugPrint("📤 UPDATE LABEL CONFIG $id => $body");

      final response = await ApiHelper().putRequest(
        "${ApiConstants.update_label_configs}/$id",
        body,
      );

      if (!mounted) return;

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("📥 UPDATE RESPONSE => $data");

      /// ✅ SUCCESS
      if (response.statusCode == 200) {
        AppMessage.success(
          context,
          (data is Map ? data["message"]?.toString() : null) ??
              "Label config updated successfully",
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Labelscreen()),
              (route) => route.isFirst,
        );
        return;
      }

      _handleError(response.statusCode, data);
    } catch (e) {
      debugPrint("❌ UPDATE LABEL ERROR => $e");
      if (mounted) showError("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // ERROR HANDLER (401 / 422 / બીજા)
  // ============================================================

  void _handleError(int? statusCode, dynamic data) {
    final Map body = data is Map ? data : {};

    if (statusCode == 422 && body["errors"] is Map) {
      final String msg = (body["errors"] as Map)
          .values
          .map((v) => v is List ? v.first.toString() : v.toString())
          .join("\n");
      showError(msg);
      return;
    }

    showError(
      body["message"]?.toString() ?? "Server error ($statusCode)",
    );
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool validateFields() {
    if (selectedRole == null || selectedRole!.isEmpty) {
      showError("Please select Item");
      return false;
    }

    if (prefixController.text.trim().isEmpty) {
      showError("Prefix is required");
      return false;
    }

    /// 🔥 Lock હોય તો Last No જૂના number થી ઓછો ના થાય
    if (_isLocked) {
      final int newLastNo = int.tryParse(lastnoController.text.trim()) ?? -1;

      if (newLastNo < _originalLastNo) {
        showError("Last No cannot be less than $_originalLastNo");
        return false;
      }
    }

    /// Min / Max બંને હોય તો Min ≤ Max
    final int? minNo = int.tryParse(minimum_no_Controller.text.trim());
    final int? maxNo = int.tryParse(max_no_Controller.text.trim());

    if (minNo != null && maxNo != null && minNo > maxNo) {
      showError("Min No cannot be greater than Max No");
      return false;
    }

    return true;
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

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

  /// 🔥 Item select / clear
  void _setItem(Map? item) {
    setState(() {
      selectedRole = item?["id"]?.toString();
      selectedItemId = int.tryParse(item?["id"]?.toString() ?? "");
    });

    debugPrint("SELECTED ITEM ID => ${selectedRole ?? "CLEARED"}");
  }
}
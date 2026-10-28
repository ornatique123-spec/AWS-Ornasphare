import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pecifician_sysytem/Vacuum/Buch/BuchScreen.dart';
import 'package:provider/provider.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/ItemProvider.dart';
import '../../Offline Data/offline_api_helper.dart';

class Createbuchscreen extends StatefulWidget {
  final Map? userData;

  const Createbuchscreen({super.key, this.userData});

  @override
  State<Createbuchscreen> createState() => _CreatebuchscreenState();
}

class _CreatebuchscreenState extends State<Createbuchscreen> {
  bool get isEditMode => widget.userData != null;

  /// =========================================================
  /// 🔥 MINI FIELD SIZES — badha field ek j shape
  /// =========================================================
  static const double _miniLabelH = 15;
  static const double _miniGap = 4;
  static const double _miniBoxH = 40;

  /// 🔥 List of Rows (Buch No, Size, Weight)
  List<Map<String, dynamic>> searchResults = [];
  Map<String, TextEditingController> controllers = {};

  bool isSaving = false;

  /// 🔥 ➕ button thi navi row pachhi niche scroll karva
  final ScrollController _scrollController = ScrollController();

  /// 🔥 Darek row ni alag id
  int _rowCounter = 0;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
    });

    if (isEditMode) {
      final user = widget.userData!;
      searchResults = [
        {
          "id": "edit_${DateTime.now().microsecondsSinceEpoch}",
          "buch_no": user["buch_no"]?.toString() ?? "",
          "size_inch": user["size_inch"]?.toString() ?? "",
          "weight": user["weight"]?.toString() ?? "",
        }
      ];
    } else {
      /// 🔥 Default 10 empty rows
      searchResults = List.generate(10, (_) => _defaultItem());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _defaultItem() {
    return {
      "id": "${DateTime.now().microsecondsSinceEpoch}_${_rowCounter++}",
      "buch_no": "",
      "size_inch": "",
      "weight": "",
    };
  }

  bool _isFilled(Map item) =>
      (item["buch_no"] ?? "").toString().trim().isNotEmpty;

  int get _filledCount => searchResults.where(_isFilled).length;

  double get _totalWeight => searchResults.where(_isFilled).fold<double>(
    0,
        (sum, e) =>
    sum + (double.tryParse(e["weight"]?.toString() ?? "") ?? 0),
  );

  /// ➕ Blank row umero ane niche sudhi scroll karo
  void _addBlankRow() {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      searchResults.add(_defaultItem());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  TextEditingController getController(Map item, String key) {
    final uniqueKey = "${item["id"]}_$key";
    if (!controllers.containsKey(uniqueKey)) {
      controllers[uniqueKey] = TextEditingController(
        text: item[key]?.toString() ?? "",
      );
    }
    return controllers[uniqueKey]!;
  }

  /// Row delete thay tyare eni controllers pan saaf
  void _disposeRowControllers(Map item) {
    final String prefix = "${item["id"]}_";
    controllers.removeWhere((k, c) {
      if (k.startsWith(prefix)) {
        c.dispose();
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          /// ✅ Main Content
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 55),

                /// 🔥 SUMMARY
                _summaryCard(),

                /// 🔥 GRADIENT LINE
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

                const SizedBox(height: 5),

                _buildRows(),

                const SizedBox(height: 10),
              ],
            ),
          ),

          /// ✅ APPBAR (OVERLAY)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
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
                    isEditMode ? "Update Vacuum Buch" : "Create Vacuum Buch",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  /// ⬅️ BACK
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
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

                  /// ➕ NAVI BLANK ROW (fakt create mode)
                  if (!isEditMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: _addBlankRow,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.secondaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: isMobile ? 20 : 24,
                            color: Colors.white,
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

      /// ✅ FIXED BOTTOM: TOTAL + SAVE
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// TOTAL STRIP
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _bottomTotalItem("Buch", "$_filledCount"),
                    ),
                    _bottomDivider(),
                    Expanded(
                      child: _bottomTotalItem(
                        "Total Weight",
                        _totalWeight.toStringAsFixed(3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              /// SAVE / UPDATE
              InkWell(
                onTap: isSaving
                    ? null
                    : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (isEditMode) {
                    update_user();
                  } else {
                    create_user();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark,
                        AppColors.secondaryDark,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEditMode
                              ? Icons.check_circle_outline
                              : Icons.save_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditMode
                              ? "Update"
                              : _filledCount > 0
                              ? "Save ($_filledCount)"
                              : "Save",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// 🔥 SUMMARY CARD (upar)
  /// =========================================================
  Widget _summaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
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
      child: Row(
        children: [
          Expanded(
            child: _infoCard(
              title: "Rows",
              value: isEditMode
                  ? "1"
                  : "$_filledCount / ${searchResults.length}",
              icon: Icons.view_list_rounded,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _infoCard(
              title: "Total Weight",
              value: _totalWeight.toStringAsFixed(3),
              icon: Icons.scale_outlined,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 ROWS
  /// =========================================================
  Widget _buildRows() {
    if (searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text(
          "No Data Found",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 5),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final item = searchResults[index];
        return KeyedSubtree(
          key: ValueKey("buch_row_${item["id"]}"),
          child: buchItemCard(item, index),
        );
      },
    );
  }

  /// 🔥 Single Row Card — header + 3 field
  Widget buchItemCard(Map<String, dynamic> item, int index) {
    final bool filled = _isFilled(item);
    final String buchNo = (item["buch_no"] ?? "").toString().trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: filled
              ? AppColors.primaryDark.withOpacity(0.35)
              : AppColors.border,
        ),
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
          /// ================= HEADER =================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(filled ? 0.16 : 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                /// INDEX
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gradientBlue,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                /// BUCH NO TITLE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "BUCH NO",
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        filled ? buchNo : "New buch",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: filled ? Colors.black : Colors.black38,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                /// STATUS CHIP
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                    filled ? Colors.green.shade600 : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    filled ? "Filled" : "Empty",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// DELETE (edit mode ma nahi)
                if (!isEditMode) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (searchResults.length > 1) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => searchResults.removeAt(index));
                        _disposeRowControllers(item);
                      } else {
                        showError("At least 1 row is required");
                      }
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      width: 26,
                      height: 26,
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
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          /// ================= FIELDS =================
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _miniField(
                    "Buch No",
                    item,
                    "buch_no",
                    icon: Icons.tag_rounded,
                    isUpperCase: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _miniField(
                    "Size",
                    item,
                    "size_inch",
                    icon: Icons.straighten_rounded,
                    suffix: "in",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _miniField(
                    "Weight",
                    item,
                    "weight",
                    icon: Icons.scale_outlined,
                    suffix: "g",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 MINI FIELD — label 15 + gap 4 + box 40
  /// =========================================================
  Widget _miniField(
      String title,
      Map<String, dynamic> item,
      String key, {
        required IconData icon,
        String? suffix,
        bool isUpperCase = false,
      }) {
    final controller = getController(item, key);
    final bool isBuch = key == "buch_no";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _miniLabelH,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: _miniGap),
        Container(
          height: _miniBoxH,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 7),
              Icon(
                icon,
                size: 14,
                color: AppColors.primaryDark.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  textCapitalization: isUpperCase
                      ? TextCapitalization.characters
                      : TextCapitalization.none,

                  /// buch_no → letters + numbers, baaki → decimal
                  keyboardType: isBuch
                      ? TextInputType.visiblePassword
                      : const TextInputType.numberWithOptions(decimal: true),

                  /// size / weight → ek j "." + 3 decimal
                  inputFormatters: isBuch
                      ? null
                      : [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,3}'),
                    ),
                  ],

                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12.5,
                    fontWeight: isBuch ? FontWeight.w700 : FontWeight.w600,
                  ),
                  onChanged: (val) {
                    item[key] = val;

                    // 🔥 Fakt CREATE mode ma: last row ma lakhay to navi row
                    final int currentIndex =
                    searchResults.indexWhere((e) => e["id"] == item["id"]);

                    if (!isEditMode &&
                        currentIndex != -1 &&
                        currentIndex == searchResults.length - 1 &&
                        val.trim().isNotEmpty) {
                      setState(() {
                        searchResults.add(_defaultItem());
                      });
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isBuch ? "B-101" : "0.000",
                    hintStyle: const TextStyle(
                      color: Colors.black26,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 7, left: 2),
                  child: Text(
                    suffix,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomTotalItem(String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _bottomDivider() {
    return Container(width: 1, height: 35, color: Colors.grey.shade300);
  }

  /// =========================================================
  /// ✅ CREATE — Multiple rows
  /// =========================================================
  Future<void> create_user() async {
    if (!validateFields()) return;

    setState(() => isSaving = true);

    try {
      final List<Map<String, dynamic>> rowsList =
      searchResults.where(_isFilled).map((item) {
        return {
          "buch_no": item["buch_no"].toString().trim(),
          "size_inch":
          double.tryParse(item["size_inch"].toString().trim()) ?? 0,
          "weight": double.tryParse(item["weight"].toString().trim()) ?? 0,
        };
      }).toList();

      final body = {"rows": rowsList};

      debugPrint("Create Buch Request => $body");

      final response = await OfflineApiHelper.instance.postRequest(
        ApiConstants.vacuum_buchs,
        body,
      );

      if (!mounted) return;
      setState(() => isSaving = false);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("Create Buch Response: $data");

      final String? message =
      data is Map ? data["message"]?.toString() : null;

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        if (response.statusCode == 202) {
          AppMessage.success(context, "No Internet. Update saved offline.");
        } else {
          AppMessage.success(context, message ?? "Data Updated Successfully");
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Buchscreen()),
              (route) => route.isFirst,
        );
      } else if (response.statusCode == 401) {
        showError(message ?? "Invalid credentials");
      } else if (response.statusCode == 422) {
        showError(_validationMessage(data));
      } else {
        showError(message ?? "Server error (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      debugPrint("Create Buch Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  /// =========================================================
  /// ✅ UPDATE — Single row
  /// =========================================================
  Future<void> update_user() async {
    if (!validateFields()) return;

    setState(() => isSaving = true);

    try {
      final userId = widget.userData!["id"];
      final item = searchResults.first;

      final body = {
        "buch_no": item["buch_no"].toString().trim(),
        "size_inch": item["size_inch"].toString().trim(),
        "weight": item["weight"].toString().trim(),
      };

      debugPrint("Update Buch Request => $body");

      final response = await ApiHelper().putRequest(
        "${ApiConstants.vacuum_buchs}/$userId",
        body,
      );

      if (!mounted) return;
      setState(() => isSaving = false);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("Update Buch Response: $data");

      final String? message =
      data is Map ? data["message"]?.toString() : null;

      if (response.statusCode == 200) {
        AppMessage.success(context, message ?? "Data Updated Successfully");

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Buchscreen()),
              (route) => route.isFirst,
        );
      } else if (response.statusCode == 401) {
        showError(message ?? "Invalid credentials");
      } else if (response.statusCode == 422) {
        showError(_validationMessage(data));
      } else {
        showError(message ?? "Server error (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      debugPrint("Update Buch Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  /// 422 validation errors → ek message
  String _validationMessage(dynamic data) {
    if (data is Map && data["errors"] is Map) {
      return (data["errors"] as Map)
          .values
          .map((v) =>
      v is List && v.isNotEmpty ? v.first.toString() : v.toString())
          .join("\n");
    }
    if (data is Map && data["message"] != null) {
      return data["message"].toString();
    }
    return "Validation error";
  }

  void showError(String? message) {
    if (!mounted) return;
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

  /// 🔥 Submit pehla check
  bool validateFields() {
    if (_filledCount == 0) {
      showError("Please fill at least 1 row");
      return false;
    }
    return true;
  }
}

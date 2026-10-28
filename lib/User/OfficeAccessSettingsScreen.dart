import 'package:flutter/material.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';

class OfficeAccessSettingsScreen extends StatefulWidget {
  const OfficeAccessSettingsScreen({super.key});

  @override
  State<OfficeAccessSettingsScreen> createState() =>
      _OfficeAccessSettingsScreenState();
}

class _OfficeAccessSettingsScreenState
    extends State<OfficeAccessSettingsScreen> {
  /// ============================================
  /// STATE
  /// ============================================

  String radiusCheck = "Disable";
  String approvedDeviceCheck = "Enable";
  String emergencyOverride = "Disable";

  bool isLoading = false;
  bool isSaving = false;

  /// ============================================
  /// CONTROLLERS
  /// ============================================

  final TextEditingController latitudeController = TextEditingController(
    text: "23.0492348",
  );

  final TextEditingController longitudeController = TextEditingController(
    text: "72.5800721",
  );

  final TextEditingController radiusController = TextEditingController(
    text: "10",
  );

  final TextEditingController overrideUntilController = TextEditingController();

  final TextEditingController reasonController = TextEditingController();

  /// ============================================
  /// INIT
  /// ============================================

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await loadOfficeAccessSettings();
    });
  }

  /// ============================================
  /// GET OFFICE SETTINGS
  /// ============================================

  Future<void> loadOfficeAccessSettings() async {
    if (isLoading) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await ApiHelper().getRequest(
        ApiConstants.officeAccessSettings,
        showLoading: false,
      );

      debugPrint("==========================================");

      debugPrint(
        "OFFICE SETTINGS GET STATUS => "
        "${response?.statusCode}",
      );

      debugPrint(
        "OFFICE SETTINGS GET RESPONSE => "
        "${response?.data}",
      );

      debugPrint("==========================================");

      if (!mounted) {
        return;
      }

      /// ========================================
      /// SUCCESS
      /// ========================================

      if (response != null && response.statusCode == 200) {
        final dynamic responseData = response.data;

        if (responseData is Map) {
          /// API success false hoy
          if (responseData["success"] == false) {
            _setDefaultLocation();
            return;
          }

          final dynamic rawData = responseData["data"];

          if (rawData is Map) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              rawData,
            );

            debugPrint("OFFICE SETTINGS DATA => $data");

            setState(() {
              /// ==================================
              /// OFFICE RADIUS CHECK
              /// ==================================

              radiusCheck = _toBool(data["geo_enabled"]) ? "Enable" : "Disable";

              /// ==================================
              /// APPROVED DEVICE CHECK
              /// ==================================

              approvedDeviceCheck = _toBool(data["device_approval_enabled"])
                  ? "Enable"
                  : "Disable";

              /// ==================================
              /// LATITUDE
              /// ==================================

              final String latitude =
                  data["office_latitude"]?.toString().trim() ?? "";

              latitudeController.text = latitude.isNotEmpty
                  ? latitude
                  : "23.0492348";

              /// ==================================
              /// LONGITUDE
              /// ==================================

              final String longitude =
                  data["office_longitude"]?.toString().trim() ?? "";

              longitudeController.text = longitude.isNotEmpty
                  ? longitude
                  : "72.5800721";

              /// ==================================
              /// ALLOWED RADIUS
              /// ==================================

              final String radius =
                  data["allowed_radius_meters"]?.toString().trim() ?? "";

              radiusController.text = radius.isNotEmpty ? radius : "10";

              /// ==================================
              /// EMERGENCY OVERRIDE
              /// ==================================

              if (data.containsKey("emergency_override")) {
                emergencyOverride = _toBool(data["emergency_override"])
                    ? "Enable"
                    : "Disable";
              }

              /// ==================================
              /// OVERRIDE UNTIL
              /// ==================================

              if (data.containsKey("override_until")) {
                overrideUntilController.text =
                    data["override_until"]?.toString() ?? "";
              }

              /// ==================================
              /// REASON
              /// ==================================

              if (data.containsKey("reason")) {
                reasonController.text = data["reason"]?.toString() ?? "";
              }
            });

            return;
          }
        }
      }

      /// ========================================
      /// NO DATA / INVALID RESPONSE
      /// ========================================

      _setDefaultLocation();
    } catch (e, stackTrace) {
      debugPrint("OFFICE SETTINGS GET ERROR => $e");

      debugPrint(
        "OFFICE SETTINGS GET STACK => "
        "$stackTrace",
      );

      if (!mounted) {
        return;
      }

      _setDefaultLocation();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// ============================================
  /// DEFAULT LOCATION
  /// ============================================

  void _setDefaultLocation() {
    if (!mounted) {
      return;
    }

    setState(() {
      latitudeController.text = "23.0492348";

      longitudeController.text = "72.5800721";

      if (radiusController.text.trim().isEmpty) {
        radiusController.text = "10";
      }
    });
  }

  /// ============================================
  /// BOOL CONVERTER
  /// ============================================

  bool _toBool(dynamic value) {
    if (value == true) {
      return true;
    }

    if (value == false) {
      return false;
    }

    final String text = value?.toString().trim().toLowerCase() ?? "";

    return text == "1" ||
        text == "true" ||
        text == "enable" ||
        text == "enabled" ||
        text == "yes";
  }

  /// ============================================
  /// SELECT DATE + TIME
  /// ============================================

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final DateTime selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    overrideUntilController.text =
        "${selectedDateTime.day.toString().padLeft(2, '0')}/"
        "${selectedDateTime.month.toString().padLeft(2, '0')}/"
        "${selectedDateTime.year} "
        "${pickedTime.format(context)}";
  }

  /// ============================================
  /// BUILD
  /// ============================================

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    final bool isMobile = size.width < 700;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) =>
        //     const HomeScreen(),
        //   ),
        // );

        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            /// ==================================
            /// MAIN BODY
            /// ==================================
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 65),

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 14 : 22),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
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
                                /// ==================
                                /// SECURITY
                                /// ==================
                                _sectionTitle("Worker App Security"),

                                const SizedBox(height: 18),

                                /// ==================
                                /// CHECKS
                                /// ==================
                                if (isMobile)
                                  Column(
                                    children: [
                                      _dropdownField(
                                        title: "Office Radius Check",
                                        value: radiusCheck,
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }

                                          setState(() {
                                            radiusCheck = value;
                                          });
                                        },
                                      ),

                                      const SizedBox(height: 14),

                                      _dropdownField(
                                        title: "Approved Device Check",
                                        value: approvedDeviceCheck,
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }

                                          setState(() {
                                            approvedDeviceCheck = value;
                                          });
                                        },
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _dropdownField(
                                          title: "Office Radius Check",
                                          value: radiusCheck,
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }

                                            setState(() {
                                              radiusCheck = value;
                                            });
                                          },
                                        ),
                                      ),

                                      const SizedBox(width: 30),

                                      Expanded(
                                        child: _dropdownField(
                                          title: "Approved Device Check",
                                          value: approvedDeviceCheck,
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }

                                            setState(() {
                                              approvedDeviceCheck = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 24),

                                /// ==================
                                /// LAT / LNG
                                /// ==================
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _textField(
                                        title: "Office Latitude",
                                        controller: latitudeController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        readOnly: true,
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: _textField(
                                        title: "Office Longitude",
                                        controller: longitudeController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        readOnly: true,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                /// ==================
                                /// RADIUS
                                /// ==================
                                _textField(
                                  title: "Allowed Radius Meter",
                                  controller: radiusController,
                                  keyboardType: TextInputType.number,
                                  readOnly: true,
                                ),

                                const SizedBox(height: 28),

                                /// ==================
                                /// EMERGENCY
                                /// ==================
                                _sectionTitle("Emergency Override"),

                                const SizedBox(height: 18),

                                if (isMobile)
                                  Column(
                                    children: [
                                      _dropdownField(
                                        title: "Emergency Override",
                                        value: emergencyOverride,
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }

                                          setState(() {
                                            emergencyOverride = value;
                                          });
                                        },
                                      ),

                                      const SizedBox(height: 14),

                                      _dateField(),

                                      const SizedBox(height: 14),

                                      _textField(
                                        title: "Reason",
                                        controller: reasonController,
                                        hint: "Emergency reason",
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _dropdownField(
                                          title: "Emergency Override",
                                          value: emergencyOverride,
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }

                                            setState(() {
                                              emergencyOverride = value;
                                            });
                                          },
                                        ),
                                      ),

                                      const SizedBox(width: 20),

                                      Expanded(child: _dateField()),

                                      const SizedBox(width: 20),

                                      Expanded(
                                        child: _textField(
                                          title: "Reason",
                                          controller: reasonController,
                                          hint: "Emergency reason",
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 28),

                                /// ==================
                                /// INFO
                                /// ==================
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.lightBlue.shade100,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: AppColors.primaryDark,
                                      ),

                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Text(
                                          "Admin users can use the system anywhere. "
                                          "These rules apply to worker mobile app APIs only.",
                                          style: TextStyle(
                                            color: AppColors.primaryDark,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 22),

                                /// ==================
                                /// SAVE
                                /// ==================
                                InkWell(
                                  onTap: isSaving
                                      ? null
                                      : () async {
                                          await saveSettings();
                                        },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryDark.withOpacity(
                                            0.85,
                                          ),
                                          AppColors.secondaryDark.withOpacity(
                                            0.85,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: isSaving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              "Save Settings",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),

            /// ==================================
            /// APPBAR
            /// ==================================
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
                color: AppColors.white,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      "Office Access Settings",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          // Navigator.pushReplacement(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (_) => const HomeScreen(),
                          //   ),
                          // );
                          Navigator.pop(context,true);
                        },
                        borderRadius: BorderRadius.circular(8),
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

  /// ============================================
  /// SECTION TITLE
  /// ============================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// ============================================
  /// DROPDOWN
  /// ============================================

  Widget _dropdownField({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 7),

        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primaryDark),
          style: const TextStyle(color: Colors.black, fontSize: 13),
          decoration: _inputDecoration(),
          items: const [
            DropdownMenuItem<String>(value: "Enable", child: Text("Enable")),
            DropdownMenuItem<String>(value: "Disable", child: Text("Disable")),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// ============================================
  /// TEXT FIELD
  /// ============================================

  Widget _textField({
    required String title,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? Colors.grey.shade700 : Colors.black,
            fontSize: 13,
            fontWeight: readOnly ? FontWeight.w500 : FontWeight.normal,
          ),
          decoration: _inputDecoration(hint: hint).copyWith(
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            suffixIcon: readOnly
                ? Icon(
                    Icons.lock_outline,
                    size: 17,
                    color: Colors.grey.shade500,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /// ============================================
  /// DATE FIELD
  /// ============================================

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Override Until",
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: overrideUntilController,
          readOnly: true,
          onTap: _selectDateTime,
          style: const TextStyle(color: Colors.black, fontSize: 13),
          decoration: _inputDecoration(hint: "dd/mm/yyyy, --:-- --").copyWith(
            suffixIcon: Icon(
              Icons.calendar_month,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }

  /// ============================================
  /// INPUT DECORATION
  /// ============================================

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.primaryDark, width: 1.3),
      ),
    );
  }

  /// ============================================
  /// SAVE SETTINGS
  /// ============================================

  Future<void> saveSettings() async {
    if (isSaving) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final double? latitude = double.tryParse(latitudeController.text.trim());

    final double? longitude = double.tryParse(longitudeController.text.trim());

    final int? radius = int.tryParse(radiusController.text.trim());

    /// ========================================
    /// VALIDATION
    /// ========================================

    if (latitude == null) {
      _showMessage("Invalid office latitude", isError: true);
      return;
    }

    if (longitude == null) {
      _showMessage("Invalid office longitude", isError: true);
      return;
    }

    if (radius == null || radius <= 0) {
      _showMessage("Please enter valid allowed radius", isError: true);
      return;
    }

    /// ========================================
    /// BODY
    /// ========================================

    final Map<String, dynamic> body = {
      "geo_enabled": radiusCheck == "Enable",

      "device_approval_enabled": approvedDeviceCheck == "Enable",

      "office_latitude": latitude,

      "office_longitude": longitude,

      "allowed_radius_meters": radius,
    };

    debugPrint("==========================================");

    debugPrint("OFFICE ACCESS SETTINGS REQUEST => $body");

    debugPrint("==========================================");

    setState(() {
      isSaving = true;
    });

    try {
      final response = await ApiHelper().postRequest(
        ApiConstants.officeAccessSettings,
        body,
      );

      debugPrint(
        "OFFICE SETTINGS STATUS => "
        "${response?.statusCode}",
      );

      debugPrint(
        "OFFICE SETTINGS RESPONSE => "
        "${response?.data}",
      );

      if (!mounted) {
        return;
      }

      /// ======================================
      /// SUCCESS
      /// ======================================

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        String message = "Settings saved successfully";

        final dynamic responseData = response.data;

        if (responseData is Map && responseData["message"] != null) {
          message = responseData["message"].toString();
        }

        _showMessage(message);

        return;
      }

      /// ======================================
      /// API ERROR
      /// ======================================

      String message = "Unable to save office access settings";

      final dynamic responseData = response?.data;

      if (responseData is Map && responseData["message"] != null) {
        message = responseData["message"].toString();
      }

      _showMessage(message, isError: true);
    } catch (e, stackTrace) {
      debugPrint("OFFICE SETTINGS SAVE ERROR => $e");

      debugPrint(
        "OFFICE SETTINGS SAVE STACK => "
        "$stackTrace",
      );

      if (!mounted) {
        return;
      }

      _showMessage("Something went wrong. Please try again.", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  /// ============================================
  /// MESSAGE
  /// ============================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  /// ============================================
  /// DISPOSE
  /// ============================================

  @override
  void dispose() {
    latitudeController.dispose();
    longitudeController.dispose();
    radiusController.dispose();
    overrideUntilController.dispose();
    reasonController.dispose();

    super.dispose();
  }
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';

/// ================================================================
/// 🔳 ADD / EDIT QR — ERP THEME
///
/// - AddQrScreen()                 → navo QR  (POST qr-making)
/// - AddQrScreen(qrData: item)     → edit QR  (PUT  qr-making/{id})
/// - Preview QR → app ma j turant QR dekhay (API call vagar)
/// - Phone: form niche preview | Tab: form dabi baju, preview jamni baju
/// ================================================================

class AddQrScreen extends StatefulWidget {
  /// List mathi Edit dabavo tyare aakho item aave
  final Map<String, dynamic>? qrData;

  const AddQrScreen({super.key, this.qrData});

  @override
  State<AddQrScreen> createState() => _AddQrScreenState();
}

class _AddQrScreenState extends State<AddQrScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController webUrlController = TextEditingController();
  final TextEditingController androidUrlController = TextEditingController();
  final TextEditingController iosUrlController = TextEditingController();

  // ============================================================
  // OPTIONS
  // ============================================================

  static const List<Map<String, dynamic>> sizeOptions = [
    {"value": 250, "label": "Small (250px)"},
    {"value": 350, "label": "Medium (350px)"},
    {"value": 500, "label": "Large (500px)"},
    {"value": 1000, "label": "Extra Large (1000px)"},
  ];

  static const List<Map<String, String>> typeOptions = [
    {"value": "web", "label": "Web"},
    {"value": "app", "label": "App"},
  ];

  static const List<Map<String, dynamic>> logoOptions = [
    {"value": 0, "label": "Without Logo"},
    {"value": 1, "label": "With Logo"},
  ];

  int selectedSize = 250;
  String selectedType = "web";
  int withLogo = 0;

  /// Navo select karelo logo
  File? logoFile;

  /// Edit vakhte server par pehlathi rahelo logo
  String? existingLogo; // path ke url
  bool removeExistingLogo = false;

  // ============================================================
  // PREVIEW / SAVE STATE
  // ============================================================

  String? previewData; // QR ma shu encode thashe
  bool isSaving = false;
  String? savedQrUrl; // API thi aavelo final QR image

  // ============================================================
  // EDIT MODE
  // ============================================================

  bool get isEdit => widget.qrData != null;

  int get editId =>
      int.tryParse(widget.qrData?["id"]?.toString() ?? "") ?? 0;

  /// Juno logo haju vaparvano che?
  bool get _keepExistingLogo =>
      isEdit &&
          logoFile == null &&
          !removeExistingLogo &&
          (existingLogo?.isNotEmpty ?? false);

  /// Juno logo http link hoy to j preview ma dekhay
  String? get _existingLogoUrl =>
      (existingLogo != null && existingLogo!.startsWith("http"))
          ? existingLogo
          : null;

  @override
  void initState() {
    super.initState();
    _fillEditData();
  }

  void _fillEditData() {
    final Map<String, dynamic>? d = widget.qrData;
    if (d == null) return;

    String v(List<String> keys) {
      for (final k in keys) {
        final s = d[k]?.toString().trim() ?? "";
        if (s.isNotEmpty && s != "null") return s;
      }
      return "";
    }

    titleController.text = v(["title", "name"]);

    final String type = v(["type", "qr_type"]).toLowerCase();
    selectedType = type == "app" ? "app" : "web";

    final int size = int.tryParse(v(["size", "qr_size"]).replaceAll("px", "")) ?? 250;
    selectedSize =
    sizeOptions.any((e) => e["value"] == size) ? size : 250;

    final dynamic wl = d["with_logo"];
    withLogo = (wl == true || wl?.toString() == "1" || wl?.toString() == "true")
        ? 1
        : 0;

    webUrlController.text = v(["web_url", "web_link", "url"]);
    androidUrlController.text = v(["android_url"]);
    iosUrlController.text = v(["ios_url"]);

    final String logo = v(["logo_url", "logo_path", "logo"]);
    existingLogo = logo.isEmpty ? null : logo;

    /// Edit khulta j preview dekhay
    final String encoded = _buildEncodedData();
    if (encoded.isNotEmpty) previewData = encoded;
  }

  @override
  void dispose() {
    titleController.dispose();
    webUrlController.dispose();
    androidUrlController.dispose();
    iosUrlController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 700;

                  if (isWide) {
                    /// TAB — form + preview side by side
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _buildFormCard()),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: _buildPreviewCard()),
                        ],
                      ),
                    );
                  }

                  /// PHONE — form upar, preview niche
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      children: [
                        _buildFormCard(),
                        const SizedBox(height: 12),
                        _buildPreviewCard(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context, true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEdit ? "Edit QR" : "Add QR",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 15,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 4),
                Text(
                  selectedType == "web" ? "Web QR" : "App QR",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
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
  // FORM CARD
  // ============================================================

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              isEdit ? Icons.edit_rounded : Icons.edit_note_rounded,
              isEdit ? "Update QR Details" : "QR Details",
            ),
            const SizedBox(height: 12),

            /// TITLE
            _label("Title"),
            _textField(
              controller: titleController,
              hint: "Enter QR title",
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? "Title is required" : null,
            ),

            const SizedBox(height: 14),

            /// QR SIZE
            _label("QR Size"),
            _dropdown<int>(
              value: selectedSize,
              items: sizeOptions
                  .map((e) => DropdownMenuItem<int>(
                value: e["value"] as int,
                child: Text(e["label"] as String),
              ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => selectedSize = v);
              },
            ),
            if (selectedSize <= 250)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Very small codes can be difficult to scan, especially with a logo. Test at the final printed size.",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.orange.shade800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            /// QR TYPE
            _label("QR Type"),
            _dropdown<String>(
              value: selectedType,
              items: typeOptions
                  .map((e) => DropdownMenuItem<String>(
                value: e["value"],
                child: Row(
                  children: [
                    Icon(
                      e["value"] == "web"
                          ? Icons.language_rounded
                          : Icons.phone_android_rounded,
                      size: 17,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(e["label"]!),
                  ],
                ),
              ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  selectedType = v;
                  previewData = null;
                  savedQrUrl = null;
                });
              },
            ),

            const SizedBox(height: 14),

            /// LINKS — type pramane
            if (selectedType == "web") ...[
              _label("Web Link"),
              _textField(
                controller: webUrlController,
                hint: "https://example.com",
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link_rounded,
                validator: _urlValidator,
              ),
            ] else ...[
              _label("Android URL"),
              _textField(
                controller: androidUrlController,
                hint: "https://play.google.com/store/apps/details?id=...",
                keyboardType: TextInputType.url,
                prefixIcon: Icons.android_rounded,
                validator: _urlValidator,
              ),
              const SizedBox(height: 14),
              _label("iOS URL"),
              _textField(
                controller: iosUrlController,
                hint: "https://apps.apple.com/app/id...",
                keyboardType: TextInputType.url,
                prefixIcon: Icons.apple_rounded,
                validator: _urlValidator,
              ),
            ],

            const SizedBox(height: 14),

            /// LOGO OPTION
            _label("Logo Option"),
            _dropdown<int>(
              value: withLogo,
              items: logoOptions
                  .map((e) => DropdownMenuItem<int>(
                value: e["value"] as int,
                child: Text(e["label"] as String),
              ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  withLogo = v;
                  if (v == 0) logoFile = null;
                });
              },
            ),

            /// LOGO PICKER
            if (withLogo == 1) ...[
              const SizedBox(height: 10),
              _buildLogoPicker(),
            ],

            const SizedBox(height: 20),

            /// BUTTONS
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: "Preview QR",
                    icon: Icons.visibility_outlined,
                    filled: false,
                    onTap: _onPreview,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    label: isSaving
                        ? (isEdit ? "Updating..." : "Saving...")
                        : (isEdit ? "Update QR" : "Save QR"),
                    icon: Icons.save_rounded,
                    filled: true,
                    loading: isSaving,
                    onTap: isSaving ? null : _onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGO PICKER
  // ============================================================

  Widget _buildLogoPicker() {
    final bool hasNew = logoFile != null;
    final bool hasOld = _keepExistingLogo;

    Widget thumb() {
      if (hasNew) return Image.file(logoFile!, fit: BoxFit.cover);
      if (hasOld && _existingLogoUrl != null) {
        return Image.network(
          _existingLogoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.image_outlined,
            color: AppColors.primaryDark,
          ),
        );
      }
      if (hasOld) {
        return const Icon(Icons.image_outlined, color: AppColors.primaryDark);
      }
      return const Icon(
        Icons.add_photo_alternate_outlined,
        color: AppColors.primaryDark,
      );
    }

    final String titleText = hasNew
        ? "New logo selected"
        : hasOld
        ? "Current logo"
        : "Select Logo";

    final String subText = hasNew
        ? logoFile!.path.split(Platform.pathSeparator).last
        : hasOld
        ? "Tap to change logo"
        : "Square PNG / JPG works best";

    return InkWell(
      onTap: _pickLogo,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (hasNew || hasOld)
                ? AppColors.border
                : AppColors.primaryDark.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: thumb(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (hasNew || hasOld)
              IconButton(
                onPressed: () {
                  setState(() {
                    if (hasNew) {
                      logoFile = null;
                    } else {
                      removeExistingLogo = true;
                    }
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.red.shade600,
                ),
              )
            else
              const Icon(
                Icons.upload_rounded,
                color: AppColors.primaryDark,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 800,
      );

      if (picked == null) return;

      setState(() {
        logoFile = File(picked.path);
        if (previewData != null) {
          previewData = _buildEncodedData();
        }
      });
    } catch (e) {
      debugPrint("Logo pick error: $e");
      if (mounted) AppMessage.error(context, "Logo select na thai shakyo");
    }
  }

  // ============================================================
  // PREVIEW CARD
  // ============================================================

  Widget _buildPreviewCard() {
    /// Preview ma logo — navo file, nahi to juno network logo
    ImageProvider? logoImage;
    if (withLogo == 1) {
      if (logoFile != null) {
        logoImage = FileImage(logoFile!);
      } else if (_keepExistingLogo && _existingLogoUrl != null) {
        logoImage = NetworkImage(_existingLogoUrl!);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(Icons.qr_code_scanner_rounded, "Preview"),
              ),
              if (savedQrUrl != null)
                _statusChip("Saved", Colors.green)
              else if (previewData != null)
                _statusChip("Preview", Colors.orange),
            ],
          ),
          const SizedBox(height: 12),

          /// SAVED (server) QR
          if (savedQrUrl != null)
            _qrFrame(
              child: Image.network(
                savedQrUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "QR image load na thai",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            )

          /// LOCAL PREVIEW
          else if (previewData != null && previewData!.isNotEmpty)
            LayoutBuilder(
              builder: (context, box) {
                final double displaySize = [
                  selectedSize.toDouble(),
                  box.maxWidth - 40,
                  320.0,
                ].reduce((a, b) => a < b ? a : b);

                return _qrFrame(
                  child: QrImageView(
                    data: previewData!,
                    version: QrVersions.auto,
                    size: displaySize,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: withLogo == 1
                        ? QrErrorCorrectLevel.H
                        : QrErrorCorrectLevel.M,
                    embeddedImage: logoImage,
                    embeddedImageStyle: QrEmbeddedImageStyle(
                      size: Size(displaySize * 0.22, displaySize * 0.22),
                    ),
                  ),
                );
              },
            )

          /// EMPTY
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 46,
                    color: AppColors.primaryDark.withOpacity(0.35),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Click Preview QR to check the code. Save before scanning a new QR.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (previewData != null || savedQrUrl != null) ...[
            const SizedBox(height: 12),
            _infoRow("Title", titleController.text.trim()),
            _infoRow("Size", "${selectedSize}px"),
            _infoRow("Type", selectedType == "web" ? "Web" : "App"),
            _infoRow("Logo", withLogo == 1 ? "With Logo" : "Without Logo"),
            if (selectedType == "app" && savedQrUrl == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Preview ma Android link dekhay che. Final QR save thaya pachhi server banavshe.",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.orange.shade800,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _qrFrame({required Widget child}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  String? _urlValidator(String? v) {
    final String value = v?.trim() ?? "";
    if (value.isEmpty) return "Link is required";

    final Uri? uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == "http" || uri.scheme == "https") ||
        uri.host.isEmpty) {
      return "Valid link nakho (https://...)";
    }
    return null;
  }

  /// QR ma shu encode karvu (local preview mate)
  String _buildEncodedData() {
    if (selectedType == "web") return webUrlController.text.trim();
    return androidUrlController.text.trim();
  }

  bool _validate() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return false;

    if (withLogo == 1 && logoFile == null && !_keepExistingLogo) {
      AppMessage.error(context, "Please select logo");
      return false;
    }
    return true;
  }

  void _onPreview() {
    if (!_validate()) return;

    setState(() {
      savedQrUrl = null;
      previewData = _buildEncodedData();
    });
  }

  Future<void> _onSave() async {
    if (!_validate()) return;

    setState(() => isSaving = true);

    try {
      final String url = isEdit
          ? "${ApiConstants.qr_making}/$editId"
          : ApiConstants.qr_making;

      final Map<String, dynamic> body = {
        "title": titleController.text.trim(),
        "type": selectedType,
        "size": selectedSize,
        "with_logo": withLogo,
      };

      /// 🔥 Type pramane links
      if (selectedType == "web") {
        body["web_url"] = webUrlController.text.trim();
      } else {
        /// App select hoy → android + ios banne jase
        body["android_url"] = androidUrlController.text.trim();
        body["ios_url"] = iosUrlController.text.trim();
      }

      Response? response;

      if (withLogo == 1 && logoFile != null) {
        /// ======================================================
        /// 🔥 NAVO LOGO → multipart, file "logo" key ma
        /// Edit hoy to Laravel mate POST + _method=PUT
        /// ======================================================
        final FormData formData = FormData.fromMap({
          ...body,
          if (isEdit) "_method": "PUT",
          "logo": await MultipartFile.fromFile(
            logoFile!.path,
            filename: logoFile!.path.split(Platform.pathSeparator).last,
          ),
        });

        debugPrint("📤 QR URL    => $url");
        debugPrint("📤 QR FIELDS => ${formData.fields}");
        debugPrint(
          "📤 QR FILES  => ${formData.files.map((f) => "${f.key}: ${f.value.filename}").toList()}",
        );

        response = await ApiHelper().postFormData(url, formData);
      } else {
        /// ======================================================
        /// 🔥 JSON
        /// - Without Logo            → logo = ""
        /// - Edit + juno logo rakhvo → logo moklavo j nahi
        /// ======================================================
        if (withLogo == 0) {
          body["logo"] = "";
        }

        debugPrint("📤 QR URL  => $url");
        debugPrint("📤 QR BODY => $body");

        response = isEdit
            ? await ApiHelper().putRequest(url, body)
            : await ApiHelper().postRequest(url, body);
      }

      debugPrint("📥 QR RESPONSE => ${response?.data}");

      if (!mounted) return;

      final dynamic data = response?.data;
      final bool ok = response != null &&
          (response.statusCode == 200 || response.statusCode == 201) &&
          !(data is Map && data["success"] == false);

      if (ok) {
        AppMessage.success(
          context,
          (data is Map ? data["message"]?.toString() : null) ??
              (isEdit ? "QR updated successfully" : "QR saved successfully"),
        );

        /// 🔥 Add ke Edit, banne ma list par pachha, list refresh thashe
        Navigator.pop(context, true);
        return;
      } else {
        AppMessage.error(context, _extractError(data));
      }
    } on DioException catch (e) {
      if (mounted) AppMessage.error(context, _extractError(e.response?.data));
    } catch (e) {
      debugPrint("❌ QR SAVE ERROR => $e");
      if (mounted) AppMessage.error(context, "Something went wrong");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Response ma QR image url koi pan key ma aave — shodhi lo
  String? _extractQrUrl(dynamic data) {
    if (data is! Map) return null;

    final dynamic inner = data["data"] is Map ? data["data"] : data;

    for (final key in [
      "qr_url",
      "qr_image",
      "qr_image_url",
      "image_url",
      "png_url",
      "qr_path",
    ]) {
      final v = inner[key]?.toString() ?? "";
      if (v.startsWith("http") && !v.toLowerCase().endsWith(".svg")) {
        return v;
      }
    }
    return null;
  }

  /// 422 validation errors / message
  String _extractError(dynamic data) {
    if (data is Map) {
      if (data["errors"] is Map && (data["errors"] as Map).isNotEmpty) {
        final first = (data["errors"] as Map).values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (data["message"] != null) return data["message"].toString();
    }
    return isEdit ? "Failed to update QR" : "Failed to save QR";
  }

  // ============================================================
  // SMALL UI HELPERS
  // ============================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
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

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 18, color: AppColors.primaryDark),
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primaryDark, 1.4),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red.shade400, 1.4),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(hint: hint, prefixIcon: prefixIcon),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primaryDark,
      ),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool filled,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              gradient: filled
                  ? const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.gradientBlue],
              )
                  : null,
              color: filled ? null : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: filled
                  ? null
                  : Border.all(color: AppColors.primaryDark.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 18,
                    color: filled ? Colors.white : AppColors.primaryDark,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : AppColors.primaryDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade800,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              title,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
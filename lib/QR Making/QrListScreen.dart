import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import 'AddQrScreen.dart';

/// ================================================================
/// 🔳 QR LIST — ERP THEME (JobWork Issue list jevu j)
///
/// GET  {baseUrl}qr-making          → list
/// DELETE {baseUrl}qr-making/{id}   → delete
///
/// Card header : QR thumbnail + Title + Type | SVG, PDF, Edit, Delete, ⌄
/// Expand      : Size, Logo, Link / Desc, Created By, Date
/// ================================================================

class QrListScreen extends StatefulWidget {
  const QrListScreen({super.key});

  @override
  State<QrListScreen> createState() => _QrListScreenState();
}

class _QrListScreenState extends State<QrListScreen> {
  final TextEditingController searchController = TextEditingController();

  List allQr = [];
  List qrList = [];

  bool isLoading = true;
  int? expandedQrId;

  @override
  void initState() {
    super.initState();
    loadQrList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // API — LIST
  // ============================================================

  Future<void> loadQrList() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiHelper().getRequest(ApiConstants.qr_making);

      debugPrint("📥 QR LIST => ${response?.data}");

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final dynamic data = response.data;

        /// data: [...] ke data: { data: [...] } (pagination) — banne handle
        List list = [];
        if (data is Map && data["data"] is List) {
          list = data["data"];
        } else if (data is Map &&
            data["data"] is Map &&
            data["data"]["data"] is List) {
          list = data["data"]["data"];
        } else if (data is List) {
          list = data;
        }

        /// 🔥 Navo QR upar
        list = List.from(list)
          ..sort((a, b) {
            final ia = int.tryParse(a["id"]?.toString() ?? "") ?? 0;
            final ib = int.tryParse(b["id"]?.toString() ?? "") ?? 0;
            return ib.compareTo(ia);
          });

        setState(() {
          allQr = list;
          isLoading = false;
        });

        _applySearch(searchController.text);
      } else {
        setState(() {
          allQr = [];
          qrList = [];
          isLoading = false;
        });
        AppMessage.error(context, "Failed to load QR list");
      }
    } catch (e) {
      debugPrint("❌ QR LIST ERROR => $e");
      if (!mounted) return;
      setState(() => isLoading = false);
      AppMessage.error(context, "Failed to load QR list");
    }
  }

  void _applySearch(String value) {
    final String q = value.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        qrList = List.from(allQr);
        return;
      }

      qrList = allQr.where((item) {
        final m = item as Map;
        return [
          _title(m),
          _type(m),
          _createdBy(m),
          _link(m),
        ].any((s) => s.toLowerCase().contains(q));
      }).toList();
    });
  }

  // ============================================================
  // API — DELETE
  // ============================================================

  Future<void> deleteQr(int id) async {
    try {
      final response =
      await ApiHelper().deleteRequest("${ApiConstants.qr_making}/$id");

      if (!mounted) return;

      final dynamic data = response?.data;
      final bool ok = response != null &&
          (response.statusCode == 200 || response.statusCode == 204) &&
          !(data is Map && data["success"] == false);

      if (ok) {
        AppMessage.success(
          context,
          (data is Map ? data["message"]?.toString() : null) ??
              "QR deleted successfully",
        );
        await loadQrList();
      } else {
        AppMessage.error(
          context,
          (data is Map ? data["message"]?.toString() : null) ??
              "Failed to delete QR",
        );
      }
    } catch (e) {
      debugPrint("❌ QR DELETE ERROR => $e");
      if (mounted) AppMessage.error(context, "Failed to delete QR");
    }
  }

  // ============================================================
  // SVG / PDF DOWNLOAD
  // ============================================================

  Future<void> _downloadAndOpen({
    required String url,
    required String fileName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiHelper().getPdfRequest(url);

      if (!mounted) return;
      Navigator.pop(context); // loader

      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/$fileName");

        await file.writeAsBytes(response.data as List<int>);
        await OpenFile.open(file.path);
      } else {
        AppMessage.error(context, "Download failed");
      }
    } catch (e) {
      debugPrint("❌ QR DOWNLOAD ERROR => $e");
      if (mounted) {
        Navigator.pop(context);
        AppMessage.error(context, "Download failed");
      }
    }
  }

  void _openSvg(Map item, int id) {
    final String url = _absUrl(item, ["svg_url", "svg_path", "svg"]) ??
        "${ApiConstants.qr_making}/$id/svg";

    _downloadAndOpen(url: url, fileName: "qr_$id.svg");
  }

  void _openPdf(Map item, int id) {
    final String url = _absUrl(item, ["pdf_url", "pdf_path", "pdf"]) ??
        "${ApiConstants.qr_making}/$id/pdf";

    _downloadAndOpen(url: url, fileName: "qr_$id.pdf");
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 40),

                _filterWidget(),

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

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : qrList.isEmpty
                      ? const Center(
                    child: Text(
                      "No QR found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: loadQrList,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: qrList.length,
                      itemBuilder: (context, index) {
                        return _buildQrCard(
                          Map<String, dynamic>.from(qrList[index]),
                          index,
                        );
                      },
                    ),
                  ),
                ),

                /// + CREATE QR
                InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddQrScreen()),
                    );

                    if (!mounted) return;
                    if (result == true) await loadQrList();
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
                      child: const Center(
                        child: Text(
                          "+ Create QR",
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

            /// APPBAR (OVERLAY)
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
                    const Text(
                      "QR List",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _filterWidget() {
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
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.black),
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: "Search QR (title, type, link)",
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QR CARD
  // ============================================================

  Widget _buildQrCard(Map<String, dynamic> item, int index) {
    final bool isTablet = MediaQuery.of(context).size.width >= 600;

    final int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
    final bool isExpanded = expandedQrId == id;

    final String title = _title(item);
    final String type = _type(item);
    final String size = _size(item);
    final String logo = _hasLogo(item) ? "With Logo" : "Without Logo";
    final String createdBy = _createdBy(item);
    final String link = _link(item);
    final String desc = _val(item, ["description", "desc", "remarks"]);
    final String createdAt = _val(item, ["created_at"]);

    final double gap = isTablet ? 8 : 4;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isExpanded
              ? AppColors.primaryDark.withOpacity(0.45)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Column(
          children: [
            /// =====================================================
            /// HEADER — ALWAYS VISIBLE
            /// =====================================================
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 8,
                vertical: isTablet ? 12 : 10,
              ),
              child: Row(
                children: [
                  /// INDEX (tab par j — phone par jagya bachavva)
                  if (isTablet) ...[
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.gradientBlue,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  /// QR THUMBNAIL — tap thi motu dekhay
                  InkWell(
                    onTap: () => _showQrBig(item),
                    borderRadius: BorderRadius.circular(6),
                    child: _qrThumb(item, isTablet ? 50 : 42),
                  ),

                  const SizedBox(width: 8),

                  /// TITLE + TYPE
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _typeChip(type),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  /// SVG
                  _iconBtn(
                    icon: Icons.code_rounded,
                    color: const Color(0xff16A34A),
                    tooltip: "SVG",
                    onTap: () => _openSvg(item, id),
                  ),
                  SizedBox(width: gap),

                  /// PDF
                  _iconBtn(
                    icon: Icons.picture_as_pdf_rounded,
                    color: const Color(0xffD32F2F),
                    tooltip: "PDF",
                    onTap: () => _openPdf(item, id),
                  ),
                  SizedBox(width: gap),

                  /// EDIT
                  _iconBtn(
                    icon: Icons.edit_rounded,
                    color: Colors.blue,
                    tooltip: "Edit",
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddQrScreen(qrData: item),
                        ),
                      );
                      if (!mounted) return;
                      if (result == true) await loadQrList();
                    },
                  ),
                  SizedBox(width: gap),

                  /// DELETE
                  _iconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    tooltip: "Delete",
                    onTap: () {
                      if (id > 0) _showDeleteDialog(item, id);
                    },
                  ),
                  SizedBox(width: gap),

                  /// EXPAND
                  InkWell(
                    onTap: () {
                      setState(() {
                        expandedQrId = expandedQrId == id ? null : id;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// =====================================================
            /// EXPANDED — Size, Logo, Desc, Created By
            /// =====================================================
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.border, width: 1.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          _erpRow("Size", size, "Logo", logo),
                          Divider(height: 1, color: AppColors.border),
                          _erpRow(
                            "Type",
                            type,
                            "Date",
                            createdAt.isNotEmpty ? _formatDate(createdAt) : "-",
                          ),
                          Divider(height: 1, color: AppColors.border),
                          _fullRow("Created By", createdBy),
                          Divider(height: 1, color: AppColors.border),
                          _fullRow("Desc", desc.isNotEmpty ? desc : link),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QR THUMB — server image hoy to e, nahi to app ma j banavo
  // ============================================================

  Widget _qrThumb(Map item, double size) {
    final String? imageUrl = _absUrl(item, [
      "qr_url",
      "qr_image_url",
      "image_url",
      "png_url",
      "qr_image",
      "qr_path",
    ]);

    Widget fallback() {
      final String data = _link(item);
      if (data.isEmpty) {
        return Icon(
          Icons.qr_code_2_rounded,
          size: size * 0.7,
          color: AppColors.primaryDark,
        );
      }
      return QrImageView(
        data: data,
        size: size - 6,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: (imageUrl != null && !imageUrl.toLowerCase().endsWith(".svg"))
          ? Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback(),
      )
          : fallback(),
    );
  }

  void _showQrBig(Map item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title(item),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                _qrThumb(item, 240),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DELETE DIALOG (JobWork Issue jevo j)
  // ============================================================

  void _showDeleteDialog(Map item, int id) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        final double width = MediaQuery.of(dialogContext).size.width;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width > 500 ? 420 : width * 0.88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.gradientBlue,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Delete QR",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "This action cannot be undone",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryDark.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            _qrThumb(item, 44),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _title(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "${_type(item)}  •  ${_size(item)}",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text(
                        "Are you sure you want to delete this QR?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    deleteQr(id);
                                  },
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primaryDark,
                                          AppColors.gradientBlue,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "Delete",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ============================================================
  // DATA HELPERS — API key thodi alag hoy to pan chale
  // ============================================================

  String _val(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != "null") return s;
    }
    return "";
  }

  String _title(Map m) {
    final t = _val(m, ["title", "name"]);
    return t.isEmpty ? "-" : t;
  }

  String _type(Map m) {
    final t = _val(m, ["type", "qr_type"]).toLowerCase();
    if (t == "web") return "Web";
    if (t == "app") return "App";
    return t.isEmpty ? "-" : t;
  }

  String _size(Map m) {
    final s = _val(m, ["size", "qr_size"]);
    if (s.isEmpty) return "-";
    return s.endsWith("px") ? s : "${s}px";
  }

  bool _hasLogo(Map m) {
    final v = m["with_logo"];
    return v == true || v?.toString() == "1" || v?.toString() == "true";
  }

  String _createdBy(Map m) {
    final dynamic c = m["created_by"];
    if (c is Map) {
      final n = _val(c, ["name", "username"]);
      if (n.isNotEmpty) return n;
    }
    final dynamic u = m["user"] ?? m["creator"];
    if (u is Map) {
      final n = _val(u, ["name", "username"]);
      if (n.isNotEmpty) return n;
    }
    final n = _val(m, ["created_by_name", "created_by_user"]);
    return n.isEmpty ? "-" : n;
  }

  String _link(Map m) {
    return _val(m, ["web_url", "web_link", "url", "android_url", "ios_url"]);
  }

  /// Fakt http thi sharu thata link j valid
  String? _absUrl(Map m, List<String> keys) {
    final v = _val(m, keys);
    return v.startsWith("http") ? v : null;
  }

  String _formatDate(String date) {
    final d = date.split("T").first.split(" ").first;
    final parts = d.split("-");
    if (parts.length != 3) return date;
    return "${parts[2]}-${parts[1]}-${parts[0]}";
  }

  // ============================================================
  // SMALL UI
  // ============================================================

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }

  Widget _typeChip(String type) {
    final bool isWeb = type == "Web";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWeb ? Icons.language_rounded : Icons.phone_android_rounded,
            size: 11,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 3),
          Text(
            type,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _erpRow(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    t1,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    v1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    t2,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aakhi width vali row (lambo text mate)
  Widget _fullRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
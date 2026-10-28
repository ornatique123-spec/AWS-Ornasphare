import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../User/CreateCustomer.dart';
// 🏢 Branch (same as Sale Summary)
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class PremiumHomeUI extends StatefulWidget {
  const PremiumHomeUI({super.key});

  @override
  State<PremiumHomeUI> createState() => _PremiumHomeUIState();
}

class _PremiumHomeUIState extends State<PremiumHomeUI> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool isCameraOn = false;
  String? capturedImagePath;
  List<XFile> selectedImages = [];
  List<String> imagePaths = [];
  bool isLoading = false;
  List userlist = [];
  List allUsers = []; // 🔥 original data store

  TextEditingController searchController = TextEditingController();

  List get filteredUserList {
    if (searchController.text.isEmpty) {
      return userlist;
    }

    return userlist.where((item) {
      final name = item["name"]?.toString().toLowerCase() ?? "";
      final mobile = item["mobile_no"]?.toString().toLowerCase() ?? "";

      final search = searchController.text.toLowerCase();

      return name.contains(search) || mobile.contains(search);
    }).toList();
  }

  int currentPage = 1;
  int lastPage = 1;
  bool isLoadingMore = false;

  ScrollController scrollController = ScrollController();

  /// =========================================================
  /// 🔥 BRANCH REPORTS (Sale Summary jevu j)
  /// =========================================================

  List<Company> branchCompanies = [];
  Set<int> selectedCompanyIds = {};
  List<int> appliedCompanyIds = [];

  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;

  /// management_branches[]=9&management_branches[]=20
  String get _branchQuery => appliedCompanyIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// url ma branch umero (branch mode hoy to j)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// =========================================================
  /// 📅 FROM / TO DATE FILTER
  /// UI: dd-MM-yyyy  •  API: from_date=yyyy-MM-dd&to_date=yyyy-MM-dd
  /// =========================================================

  DateTime? fromDate; // picker ma select
  DateTime? toDate;
  DateTime? _appliedFrom; // "Show" dabavya pachhi apply
  DateTime? _appliedTo;

  bool get _dateApplied => _appliedFrom != null || _appliedTo != null;

  String _two(int v) => v.toString().padLeft(2, '0');

  /// 05-10-2026
  String _uiDate(DateTime d) => "${_two(d.day)}-${_two(d.month)}-${d.year}";

  /// 2026-10-05
  String _apiDate(DateTime d) => "${d.year}-${_two(d.month)}-${_two(d.day)}";

  String get _dateQuery => [
    if (_appliedFrom != null) "from_date=${_apiDate(_appliedFrom!)}",
    if (_appliedTo != null) "to_date=${_apiDate(_appliedTo!)}",
  ].join("&");

  /// url ma branch + date banne umero
  String _q(String url) {
    final String withBranch = _br(url);
    if (!_dateApplied) return withBranch;
    return "$withBranch${withBranch.contains('?') ? '&' : '?'}$_dateQuery";
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (isFrom ? fromDate : toDate) ?? now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8B5CF6),
            onPrimary: Colors.white,
            surface: Color(0xFF0F111A),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF0F111A),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        fromDate = picked;
      } else {
        toDate = picked;
      }
    });
  }

  /// 🔥 SHOW — date apply kari ne list farithi
  Future<void> applyDateFilter() async {
    if (fromDate == null && toDate == null) {
      showError("Please select From / To date");
      return;
    }
    if (fromDate != null && toDate != null && fromDate!.isAfter(toDate!)) {
      showError("From date, To date pachhi na hovi joie");
      return;
    }
    setState(() {
      _appliedFrom = fromDate;
      _appliedTo = toDate;
    });
    await _reloadCards();
  }

  /// Date filter kadhi nakho
  Future<void> clearDateFilter() async {
    final bool wasApplied = _dateApplied;
    setState(() {
      fromDate = null;
      toDate = null;
      _appliedFrom = null;
      _appliedTo = null;
    });
    if (wasApplied) await _reloadCards();
  }

  /// row → branch name (company_id / branch / company_name)
  String _branchOf(Map item) {
    final int? id = int.tryParse("${item["company_id"] ?? ""}");
    if (id != null) {
      for (final c in branchCompanies) {
        if (c.id == id) return c.name;
      }
    }
    final dynamic b = item["branch"] ?? item["branch_name"] ?? item["company"];
    if (b is Map && b["name"] != null) return b["name"].toString();
    final String t = (b ?? item["company_name"] ?? "").toString().trim();
    return t.isEmpty || t == "null" ? "" : t;
  }

  int? get _mainCompanyId {
    for (final c in branchCompanies) {
      if (c.isMain) return c.id;
    }
    return null;
  }

  /// ✅ Main company no card? (fakt ema j Edit)
  /// Branch list j na hoy (branch user) → potano data → true
  bool _isMainData(Map item) {
    final int? mainId = _mainCompanyId;
    if (mainId == null) return true;

    final int? id = int.tryParse("${item["company_id"] ?? ""}");
    if (id != null) return id == mainId;

    final String br = _branchOf(item).trim().toLowerCase();
    if (br.isEmpty) return true;
    for (final c in branchCompanies) {
      if (c.name.trim().toLowerCase() == br) return c.isMain;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    initCamera();
    category();
    _loadBranches();

    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 40) {
        if (!isLoadingMore && currentPage < lastPage) {
          category(loadMore: true);
        }
      }
    });
  }

  /// =========================================================
  /// 🔥 LOAD BRANCHES
  /// =========================================================

  Future<void> _loadBranches() async {
    setState(() => branchesLoading = true);

    try {
      // 🔐 Fakt main company admin ne j Branch Reports dekhay
      final bool isAdmin = await BranchAccess.isMainCompanyAdmin();
      if (!isAdmin) {
        if (mounted) setState(() => canViewBranches = false);
        return;
      }

      final overview = await BranchApi.fetchOverview();
      if (!mounted) return;

      final List<Company> list = [
        if (overview.mainCompany != null) overview.mainCompany!,
        ...overview.branches,
      ];

      setState(() {
        branchCompanies = list;
        canViewBranches = list.length > 1;
        selectedCompanyIds = {
          if (overview.mainCompany != null) overview.mainCompany!.id,
        };
      });
    } catch (e) {
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// List page 1 thi farithi (search emnu em rahe)
  Future<void> _reloadCards() async {
    setState(() {
      currentPage = 1;
      lastPage = 1;
    });
    await category();
    if (scrollController.hasClients) scrollController.jumpTo(0);
  }

  /// 🔥 VIEW — fakt select kareli branches
  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      showError("Please select at least one branch");
      return;
    }
    setState(() => appliedCompanyIds = selectedCompanyIds.toList());
    await _reloadCards();
  }

  /// Branch report bandh → potani company na cards
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadCards();
  }

  Future<void> category({bool loadMore = false}) async {
    if (isLoadingMore) return;

    final int page = loadMore ? currentPage + 1 : 1;
    if (loadMore) setState(() => isLoadingMore = true);

    try {
      final String url = _q("${ApiConstants.visiting_card_list}?page=$page");
      debugPrint("🌐 VISITING CARD LIST => $url");

      final response = await ApiHelper().getRequest(url);
      final dynamic body = response?.data;

      if (response != null && response.statusCode == 200 && body is Map) {
        final dynamic d = body["data"];

        // data.data[] (paginate) athva data[]
        List categories = [];
        if (d is Map && d["data"] is List) {
          categories = d["data"];
        } else if (d is List) {
          categories = d;
        }

        final Map? meta = d is Map && d["last_page"] != null
            ? d
            : (body["pagination"] is Map
            ? body["pagination"]
            : (body["meta"] is Map ? body["meta"] : null));

        if (!mounted) return;

        setState(() {
          currentPage = int.tryParse("${meta?["current_page"] ?? ""}") ?? page;
          lastPage = int.tryParse("${meta?["last_page"] ?? ""}") ?? page;

          if (loadMore) {
            userlist.addAll(categories);
            allUsers.addAll(categories);
          } else {
            userlist = List.from(categories);
            allUsers = List.from(categories);
          }
        });
      } else if (!loadMore) {
        showError(body is Map && body["message"] != null
            ? body["message"].toString()
            : "Visiting cards load na thaya");
      }
    } catch (e) {
      debugPrint("❌ Visiting card list error: $e");
      if (!loadMore) showError("Visiting cards load na thaya");
    } finally {
      if (mounted) {
        setState(() => isLoadingMore = false);
      } else {
        isLoadingMore = false;
      }
    }

    debugPrint("Total Customer : ${userlist.length}");
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(
      cameras![0],
      ResolutionPreset.medium,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void startCamera() {
    setState(() {
      isCameraOn = true;
      capturedImagePath = null;
    });
  }

  // ============================================================
  // 📞 CALL / 💬 WHATSAPP / ➕ ADD HELPERS
  // ============================================================

  /// "+91 98765-43210" → "9876543210"
  String _cleanMobile(dynamic value) {
    String num = (value ?? "").toString().replaceAll(RegExp(r'\D'), '');

    if (num.startsWith("91") && num.length > 10) {
      num = num.substring(2);
    }
    if (num.startsWith("0") && num.length > 10) {
      num = num.substring(1);
    }

    return num;
  }

  /// mobile_no hoy to e, nahi to mobile_numbers no pehlo number
  String _firstMobile(Map data) {
    final String direct = _cleanMobile(data["mobile_no"]);
    if (direct.isNotEmpty) return direct;

    final dynamic list = data["mobile_numbers"];
    if (list is List && list.isNotEmpty) {
      return _cleanMobile(list.first);
    }

    return "";
  }

  Future<void> _callNumber(String number) async {
    if (number.isEmpty) {
      showError("Mobile number nathi");
      return;
    }

    final Uri url = Uri(scheme: "tel", path: number);

    try {
      final bool ok = await launchUrl(url);
      if (!ok) showError("Call open na thai shaki");
    } catch (e) {
      print("Call Error: $e");
      showError("Call open na thai shaki");
    }
  }

  Future<void> _openWhatsApp(String number) async {
    if (number.isEmpty) {
      showError("Mobile number nathi");
      return;
    }

    /// 10 digit hoy to India code (91) aagal lagavo
    final String waNumber = number.length == 10 ? "91$number" : number;

    final Uri url = Uri.parse("https://wa.me/$waNumber");

    try {
      final bool ok = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) showError("WhatsApp open na thai shakyu");
    } catch (e) {
      print("WhatsApp Error: $e");
      showError("WhatsApp open na thai shakyu");
    }
  }

  /// ➕ Visiting card mathi Customer banavo
  Future<void> _addAsCustomer(Map data) async {
    final Map<String, dynamic> customerData = {
      ...Map<String, dynamic>.from(data),
      "mobile_no": _firstMobile(data),
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Createcustomer(userData: customerData),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await category();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06070D),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  /// 🔹 TAG
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "AI Vision Ready",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 TITLE
                  const Text(
                    "Scan.",
                    style: TextStyle(color: Colors.white, fontSize: 30),
                  ),
                  const Text(
                    "Extract. Excel.",
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "AI-powered visiting card scanner • Auto language detection • Export to Excel",
                    style: TextStyle(color: Colors.white54),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.black,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: capturedImagePath != null

                          /// 🔥 IMAGE PREVIEW
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(capturedImagePath!),
                              fit: BoxFit.cover,
                            ),
                          )

                          /// 🔥 CAMERA PREVIEW (NO STRETCH)
                              : isCameraOn &&
                              _controller != null &&
                              _controller!.value.isInitialized
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 250,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: _controller!
                                      .value.previewSize!.height,
                                  height: _controller!
                                      .value.previewSize!.width,
                                  child: CameraPreview(_controller!),
                                ),
                              ),
                            ),
                          )

                          /// 🔥 DEFAULT UI
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.qr_code_2,
                                  size: 40, color: Color(0xFF8B5CF6)),
                              SizedBox(height: 10),
                              Text(
                                "Snap a card. Get clean data.",
                                style: TextStyle(color: Colors.white),
                              ),
                              Text(
                                "Point camera at visiting card",
                                style: TextStyle(color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                        IgnorePointer(
                          child: Stack(
                            children: [
                              Positioned(top: 10, left: 10, child: corner()),
                              Positioned(
                                  top: 10,
                                  right: 10,
                                  child: corner(isRight: true)),
                              Positioned(
                                  bottom: 10,
                                  left: 10,
                                  child: corner(isBottom: true)),
                              Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child:
                                  corner(isRight: true, isBottom: true)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      /// 🔹 CAPTURE BUTTON
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () async {
                            if (!isCameraOn) {
                              startCamera();
                            } else {
                              await captureImage();
                            }
                          },
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCameraOn ? Icons.camera : Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCameraOn ? "Take Photo" : "Open Camera",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// 🔹 UPLOAD BUTTON
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () async {
                            await pickMultipleImages();
                          },
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.upload,
                                    color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Upload",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  /// ❌ PLAN INFO (Premium banner, Free uploads, feature
                  /// tiles) HIDE karyu che.

                  /// 🏢 BRANCH REPORTS
                  _buildBranchCard(),

                  const SizedBox(height: 20),

                  /// 🔹 RECENT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// 🔥 TITLE
                        const Text(
                          "Recent List",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: TextField(
                            controller: searchController,
                            onChanged: (value) {
                              setState(() {});
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Search name or mobile",
                              hintStyle: TextStyle(color: Colors.white54),
                              prefixIcon:
                              Icon(Icons.search, color: Colors.white70),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        /// 📅 FROM / TO DATE
                        _buildDateFilter(),

                        const SizedBox(height: 10),

                        /// 🔥 LIST
                        if (filteredUserList.isNotEmpty)
                          SizedBox(
                            height: 350,
                            child: ListView.builder(
                              shrinkWrap: true,
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredUserList.length + 1,
                              itemBuilder: (context, index) {
                                if (index == filteredUserList.length) {
                                  return isLoadingMore
                                      ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Center(
                                      child:
                                      CircularProgressIndicator(),
                                    ),
                                  )
                                      : const SizedBox();
                                }

                                final item = filteredUserList[index];
                                final String mobile = _firstMobile(item);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      /// 🔹 ICON
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED)
                                              .withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person,
                                            color: Colors.white, size: 18),
                                      ),

                                      const SizedBox(width: 10),

                                      /// 🔹 TEXT
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item["name"]?.toString() ?? "-",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),

                                            /// 🏢 BRANCH BADGE (branch mode)
                                            if (_branchMode &&
                                                _branchOf(item).isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 3, bottom: 2),
                                                child: _branchBadge(
                                                    _branchOf(item)),
                                              ),
                                            Text(
                                              item["mobile_no"]?.toString() ??
                                                  "-",
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      /// 📞 CALL
                                      _listIconBtn(
                                        icon: Icons.call,
                                        color: const Color(0xFF8B5CF6),
                                        onTap: () => _callNumber(mobile),
                                      ),

                                      const SizedBox(width: 8),

                                      /// 💬 WHATSAPP
                                      _listIconBtn(
                                        icon: Icons.chat_rounded,
                                        color: const Color(0xFF22C55E),
                                        onTap: () => _openWhatsApp(mobile),
                                      ),

                                      /// ✏️ EDIT (fakt main branch na card ma)
                                      if (_isMainData(item))
                                        const SizedBox(width: 8),
                                      if (_isMainData(item))
                                        _listIconBtn(
                                          icon: Icons.edit,
                                          color: Colors.white70,
                                          onTap: () {
                                            showeditResultPopup({
                                              "id": item["id"],
                                              "name": item["name"] ?? "",
                                              "mobile_no":
                                              item["mobile_no"] ?? "",
                                              "email": item["email"] ?? "",
                                              "city": item["city"] ?? "",
                                              "pincode": item["pincode"] ?? "",
                                              "address": item["address"] ?? "",
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Text(
                                "No scans yet",
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),

            /// 🔥 PREMIUM LOADER OVERLAY
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F111A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.4),
                            blurRadius: 20,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 25,
                            width: 25,
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFF7C3AED),
                                  ],
                                ).createShader(rect);
                              },
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Scanning Card...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Extracting AI data",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
        ),
        child: SafeArea(
          child: Row(
            children: [
              /// PDF BUTTON
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () {
                    openPdf();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "PDF",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              /// EXCEL BUTTON
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () {
                    openexel();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "Excel",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
  /// 📅 DATE FILTER UI (From / To + Show / Clear)
  /// =========================================================

  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _dateBox(
                label: "From Date",
                date: fromDate,
                onTap: () => _pickDate(isFrom: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateBox(
                label: "To Date",
                date: toDate,
                onTap: () => _pickDate(isFrom: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: applyDateFilter,
                borderRadius: BorderRadius.circular(5),
                child: Ink(
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        "Show",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: clearDateFilter,
                borderRadius: BorderRadius.circular(5),
                child: Ink(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Text(
                      "Clear",
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_dateApplied) ...[
          const SizedBox(height: 6),
          Text(
            "Showing: ${_appliedFrom != null ? _uiDate(_appliedFrom!) : "Start"}"
                "  →  ${_appliedTo != null ? _uiDate(_appliedTo!) : "Today"}",
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: date != null
                ? const Color(0xFF8B5CF6).withOpacity(0.6)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? _uiDate(date) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: date != null ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Recent list na nana icon buttons
  Widget _listIconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  static Widget featureTile(String title, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF8B5CF6),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == "On"
                  ? const Color(0xFF8B5CF6).withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: status == "On"
                    ? const Color(0xFF8B5CF6)
                    : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget corner({bool isRight = false, bool isBottom = false}) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        children: [
          Align(
            alignment: isBottom ? Alignment.bottomCenter : Alignment.topCenter,
            child: Container(
              height: 2,
              width: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Align(
            alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 2,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> captureImage() async {
    try {
      if (_controller == null) return;

      final image = await _controller!.takePicture();

      if (image.path.isEmpty) return;

      /// 🔥 OPEN CROP SCREEN
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        capturedImagePath = croppedFile.path;
        isCameraOn = false;
      });

      await extractCardApi([croppedFile.path]);
    } catch (e) {
      print("Capture/Crop Error: $e");
    }
  }

  Future<void> extractCardApi(List<String> imagePaths) async {
    try {
      setState(() {
        isLoading = true;
      });

      FormData formData = FormData();

      for (String path in imagePaths) {
        formData.files.add(
          MapEntry(
            "card_images[]",
            await MultipartFile.fromFile(
              path,
              filename: "card.jpg",
            ),
          ),
        );
      }

      final response = await ApiHelper()
          .postFormData(ApiConstants.visiting_cards_extract, formData);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;

      printFullJson(data);

      if (response.statusCode == 200) {
        print("✅ API SUCCESS");

        List list = data['data'];

        List cleanJson = generateCleanJson(list);

        List finalCleanJson = cleanJson.map((item) {
          String address = item["address"] ?? "";
          final List mobiles = item["mobile_numbers"] ?? [];

          return {
            "name": item["name"],
            "mobile_numbers": mobiles,
            "mobile_no": mobiles.isNotEmpty ? mobiles.first : "",
            "email": item["email"],
            "address": address,
            "city": extractCity(address),
            "pincode": extractPincode(address),
          };
        }).toList();

        print("✅ FINAL CLEAN JSON WITH CITY PINCODE:");
        printFullJson(finalCleanJson);

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showResultPopup(finalCleanJson);
      } else {
        showError(data['message']?.toString() ?? "Extract failed");
      }
    } catch (e) {
      print("❌ Exception: $e");
      showError("Card scan na thai shakyu");
    } finally {
      /// 🔥 Error aave to pan loader band thay
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void printFullJson(dynamic jsonData) {
    const int chunkSize = 800;

    String data = jsonData.toString();

    for (int i = 0; i < data.length; i += chunkSize) {
      print(data.substring(
        i,
        i + chunkSize > data.length ? data.length : i + chunkSize,
      ));
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void showResultPopup(List dataList) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// 🔥 HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 8),
                          Text(
                            "Extracted Data",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// 🔥 LIST OF DATA
                      SizedBox(
                        height: 500,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: dataList.length,
                          itemBuilder: (context, index) {
                            var data = dataList[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                const Color(0xffFAF7F2).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  /// 🔥 TOP HEADER (COUNT + ACTION ICONS)
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED)
                                              .withOpacity(0.1),
                                          borderRadius:
                                          BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          "${index + 1}",
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.end,
                                        children: [
                                          /// ➕ ADD
                                          actionButton(
                                            icon: Icons.add,
                                            label: "Add",
                                            color: const Color(0xFF8B5CF6),
                                            onTap: () => _addAsCustomer(data),
                                          ),
                                          const SizedBox(width: 10),

                                          /// 📞 CALL
                                          actionButton(
                                            icon: Icons.call_rounded,
                                            label: "Call",
                                            color: const Color(0xFF8B5CF6),
                                            onTap: () =>
                                                _callNumber(_firstMobile(data)),
                                          ),
                                          const SizedBox(width: 10),

                                          /// 💬 WHATSAPP
                                          actionButton(
                                            icon: Icons.chat_rounded,
                                            label: "WhatsApp",
                                            color: const Color(0xFF22C55E),
                                            onTap: () => _openWhatsApp(
                                                _firstMobile(data)),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),

                                  premiumField(
                                    "Name",
                                    data["name"],
                                        (val) {
                                      data["name"] = val;
                                    },
                                  ),

                                  premiumField(
                                    "Mobile",
                                    (data["mobile_numbers"] != null &&
                                        data["mobile_numbers"].isNotEmpty)
                                        ? data["mobile_numbers"].join(", ")
                                        : "",
                                        (value) {
                                      data["mobile_numbers"] = value
                                          .split(",")
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty)
                                          .toList();

                                      data["mobile_no"] =
                                      data["mobile_numbers"].isNotEmpty
                                          ? data["mobile_numbers"][0]
                                          : "";
                                    },
                                  ),

                                  premiumField(
                                    "Email",
                                    data["email"] ?? "",
                                        (value) {
                                      data["email"] = value;
                                    },
                                  ),

                                  premiumField(
                                    "City",
                                    data["city"] ?? "",
                                        (value) {
                                      data["city"] = value;
                                    },
                                  ),

                                  premiumField(
                                    "Pincode",
                                    data["pincode"] ?? "",
                                        (value) {
                                      data["pincode"] = value;
                                    },
                                  ),

                                  premiumField(
                                    "Address",
                                    data["address"] ?? "",
                                        (value) {
                                      data["address"] = value;
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () async {
                            List updatedList = [];

                            for (var item in dataList) {
                              updatedList.add({
                                "name": item["name"],
                                "mobile_no": item["mobile_no"],
                                "mobile_numbers": item["mobile_numbers"],
                                "email": item["email"],
                                "city": item["city"],
                                "pincode": item["pincode"],
                                "address": item["address"],
                              });
                            }

                            print("EDITED DATA BEFORE SAVE");
                            printFullJson(updatedList);

                            Navigator.pop(dialogContext);

                            setState(() {
                              capturedImagePath = null;
                            });

                            /// 🔥 Save + list refresh
                            await bulkSaveCards(updatedList);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Done",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void showeditResultPopup(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// 🔥 HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 8),
                          Text(
                            "Extracted Data",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 500,
                        child: SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xffFAF7F2).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        "1",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        /// ➕ ADD
                                        actionButton(
                                          icon: Icons.add,
                                          label: "Add",
                                          color: const Color(0xFF8B5CF6),
                                          onTap: () => _addAsCustomer(data),
                                        ),

                                        const SizedBox(width: 10),

                                        /// 📞 CALL
                                        actionButton(
                                          icon: Icons.call,
                                          label: "Call",
                                          color: const Color(0xFF8B5CF6),
                                          onTap: () =>
                                              _callNumber(_firstMobile(data)),
                                        ),

                                        const SizedBox(width: 10),

                                        /// 💬 WHATSAPP
                                        actionButton(
                                          icon: Icons.chat_rounded,
                                          label: "WhatsApp",
                                          color: const Color(0xFF22C55E),
                                          onTap: () =>
                                              _openWhatsApp(_firstMobile(data)),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                premiumField(
                                  "Name",
                                  data["name"] ?? "",
                                      (value) {
                                    data["name"] = value;
                                  },
                                ),
                                premiumField(
                                  "Mobile",
                                  data["mobile_no"] ?? "",
                                      (value) {
                                    data["mobile_no"] = value;
                                  },
                                ),
                                premiumField(
                                  "Email",
                                  data["email"] ?? "",
                                      (value) {
                                    data["email"] = value;
                                  },
                                ),
                                premiumField(
                                  "City",
                                  data["city"] ?? "",
                                      (value) {
                                    data["city"] = value;
                                  },
                                ),
                                premiumField(
                                  "Pincode",
                                  data["pincode"] ?? "",
                                      (value) {
                                    data["pincode"] = value;
                                  },
                                ),
                                premiumField(
                                  "Address",
                                  data["address"] ?? "",
                                      (value) {
                                    data["address"] = value;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () async {
                            await visitngcard(data);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFF7C3AED),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Update Visiting Card",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
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
            ),
          ),
        );
      },
    );
  }

  Widget premiumField(
      String title,
      dynamic value,
      Function(String) onChanged,
      ) {
    TextEditingController controller = TextEditingController(
      text: value?.toString() ?? "",
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
          const Text(
            ": ",
            style: TextStyle(color: Colors.black),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: title == "Address" ? 3 : 1,
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final baseColor = color ?? const Color(0xFF7C3AED);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withOpacity(0.25),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: baseColor.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 1,
            )
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                baseColor.withOpacity(0.9),
                baseColor.withOpacity(0.5),
              ],
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Future<void> pickMultipleImages() async {
    try {
      bool granted = await requestGalleryPermission();
      if (!granted) {
        showError("Gallery permission denied");
        return;
      }

      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) return;

      List<String> croppedPaths = [];

      for (var img in images) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: img.path,
          aspectRatio: const CropAspectRatio(ratioX: 2, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Visiting Card',
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Crop Visiting Card',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          croppedPaths.add(croppedFile.path);
        }
      }

      if (croppedPaths.isEmpty) return;

      setState(() {
        selectedImages = images;
        imagePaths = croppedPaths;
      });

      await extractCardApi(imagePaths);
    } catch (e) {
      print("Image Picker Error: $e");
      showError("Failed to pick images");
    }
  }

  Future<bool> requestGalleryPermission() async {
    var status = await Permission.photos.request(); // iOS
    if (status.isGranted) return true;

    status = await Permission.storage.request(); // Android
    return status.isGranted;
  }

  List<Map<String, dynamic>> generateCleanJson(List records) {
    List<Map<String, dynamic>> finalList = [];

    for (var item in records) {
      if (item["success"] != true) continue;

      Map fields = item["fields"] ?? {};

      String rawText = (item["english_text"] ?? "").toString();

      List<String> lines = rawText
          .split("\n")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      /// ✅ NAME (number vagar ni line)
      String name = "";
      for (String line in lines) {
        if (!RegExp(r'\d').hasMatch(line) &&
            line.length > 3 &&
            !line.toLowerCase().contains("decorators") &&
            !line.toLowerCase().contains("jewellers")) {
          name = line;
          break;
        }
      }

      /// ✅ MOBILE
      List mobiles = fields["mobile_numbers"] ?? [];

      List<String> cleanMobiles = mobiles
          .map((e) => _cleanMobile(e))
          .where((e) => RegExp(r'^[6-9]\d{9}$').hasMatch(e))
          .toSet()
          .toList();

      if (cleanMobiles.isEmpty) {
        RegExp phoneRegex = RegExp(r'[6-9]\d{9}');
        cleanMobiles = phoneRegex
            .allMatches(rawText)
            .map((e) => e.group(0)!)
            .toSet()
            .toList();
      }

      /// ✅ EMAIL
      String email = fields["email"] ?? "";

      if (email.isEmpty) {
        RegExp emailRegex = RegExp(r'\S+@\S+\.\S+');
        var match = emailRegex.firstMatch(rawText);
        if (match != null) {
          email = match.group(0)!;
        }
      }

      /// ✅ ADDRESS
      String address = (fields["address"] ?? "")
          .toString()
          .replaceAll("\n", ", ")
          .replaceAll(RegExp(r',+'), ",")
          .trim();

      finalList.add({
        "name": name,
        "mobile_numbers": cleanMobiles,
        "email": email,
        "address": address,
      });
    }

    return finalList;
  }

  Future<void> bulkSaveCards(List records) async {
    try {
      final response = await ApiHelper().postRequest(
        ApiConstants.visiting_cards_save,
        {"records": records},
      );

      print("Bulk Save Response:");
      printFullJson(response?.data);

      if (response != null && response.statusCode == 200) {
        print("✅ Visiting Cards Saved Successfully");

        /// 🔥 RECENT LIST REFRESH
        searchController.clear();
        await category();

        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }

        showSuccess("Visiting card saved");
      } else {
        showError("Save failed");
      }
    } catch (e) {
      print("❌ Bulk Save Error: $e");
      showError("Save failed");
    }
  }

  Future<void> visitngcard(Map<String, dynamic> data) async {
    try {
      final userId = data["id"];

      final body = {
        "name": data["name"] ?? "",
        "mobile_no": data["mobile_no"] ?? "",
        "email": data["email"] ?? "",
        "city": data["city"] ?? "",
        "pincode": data["pincode"] ?? "",
        "address": data["address"] ?? "",
      };

      final response = await ApiHelper().putRequest(
        "${ApiConstants.Update_visiting_card}/$userId",
        body,
      );

      if (response == null) {
        showError("No response from server");
        return;
      }

      final responseData = response.data;

      if (response.statusCode == 200) {
        int index = userlist.indexWhere(
              (item) => item["id"].toString() == data["id"].toString(),
        );

        if (index != -1) {
          setState(() {
            userlist[index]["name"] = data["name"];
            userlist[index]["mobile_no"] = data["mobile_no"];
            userlist[index]["email"] = data["email"];
            userlist[index]["city"] = data["city"];
            userlist[index]["pincode"] = data["pincode"];
            userlist[index]["address"] = data["address"];
          });
        }
      } else if (response.statusCode == 422) {
        String errorMessage = "";

        if (responseData["errors"] != null) {
          Map errors = responseData["errors"];

          errors.forEach((key, value) {
            errorMessage += "${value[0]}\n";
          });
        } else {
          errorMessage = responseData["message"] ?? "Validation error";
        }

        showError(errorMessage);
      } else {
        showError(
            responseData["message"] ?? "Server error ${response.statusCode}");
      }
    } catch (e) {
      print("Update Exception : $e");
      showError("Something went wrong");
    }
  }

  String? extractPincode(String address) {
    RegExp regex = RegExp(r'\d[\d\s]{4,6}\d');

    Match? match = regex.firstMatch(address);

    if (match != null) {
      return match.group(0)!.replaceAll(" ", "");
    }

    return null;
  }

  String? extractCity(String address) {
    String clean = address.replaceAll("\n", " ").trim();

    clean = clean.replaceAll(RegExp(r'-?\d+'), '');

    List<String> parts = clean.split(',');

    if (parts.isNotEmpty) {
      return parts.last
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll("-", "")
          .trim();
    }

    return null;
  }

  /// =========================================================
  /// 📄 PDF / EXCEL — branch wise
  /// visiting_card_pdf?management_branches[]=9&management_branches[]=20
  /// =========================================================

  String? _exporting; // "pdf" / "excel" chalu hoy tyare bijo tap nahi

  Future<void> openPdf() => _export("pdf");

  Future<void> openexel() => _export("excel");

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    _exporting = type;

    final bool isPdf = type == "pdf";
    final String label = isPdf ? "PDF" : "Excel";

    try {
      // branch + from/to date banne PDF / Excel ma pan
      final String url = _q(
        isPdf ? ApiConstants.visiting_card_pdf : ApiConstants.visiting_card_excel,
      );
      debugPrint("📤 VISITING CARD $label => $url");

      final response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      if (response == null || response.statusCode != 200) {
        showError(_exportError(response?.data) ?? "$label Download Failed");
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // Bytes ni jagya e JSON error aave to
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        showError(_exportError(raw) ?? "No file received from server");
        return;
      }

      final dir = await getTemporaryDirectory();
      final String ext = isPdf ? "pdf" : "xlsx";
      final file = File(
        "${dir.path}/visiting_card_${DateTime.now().millisecondsSinceEpoch}.$ext",
      );
      await file.writeAsBytes(bytes, flush: true);

      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ VISITING CARD $label ERROR => $e");
      showError("$label Download Failed");
    } finally {
      _exporting = null;
    }
  }

  /// JSON (bytes / map / string) mathi message
  String? _exportError(dynamic data) {
    try {
      dynamic d = data;
      if (d is List<int>) d = utf8.decode(d);
      if (d is String) d = jsonDecode(d);
      if (d is Map && d["message"] != null) return d["message"].toString();
    } catch (_) {}
    return null;
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab) — dark theme
  // ============================================================

  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _green = Color(0xFF22C55E);

  Widget _branchBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _purple.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_tree_rounded, size: 10, color: _purple),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC4B5FD),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard() {
    if (branchesLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Text(
          "Loading branches...",
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList =
    branchCompanies.where((c) => selectedCompanyIds.contains(c.id)).toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- HEADER (tap = expand) ----------------
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Branch Reports",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedCompanyIds.length}/${branchCompanies.length}",
                      style: const TextStyle(
                        color: Color(0xFFC4B5FD),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: branchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- BODY ----------------
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !branchExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Multi select box
                  InkWell(
                    onTap: _openBranchPicker,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            )
                                : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in selectedList)
                                  _branchChip(c),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Select one or more branches to combine their visiting cards.",
                    style: TextStyle(fontSize: 11.5, color: Colors.white38),
                  ),

                  const SizedBox(height: 10),

                  // VIEW
                  InkWell(
                    onTap: viewBranchReport,
                    borderRadius: BorderRadius.circular(5),
                    child: Ink(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff22C55E), Color(0xff16A34A)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_rounded,
                              size: 17, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            "View",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Branch report chalu hoy tyare info + clear
                  if (_branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 15, color: _green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing visiting cards of "
                                  "${appliedCompanyIds.length} "
                                  "${appliedCompanyIds.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF86EFAC),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: clearBranchReport,
                            style: TextButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFF87171),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChip(Company c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _purple.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.isMain ? Icons.verified_rounded : c.type.icon,
            size: 13,
            color: const Color(0xFFC4B5FD),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _companyLabel(c),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => setState(() => selectedCompanyIds.remove(c.id)),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 Multi-select bottom sheet
  Future<void> _openBranchPicker() async {
    final Set<int> temp = {...selectedCompanyIds};

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final bool allSelected = temp.length == branchCompanies.length;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Select Branches",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                if (allSelected) {
                                  temp.clear();
                                } else {
                                  temp.addAll(branchCompanies.map((c) => c.id));
                                }
                              });
                            },
                            child: Text(
                              allSelected ? "Clear All" : "Select All",
                              style: const TextStyle(
                                color: Color(0xFFC4B5FD),
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: branchCompanies.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.white10,
                        ),
                        itemBuilder: (context, i) {
                          final c = branchCompanies[i];
                          final bool checked = temp.contains(c.id);

                          return InkWell(
                            onTap: () => setSheet(() {
                              checked ? temp.remove(c.id) : temp.add(c.id);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _purple.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      c.isMain
                                          ? Icons.verified_rounded
                                          : c.type.icon,
                                      size: 17,
                                      color: const Color(0xFFC4B5FD),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _companyLabel(c),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            c.isMain ? "Main" : c.type.label,
                                            if (c.city != null) c.city!,
                                            if (!c.active) "Inactive",
                                          ].join(" • "),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.active
                                                ? Colors.white54
                                                : Colors.red.shade300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? _purple
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: checked
                                            ? _purple
                                            : Colors.white38,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: checked
                                        ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => Navigator.pop(sheetContext, temp),
                              borderRadius: BorderRadius.circular(5),
                              child: Ink(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFF4F46E5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Text(
                                    "Done (${temp.length})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
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
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => selectedCompanyIds = result);
    }
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/ItemProvider.dart';
import '../Extra/JewelleryBgRemover.dart';
import '../Extra/PremiumSearchableDropdown.dart';
import 'BatchImageScreen.dart';
import 'Batchbgtemplates.dart';
import 'BatchModelTemplates.dart';
import 'ImageSearchScreen.dart';
import 'TryOnScreen.dart';
// 🏢 Branch (same as Branch Reports / Report builder)
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

/// ================================================================
/// 🔥 RGBA → JPG (TOP-LEVEL — background isolate ma chale)
///
/// PNG encode UI thread par khub slow hatu ane file pan moti
/// banti hati. Have JPG encode compute() thi alag isolate ma
/// thay che, etle UI hang nathi thatu.
/// 🔥 Quality 95 — share kareli image sharp rahe.
/// ================================================================

Uint8List _encodeRgbaToJpg(Map<String, dynamic> a) {
  final img.Image image = img.Image.fromBytes(
    width: a["w"] as int,
    height: a["h"] as int,
    bytes: (a["rgba"] as Uint8List).buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// ================================================================
/// STOCK GALLERY SCREEN
/// ================================================================

class StockGalleryScreen extends StatefulWidget {
  const StockGalleryScreen({Key? key}) : super(key: key);

  @override
  State<StockGalleryScreen> createState() => _StockGalleryScreenState();
}

class _StockGalleryScreenState extends State<StockGalleryScreen> {
  /// =========================================================
  /// PREMIUM PALETTE
  /// =========================================================

  static const Color _gold = Color(0xffC9A227);
  static const Color _goldLight = Color(0xffE7C766);
  static const Color _ink = Color(0xff1A1A1F);
  static const Color _inkSoft = Color(0xff3A3A42);
  static const Color _muted = Color(0xff8B8B93);
  static const Color _surface = Color(0xffFAFAFB);
  static const Color _divider = Color(0xffECECEF);
  bool _isSelectingAll = false;

  /// =========================================================
  /// FILTER STATE
  /// =========================================================

  String selectedItem = "All Items";

  /// 🔍 Item dropdown ma keyboard search thi aavel keyword (e.g. "watch")
  /// null = keyword search bandh
  String? itemKeyword;

  bool _isSharing = false;
  // DEFAULT = ALL
  String selectedStockStatus = "All";

  // DEFAULT = ALL
  String selectedImageStatus = "All";
  // ✅ WEIGHT FILTER & SORT (Filter & Sort bottom sheet)
  String sortByWeight = "Default"; // Default | Low | High
  String selectedWeightRange = "All"; // All | 1-10 | 1-20 | 10-20 | 20-50 | 50+ | Custom
  final TextEditingController minWeightController =
  TextEditingController(text: "0");
  final TextEditingController maxWeightController =
  TextEditingController(text: "100");

  final TextEditingController searchController = TextEditingController();

  /// 🔍 Appbar ma search chalu chhe?
  bool _showSearch = false;
  final FocusNode _searchFocus = FocusNode();

  final List<String> itemOptions = ["All Items"];

  final List<String> stockStatusOptions = ["All", "In Stock", "Out Stock"];

  final List<String> imageStatusOptions = [
    "All",
    "With Image",
    "Without Image",
  ];

  /// =========================================================
  /// DATA STATE
  /// =========================================================

  bool isLoading = false;
  bool isLoadingMore = false;

  /// =========================================================
  /// 🔥 BRANCH REPORTS (Sale Summary jevu j)
  /// =========================================================

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View Report" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe? (true hoy to management_branches[] jay)
  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// Apply thayeli branches na slug → "a,b" (comma encode nahi)
  String get _slugs => branchCompanies
      .where((c) => appliedCompanyIds.contains(c.id))
      .map((c) => Uri.encodeQueryComponent(c.slug ?? c.id.toString()))
      .join(",");

  /// management_branches[]=9&management_branches[]=20 (apply thayeli ids)
  String get _branchQuery => appliedCompanyIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// add &management_branches[]=.. to a gallery url (branch mode only)
  String _br(String url) => _branchMode
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// =========================================================
  /// 🔥 BRANCH MERGE API
  /// stock-gallery?page=1&management_branches[]=9&management_branches[]=20
  /// =========================================================

  static const int _branchPerPage = 24;

  /// Gallery nu page url — branch hoy to management_branches[] umerai
  String _galleryPageUrl(int page) =>
      _br("${ApiConstants.stock_gallery}?page=$page");

  /// Response alag alag shape ma aave to pan chale
  /// (data[] / data.data[] / rows / items + pagination / meta / recordsFiltered)
  ({
  List<Map<String, dynamic>> items,
  int current,
  int last,
  int total,
  int perPage,
  }) _parseGallery(Map body, int requestedPage) {
    final dynamic data = body["data"];

    // ---- items ----
    List raw = [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      final dynamic inner = data["data"] ?? data["rows"] ?? data["items"];
      if (inner is List) raw = inner;
    } else if (body["rows"] is List) {
      raw = body["rows"];
    } else if (body["items"] is List) {
      raw = body["items"];
    }

    final List<Map<String, dynamic>> items = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // ---- pagination ----
    Map? meta;
    if (body["pagination"] is Map) {
      meta = body["pagination"];
    } else if (body["meta"] is Map) {
      meta = body["meta"];
    } else if (data is Map && data["current_page"] != null) {
      meta = data;
    } else if (data is Map && data["pagination"] is Map) {
      meta = data["pagination"];
    }

    int? toInt(dynamic v) => int.tryParse("${v ?? ""}");

    final int per = toInt(meta?["per_page"]) ??
        toInt(body["per_page"]) ??
        (_branchMode ? _branchPerPage : 24);

    // ✅ Total direct API mathi (recordsFiltered / pagination.total)
    final int? total = toInt(body["recordsFiltered"]) ??
        toInt(body["recordsTotal"]) ??
        toInt(meta?["total"]) ??
        toInt(body["total"]) ??
        (data is Map ? toInt(data["total"]) : null);

    final int current = toInt(meta?["current_page"]) ?? requestedPage;

    int last = toInt(meta?["last_page"]) ?? 0;
    if (last <= 0) {
      if (total != null && per > 0) {
        last = (total / per).ceil();
      } else {
        // khabar nathi → puru page aavyu to haju aagal hoi shake
        last = items.length >= per ? requestedPage + 1 : requestedPage;
      }
    }
    if (last < 1) last = 1;

    return (
    items: items,
    current: current,
    last: last,
    total: total ?? 0,
    perPage: per,
    );
  }

  /// Merge ma 2 branch nu same id hoi shake → company_id sathe key
  String _itemKey(Map e) => "${e["company_id"] ?? ""}|${e["id"]}";

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

  /// Main company nu id (branch list mathi)
  int? get _mainCompanyId {
    for (final c in branchCompanies) {
      if (c.isMain) return c.id;
    }
    return null;
  }

  /// ✅ Aa item main company no chhe? (fakt eni j image upload / edit)
  /// Branch list j na hoy (branch user) to potano j data → true
  bool _isMainData(Map item) {
    final int? mainId = _mainCompanyId;
    if (mainId == null) return true;

    final int? id = int.tryParse("${item["company_id"] ?? ""}");
    if (id != null) return id == mainId;

    // company_id na aave to branch na naam thi
    final String br = _branchOf(item).trim().toLowerCase();
    if (br.isEmpty) return true;
    for (final c in branchCompanies) {
      if (c.name.trim().toLowerCase() == br) return c.isMain;
    }
    return true;
  }

  List<Map<String, dynamic>> stockItems = [];

  Set<String> selectedIds = {};

  /// =========================================================
  /// 🔥 PER-ITEM IMAGE UPLOAD (upload + rotate/crop/reset)
  /// =========================================================

  final ImagePicker _stockImagePicker = ImagePicker();

  File? _stockSelectedImageFile;
  File? _stockOriginalImageFile;

  Uint8List? _bgRemovedPng; // transparent PNG (remove pachi)
  Color? _bgColor = const Color(0xffFFFFFF); // null = transparent PNG
  double _bgStrength = 32;
  bool _bgShadow = true;
  bool _bgBusy = false;

  /// Jewellery mate premium background rang
  static const List<Color?> _bgPalette = [
    null, // Transparent (PNG)
    Color(0xffFFFFFF), // White
    Color(0xffFBF8F1), // Ivory
    Color(0xffF3E5C8), // Champagne
    Color(0xffF6E1E3), // Blush
    Color(0xffE6EEF6), // Mist blue
    Color(0xff141414), // Velvet black
    Color(0xff5A1220), // Maroon
    Color(0xff0F3D2E), // Emerald
    Color(0xff14234B), // Royal blue
  ];

  /// =========================================================
  /// 🔥 FAST + HD SHARE / DOWNLOAD SETTINGS
  ///
  /// - Ek j Dio reuse thay (connection keep-alive → fast)
  /// - 4 images ek saathe (parallel) prepare thay
  /// - Moti image 1600px sudhi, nani image 1080px sudhi
  /// =========================================================

  final Dio _shareDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// 4 images ek saathe (moti HD image → memory safe)
  static const int _shareConcurrency = 4;

  /// 🔥 HD share — moti image 1600px sudhi j nani thay
  static const int _shareMaxWidth = 1920;

  /// 🔥 Nani image ochhama ochhi 1080px par render (caption text sharp rahe)
  static const int _shareMinWidth = 1920;

  /// Caption design version — design badlay tyare ++ karo, etle juni
  /// cache vaali (low quality) images farithi navi HD ma bane
  static const int _captionVersion = 6;

  /// =========================================================
  /// 🚀 BACKGROUND PRE-PREPARE (WARM-UP)
  ///
  /// User item select kare e j vakhte image background ma
  /// taiyar thava lage. WhatsApp button dabave tyare moti
  /// bhaage images already ready hoy → share lagbhag instant.
  ///
  /// _prepTasks: cacheKey → Future (same item 2 vaar na bane)
  /// _prepQueue: worker pool (max _shareConcurrency ek saathe)
  /// =========================================================

  final Map<String, Future<XFile?>> _prepTasks = {};
  final List<Future<void> Function()> _prepQueue = [];
  int _prepActive = 0;
  bool _isDisposed = false;

  late final Future<Directory> _shareCacheDirFuture = _getShareCacheDir();

  /// =========================================================
  /// 🔥 FILTER MATE BADHA PAGES LOAD
  ///
  /// Data 24-24 na pages ma aave che ane filter Flutter side
  /// par thay che. Filter active thata j baki na badha pages
  /// automatic load thay che → badhi matching items dekhay.
  /// =========================================================

  Future<bool>? _loadAllFuture; // ek saathe 2 vaar load na thay
  bool _isLoadingAll = false; // background page loading chalu che?
  Timer? _searchDebounce;

  /// Background loading no progress text (Select All dialog ma vaprase)
  final ValueNotifier<String> _loadProgress = ValueNotifier("");

  /// Ek saathe ketla pages parallel fetch karva
  static const int _pageBatchSize = 4;

  /// =========================================================
  /// 🔥 FILTERED LIST CACHE
  /// =========================================================

  List<Map<String, dynamic>>? _filteredCache;
  String _filteredCacheKey = "";
  int _dataRev = 0; // item data badlay (e.g. image upload) tyare ++

  /// =========================================================
  /// PAGINATION
  /// =========================================================

  int currentPage = 1;
  int lastPage = 1;
  int totalItemsFromApi = 0;
  int perPage = 24;

  /// =========================================================
  /// SCROLL CONTROLLER + FLOATING "SCROLL TO TOP" BUTTON
  /// =========================================================

  final ScrollController _scrollController = ScrollController();

  bool _showScrollToTop = false;

  static const double _scrollToTopThreshold = 400;

  void _onScroll() {
    final double offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0;

    final bool shouldShow = offset > _scrollToTopThreshold;

    if (shouldShow != _showScrollToTop) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  /// =========================================================
  /// INIT
  /// =========================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      Provider.of<ItemProvider>(context, listen: false).loadItems();
    });
    Future.microtask(() => fetchStockGallery());
    _loadBranches();

    /// 🔥 Juni share cache (2 divas thi juni) saaf karo
    _trimShareCache();
  }

  /// =========================================================
  /// 🔥 SHARE CACHE HELPERS
  /// =========================================================

  /// Stable hash — app restart pachi pan same rahe (cache key mate)
  String _stableHash(String input) {
    int hash = 0x811c9dc5;

    for (final int c in input.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash.toRadixString(16);
  }

  Future<Directory> _getShareCacheDir() async {
    final Directory tmp = await getTemporaryDirectory();

    final Directory dir = Directory("${tmp.path}/wa_share_cache");

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<void> _trimShareCache() async {
    try {
      final Directory dir = await _getShareCacheDir();

      final DateTime limit = DateTime.now().subtract(const Duration(days: 2));

      await for (final FileSystemEntity f in dir.list()) {
        if (f is File && (await f.lastModified()).isBefore(limit)) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint("⚠️ SHARE CACHE TRIM ERROR => $e");
    }
  }

  /// =========================================================
  /// 🔥 KOI PAN FILTER / SORT ACTIVE CHE?
  /// =========================================================

  bool get _hasActiveFilter =>
      selectedItem != "All Items" ||
          itemKeyword != null ||
          selectedStockStatus != "All" ||
          selectedImageStatus != "All" ||
          searchController.text.trim().isNotEmpty ||
          selectedWeightRange != "All" ||
          sortByWeight != "Default";

  /// =========================================================
  /// 🔥 FILTER ACTIVE HOY TO BAAKI NA PAGES BACKGROUND MA LOAD
  /// =========================================================

  Future<void> _ensureAllPagesForFilter() async {
    if (!_hasActiveFilter) return;
    if (currentPage >= lastPage) return;

    final bool ok = await _loadAllRemainingPages();

    if (!ok && mounted) {
      AppMessage.error(
        context,
        "Some pages could not be loaded. Showing loaded items only.",
      );
    }
  }

  /// =========================================================
  /// FILTERED LIST
  /// =========================================================

  List<Map<String, dynamic>> get filteredStockItems {
    final String key = [
      selectedItem,
      itemKeyword ?? "",
      selectedStockStatus,
      selectedImageStatus,
      searchController.text.trim().toLowerCase(),
      selectedWeightRange,
      minWeightController.text,
      maxWeightController.text,
      sortByWeight,
      stockItems.length,
      identityHashCode(stockItems),
      _dataRev,
    ].join("|");

    if (_filteredCache != null && key == _filteredCacheKey) {
      return _filteredCache!;
    }

    _filteredCacheKey = key;
    _filteredCache = _computeFilteredStockItems();
    return _filteredCache!;
  }

  List<Map<String, dynamic>> _computeFilteredStockItems() {
    final String search = searchController.text.trim().toLowerCase();

    /// 🔍 Item dropdown keyword (lowercase)
    final String? keyword = itemKeyword?.trim().toLowerCase();

    List<Map<String, dynamic>> result = stockItems.where((item) {
      /// ITEM FILTER
      /// keyword hoy → naam ma keyword hoy evi badhi items (e.g. "watch")
      /// nahi to → select karel ek item (athva All Items)
      final String itemName = item["item_name"]?.toString() ?? "";

      final bool itemMatch = (keyword != null && keyword.isNotEmpty)
          ? itemName.toLowerCase().contains(keyword)
          : (selectedItem == "All Items" || itemName == selectedItem);

      if (!itemMatch) {
        return false;
      }

      /// STOCK STATUS FILTER
      final String stockStatus =
          item["stock_status"]?.toString().trim().toLowerCase() ?? "";

      final String selectedStockStatusNormalized = selectedStockStatus
          .trim()
          .toLowerCase();

      final bool stockMatch =
          selectedStockStatus == "All" ||
              stockStatus == selectedStockStatusNormalized;

      if (!stockMatch) {
        return false;
      }

      /// IMAGE STATUS FILTER
      final dynamic rawHasImage = item["has_image"];

      final String rawHasImageStr = rawHasImage
          ?.toString()
          .trim()
          .toLowerCase() ?? "";

      final bool hasImageFlag =
          rawHasImage == true ||
              rawHasImageStr == "true" ||
              rawHasImageStr == "1" ||
              rawHasImageStr == "yes";

      final bool hasImageUrl =
          item["image_url"] != null &&
              item["image_url"].toString().trim().isNotEmpty;

      final bool hasImage = hasImageFlag || hasImageUrl;

      bool imageMatch = true;

      if (selectedImageStatus == "With Image") {
        imageMatch = hasImage;
      } else if (selectedImageStatus == "Without Image") {
        imageMatch = !hasImage;
      }

      if (!imageMatch) {
        return false;
      }

      /// SEARCH FILTER
      if (search.isEmpty) {
        return true;
      }

      final String searchableText = [
        item["item_name"],
        item["label_code"],
        item["qr_code"],
        item["huid"],
      ].map((value) => value?.toString().toLowerCase() ?? "").join(" ");

      return searchableText.contains(search);
    }).toList();

    /// 🔥 WEIGHT RANGE FILTER
    result = result.where((item) {
      final double wt =
          double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0;

      switch (selectedWeightRange) {
        case "1-10":
          return wt >= 1 && wt <= 10;
        case "1-20":
          return wt >= 1 && wt <= 20;
        case "10-20":
          return wt >= 10 && wt <= 20;
        case "20-50":
          return wt >= 20 && wt <= 50;
        case "50+":
          return wt >= 50;
        case "Custom":
          final double minW =
              double.tryParse(minWeightController.text.trim()) ?? 0;
          final double maxW =
              double.tryParse(maxWeightController.text.trim()) ??
                  double.infinity;
          return wt >= minW && wt <= maxW;
        case "All":
        default:
          return true;
      }
    }).toList();

    /// 🔥 SORT BY WEIGHT
    if (sortByWeight == "Low") {
      result.sort((a, b) {
        final double wa =
            double.tryParse(a["net_weight"]?.toString() ?? "0") ?? 0;
        final double wb =
            double.tryParse(b["net_weight"]?.toString() ?? "0") ?? 0;
        return wa.compareTo(wb);
      });
    } else if (sortByWeight == "High") {
      result.sort((a, b) {
        final double wa =
            double.tryParse(a["net_weight"]?.toString() ?? "0") ?? 0;
        final double wb =
            double.tryParse(b["net_weight"]?.toString() ?? "0") ?? 0;
        return wb.compareTo(wa);
      });
    }

    return result;
  }

  /// =========================================================
  /// API CALL
  /// =========================================================

  Future<void> fetchStockGallery({bool loadMore = false}) async {
    if (loadMore) {
      if (isLoadingMore) {
        return;
      }

      if (currentPage >= lastPage) {
        debugPrint("⚠️ Already on last page");
        return;
      }

      setState(() {
        isLoadingMore = true;
      });
    } else {
      setState(() {
        isLoading = true;
        currentPage = 1;
      });
    }

    final int requestedPage = loadMore ? currentPage + 1 : 1;

    debugPrint("======================================");
    debugPrint("📤 STOCK GALLERY REQUEST");
    debugPrint("PAGE => $requestedPage");
    debugPrint("STOCK FILTER => $selectedStockStatus");
    debugPrint("IMAGE FILTER => $selectedImageStatus");
    debugPrint("SEARCH => ${searchController.text.trim()}");
    debugPrint("======================================");

    try {
      final String endpoint = _galleryPageUrl(requestedPage);

      debugPrint("🌐 STOCK GALLERY URL => $endpoint");

      final response = await ApiHelper().getRequest(endpoint);

      final dynamic body = response?.data;

      if (response != null && response.statusCode == 200 && body is Map) {
        final Map<String, dynamic> responseData =
        Map<String, dynamic>.from(body);

        // success key na aave (branch report) to pan data chale
        final bool success = responseData["success"] != false;

        if (success) {
          final parsed = _parseGallery(responseData, requestedPage);
          final List<Map<String, dynamic>> newItems = parsed.items;

          currentPage = parsed.current;
          lastPage = parsed.last;
          perPage = parsed.perPage;
          totalItemsFromApi = parsed.total;

          if (!loadMore) {
            stockItems = newItems;
          } else {
            final Set<String> have = stockItems.map(_itemKey).toSet();
            stockItems.addAll(newItems.where((e) => have.add(_itemKey(e))));
          }

          // Total na aave to je load thaya e j
          if (totalItemsFromApi < stockItems.length &&
              currentPage >= lastPage) {
            totalItemsFromApi = stockItems.length;
          }

          debugPrint("======================================");
          debugPrint("✅ STOCK GALLERY SUCCESS");
          debugPrint("CURRENT PAGE => $currentPage");
          debugPrint("LAST PAGE    => $lastPage");
          debugPrint("PER PAGE     => $perPage");
          debugPrint("TOTAL        => $totalItemsFromApi");
          debugPrint("NEW ITEMS    => ${newItems.length}");
          debugPrint("TOTAL LOADED => ${stockItems.length}");
          debugPrint("FILTERED     => ${filteredStockItems.length}");
          debugPrint("======================================");

          if (mounted) {
            setState(() {});
          }
        } else {
          debugPrint("❌ STOCK GALLERY success=false");

          if (!loadMore && mounted) {
            AppMessage.error(
              context,
              responseData["message"]?.toString() ??
                  "Failed to load stock gallery",
            );
          }
        }
      } else {
        debugPrint("❌ STOCK GALLERY STATUS => ${response?.statusCode}");

        if (!loadMore && mounted) {
          AppMessage.success(context, "Failed to load stock gallery");
        }
      }
    } catch (e) {
      debugPrint("❌ STOCK GALLERY ERROR => $e");

      if (!loadMore && mounted) {
        AppMessage.success(context, "Failed to load stock gallery");
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  /// =========================================================
  /// DERIVED SUMMARY VALUES
  /// =========================================================

  int get totalItems => filteredStockItems.length;

  int get inStockCount => filteredStockItems
      .where((e) => e["stock_status"]?.toString() == "In Stock")
      .length;

  int get outStockCount => filteredStockItems
      .where((e) => e["stock_status"]?.toString() == "Out Stock")
      .length;

  int get withImageCount => filteredStockItems
      .where(
        (e) =>
    e["has_image"] == true ||
        (e["image_url"] != null &&
            e["image_url"].toString().trim().isNotEmpty),
  )
      .length;

  int get withoutImageCount => filteredStockItems.length - withImageCount;

  double get grossWt => filteredStockItems.fold(
    0.0,
        (sum, e) =>
    sum + (double.tryParse(e["gross_weight"]?.toString() ?? "0") ?? 0),
  );

  double get otherWt => filteredStockItems.fold(
    0.0,
        (sum, e) =>
    sum + (double.tryParse(e["other_weight"]?.toString() ?? "0") ?? 0),
  );

  double get netWt => filteredStockItems.fold(
    0.0,
        (sum, e) =>
    sum + (double.tryParse(e["net_weight"]?.toString() ?? "0") ?? 0),
  );

  /// =========================================================
  /// BUILD
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    final List<Map<String, dynamic>> visibleItems = filteredStockItems;

    return Scaffold(
      backgroundColor: AppColors.background,

      /// 🔥 FLOATING SCROLL-TO-TOP BUTTON
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
        onPressed: _scrollToTop,
        backgroundColor: AppColors.primaryDark,
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
        ),
      )
          : null,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await fetchStockGallery();

            // Refresh pachi filter active hoy to farithi badha pages
            await _ensureAllPagesForFilter();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              /// 🏢 BRANCH REPORT
              SliverToBoxAdapter(child: _buildBranchCard()),

              SliverToBoxAdapter(child: _buildFilterCard(isMobile)),

              SliverToBoxAdapter(child: _buildSummaryRow()),

              SliverToBoxAdapter(child: _buildActionButtons(isMobile)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingAll
                            ? "$totalItems item(s) found • loading more pages..."
                            : "$totalItems item(s) loaded"
                            "${totalItemsFromApi > 0 ? " / $totalItemsFromApi" : ""}",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_isLoadingAll) ...[
                        const SizedBox(height: 6),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    ],
                  ),
                ),
              ),

              if (isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (visibleItems.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        _isLoadingAll
                            ? "Searching in remaining pages..."
                            : stockItems.isEmpty
                            ? "No Items Found"
                            : "No Items Found for selected filter",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _stockCard(visibleItems[index]);
                      }, childCount: visibleItems.length),
                    ),
                  ),

                  SliverToBoxAdapter(child: _buildLoadMoreButton()),
                ],

              if (!isLoading &&
                  visibleItems.isEmpty &&
                  stockItems.isNotEmpty &&
                  currentPage < lastPage)
                SliverToBoxAdapter(child: _buildLoadMoreButton()),
            ],
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes)
  /// stock_gallery?management_branches[]=9&management_branches[]=20&export=pdf
  /// =========================================================

  static String get _exportUrl => ApiConstants.stock_gallery;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // Gallery ma je branch chhe e j export ma pan (management_branches[])
      final String base = _br(_exportUrl);
      final String url = "$base${base.contains('?') ? '&' : '?'}export=$type";
      debugPrint("📤 EXPORT $type URL => $url");

      final response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (response == null || response.statusCode != 200) {
        AppMessage.error(
          context,
          _exportError(response?.data) ??
              "Failed to download ${type == 'pdf' ? 'PDF' : 'Excel'}",
        );
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // Bytes ni jagya e JSON error aave to
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        AppMessage.error(
          context,
          _exportError(raw) ?? "No file received from server",
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final String stamp =
          "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}";
      final String ext = type == "pdf" ? "pdf" : "xlsx";
      final file = File("${dir.path}/Stock_Gallery_$stamp.$ext");
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      AppMessage.success(
          context, "${type == 'pdf' ? 'PDF' : 'Excel'} downloaded");
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ EXPORT $type ERROR => $e");
      if (mounted) AppMessage.error(context, "Download failed");
    } finally {
      if (mounted) setState(() => _exporting = null);
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

  Widget _exportBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool busy,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _exporting != null ? null : onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          // Loader fakt ApiHelper nu j (button ma spinner nahi)
          child: Opacity(
            opacity: busy ? 0.5 : 1,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }


  /// =========================================================
  /// 🔥 LOAD BRANCHES (Sale Summary jevu j)
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

        // Main company + ek branch hoy tyare j tab dekhay
        canViewBranches = list.length > 1;

        // Default: main company select
        selectedCompanyIds = {
          if (overview.mainCompany != null) overview.mainCompany!.id,
        };
      });
    } catch (e) {
      // Branch access nathi (branch user / staff) → tab nahi dekhay
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// Gallery farithi page 1 thi (selection + list reset)
  Future<void> _reloadGallery() async {
    setState(() {
      selectedIds.clear();
      stockItems = [];
      currentPage = 1;
      lastPage = 1;
      totalItemsFromApi = 0;
      _filteredCache = null;
      _dataRev++;
    });
    await fetchStockGallery();
    await _ensureAllPagesForFilter();
  }

  /// 🔥 VIEW REPORT — fakt select kareli branches
  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }

    setState(() {
      appliedCompanyIds = selectedCompanyIds.toList();
      branchReportLoading = true;
    });

    try {
      await _reloadGallery();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadGallery();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab) — Sale Summary jevu j
  // ============================================================

  Widget _buildBranchCard() {
    if (branchesLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.all(14),
        decoration: _branchCardDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Loading branches...",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList =
    branchCompanies.where((c) => selectedCompanyIds.contains(c.id)).toList();

    final bool appliedDiffers = appliedCompanyIds.toSet().length !=
        selectedCompanyIds.length ||
        !appliedCompanyIds.toSet().containsAll(selectedCompanyIds);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: _branchCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- HEADER (tap = expand) ----------------
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Branch Reports",
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedCompanyIds.length}/${branchCompanies.length}",
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: branchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryDark,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
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
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Select one or more branches to combine their stock gallery.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _viewReportButton(highlight: appliedDiffers),

                  // Branch report chalu hoy tyare info + clear
                  if (_branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff16A34A).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xff16A34A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xff16A34A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing combined stock of "
                                  "${appliedCompanyIds.length} "
                                  "${appliedCompanyIds.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff166534),
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
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xffD32F2F),
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
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.isMain ? Icons.verified_rounded : c.type.icon,
            size: 13,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _companyLabel(c),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => setState(() => selectedCompanyIds.remove(c.id)),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewReportButton({required bool highlight}) {
    return InkWell(
      onTap: branchReportLoading ? null : viewBranchReport,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff22C55E), Color(0xff16A34A)],
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color:
              const Color(0xff16A34A).withOpacity(highlight ? 0.35 : 0.15),
              blurRadius: highlight ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: branchReportLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_rounded, size: 17, color: Colors.white),
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
    );
  }

  /// 🔥 Multi-select bottom sheet
  Future<void> _openBranchPicker() async {
    final Set<int> temp = {...selectedCompanyIds};

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                        color: Colors.grey.shade300,
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
                                color: Color(0xff172033),
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
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: branchCompanies.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade200,
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
                                      color: AppColors.primaryDark
                                          .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      c.isMain
                                          ? Icons.verified_rounded
                                          : c.type.icon,
                                      size: 17,
                                      color: AppColors.primaryDark,
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
                                            color: Color(0xff172033),
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
                                                ? Colors.grey.shade600
                                                : Colors.red.shade400,
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
                                          ? AppColors.gradientBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: checked
                                            ? AppColors.gradientBlue
                                            : Colors.grey.shade400,
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
                                side: BorderSide(color: AppColors.border),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
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
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark,
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

  BoxDecoration _branchCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// =========================================================
  /// LOAD MORE BUTTON
  /// =========================================================

  Widget _buildLoadMoreButton() {
    // Background ma pages aavi rahya hoy to button ni jagya e status
    if (_isLoadingAll) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            ValueListenableBuilder<String>(
              valueListenable: _loadProgress,
              builder: (_, value, __) => Text(
                value.isEmpty ? "Loading more..." : value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (currentPage >= lastPage) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 25),
        child: Center(
          child: Text(
            "All items loaded",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 25),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isLoadingMore
              ? null
              : () {
            fetchStockGallery(loadMore: true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gradientBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isLoadingMore
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
            "Load More",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// HEADER
  /// =========================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      color: AppColors.white,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(5),
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
            child: _showSearch
                ? _appbarSearchField()
                : const Text(
              "Stock Gallery",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(width: 6),

          /// 🔍 SEARCH ICON — appbar ma search khule / bandh thay
          InkWell(
            onTap: _toggleSearch,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _showSearch
                    ? AppColors.primaryDark
                    : AppColors.primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
                color: _showSearch ? Colors.white : AppColors.primaryDark,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 5),


          /// ✅ EXCEL + PDF (branch wise)
          // _exportBtn(
          //   icon: Icons.table_chart_rounded,
          //   color: const Color(0xff16A34A),
          //   tooltip: "Excel",
          //   busy: _exporting == "excel",
          //   onTap: () => _export("excel"),
          //   isMobile: MediaQuery.of(context).size.width < 600,
          // ),
          // const SizedBox(width: 5),
          // _exportBtn(
          //   icon: Icons.picture_as_pdf_rounded,
          //   color: const Color(0xffDC2626),
          //   tooltip: "PDF",
          //   busy: _exporting == "pdf",
          //   onTap: () => _export("pdf"),
          //   isMobile: MediaQuery.of(context).size.width < 600,
          // ),
          // const SizedBox(width: 5),

          if (!_showSearch) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                "Selected: ${selectedIds.length}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ),

            const SizedBox(width: 5),
          ],

          /// 🔥 FILTER & SORT ICON — opens bottom sheet
          InkWell(
            onTap: _openFilterSortSheet,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.primaryDark,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// 🔥 FILTER & SORT BOTTOM SHEET
  /// =========================================================

  InputDecoration _weightInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gold),
      ),
    );
  }

  Widget _weightInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: _weightInputDecoration(),
        ),
      ],
    );
  }

  void _openFilterSortSheet() {
    String tempSort = sortByWeight;
    String tempRange = selectedWeightRange;

    final TextEditingController tempMinController =
    TextEditingController(text: minWeightController.text);
    final TextEditingController tempMaxController =
    TextEditingController(text: maxWeightController.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// DRAG HANDLE
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: _divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    /// TITLE ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter & Sort",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(sheetContext),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              color: _inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    /// SORT BY WEIGHT
                    const Text(
                      "Sort By Weight",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sortChip("Default", "Default", tempSort,
                                () => setSheetState(() => tempSort = "Default")),
                        _sortChip("Low → High", "Low", tempSort,
                                () => setSheetState(() => tempSort = "Low")),
                        _sortChip("High → Low", "High", tempSort,
                                () => setSheetState(() => tempSort = "High")),
                      ],
                    ),

                    const SizedBox(height: 22),

                    /// WEIGHT RANGE
                    const Text(
                      "Weight Range",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _weightRangeChip("All", "All", tempRange,
                                () => setSheetState(() => tempRange = "All")),
                        _weightRangeChip("1 – 10 gm", "1-10", tempRange,
                                () => setSheetState(() => tempRange = "1-10")),
                        _weightRangeChip("1 – 20 gm", "1-20", tempRange,
                                () => setSheetState(() => tempRange = "1-20")),
                        _weightRangeChip("10 – 20 gm", "10-20", tempRange,
                                () => setSheetState(() => tempRange = "10-20")),
                        _weightRangeChip("20 – 50 gm", "20-50", tempRange,
                                () => setSheetState(() => tempRange = "20-50")),
                        _weightRangeChip("50+ gm", "50+", tempRange,
                                () => setSheetState(() => tempRange = "50+")),
                        _weightRangeChip("Custom", "Custom", tempRange,
                                () => setSheetState(() => tempRange = "Custom")),
                      ],
                    ),

                    /// CUSTOM WEIGHT RANGE INPUT
                    if (tempRange == "Custom") ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.hourglass_bottom_rounded,
                                  size: 16,
                                  color: _inkSoft,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Custom Weight Range",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: _weightInput(
                                      "Min Weight", tempMinController),
                                ),
                                const Padding(
                                  padding:
                                  EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    "—",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _weightInput(
                                      "Max Weight", tempMaxController),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              "Enter net weight range in grams",
                              style: TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    /// RESET + APPLY FILTER
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempSort = "Default";
                                tempRange = "All";
                                tempMinController.text = "0";
                                tempMaxController.text = "100";
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: _divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Reset",
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                sortByWeight = tempSort;
                                selectedWeightRange = tempRange;
                                minWeightController.text =
                                    tempMinController.text;
                                maxWeightController.text =
                                    tempMaxController.text;
                                selectedIds.clear();
                              });

                              Navigator.pop(sheetContext);

                              // 🔥 weight filter/sort → badha pages
                              _ensureAllPagesForFilter();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ink,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Apply Filter",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      tempMinController.dispose();
      tempMaxController.dispose();
    });
  }

  /// =========================================================
  /// SORT CHIP
  /// =========================================================

  Widget _sortChip(
      String label,
      String value,
      String current,
      VoidCallback onTap,
      ) {
    final bool selected = current == value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _ink : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _ink : _divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _inkSoft,
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// WEIGHT RANGE CHIP
  /// =========================================================

  Widget _weightRangeChip(
      String label,
      String value,
      String current,
      VoidCallback onTap,
      ) {
    final bool selected = current == value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _gold.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _gold : _divider,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: _gold),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? _ink : _inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// FILTER CARD
  /// =========================================================

  Widget _buildFilterCard(bool isMobile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ROW 1 — ITEM (puri width)
          Consumer<ItemProvider>(
            builder: (context, provider, child) {
              final List<Map<String, dynamic>> allItems = provider.items
                  .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e))
                  .toList();

              /// ✅ Fakt jobwork_item_type = "finish" vali items
              /// (API ma e field j na aave to badhi items rahe)
              final bool hasType =
              allItems.any((e) => e.containsKey("jobwork_item_type"));

              final List<Map<String, dynamic>> itemList = hasType
                  ? allItems
                  .where((e) =>
              (e["jobwork_item_type"] ?? "")
                  .toString()
                  .trim()
                  .toLowerCase() ==
                  "finish")
                  .toList()
                  : allItems;

              /// 🔍 Keyword search chalu hoy to field ma "Search: watch" dekhay
              final Map<String, dynamic>? keywordEntry = itemKeyword == null
                  ? null
                  : {
                "id": "__search__",
                "item_name": "Search: $itemKeyword",
              };

              final List<Map<String, dynamic>> dropdownItems = [
                {"id": "all", "item_name": "All Items"},
                if (keywordEntry != null) keywordEntry,
                ...itemList,
              ];

              Map<String, dynamic>? selectedItemData;

              if (keywordEntry != null) {
                selectedItemData = keywordEntry;
              } else {
                try {
                  selectedItemData = dropdownItems.firstWhere(
                        (item) =>
                    item["item_name"]?.toString() == selectedItem,
                  );
                } catch (_) {
                  selectedItemData = dropdownItems.first;
                }
              }

              return PremiumSearchableDropdown<Map<String, dynamic>>(
                label: "Item",
                hint: "Select Item",
                items: dropdownItems,
                value: selectedItemData,
                prefixIcon: Icons.inventory_2_outlined,
                itemLabel: (item) {
                  return item["item_name"]?.toString() ?? "-";
                },
                searchText: (item) {
                  return [
                    item["item_name"]?.toString() ?? "",
                    item["item_code"]?.toString() ?? "",
                  ].join(" ");
                },

                /// 🔥 KEYBOARD SEARCH BUTTON
                /// "watch" lakhi ne search dabavo → naam ma "watch"
                /// hoy evi badhi stock items grid ma
                onSearchSubmitted: (query) {
                  setState(() {
                    itemKeyword = query.trim();
                    selectedItem = "All Items";
                    selectedIds.clear();
                  });

                  // 🔥 baki na badha pages load → badhi matching items
                  _ensureAllPagesForFilter();
                },

                onChanged: (selectedData) {
                  // "Search: ..." entry fari select kare to kai nahi
                  if (selectedData?["id"] == "__search__") return;

                  setState(() {
                    itemKeyword = null; // 🔥 keyword search bandh
                    selectedItem =
                        selectedData?["item_name"]?.toString() ??
                            "All Items";
                    selectedIds.clear();
                  });

                  // 🔥 category select → badha pages load
                  _ensureAllPagesForFilter();
                },
              );
            },
          ),

          const SizedBox(height: 10),

          /// ROW 2 — STOCK STATUS + IMAGE STATUS
          /// (Search have appbar ma chhe)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _filterDropdown(
                  "Stock Status",
                  stockStatusOptions,
                  selectedStockStatus,
                      (v) {
                    if (v == null) return;

                    setState(() {
                      selectedStockStatus = v;
                      selectedIds.clear();
                    });

                    _ensureAllPagesForFilter();
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _filterDropdown(
                  "Image Status",
                  imageStatusOptions,
                  selectedImageStatus,
                      (v) {
                    if (v == null) return;

                    setState(() {
                      selectedImageStatus = v;
                      selectedIds.clear();
                    });

                    _ensureAllPagesForFilter();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// APPLY + SELECT ALL + RESET + 📷 IMAGE SEARCH
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Expanded(
              //   child: _actionChip(
              //     label: "Apply",
              //     fillWidth: true,
              //     color: const Color(0xffE53E5A),
              //     onTap: () {
              //       setState(() {
              //         selectedIds.clear();
              //       });
              //
              //       debugPrint("✅ LOCAL FILTER APPLIED");
              //       debugPrint("Item => $selectedItem");
              //       debugPrint("Stock => $selectedStockStatus");
              //       debugPrint("Image => $selectedImageStatus");
              //       debugPrint("Search => ${searchController.text}");
              //       debugPrint("Visible => ${filteredStockItems.length}");
              //
              //       _ensureAllPagesForFilter();
              //     },
              //   ),
              // ),
              //
              // const SizedBox(width: 10),

              Expanded(
                child: _actionChip(
                  label: "Select All",
                  fillWidth: true,
                  color: const Color(0xff2FAE60),
                  onTap: _selectAllInStockWithImage,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _actionChip(
                  label: "Reset",
                  fillWidth: true,
                  color: AppColors.gradientBlue,
                  onTap: () {
                    setState(() {
                      selectedItem = "All Items";
                      itemKeyword = null; // 🔥 keyword search pan clear
                      selectedStockStatus = "All";
                      selectedImageStatus = "All";
                      searchController.clear();
                      selectedIds.clear();

                      sortByWeight = "Default";
                      selectedWeightRange = "All";
                      minWeightController.text = "0";
                      maxWeightController.text = "100";
                    });
                  },
                ),
              ),

              const SizedBox(width: 10),

              /// 📷 IMAGE SEARCH
              Tooltip(
                message: "Search by Image",
                child: InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageSearchScreen(
                          // Branch merge hoy to e j branches ma search
                          pageUrl: _galleryPageUrl,
                          // Result par click → gallery search ma e item
                          onItemTap: (item) async {
                            final String code = (item["label_code"] ??
                                item["qr_code"] ??
                                item["item_name"] ??
                                "")
                                .toString()
                                .trim();
                            if (code.isEmpty || code == "null") return;

                            setState(() {
                              _showSearch = true;
                              searchController.text = code;
                              selectedIds.clear();
                            });
                            await _ensureAllPagesForFilter();
                          },
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    width: 40,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.primaryDark.withOpacity(0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.image_search_rounded,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// FILTER DROPDOWN
  /// =========================================================

  Widget _filterDropdown(
      String label,
      List<String> options,
      String value,
      ValueChanged<String?> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 5),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black45,
              ),
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              items: options
                  .map(
                    (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
              )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// =========================================================
  /// SEARCH
  /// =========================================================

  /// 🔍 Search khol / bandh (bandh thay tyare search clear)
  void _toggleSearch() {
    if (_showSearch) {
      final bool hadText = searchController.text.trim().isNotEmpty;
      _searchDebounce?.cancel();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _showSearch = false;
        if (hadText) {
          searchController.clear();
          selectedIds.clear();
        }
      });
    } else {
      setState(() => _showSearch = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  void _onSearchChanged(String _) {
    setState(() {
      selectedIds.clear();
    });

    // 🔥 typing band thay pachi silent ma badha pages
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
          () => _ensureAllPagesForFilter(),
    );
  }

  /// 🔍 APPBAR SEARCH FIELD (title ni jagya e)
  Widget _appbarSearchField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.black87, fontSize: 13.5),
        onChanged: _onSearchChanged,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: "Search item, label, QR, HUID",
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search,
            size: 19,
            color: Colors.black45,
          ),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 34, minHeight: 34),
          suffixIcon: searchController.text.isNotEmpty
              ? InkWell(
            onTap: () {
              setState(() {
                searchController.clear();
                selectedIds.clear();
              });
            },
            child: const Icon(Icons.clear, size: 18),
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 9,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.gradientBlue),
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// ACTION CHIP
  /// =========================================================

  Widget _actionChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fillWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: fillWidth ? double.infinity : null,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// SUMMARY
  /// =========================================================

  Widget _buildSummaryRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryBox(
              "Total Items",
              "${!_hasActiveFilter && totalItemsFromApi > totalItems ? totalItemsFromApi : totalItems}",
            ),
            _summaryBox("In Stock", "$inStockCount"),
            _summaryBox("Out Stock", "$outStockCount"),
            _summaryBox("With Image", "$withImageCount"),
            _summaryBox("Without Image", "$withoutImageCount"),
            _summaryBox("Gross Wt", grossWt.toStringAsFixed(3)),
            _summaryBox("Other Wt", otherWt.toStringAsFixed(3)),
            _summaryBox("Net Wt", netWt.toStringAsFixed(3)),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox(String title, String value) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// ACTION BUTTONS
  /// =========================================================

  Widget _buildActionButtons(bool isMobile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: _iconActionButton(
              icon: Icons.picture_as_pdf_rounded,
              label: "PDF",
              color: const Color(0xffE53E5A),
              onTap: _handlePdfSelected,
            ),
          ),
          const SizedBox(width: 7),

          Expanded(
            child: _iconActionButton(
              icon: Icons.download_rounded,
              label: "Download",
              color: const Color(0xff2FAE60),
              onTap: () {
                _handleDownloadImages(selected: true);
              },
            ),
          ),
          const SizedBox(width: 7),

          Expanded(
            child: _iconActionButton(
              icon: Icons.share_rounded,
              label: "WhatsApp",
              color: const Color(0xff25D366),
              onTap: _handleWhatsAppShare,
            ),
          ),
          const SizedBox(width: 7),

          /// 🔥 SELECT KARELI ITEMS NU BATCH (2, 5, 10... jetli select)
          Expanded(
            child: _iconActionButton(
              icon: Icons.layers_rounded,
              label: "Batch",
              color: const Color(0xff1E4FD8),
              onTap: _createBatchFromSelection,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// 🔥 SELECT KARELI ITEMS → BATCH SCREEN
  /// =========================================================

  List<Map<String, dynamic>> _batchItemsFor(Set<String> ids) {
    final List<Map<String, dynamic>> result = [];
    final Set<String> added = {};

    /// Pehla filter/sort no order
    for (final Map<String, dynamic> e in filteredStockItems) {
      final String id = e["id"].toString();
      if (ids.contains(id) && added.add(id)) {
        result.add(Map<String, dynamic>.from(e));
      }
    }

    /// Filter bahar ni koi selected item rahi gai hoy to e pan
    for (final Map<String, dynamic> e in stockItems) {
      final String id = e["id"].toString();
      if (ids.contains(id) && added.add(id)) {
        result.add(Map<String, dynamic>.from(e));
      }
    }

    return result;
  }

  void _createBatchFromSelection() {
    if (selectedIds.isEmpty) {
      AppMessage.error(
        context,
        "Select items (tap the circle on image) to create a batch",
      );
      return;
    }

    final List<Map<String, dynamic>> batchItems = _batchItemsFor(selectedIds);

    if (batchItems.isEmpty) {
      AppMessage.error(context, "No selected items found");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BatchImageScreen(items: batchItems)),
    );
  }

  /// =========================================================
  /// PDF SELECTED
  /// =========================================================

  Future<void> _handlePdfSelected() async {
    if (selectedIds.isEmpty) {
      AppMessage.success(context, "Please select at least one item");
      return;
    }

    try {
      final List<int> ids = selectedIds
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toList();

      if (ids.isEmpty) {
        AppMessage.success(context, "Invalid selected items");
        return;
      }

      debugPrint("======================================");
      debugPrint("📄 PDF SELECTED");
      debugPrint("SELECTED IDS => $ids");
      debugPrint("======================================");

      final Map<String, dynamic> body = {
        "scope": "selected",
        "selected_ids": ids,
      };

      debugPrint("📤 PDF POST REQUEST BODY => $body");

      final postResponse = await ApiHelper().postRequest(
        _br("${ApiConstants.baseUrl}stock-gallery/pdf"),
        body,
      );

      if (postResponse == null || postResponse.statusCode != 200) {
        debugPrint("❌ PDF POST API STATUS => ${postResponse?.statusCode}");

        if (mounted) {
          AppMessage.success(context, "Failed to generate PDF");
        }

        return;
      }

      final Map<String, dynamic> responseData = Map<String, dynamic>.from(
        postResponse.data,
      );

      debugPrint("📥 PDF POST RESPONSE => $responseData");

      final bool success = responseData["success"] == true;

      if (!success) {
        final String message =
        responseData["message"]?.toString().trim().isNotEmpty == true
            ? responseData["message"].toString()
            : "Unable to generate PDF";

        if (mounted) {
          AppMessage.success(context, message);
        }

        return;
      }

      debugPrint("✅ PDF POST API SUCCESS");

      final String selectedIdsParam = ids.join(",");

      final String directPdfUrl =
          "${ApiConstants.baseUrl}stock-gallery/pdf"
          "?direct=1"
          "&scope=selected"
          "&selected_ids="
          "${Uri.encodeComponent(selectedIdsParam)}"
          "${_branchMode ? "&$_branchQuery" : ""}";

      debugPrint("🌐 DIRECT PDF GET URL => $directPdfUrl");

      final getResponse = await ApiHelper().getPdfRequest(directPdfUrl);

      debugPrint("📥 DIRECT PDF GET STATUS => ${getResponse?.statusCode}");

      if (getResponse == null || getResponse.statusCode != 200) {
        debugPrint("❌ DIRECT PDF GET FAILED => ${getResponse?.statusCode}");

        if (mounted) {
          AppMessage.success(context, "Failed to download PDF");
        }

        return;
      }

      final dynamic responseDataBytes = getResponse.data;

      late final List<int> bytes;

      if (responseDataBytes is List<int>) {
        bytes = responseDataBytes;
      } else {
        debugPrint(
          "❌ INVALID PDF RESPONSE TYPE => ${responseDataBytes.runtimeType}",
        );

        if (mounted) {
          AppMessage.success(context, "Invalid PDF response");
        }

        return;
      }

      if (bytes.isEmpty) {
        debugPrint("❌ PDF RESPONSE IS EMPTY");

        if (mounted) {
          AppMessage.success(context, "PDF is empty");
        }

        return;
      }

      debugPrint("📄 PDF BYTES LENGTH => ${bytes.length}");

      final Directory dir = await getTemporaryDirectory();

      final String fileName =
          "stock_gallery_${DateTime.now().millisecondsSinceEpoch}.pdf";

      final String filePath = "${dir.path}/$fileName";

      final File file = File(filePath);

      await file.writeAsBytes(bytes, flush: true);

      debugPrint("✅ PDF SAVED => ${file.path}");

      final result = await OpenFile.open(file.path);

      debugPrint("📂 PDF OPEN RESULT => ${result.type}");

      if (result.type != ResultType.done) {
        debugPrint("❌ PDF OPEN FAILED => ${result.message}");

        if (mounted) {
          AppMessage.success(context, "Unable to open PDF");
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ PDF API ERROR => $e");
      debugPrint("❌ PDF STACKTRACE => $stackTrace");

      if (mounted) {
        AppMessage.success(context, "Failed to generate PDF");
      }
    }
  }

  /// =========================================================
  /// PDF FILTERED
  /// =========================================================

  Future<void> _handlePdfFiltered() async {
    final Set<String> ids = filteredStockItems
        .map((e) => e["id"].toString())
        .toSet();

    debugPrint("📄 PDF Filtered");
    debugPrint("Item => $selectedItem");
    debugPrint("Stock => $selectedStockStatus");
    debugPrint("Image => $selectedImageStatus");
    debugPrint("Search => ${searchController.text}");
    debugPrint("Filtered Count => ${ids.length}");
    debugPrint("Filtered IDs => $ids");
  }

  /// =========================================================
  /// 🔥 PROGRESS LOADER (Share + Download banne mate common)
  /// =========================================================

  VoidCallback _showProgressLoader({
    required String title,
    required ValueNotifier<String> progress,
    required Color color,
  }) {
    bool loaderOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<String>(
                      valueListenable: progress,
                      builder: (_, value, __) => Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return () {
      if (!loaderOpen) return;
      loaderOpen = false;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    };
  }

  /// =========================================================
  /// 🔥 ITEM META (name / code / weights / cache key)
  /// =========================================================

  Map<String, String>? _shareMeta(Map<String, dynamic> item) {
    final String id = item["id"]?.toString().trim() ?? "";

    final String imageUrl = item["image_url"]?.toString().trim() ?? "";

    if (id.isEmpty || imageUrl.isEmpty) return null;

    final String itemName =
    item["item_name"]?.toString().trim().isNotEmpty == true
        ? item["item_name"].toString().trim()
        : "Item";

    final String code =
    item["label_code"]?.toString().trim().isNotEmpty == true
        ? item["label_code"].toString().trim()
        : (item["qr_code"]?.toString().trim() ?? "-");

    String fmt(String key) =>
        (double.tryParse(item[key]?.toString() ?? "0") ?? 0)
            .toStringAsFixed(3);

    final String gross = fmt("gross_weight");
    final String net = fmt("net_weight");

    // 🔥 LESS WT: other_weight hoy to e, nahi to (gross - net)
    double lessVal = double.tryParse(item["other_weight"]?.toString() ?? "") ?? 0;

    if (lessVal <= 0) {
      final double g = double.tryParse(gross) ?? 0;
      final double n = double.tryParse(net) ?? 0;
      final double diff = g - n;
      if (diff > 0.0005) lessVal = diff;
    }

    final String less = lessVal.toStringAsFixed(3);

    // image / name / code / weight / size badlay to navi file bane
    final String hash = _stableHash(
      "$imageUrl|$itemName|$code|$gross|$less|$net|$_shareMaxWidth|$_shareMinWidth|v$_captionVersion",
    );

    final String key = "${id}_$hash";

    return {
      "id": id,
      "url": imageUrl,
      "name": itemName,
      "code": code,
      "gross": gross,
      "less": less,
      "net": net,
      "key": key,
      "mime": item["image_mime"]?.toString().toLowerCase().trim() ?? "",
    };
  }

  /// =========================================================
  /// 🚀 WORKER POOL — max _shareConcurrency task ek saathe
  /// =========================================================

  Future<T> _runInPool<T>(Future<T> Function() task) {
    final Completer<T> completer = Completer<T>();

    _prepQueue.add(() async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    _pumpPool();

    return completer.future;
  }

  void _pumpPool() {
    while (!_isDisposed &&
        _prepActive < _shareConcurrency &&
        _prepQueue.isNotEmpty) {
      final Future<void> Function() job = _prepQueue.removeAt(0);

      _prepActive++;

      job().whenComplete(() {
        _prepActive--;
        _pumpPool();
      });
    }
  }

  /// =========================================================
  /// 🚀 GET PREPARED — already chalu/taiyar hoy to e j Future
  /// =========================================================

  Future<XFile?> _getPrepared(Map<String, dynamic> item) {
    final Map<String, String>? meta = _shareMeta(item);

    if (meta == null) return Future.value(null);

    final String key = meta["key"]!;

    return _prepTasks.putIfAbsent(key, () {
      return _runInPool(() => _prepareShareFile(meta)).then((file) {
        if (file == null) _prepTasks.remove(key);
        return file;
      });
    });
  }

  /// Select thata j background ma taiyar karvanu shuru
  void _warmUp(Iterable<Map<String, dynamic>> items) {
    for (final Map<String, dynamic> item in items) {
      _getPrepared(item);
    }
  }

  /// =========================================================
  /// 🔥 EK ITEM → CAPTION VAALI IMAGE FILE (DISK CACHE SAATHE)
  /// =========================================================

  Future<XFile?> _prepareShareFile(Map<String, String> meta) async {
    if (_isDisposed) return null;

    final String id = meta["id"]!;
    final String imageUrl = meta["url"]!;
    final String itemName = meta["name"]!;
    final String code = meta["code"]!;
    final String grossWtStr = meta["gross"]!;
    final String lessWtStr = meta["less"]!;
    final String netWtStr = meta["net"]!;
    final String key = meta["key"]!;

    final Directory cacheDir = await _shareCacheDirFuture;

    final File out = File("${cacheDir.path}/$key.jpg");

    if (await out.exists() && await out.length() > 0) {
      debugPrint("⚡ CACHE HIT [$id]");
      return XFile(out.path, mimeType: "image/jpeg");
    }

    try {
      /// DOWNLOAD DIRECT MEMORY MA
      final Response<List<int>> res = await _shareDio.get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      final List<int>? data = res.data;

      if (data == null || data.isEmpty) {
        debugPrint("❌ EMPTY IMAGE [$id]");
        return null;
      }

      final Uint8List bytes =
      data is Uint8List ? data : Uint8List.fromList(data);

      /// CAPTION + JPG
      try {
        final Uint8List composed = await _addCaptionBelowImage(
          imageBytes: bytes,
          name: itemName,
          code: code,
          grossWt: grossWtStr,
          netWt: netWtStr,
          lessWt: lessWtStr,
          maxWidth: _shareMaxWidth,
          minWidth: _shareMinWidth,
        );

        await out.writeAsBytes(composed);

        return XFile(out.path, mimeType: "image/jpeg");
      } catch (e) {
        debugPrint("❌ CAPTION ADD ERROR [$id] => $e");

        // Caption fail → original image
        final String mime = meta["mime"]!;
        final String lowerUrl = imageUrl.toLowerCase();

        String ext = "jpg";
        if (mime.contains("webp") || lowerUrl.contains(".webp")) {
          ext = "webp";
        } else if (mime.contains("png") || lowerUrl.contains(".png")) {
          ext = "png";
        }

        final File rawFile = File("${cacheDir.path}/${key}_raw.$ext");
        await rawFile.writeAsBytes(bytes);

        return XFile(
          rawFile.path,
          mimeType: ext == "jpg" ? "image/jpeg" : "image/$ext",
        );
      }
    } on DioException catch (e) {
      debugPrint("❌ DIO ERROR [$id] => ${e.type} | ${e.response?.statusCode}");
      return null;
    } catch (e) {
      debugPrint("❌ IMAGE PREPARE ERROR [$id] => $e");
      return null;
    }
  }

  /// =========================================================
  /// 🔥 PARALLEL PREPARE (pool + warm-up reuse)
  /// =========================================================

  Future<List<XFile?>> _prepareFilesParallel(
      List<Map<String, dynamic>> items,
      ValueNotifier<String> progress,
      ) async {
    final int total = items.length;

    int done = 0;

    progress.value = "Preparing 0 / $total";

    final List<Future<XFile?>> futures = items.map((item) {
      return _getPrepared(item).then((file) {
        done++;
        progress.value = "Preparing $done / $total";
        return file;
      });
    }).toList();

    return Future.wait(futures);
  }

  /// =========================================================
  /// DOWNLOAD IMAGES (parallel + cache — fast)
  /// =========================================================

  Future<void> _handleDownloadImages({required bool selected}) async {
    final List<Map<String, dynamic>> items = selected
        ? stockItems.where((item) {
      final String id = item["id"]?.toString().trim() ?? "";
      return selectedIds.contains(id);
    }).toList()
        : filteredStockItems;

    if (selected && selectedIds.isEmpty) {
      AppMessage.success(context, "Please select at least one item");
      return;
    }

    if (items.isEmpty) {
      AppMessage.success(
        context,
        selected ? "No selected items found" : "No filtered items found",
      );
      return;
    }

    /// GALLERY PERMISSION
    try {
      bool hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        if (mounted) {
          AppMessage.error(context, "Gallery permission is required");
        }
        return;
      }
    } catch (e) {
      debugPrint("❌ GALLERY PERMISSION ERROR => $e");

      if (mounted) {
        AppMessage.error(context, "Unable to access gallery");
      }
      return;
    }

    if (!mounted) return;

    final ValueNotifier<String> progress =
    ValueNotifier("Preparing 0 / ${items.length}");

    final VoidCallback closeLoader = _showProgressLoader(
      title: "Downloading images",
      progress: progress,
      color: const Color(0xff2FAE60),
    );

    int successCount = 0;
    int failedCount = 0;

    debugPrint("======================================");
    debugPrint("🖼️ IMAGE DOWNLOAD STARTED");
    debugPrint("TOTAL ITEMS => ${items.length}");
    debugPrint("======================================");

    try {
      final List<XFile?> files = await _prepareFilesParallel(items, progress);

      /// SAVE TO GALLERY
      for (int i = 0; i < files.length; i++) {
        final XFile? f = files[i];

        if (f == null) {
          failedCount++;
          continue;
        }

        progress.value = "Saving ${i + 1} / ${files.length}";

        try {
          await Gal.putImage(f.path, album: "Ornasphere");
          successCount++;
        } on GalException catch (e) {
          failedCount++;
          debugPrint("❌ GAL ERROR => ${e.type.message}");
        } catch (e) {
          failedCount++;
          debugPrint("❌ GALLERY SAVE ERROR => $e");
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ IMAGE DOWNLOAD ERROR => $e");
      debugPrint("STACK => $stackTrace");
    } finally {
      closeLoader();
      Future.delayed(const Duration(milliseconds: 400), progress.dispose);
    }

    debugPrint("======================================");
    debugPrint("🖼️ IMAGE DOWNLOAD COMPLETED");
    debugPrint("SUCCESS => $successCount");
    debugPrint("FAILED => $failedCount");
    debugPrint("======================================");

    if (!mounted) return;

    if (successCount > 0 && failedCount == 0) {
      AppMessage.success(
        context,
        "$successCount image(s) downloaded successfully",
      );
    } else if (successCount > 0) {
      AppMessage.success(
        context,
        "$successCount downloaded, $failedCount failed",
      );
    } else {
      AppMessage.error(context, "No images could be downloaded");
    }
  }

  /// =========================================================
  /// 💎 PREMIUM CAPTION BELOW IMAGE (BURN INTO IMAGE)
  ///
  /// Layout (upar thi niche):
  ///   1. Image (moti hoy to maxWidth sudhi nani, nani hoy to
  ///      minWidth sudhi HQ upscale — caption text sharp rahe)
  ///   2. Patli gold patti
  ///   3. ITEM NAME
  ///   4. Gold divider: ──── ◆ ────
  ///   5. Columns: CODE | G.WT | (L.WT) | N.WT
  /// =========================================================

  Future<Uint8List> _addCaptionBelowImage({
    required Uint8List imageBytes,
    required String name,
    required String code,
    required String grossWt,
    required String netWt,
    String lessWt = "",
    int maxWidth = 1080,
    int minWidth = 0,
  }) async {
    /// RESIZE DURING DECODE (moti image → maxWidth)
    final ui.ImmutableBuffer buffer =
    await ui.ImmutableBuffer.fromUint8List(imageBytes);

    final ui.ImageDescriptor descriptor =
    await ui.ImageDescriptor.encoded(buffer);

    final ui.Codec codec = await descriptor.instantiateCodec(
      targetWidth: descriptor.width > maxWidth ? maxWidth : null,
    );

    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    /// 🔥 Nani image → minWidth sudhi high-quality upscale
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();

    final double scale =
    (minWidth > 0 && srcW < minWidth) ? minWidth / srcW : 1.0;

    final double w = (srcW * scale).roundToDouble();
    final double imgHeight = (srcH * scale).roundToDouble();

    /// 💎 PREMIUM PALETTE
    const Color captionBg = Colors.white;
    const Color inkColor = Color(0xff1A1A1F);
    const Color labelColor = Color(0xff9A9AA2);
    const Color goldColor = Color(0xffC9A227);
    const Color colDividerColor = Color(0xffECE7DA);

    /// COLUMNS
    /// NORMAL   → CODE | G.WT | N.WT
    /// LESS HOY → CODE | G.WT | L.WT | N.WT
    final double lessValue = double.tryParse(lessWt) ?? 0;
    final bool hasLess = lessValue > 0;

    final List<List<String>> columns = [
      ["CODE", code],
      ["G.WT", grossWt],
      if (hasLess) ["L.WT", lessWt],
      ["N.WT", netWt],
    ];

    final int colCount = columns.length;
    final double colWidth = w / colCount;

    /// SIZES (image width na % ma)
    final double goldBarHeight = (w * 0.004).clamp(2.0, 6.0);
    final double topPadding = w * 0.032;
    final double nameFontSize = w * 0.036;
    final double afterNameGap = w * 0.014;

    final double ornamentLineLen = w * 0.045;
    final double ornamentDiamond = w * 0.0065;
    final double ornamentGap = w * 0.010;
    final double ornamentHeight = ornamentDiamond * 2;
    final double afterOrnamentGap = w * 0.024;

    final double labelFontSize = w * (colCount >= 4 ? 0.0175 : 0.020);
    final double valueFontSize = w * (colCount >= 4 ? 0.027 : 0.033);
    final double labelValueGap = w * 0.006;
    final double bottomPadding = w * 0.032;

    /// NAME
    final TextPainter namePainter = TextPainter(
      text: TextSpan(
        text: name.toUpperCase(),
        style: TextStyle(
          color: inkColor,
          fontSize: nameFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: nameFontSize * 0.07,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: "…",
    );

    namePainter.layout(maxWidth: w * 0.92);

    /// LABELS + VALUES
    TextPainter buildLabel(String text) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: labelColor,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: labelFontSize * 0.14,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: "…",
      );
      painter.layout(maxWidth: colWidth - 8);
      return painter;
    }

    TextPainter buildValue(String text, {bool highlight = false}) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: highlight ? goldColor : inkColor,
            fontSize: valueFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: "…",
      );
      painter.layout(maxWidth: colWidth - 12);
      return painter;
    }

    final List<TextPainter> labels =
    columns.map((c) => buildLabel(c[0])).toList();

    final List<TextPainter> values = [
      for (int i = 0; i < colCount; i++)
        buildValue(
          columns[i][1],
          highlight: hasLess && i == colCount - 1,
        ),
    ];

    final double rowLabelHeight =
    labels.map((p) => p.height).reduce((a, b) => a > b ? a : b);
    final double rowValueHeight =
    values.map((p) => p.height).reduce((a, b) => a > b ? a : b);

    /// TOTAL CANVAS SIZE
    final double captionHeight = goldBarHeight +
        topPadding +
        namePainter.height +
        afterNameGap +
        ornamentHeight +
        afterOrnamentGap +
        rowLabelHeight +
        labelValueGap +
        rowValueHeight +
        bottomPadding;

    final double totalHeight = imgHeight + captionHeight;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w, totalHeight),
    );

    // BACKGROUND
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, totalHeight),
      Paint()..color = captionBg,
    );

    // IMAGE (high quality filter saathe)
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH(0, 0, w, imgHeight),
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );

    /// 1) GOLD PATTI
    canvas.drawRect(
      Rect.fromLTWH(0, imgHeight, w, goldBarHeight),
      Paint()..color = goldColor,
    );

    double y = imgHeight + goldBarHeight + topPadding;

    /// 2) NAME
    namePainter.paint(
      canvas,
      Offset((w - namePainter.width) / 2, y),
    );

    y += namePainter.height + afterNameGap;

    /// 3) ORNAMENT  ──── ◆ ────
    final double cx = w / 2;
    final double cy = y + ornamentDiamond;

    final Paint goldLinePaint = Paint()
      ..color = goldColor
      ..strokeWidth = (w * 0.0012).clamp(1.0, 2.0);

    canvas.drawLine(
      Offset(cx - ornamentDiamond - ornamentGap - ornamentLineLen, cy),
      Offset(cx - ornamentDiamond - ornamentGap, cy),
      goldLinePaint,
    );

    canvas.drawLine(
      Offset(cx + ornamentDiamond + ornamentGap, cy),
      Offset(cx + ornamentDiamond + ornamentGap + ornamentLineLen, cy),
      goldLinePaint,
    );

    final Path diamond = Path()
      ..moveTo(cx, cy - ornamentDiamond)
      ..lineTo(cx + ornamentDiamond, cy)
      ..lineTo(cx, cy + ornamentDiamond)
      ..lineTo(cx - ornamentDiamond, cy)
      ..close();

    canvas.drawPath(diamond, Paint()..color = goldColor);

    y += ornamentHeight + afterOrnamentGap;

    /// 4) COLUMNS — label + value
    final double rowTopY = y;

    for (int i = 0; i < colCount; i++) {
      final double centerX = colWidth * (i + 0.5);

      labels[i].paint(
        canvas,
        Offset(centerX - labels[i].width / 2, rowTopY),
      );

      values[i].paint(
        canvas,
        Offset(
          centerX - values[i].width / 2,
          rowTopY + rowLabelHeight + labelValueGap,
        ),
      );
    }

    /// 5) COLUMNS VACHCHE PATLI VERTICAL LINES
    final double dividerTop = rowTopY;
    final double dividerBottom =
        rowTopY + rowLabelHeight + labelValueGap + rowValueHeight;

    final Paint colDividerPaint = Paint()
      ..color = colDividerColor
      ..strokeWidth = (w * 0.0012).clamp(1.0, 2.0);

    for (int i = 1; i < colCount; i++) {
      canvas.drawLine(
        Offset(colWidth * i, dividerTop),
        Offset(colWidth * i, dividerBottom),
        colDividerPaint,
      );
    }

    /// EXPORT JPG (isolate ma encode)
    final ui.Picture picture = recorder.endRecording();

    final int outW = w.toInt();
    final int outH = totalHeight.ceil();

    final ui.Image finalImage = await picture.toImage(outW, outH);

    final ByteData? raw = await finalImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    image.dispose();
    finalImage.dispose();
    picture.dispose();

    if (raw == null) {
      throw Exception("Image export failed");
    }

    return compute(_encodeRgbaToJpg, {
      "w": outW,
      "h": outH,
      "rgba": raw.buffer.asUint8List(),
    });
  }

  /// =========================================================
  /// 🔥 WHATSAPP SHARE (FAST + HD)
  ///
  /// - 4 images parallel prepare
  /// - HD JPG (quality 95)
  /// - Cache: same item bijivar share → instant
  /// - In Stock + Out Stock banne share thay
  /// =========================================================

  Future<void> _handleWhatsAppShare() async {
    if (_isSharing) return;

    if (selectedIds.isEmpty) {
      AppMessage.error(context, "Please select at least one item");
      return;
    }

    final List<Map<String, dynamic>> items = stockItems.where((item) {
      final String id = item["id"]?.toString().trim() ?? "";
      return selectedIds.contains(id);
    }).toList();

    if (items.isEmpty) {
      AppMessage.error(context, "No selected items found");
      return;
    }

    _isSharing = true;

    final ValueNotifier<String> progress =
    ValueNotifier("Preparing 0 / ${items.length}");

    final VoidCallback closeLoader = _showProgressLoader(
      title: "Preparing images",
      progress: progress,
      color: const Color(0xff25D366),
    );

    int failedCount = 0;
    int sharedCount = 0;
    bool shared = false;

    try {
      final List<XFile?> results =
      await _prepareFilesParallel(items, progress);

      final List<XFile> shareFiles = results.whereType<XFile>().toList();

      failedCount = results.length - shareFiles.length;
      sharedCount = shareFiles.length;

      // SHARE SHEET ખૂલે એ પહેલાં LOADER બંધ
      closeLoader();

      if (shareFiles.isEmpty) {
        if (mounted) AppMessage.error(context, "No images available to share");
        return;
      }

      final ShareResult result = await Share.shareXFiles(
        shareFiles,
        subject: "Stock Items",
      );

      debugPrint("MULTI SHARE RESULT => ${result.status}");

      shared = result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.unavailable;
    } catch (e, stackTrace) {
      debugPrint("❌ WHATSAPP SHARE ERROR => $e");
      debugPrint("STACK => $stackTrace");

      closeLoader();

      if (mounted) AppMessage.error(context, "Unable to share items");
    } finally {
      closeLoader();
      _isSharing = false;
      Future.delayed(const Duration(milliseconds: 400), progress.dispose);
    }

    if (!mounted || !shared) return;

    if (failedCount == 0) {
      AppMessage.success(context, "$sharedCount item(s) shared");
    } else {
      AppMessage.success(context, "$sharedCount shared, $failedCount failed");
    }
  }

  /// =========================================================
  /// STOCK ITEM CARD
  /// =========================================================

  Widget _stockCard(Map<String, dynamic> item) {
    final String id = item["id"].toString();

    final bool isSelected = selectedIds.contains(id);

    final bool inStock = item["stock_status"]?.toString() == "In Stock";

    final String imageUrl = item["image_url"]?.toString() ?? "";

    // 🔥 image hoy etle select thay (In Stock + Out Stock banne)
    final bool canSelect = imageUrl.isNotEmpty;

    final String name = item["item_name"]?.toString() ?? "-";

    final String label =
    item["label_code"]?.toString().trim().isNotEmpty == true
        ? item["label_code"].toString()
        : item["qr_code"]?.toString() ?? "-";

    final String grossWtStr =
    (double.tryParse(item["gross_weight"]?.toString() ?? "0") ?? 0)
        .toStringAsFixed(3);

    final String netWtStr =
    (double.tryParse(item["net_weight"]?.toString() ?? "0") ?? 0)
        .toStringAsFixed(3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.gradientBlue : AppColors.border,
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImage(),
                  )
                      : _placeholderImage(),

                  /// CHECKBOX
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: !canSelect
                          ? null
                          : () {
                        setState(() {
                          if (isSelected) {
                            selectedIds.remove(id);
                          } else {
                            selectedIds.add(id);

                            // 🚀 select thata j background ma taiyar
                            _warmUp([item]);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !canSelect
                              ? Colors.grey.shade300
                              : (isSelected
                              ? AppColors.gradientBlue
                              : Colors.white.withOpacity(0.9)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: !canSelect
                                ? Colors.grey.shade400
                                : (isSelected
                                ? AppColors.gradientBlue
                                : Colors.grey.shade400),
                          ),
                        ),
                        child: Icon(
                          !canSelect
                              ? Icons.block
                              : (isSelected ? Icons.check : null),
                          size: 16,
                          color: !canSelect
                              ? Colors.grey.shade500
                              : (isSelected
                              ? Colors.white
                              : Colors.transparent),
                        ),
                      ),
                    ),
                  ),

                  /// STOCK BADGE
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: inStock ? const Color(0xff2FAE60) : Colors.red,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        inStock ? "In Stock" : "Out Stock",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  /// 🏢 BRANCH BADGE (branch mode)
                  if (_branchMode && _branchOf(item).isNotEmpty)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      right: 6,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.store_mall_directory_rounded,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _branchOf(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
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
            ),
          ),

          /// DETAILS
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                _detailLine("Label/QR", label),

                _detailLine("Gross Wt", grossWtStr),

                _detailLine("Net Wt", netWtStr),

                // 🔐 Biji branch na item ma image upload / edit nahi
                if (_isMainData(item)) _stockImageUploadButton(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================
  /// PLACEHOLDER
  /// =========================================================

  Widget _placeholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffFFD678), Color(0xffD65C96)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 46,
          color: Colors.white.withOpacity(0.85),
        ),
      ),
    );
  }

  /// =========================================================
  /// DETAIL LINE
  /// =========================================================

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.5),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontSize: 10.5, color: Colors.black45),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// 🔥 SELECTABLE (Select All mate)
  ///
  /// Stock filter "All"      → juno behaviour (fakt In Stock + Image)
  /// "In Stock"/"Out Stock"  → e filter ni badhi image vaali item
  /// =========================================================

  bool _isSelectable(Map<String, dynamic> item) {
    final String stockStatus =
        item["stock_status"]?.toString().trim().toLowerCase() ?? "";

    final String imageUrl = item["image_url"]?.toString().trim() ?? "";

    if (imageUrl.isEmpty) return false;

    if (selectedStockStatus == "All") return stockStatus == "in stock";

    return true;
  }

  /// =========================================================
  /// 🔥 બાકીના બધા pages load કરો
  /// =========================================================

  /// Guard: chalu loading hoy to e j Future return (double load nahi)
  Future<bool> _loadAllRemainingPages() {
    if (_loadAllFuture != null) return _loadAllFuture!;
    if (currentPage >= lastPage) return Future.value(true);

    return _loadAllFuture =
        _doLoadAllPages().whenComplete(() => _loadAllFuture = null);
  }

  /// =========================================================
  /// 🔥 BACKGROUND PAGE LOADING (PARALLEL + PAGE-WISE UPDATE)
  /// =========================================================

  Future<bool> _doLoadAllPages() async {
    if (mounted) setState(() => _isLoadingAll = true);

    _loadProgress.value = "Loading page ${currentPage + 1} / $lastPage";

    bool ok = true;

    Future<dynamic> fetchPage(int page) async {
      try {
        return await ApiHelper().getRequest(
          _galleryPageUrl(page),
          showLoading: false,
        );
      } catch (e) {
        debugPrint("❌ PAGE $page ERROR => $e");
        return null;
      }
    }

    try {
      final Set<String> existingIds =
      stockItems.map(_itemKey).toSet();

      int nextPage = currentPage + 1;

      while (nextPage <= lastPage && !_isDisposed) {
        final List<int> pages = [
          for (int p = nextPage;
          p < nextPage + _pageBatchSize && p <= lastPage;
          p++)
            p,
        ];

        final List<dynamic> responses =
        await Future.wait(pages.map(fetchPage));

        if (_isDisposed) break;

        for (int i = 0; i < pages.length; i++) {
          final dynamic response = responses[i];

          if (response == null ||
              response.statusCode != 200 ||
              response.data is! Map ||
              response.data["success"] == false) {
            debugPrint("❌ PAGE ${pages[i]} LOAD FAILED");
            ok = false;
            break;
          }

          final parsed = _parseGallery(
            Map<String, dynamic>.from(response.data),
            pages[i],
          );

          for (final map in parsed.items) {
            if (existingIds.add(_itemKey(map))) {
              stockItems.add(map);
            }
          }

          lastPage = parsed.last > lastPage ? parsed.last : lastPage;
          if (parsed.items.isEmpty) lastPage = pages[i]; // aagal kai nathi
          if (parsed.total > 0) totalItemsFromApi = parsed.total;

          currentPage = pages[i];
        }

        _loadProgress.value = "Loaded page $currentPage / $lastPage";

        // 🔥 Page-wise UI update — matching items turant dekhay
        if (mounted) setState(() {});

        if (!ok) break;

        nextPage = currentPage + 1;
      }

      debugPrint("✅ ALL PAGES LOADED => ${stockItems.length} items");
    } catch (e) {
      debugPrint("❌ LOAD ALL PAGES ERROR => $e");
      ok = false;
    } finally {
      _isLoadingAll = false;
      if (mounted) setState(() {});
    }

    return ok;
  }

  /// =========================================================
  /// 🔥 SELECT ALL — આખા data માંથી (બધા pages)
  /// =========================================================

  Future<void> _selectAllInStockWithImage() async {
    if (_isSelectingAll) return;
    _isSelectingAll = true;

    try {
      final bool needsLoad =
          _loadAllFuture != null || currentPage < lastPage;

      VoidCallback closeLoader = () {};

      if (needsLoad) {
        closeLoader = _showProgressLoader(
          title: "Loading all items",
          progress: _loadProgress,
          color: const Color(0xff2FAE60),
        );
      }

      bool ok;

      try {
        ok = await _loadAllRemainingPages();
      } finally {
        closeLoader();
      }

      if (!mounted) return;

      if (!ok) {
        AppMessage.error(
          context,
          "Some pages could not be loaded. Selected from loaded items.",
        );
      }

      final Set<String> matchingIds = filteredStockItems
          .where(_isSelectable)
          .map((item) => item["id"].toString())
          .toSet();

      setState(() {
        selectedIds = matchingIds;
      });

      // 🚀 Select All pachi badhi images background ma taiyar
      _warmUp(
        filteredStockItems.where(
              (item) => matchingIds.contains(item["id"].toString()),
        ),
      );

      if (matchingIds.isEmpty) {
        AppMessage.error(context, "No items with image found");
      } else {
        AppMessage.success(context, "${matchingIds.length} item(s) selected");
        await _askCreateBatch(matchingIds);
      }
    } finally {
      _isSelectingAll = false;
    }
  }

  /// =========================================================
  /// 🔥 UPLOAD BUTTON (per item)
  /// =========================================================

  Widget _stockImageUploadButton(Map<String, dynamic> item) {
    final String imageUrl = item["image_url"]?.toString().trim() ?? "";

    final bool hasImage = imageUrl.isNotEmpty;

    /// IMAGE ALREADY UPLOADED — "View" + "Change"
    if (hasImage) {
      final String id = item["id"]?.toString() ?? "";

      final String name = item["item_name"]?.toString() ?? "";

      final String label =
      item["label_code"]?.toString().trim().isNotEmpty == true
          ? item["label_code"].toString()
          : (item["qr_code"]?.toString() ?? "-");

      return Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openStockImagePreview(
                imageUrl: imageUrl,
                itemName: name,
                qrCode: label,
                heroTag: "stock_item_image_$id",
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff2FAE60).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xff2FAE60).withOpacity(0.30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 15,
                      color: Color(0xff2FAE60),
                    ),
                    SizedBox(width: 4),
                    Text(
                      "View",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff2FAE60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: InkWell(
              onTap: () => _openStockImageUploadSheet(item),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primaryDark.withOpacity(0.25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Change",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    /// NO IMAGE — ONLY "Upload"
    return InkWell(
      onTap: () => _openStockImageUploadSheet(item),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primaryDark.withOpacity(0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 15,
              color: AppColors.primaryDark,
            ),
            SizedBox(width: 4),
            Text(
              "Upload",
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// 🔥 UPLOAD BOTTOM SHEET HELPERS
  /// =========================================================

  Widget _noImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 45,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            "No Image",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _sourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryDark),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// 🔥 UPLOAD / EDIT BOTTOM SHEET
  /// Rotate / Crop / Reset / Remove BG / Colors / Templates / Model
  /// =========================================================

  void _openStockImageUploadSheet(Map<String, dynamic> item) {
    _stockSelectedImageFile = null;
    _stockOriginalImageFile = null;
    _resetBgState();

    final String itemName = item["item_name"]?.toString() ?? "";

    final String labelCode =
    item["label_code"]?.toString().trim().isNotEmpty == true
        ? item["label_code"].toString()
        : (item["qr_code"]?.toString() ?? "-");

    final String existingImageUrl = item["image_url"]?.toString().trim() ?? "";

    /// 🔥 JOONI (SERVER) IMAGE EDIT MATE
    File? existingLocalFile;
    bool loadingExisting = false;
    bool existingRequested = false;
    bool existingFailed = false;

    /// 💎 BATCH JEVA BACKGROUND — Colors / Templates / Model
    int bgTab = 0; // 0 = Colors, 1 = Templates, 2 = Model
    String tplCategory = BgCategory.all;
    BgTemplate? selectedTpl;
    ModelTemplate selectedModel = ModelLibrary.all.first;
    final JewelType jewelType = JewelTypeDetector.detect(itemName);
    final JewelAdjust modelAdjust = JewelAdjust();
    bool modelsRequested = false;

    /// Background remove pachi trim karel PNG (template / model mate)
    File? trimmedPngFile;
    Size? trimmedSize;
    JewelParts? trimmedParts;

    /// 🗑️ Image remove chalu che?
    bool removingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            /// Sheet band thai gai hoy to setState na thay
            void safeSet(VoidCallback fn) {
              if (context.mounted) setSheetState(fn);
            }

            /// 🔥 JOONI IMAGE → EDITABLE FILE
            Future<void> loadExistingForEdit() async {
              if (existingImageUrl.isEmpty || loadingExisting) return;

              safeSet(() {
                loadingExisting = true;
                existingFailed = false;
              });

              final File? f = await _downloadImageToTemp(
                existingImageUrl,
                item["id"]?.toString() ?? "0",
              );

              if (!context.mounted) return;

              safeSet(() {
                loadingExisting = false;

                if (f == null) {
                  existingFailed = true;
                  return;
                }

                /// Vachche user e navi image pick kari hoy to overwrite na karo
                if (_stockSelectedImageFile == null) {
                  existingLocalFile = f;
                  _stockSelectedImageFile = f;
                  _stockOriginalImageFile = f;
                  _bgRemovedPng = null;
                }
              });
            }

            /// Sheet khulta j ek vaar load
            if (!existingRequested && existingImageUrl.isNotEmpty) {
              existingRequested = true;
              WidgetsBinding.instance.addPostFrameCallback(
                    (_) => loadExistingForEdit(),
              );
            }

            /// 👩 Gallery mathi umerel real models (batch jevu j)
            if (!modelsRequested) {
              modelsRequested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final List<ModelTemplate> list = await ModelStore.load();
                  ModelLibrary.custom
                    ..clear()
                    ..addAll(list);
                  safeSet(() {});
                } catch (e) {
                  debugPrint("MODEL LOAD ERROR => $e");
                }
              });
            }

            /// Final image kai rite banse (preview + submit banne ek j)
            String finalMode() {
              if (bgTab == 2 &&
                  jewelType != JewelType.other &&
                  trimmedPngFile != null &&
                  trimmedSize != null) {
                return "model";
              }
              if (bgTab == 1 && selectedTpl != null && trimmedPngFile != null) {
                return "template";
              }
              return "color";
            }

            /// 🗑️ REMOVE IMAGE (server mathi)
            Future<void> removeImage() async {
              final bool? yes = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    "Remove Image",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  content: const Text(
                    "Are you sure you want to remove this item's image?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text("Remove"),
                    ),
                  ],
                ),
              );

              if (yes != true) return;

              safeSet(() => removingImage = true);

              final bool ok = await _removeStockItemImage(item);

              if (ok) {
                if (bottomSheetContext.mounted) {
                  Navigator.pop(bottomSheetContext);
                }
              } else {
                safeSet(() => removingImage = false);
              }
            }

            /// PICK IMAGE
            Future<void> pickImage(ImageSource source) async {
              final XFile? picked = await _stockImagePicker.pickImage(
                source: source,
                imageQuality: 90,
                maxWidth: 1600,
                maxHeight: 1600,
              );

              if (picked == null) return;

              final File file = File(picked.path);

              safeSet(() {
                _stockSelectedImageFile = file;
                _stockOriginalImageFile = file;
                _bgRemovedPng = null; // navi image → junu result saaf
              });
            }

            /// ROTATE (angle: -90 = left, 90 = right)
            Future<void> rotateImage(int angle) async {
              if (_stockSelectedImageFile == null || _bgBusy) return;

              try {
                final Uint8List bytes =
                await _stockSelectedImageFile!.readAsBytes();

                final img.Image? decoded = img.decodeImage(bytes);

                if (decoded == null) return;

                final img.Image rotated = img.copyRotate(
                  decoded,
                  angle: angle,
                );

                final Directory tempDir = await getTemporaryDirectory();

                final String newPath =
                    "${tempDir.path}/rotated_${DateTime.now().microsecondsSinceEpoch}.jpg";

                final File newFile = File(newPath);

                await newFile.writeAsBytes(
                  img.encodeJpg(rotated, quality: 97),
                );

                safeSet(() {
                  _stockSelectedImageFile = newFile;
                  _bgRemovedPng = null;
                });
              } catch (e) {
                debugPrint("ROTATE ERROR => $e");

                if (context.mounted) {
                  AppMessage.error(context, "Unable to rotate image");
                }
              }
            }

            /// CROP
            Future<void> cropImage() async {
              if (_stockSelectedImageFile == null || _bgBusy) return;

              try {
                final CroppedFile? cropped = await ImageCropper().cropImage(
                  sourcePath: _stockSelectedImageFile!.path,
                  uiSettings: [
                    AndroidUiSettings(
                      toolbarTitle: "Crop Image",
                      toolbarColor: AppColors.primaryDark,
                      toolbarWidgetColor: Colors.white,
                      lockAspectRatio: false,
                    ),
                    IOSUiSettings(title: "Crop Image"),
                  ],
                );

                if (cropped == null) return;

                safeSet(() {
                  _stockSelectedImageFile = File(cropped.path);
                  _bgRemovedPng = null;
                });
              } catch (e) {
                debugPrint("CROP ERROR => $e");

                if (context.mounted) {
                  AppMessage.error(context, "Unable to crop image");
                }
              }
            }

            /// RESET — original picked image par pachu javu
            void resetImage() {
              if (_bgBusy) return;

              safeSet(() {
                _stockSelectedImageFile = _stockOriginalImageFile;
                _bgRemovedPng = null;
              });
            }

            /// 💎 REMOVE BACKGROUND (app side, isolate ma)
            Future<void> removeBackground() async {
              if (_stockSelectedImageFile == null || _bgBusy) return;

              safeSet(() => _bgBusy = true);

              try {
                final Uint8List bytes =
                await _stockSelectedImageFile!.readAsBytes();

                final Uint8List png = await JewelleryBgRemover.removeBackground(
                  bytes,
                  strength: _bgStrength,
                );

                /// 💎 Template / Model mate trim karel PNG
                File? tf;
                Size? sz;
                JewelParts? parts;

                try {
                  final Uint8List trimmed =
                  await BgComposer.trimTransparent(png);

                  final Directory dir = await getTemporaryDirectory();

                  tf = File(
                    "${dir.path}/single_trim_${DateTime.now().microsecondsSinceEpoch}.png",
                  );

                  await tf.writeAsBytes(trimmed, flush: true);

                  sz = await ModelComposer.readSize(trimmed);
                  parts = await JewelSplitter.split(trimmed);
                } catch (e) {
                  debugPrint("TRIM ERROR => $e");
                  tf = null;
                }

                safeSet(() {
                  _bgRemovedPng = png;
                  trimmedPngFile = tf;
                  trimmedSize = sz;
                  trimmedParts = parts;
                });
              } catch (e) {
                debugPrint("BG REMOVE ERROR => $e");

                if (context.mounted) {
                  AppMessage.error(
                    context,
                    "Background could not be removed. Try a lower strength.",
                  );
                }
              } finally {
                safeSet(() => _bgBusy = false);
              }
            }

            /// =====================================================
            /// PREVIEW
            /// =====================================================
            Widget buildPreview() {
              if (_bgRemovedPng != null) {
                final String mode = finalMode();

                /// 👩 MODEL PREVIEW
                if (mode == "model") {
                  return ModelPreview(
                    model: selectedModel,
                    png: trimmedPngFile!,
                    pngSize: trimmedSize!,
                    type: jewelType,
                    adjust: modelAdjust,
                    parts: trimmedParts,
                    adjustKey: modelAdjust.key,
                  );
                }

                /// 🖼️ TEMPLATE PREVIEW
                if (mode == "template") {
                  return JewelOnBackground(
                    template: selectedTpl!,
                    png: trimmedPngFile!,
                    shadow: _bgShadow,
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_bgColor == null)
                      const CustomPaint(painter: CheckerboardPainter())
                    else
                      ColoredBox(color: _bgColor!),

                    /// SOFT SHADOW PREVIEW
                    if (_bgColor != null && _bgShadow)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                        child: ImageFiltered(
                          imageFilter:
                          ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.30),
                              BlendMode.srcIn,
                            ),
                            child: Image.memory(
                              _bgRemovedPng!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.memory(
                        _bgRemovedPng!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                );
              }

              if (_stockSelectedImageFile != null) {
                return Image.file(
                  _stockSelectedImageFile!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                );
              }

              if (existingImageUrl.isNotEmpty) {
                return Image.network(
                  existingImageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;

                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      _noImagePlaceholder(),
                );
              }

              return _noImagePlaceholder();
            }

            /// =====================================================
            /// 🔥 TAB CHIP
            /// =====================================================
            Widget tabChip(String label, IconData icon, int index) {
              final bool sel = bgTab == index;

              return InkWell(
                onTap: _bgBusy
                    ? null
                    : () => safeSet(() {
                  bgTab = index;
                  if (index == 1 && selectedTpl == null) {
                    selectedTpl = BgLibrary.templates.first;
                  }
                }),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? AppColors.primaryDark : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: sel ? Colors.white : AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            /// =====================================================
            /// 🖼️ TEMPLATE PANEL — category + tiles
            /// =====================================================
            Widget buildTemplatePanel() {
              final List<BgTemplate> list = [
                ...BgLibrary.assetTemplates,
                ...BgLibrary.templates,
              ]
                  .where(
                    (t) =>
                tplCategory == BgCategory.all ||
                    t.category == tplCategory,
              )
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// CATEGORY
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: BgCategory.list.map((c) {
                        final bool sel = c == tplCategory;

                        return GestureDetector(
                          onTap: () => safeSet(() => tplCategory = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primaryDark.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sel
                                    ? AppColors.primaryDark
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? AppColors.primaryDark
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// TILES
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final BgTemplate t = list[i];
                        final bool sel = selectedTpl?.id == t.id;

                        return GestureDetector(
                          onTap: () => safeSet(() => selectedTpl = t),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: sel
                                        ? AppColors.primaryDark
                                        : AppColors.border,
                                    width: sel ? 2.4 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      BgTemplateView(template: t),
                                      if (sel)
                                        Center(
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                            color: t.isDark
                                                ? Colors.white
                                                : AppColors.primaryDark,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 62,
                                child: Text(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            /// =====================================================
            /// 👩 MODEL PANEL — Necklace / Earring / Set mate
            /// =====================================================
            Widget adjSlider(
                String label,
                double value,
                double min,
                double max,
                ValueChanged<double> onChanged,
                ) {
              return Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      activeColor: AppColors.primaryDark,
                      onChanged: onChanged,
                    ),
                  ),
                ],
              );
            }

            Widget buildModelPanel() {
              if (jewelType == JewelType.other) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: const Text(
                    "Model try-on works for Necklace, Chain, Earring and Set "
                        "items only. Use Colors or Templates for this item.",
                    style: TextStyle(fontSize: 11.5, color: Colors.black87),
                  ),
                );
              }

              final List<ModelTemplate> models = ModelLibrary.all;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        jewelType.icon,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Detected: ${jewelType.label}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: models.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final ModelTemplate m = models[i];
                        final bool sel = m.id == selectedModel.id;

                        return GestureDetector(
                          onTap: () => safeSet(() => selectedModel = m),
                          child: Column(
                            children: [
                              Container(
                                width: 62,
                                height: 74,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: sel
                                        ? AppColors.primaryDark
                                        : AppColors.border,
                                    width: sel ? 2.4 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: ModelThumb(model: m),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 64,
                                child: Text(
                                  m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  /// SIZE + POSITION
                  adjSlider(
                    "Size",
                    modelAdjust.scale,
                    0.5,
                    1.8,
                        (v) => safeSet(() => modelAdjust.scale = v),
                  ),
                  adjSlider(
                    "Up / Down",
                    modelAdjust.dy,
                    -0.15,
                    0.15,
                        (v) => safeSet(() => modelAdjust.dy = v),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => safeSet(() => modelAdjust.reset()),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text("Reset position"),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              );
            }

            /// =====================================================
            /// BACKGROUND PANEL
            /// =====================================================
            Widget buildBgPanel() {
              if (_stockSelectedImageFile == null) {
                return const SizedBox.shrink();
              }

              /// Haju remove nathi karyu → mukhya button
              if (_bgRemovedPng == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _bgBusy ? null : removeBackground,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.secondaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_bgBusy)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(
                                Icons.auto_fix_high_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _bgBusy
                                  ? "Removing background..."
                                  : "Remove background",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Crop out the label sticker first for a clean result.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              }

              /// Remove thai gayu → rang, strength, shadow
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// TITLE + UNDO
                    Row(
                      children: [
                        const Text(
                          "Background",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _bgBusy
                              ? null
                              : () => safeSet(() => _bgRemovedPng = null),
                          icon: const Icon(Icons.undo_rounded, size: 16),
                          label: const Text("Undo"),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),

                    /// 🔥 TABS — Colors / Templates / Model
                    Row(
                      children: [
                        Expanded(
                          child: tabChip("Colors", Icons.palette_outlined, 0),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: tabChip(
                            "Templates",
                            Icons.wallpaper_rounded,
                            1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: tabChip(
                            "Model",
                            Icons.face_retouching_natural,
                            2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// COLOR SWATCHES
                    if (bgTab == 0)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _bgPalette
                              .map(
                                (c) => _bgSwatch(
                              c,
                              c == _bgColor,
                                  () => safeSet(() => _bgColor = c),
                            ),
                          )
                              .toList(),
                        ),
                      ),

                    /// 🖼️ TEMPLATES
                    if (bgTab == 1) buildTemplatePanel(),

                    /// 👩 MODEL
                    if (bgTab == 2) buildModelPanel(),

                    const SizedBox(height: 8),

                    /// STRENGTH
                    Row(
                      children: [
                        const Text(
                          "Strength",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _bgStrength,
                            min: 12,
                            max: 80,
                            divisions: 34,
                            activeColor: AppColors.primaryDark,
                            label: _bgStrength.round().toString(),
                            onChanged: _bgBusy
                                ? null
                                : (v) => safeSet(() => _bgStrength = v),
                            onChangeEnd: (_) => removeBackground(),
                          ),
                        ),
                        SizedBox(
                          width: 26,
                          child: _bgBusy
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            _bgStrength.round().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Text(
                      "Lower it if the jewellery gets cut. Raise it if background remains.",
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    /// SHADOW (rang / template / model hoy tyare)
                    if (bgTab != 0 || _bgColor != null)
                      Row(
                        children: [
                          const Text(
                            "Soft shadow",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _bgShadow,
                            activeColor: AppColors.primaryDark,
                            onChanged: (v) => safeSet(() => _bgShadow = v),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// HEADER
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Item Image",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () => Navigator.pop(bottomSheetContext),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: AppColors.border),

                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// PREVIEW
                              Container(
                                width: double.infinity,
                                height: 260,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      buildPreview(),

                                      /// 🔥 Jooni image edit mate taiyar thay che
                                      if (loadingExisting)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 10,
                                          child: Center(
                                            child: Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.65),
                                                borderRadius:
                                                BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Preparing image for editing...",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                      FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                      /// 🔥 Download fail → Retry
                                      if (existingFailed &&
                                          _stockSelectedImageFile == null)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 10,
                                          child: Center(
                                            child: ElevatedButton.icon(
                                              onPressed: loadExistingForEdit,
                                              icon: const Icon(
                                                Icons.refresh,
                                                size: 16,
                                              ),
                                              label:
                                              const Text("Retry to edit"),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                AppColors.primaryDark,
                                                foregroundColor: Colors.white,
                                                visualDensity:
                                                VisualDensity.compact,
                                              ),
                                            ),
                                          ),
                                        ),

                                      /// PROCESSING OVERLAY
                                      if (_bgBusy)
                                        Container(
                                          color: Colors.black26,
                                          alignment: Alignment.center,
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                              BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  "Working on it...",
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              /// EDIT TOOLBAR
                              if (_stockSelectedImageFile != null)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _sheetToolBtn(
                                        icon: Icons.rotate_left_rounded,
                                        label: "Rotate L",
                                        onTap: () => rotateImage(-90),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _sheetToolBtn(
                                        icon: Icons.rotate_right_rounded,
                                        label: "Rotate R",
                                        onTap: () => rotateImage(90),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _sheetToolBtn(
                                        icon: Icons.crop_rounded,
                                        label: "Crop",
                                        onTap: cropImage,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _sheetToolBtn(
                                        icon: Icons.restart_alt_rounded,
                                        label: "Reset",
                                        onTap: resetImage,
                                      ),
                                    ),
                                  ],
                                ),

                              if (_stockSelectedImageFile != null)
                                const SizedBox(height: 12),

                              /// 💎 BACKGROUND PANEL
                              buildBgPanel(),

                              const SizedBox(height: 16),

                              _imageInfoLine("Item", itemName),

                              const SizedBox(height: 10),

                              _imageInfoLine("Label Code", labelCode),

                              const SizedBox(height: 16),

                              const Text(
                                "Upload Image",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 7),

                              /// CHOOSE IMAGE
                              InkWell(
                                onTap: _bgBusy
                                    ? null
                                    : () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    builder: (sourceContext) {
                                      return SafeArea(
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.fromLTRB(
                                              20, 15, 20, 25),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _sourceTile(
                                                  icon: Icons
                                                      .camera_alt_outlined,
                                                  label: "Camera",
                                                  onTap: () async {
                                                    Navigator.pop(
                                                        sourceContext);
                                                    await pickImage(
                                                        ImageSource.camera);
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _sourceTile(
                                                  icon: Icons
                                                      .photo_library_outlined,
                                                  label: "Gallery",
                                                  onTap: () async {
                                                    Navigator.pop(
                                                        sourceContext);
                                                    await pickImage(
                                                        ImageSource.gallery);
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryDark
                                              .withOpacity(0.1),
                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 20,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _stockSelectedImageFile == null
                                              ? "Choose Image"
                                              : (_stockSelectedImageFile ==
                                              existingLocalFile
                                              ? "Current image • tap to change"
                                              : _stockSelectedImageFile!.path
                                              .split("/")
                                              .last),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                            _stockSelectedImageFile == null
                                                ? Colors.black87
                                                : AppColors.primaryDark,
                                            fontWeight:
                                            _stockSelectedImageFile == null
                                                ? FontWeight.normal
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _stockSelectedImageFile == null
                                            ? Icons.chevron_right
                                            : Icons.check_circle,
                                        color: _stockSelectedImageFile == null
                                            ? Colors.grey.shade600
                                            : Colors.green,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),

                      /// SUBMIT
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            /// 🗑️ REMOVE — image hoy tyare j
                            if (existingImageUrl.isNotEmpty) ...[
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: (_bgBusy || removingImage)
                                        ? null
                                        : removeImage,
                                    icon: removingImage
                                        ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                        : const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      "Remove",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Colors.red.withOpacity(0.5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],

                            Expanded(
                              flex: existingImageUrl.isNotEmpty ? 2 : 1,
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: (_bgBusy ||
                                      loadingExisting ||
                                      removingImage)
                                      ? null
                                      : () async {
                                    if (_stockSelectedImageFile == null) {
                                      AppMessage.error(
                                        context,
                                        "Please choose image",
                                      );
                                      return;
                                    }

                                    /// 🔥 Jooni image ma kai badlaav nathi → upload nahi
                                    if (_stockSelectedImageFile ==
                                        existingLocalFile &&
                                        _bgRemovedPng == null) {
                                      AppMessage.error(
                                        context,
                                        "No changes made. Edit the image or choose a new one.",
                                      );
                                      return;
                                    }

                                    File toUpload = _stockSelectedImageFile!;

                                    /// 💎 BG removed hoy to final image banavo
                                    if (_bgRemovedPng != null) {
                                      safeSet(() => _bgBusy = true);

                                      try {
                                        final String mode = finalMode();

                                        bool transparent = false;
                                        Uint8List finalBytes;

                                        if (mode == "model") {
                                          /// 👩 Model par jewellery
                                          finalBytes =
                                          await ModelComposer.compose(
                                            await trimmedPngFile!
                                                .readAsBytes(),
                                            selectedModel,
                                            jewelType,
                                            modelAdjust,
                                            parts: trimmedParts,
                                            shadow: _bgShadow,
                                          );
                                        } else if (mode == "template") {
                                          /// 🖼️ Template background
                                          finalBytes =
                                          await BgComposer.compose(
                                            await trimmedPngFile!
                                                .readAsBytes(),
                                            selectedTpl!,
                                            shadow: _bgShadow,
                                          );
                                        } else if (_bgColor == null) {
                                          /// Transparent PNG
                                          transparent = true;
                                          finalBytes = _bgRemovedPng!;
                                        } else {
                                          /// Solid rang
                                          finalBytes =
                                          await JewelleryBgRemover
                                              .composeOnColor(
                                            _bgRemovedPng!,
                                            _bgColor!,
                                            shadow: _bgShadow,
                                          );
                                        }

                                        final Directory dir =
                                        await getTemporaryDirectory();

                                        toUpload = File(
                                          "${dir.path}/jewel_${DateTime.now().microsecondsSinceEpoch}"
                                              ".${transparent ? "png" : "jpg"}",
                                        );

                                        await toUpload
                                            .writeAsBytes(finalBytes);
                                      } catch (e) {
                                        debugPrint("BG COMPOSE ERROR => $e");

                                        if (context.mounted) {
                                          AppMessage.error(
                                            context,
                                            "Unable to prepare image",
                                          );
                                        }
                                        return;
                                      } finally {
                                        safeSet(() => _bgBusy = false);
                                      }
                                    }

                                    _uploadStockItemImage(
                                      item,
                                      toUpload,
                                      bottomSheetContext,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Submit",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryDark,
                                    disabledBackgroundColor:
                                    Colors.grey.shade400,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7),
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
            );
          },
        );
      },
    ).whenComplete(() {
      _stockSelectedImageFile = null;
      _stockOriginalImageFile = null;
      _resetBgState();
    });
  }

  /// =========================================================
  /// 🔥 SERVER NI JOONI IMAGE → TEMP FILE (edit karva mate)
  /// =========================================================

  Future<File?> _downloadImageToTemp(String url, String id) async {
    try {
      final Response<List<int>> res = await _shareDio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      final List<int>? data = res.data;
      if (data == null || data.isEmpty) return null;

      final String lower = url.toLowerCase();
      String ext = "jpg";
      if (lower.contains(".png")) {
        ext = "png";
      } else if (lower.contains(".webp")) {
        ext = "webp";
      }

      final Directory dir = await getTemporaryDirectory();
      final File file = File(
        "${dir.path}/existing_${id}_${DateTime.now().microsecondsSinceEpoch}.$ext",
      );

      await file.writeAsBytes(data, flush: true);
      return file;
    } catch (e) {
      debugPrint("❌ EXISTING IMAGE DOWNLOAD ERROR => $e");
      return null;
    }
  }

  /// Sheet khule / band thay tyare background settings default par
  void _resetBgState() {
    _bgRemovedPng = null;
    _bgColor = const Color(0xffFFFFFF);
    _bgStrength = 32;
    _bgShadow = true;
    _bgBusy = false;
  }

  /// Background rang no gol button (null = transparent)
  Widget _bgSwatch(Color? color, bool selected, VoidCallback onTap) {
    final bool dark = color != null && color.computeLuminance() < 0.4;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.white,
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (color == null)
                const CustomPaint(painter: CheckerboardPainter(cell: 6)),
              if (selected)
                Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: dark ? Colors.white : AppColors.primaryDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// =========================================================
  /// TOOLBAR SMALL BUTTON (Rotate/Crop/Reset)
  /// =========================================================

  Widget _sheetToolBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageInfoLine(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  /// =========================================================
  /// 🗑️ REMOVE IMAGE API
  /// DELETE {itemset}/{id}/image
  /// =========================================================

  Future<bool> _removeStockItemImage(Map<String, dynamic> item) async {
    final int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

    if (id <= 0) {
      AppMessage.error(context, "Invalid item ID");
      return false;
    }

    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.itemset}/$id/image",
      );

      debugPrint("STOCK IMAGE REMOVE RESPONSE => ${response?.data}");

      if (!mounted) return false;

      final dynamic data = response?.data;

      final bool ok = response != null &&
          (response.statusCode == 200 || response.statusCode == 204) &&
          !(data is Map && data["success"] == false);

      if (!ok) {
        AppMessage.error(
          context,
          (data is Map ? data["message"]?.toString() : null) ??
              "Unable to remove image",
        );
        return false;
      }

      setState(() {
        final int index = stockItems.indexWhere(
              (e) => e["id"]?.toString() == id.toString(),
        );

        if (index != -1) {
          stockItems[index]["image_url"] = "";
          stockItems[index]["has_image"] = false;
        }

        // Image vagar select na rahe
        selectedIds.remove(id.toString());

        _dataRev++; // filtered cache refresh
      });

      AppMessage.success(
        context,
        (data is Map ? data["message"]?.toString() : null) ??
            "Image removed successfully",
      );

      return true;
    } catch (e) {
      debugPrint("STOCK IMAGE REMOVE ERROR => $e");

      if (mounted) AppMessage.error(context, "Unable to remove image");

      return false;
    }
  }

  /// =========================================================
  /// 🔥 UPLOAD API
  /// =========================================================

  Future<void> _uploadStockItemImage(
      Map<String, dynamic> item,
      File imageFile,
      BuildContext sheetContext,
      ) async {
    try {
      final int id = int.tryParse(item["id"]?.toString() ?? "0") ?? 0;

      if (id <= 0) {
        AppMessage.error(context, "Invalid item ID");
        return;
      }

      FocusManager.instance.primaryFocus?.unfocus();

      final String fileName = imageFile.path.split("/").last;

      final FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      debugPrint("======================================");
      debugPrint("STOCK IMAGE UPLOAD => ID: $id | FILE: $fileName");
      debugPrint("======================================");

      final response = await ApiHelper().postRequest(
        "${ApiConstants.itemset}/$id/image",
        formData,
      );

      debugPrint("STOCK IMAGE UPLOAD RESPONSE => ${response?.data}");

      if (!mounted) return;

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        AppMessage.success(
          context,
          response.data?["message"] ?? "Image uploaded successfully",
        );

        Navigator.pop(sheetContext);

        final dynamic responseItem = response.data is Map
            ? (response.data["data"] ?? response.data["item"])
            : null;

        String? newImageUrl;

        if (responseItem is Map && responseItem["image_url"] != null) {
          newImageUrl = responseItem["image_url"].toString();
        }

        setState(() {
          final int index = stockItems.indexWhere(
                (e) => e["id"]?.toString() == id.toString(),
          );

          if (index != -1) {
            if (newImageUrl != null && newImageUrl.isNotEmpty) {
              stockItems[index]["image_url"] = newImageUrl;
            }

            stockItems[index]["has_image"] = true;
          }

          _dataRev++; // filtered cache refresh
        });

        if (newImageUrl == null || newImageUrl.isEmpty) {
          await fetchStockGallery();
        }
      } else {
        AppMessage.error(
          context,
          response?.data?["message"] ?? "Image upload failed",
        );
      }
    } catch (e) {
      debugPrint("STOCK IMAGE UPLOAD ERROR => $e");

      if (!mounted) return;

      AppMessage.error(context, "Image upload failed");
    }
  }

  /// =========================================================
  /// DISPOSE
  /// =========================================================

  @override
  void dispose() {
    searchController.dispose();
    _searchFocus.dispose();
    minWeightController.dispose();
    maxWeightController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isDisposed = true;
    _prepQueue.clear();
    _searchDebounce?.cancel();
    _loadProgress.dispose();
    _shareDio.close(force: true);
    super.dispose();
  }

  /// =========================================================
  /// 🔥 FULL-SCREEN ZOOMABLE IMAGE PREVIEW
  /// =========================================================

  void _openStockImagePreview({
    required String imageUrl,
    required String itemName,
    required String qrCode,
    required String heroTag,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Image Preview",
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                /// FULL IMAGE
                Positioned.fill(
                  child: Center(
                    child: Hero(
                      tag: heroTag,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 55,
                                    color: Colors.white54,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Unable to load image",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                /// TOP BAR
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName.isEmpty ? "Item Image" : itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (qrCode.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  "Label: $qrCode",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      InkWell(
                        onTap: () => Navigator.pop(dialogContext),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// BOTTOM — PINCH HINT + 💍 TRY ON
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Row(
                    children: [
                      /// PINCH HINT
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pinch_outlined,
                              color: Colors.white70,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Pinch to zoom",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      /// 💍 TRY ON BUTTON
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.secondaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withOpacity(0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              /// Pehla preview band, pachhi Try On screen
                              Navigator.pop(dialogContext);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TryOnScreen(
                                    imageUrl: imageUrl,
                                    itemName: itemName,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Try on",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              curvedAnimation,
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// =========================================================
  /// 💎 BLUE PREMIUM — "CREATE BATCH" POPUP
  /// Not now → selection + WhatsApp share
  /// Create  → Batch with Image page
  /// =========================================================

  static const Color _bNavy = Color(0xff0B1E4A);
  static const Color _bRoyal = Color(0xff1E4FD8);
  static const Color _bSky = Color(0xff5B93FF);
  static const Color _bIce = Color(0xffEEF4FF);
  static const Color _bLine = Color(0xffDCE6FA);
  static const Color _bText = Color(0xff5C6B8A);

  Future<void> _askCreateBatch(Set<String> ids) async {
    if (!mounted || ids.isEmpty) return;

    final bool? ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Create Batch",
      barrierColor: _bNavy.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                elevation: 18,
                shadowColor: _bNavy.withOpacity(0.4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// ── BLUE GRADIENT HEADER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_bNavy, _bRoyal, _bSky],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -40,
                            right: -30,
                            child: _glowCircle(110, 0.10),
                          ),
                          Positioned(
                            bottom: -50,
                            left: -36,
                            child: _glowCircle(100, 0.07),
                          ),

                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),

                                const SizedBox(height: 14),

                                const Text(
                                  "Create Batch?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                /// COUNT CHIP
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 15,
                                        color: _bRoyal,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${ids.length} item(s) selected",
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _bNavy,
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

                    /// ── BODY
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Backgrounds will be removed from all selected "
                                "images and shown in a grid, ready to share.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: _bText,
                            ),
                          ),

                          const SizedBox(height: 16),

                          /// FEATURES
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _bIce,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _bLine),
                            ),
                            child: Column(
                              children: [
                                _batchFeatureRow(
                                  Icons.auto_fix_high_rounded,
                                  "Remove background",
                                  "Clean look for every jewellery photo",
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1, color: _bLine),
                                ),
                                _batchFeatureRow(
                                  Icons.grid_view_rounded,
                                  "Grid preview",
                                  "Choose background colour & shadow",
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1, color: _bLine),
                                ),
                                _batchFeatureRow(
                                  Icons.share_rounded,
                                  "Share on WhatsApp",
                                  "With name, code & weight caption",
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          /// BUTTONS
                          Row(
                            children: [
                              /// NOT NOW
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: _bLine,
                                        width: 1.2,
                                      ),
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: _bText,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            "Not now",
                                            style: TextStyle(
                                              color: _bText,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              /// CREATE BATCH
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_bRoyal, _bSky],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _bRoyal.withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.layers_rounded,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  "Create Batch",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      transitionBuilder: (_, animation, __, child) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (ok != true || !mounted) return;

    // Filter/sort no order same rahe
    final List<Map<String, dynamic>> batchItems = _batchItemsFor(ids);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BatchImageScreen(items: batchItems)),
    );
  }

  /// Header ma halka safed gol (premium depth mate)
  Widget _glowCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  /// Popup ni ander feature line (blue icon + title + subtitle)
  Widget _batchFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bRoyal, _bSky],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _bNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: _bText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
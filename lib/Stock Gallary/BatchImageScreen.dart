import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/JewelleryBgRemover.dart';
import 'Batchbgtemplates.dart';
import 'BatchModelTemplates.dart';
import 'ModelCalibrateScreen.dart';
import 'BgEraseEditorScreen.dart';
import 'PromptBackground.dart';

/// ================================================================
/// 💎 BATCH WITH IMAGE SCREEN
///
/// - Select All pachi "Create Batch" OK karvathi aa page khule
/// - Darek item ni image download → FULL HD (1920px) source
/// - 🔥 Background sidhu FULL HD (1920px) image par kadhay — sudharel
///   remover patli chain / kaala mani / latkan kyare pan nathi kapto
/// - 🔥 Auto-retry: result khali / kapayel lage ke error aave to
///   ochhi strength thi farithi try → koi pan jewellery image chale
/// - 24 rang + custom rang + templates + potani gallery image
/// - 🖌️ Brush editor: baki rahel background kadho / kapayel bhag restore
/// - 📄 Save PDF: catalogue PDF (1/4/6/9 per page)
/// - Select All → WhatsApp share (gallery jevu j caption saathe)
/// - Disk cache: same batch farithi khole to images instant
/// ================================================================

/// ================================================================
/// 🔥 HQ SOURCE (TOP-LEVEL — background isolate ma chale)
///
/// - Image pehla thi nani (≤ maxW) ane rotation vagar ni hoy →
///   ORIGINAL bytes j vapro (farithi JPG encode nahi = 0 loss)
/// - Moti hoy → cubic resize + JPG quality 97
/// ================================================================

Uint8List _hqSource(Map<String, dynamic> a) {
  final Uint8List raw = a["raw"] as Uint8List;
  final int maxW = a["maxW"] as int;

  final img.Image? decoded = img.decodeImage(raw);
  if (decoded == null) throw Exception("Unable to decode image");

  final int orientation = decoded.exif.imageIfd.orientation ?? 1;

  // ✅ Kai badlavu nathi → original j (lossless)
  if (decoded.width <= maxW && orientation == 1) return raw;

  img.Image im = img.bakeOrientation(decoded);

  if (im.width > maxW) {
    im = img.copyResize(
      im,
      width: maxW,
      interpolation: img.Interpolation.cubic,
    );
  }

  return Uint8List.fromList(img.encodeJpg(im, quality: 97));
}

/// ================================================================
/// 🔥 SHARE JPG ENCODER (TOP-LEVEL — background isolate ma chale)
///
/// - Image bhaag par halku "unsharp" sharpen → sonu / nakshi /
///   stone vadhu crisp dekhay (caption par nahi → text ma halo nahi)
/// - JPG quality 95
/// ================================================================

Uint8List _encodeShareJpg(Map<String, dynamic> a) {
  final int w = a["w"] as int;
  final int h = a["h"] as int;
  final int sharpH = a["sharpH"] as int;
  final double amount = (a["amount"] as num).toDouble();

  final Uint8List px = Uint8List.fromList(a["rgba"] as Uint8List);

  if (amount > 0 && sharpH > 2 && w > 2) {
    // Original copy (blur aa parthi j gana — pixel badlata jay to pan)
    final Uint8List src = Uint8List.fromList(px.sublist(0, w * sharpH * 4));

    for (int y = 1; y < sharpH - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final int base = (y * w + x) * 4;

        for (int c = 0; c < 3; c++) {
          int sum = 0;
          for (int dy = -1; dy <= 1; dy++) {
            final int row = ((y + dy) * w) * 4;
            sum += src[row + (x - 1) * 4 + c] +
                src[row + x * 4 + c] +
                src[row + (x + 1) * 4 + c];
          }

          final double blur = sum / 9.0;
          final int v = src[base + c];
          final double out = v + amount * (v - blur);

          px[base + c] = out <= 0 ? 0 : (out >= 255 ? 255 : out.round());
        }
      }
    }
  }

  final img.Image image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: px.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// ================================================================
/// 🔥 CUTOUT KETLU DEKHAY CHE? (0.0 – 1.0)
///
/// 0.0 → badhu kadhai gayu (jewellery pan gai)
/// 1.0 → kai j nathi kadhayu (background rahi gayu)
/// Aa parthi nakki thay ke farithi biji strength thi try karvu ke nahi.
/// ================================================================

double _alphaCoverage(Uint8List png) {
  final img.Image? im = img.decodePng(png);
  if (im == null) return 0;

  // Alpha channel j nathi → kai kadhayu nathi
  if (im.numChannels < 4) return 1;

  int visible = 0;
  int total = 0;

  for (int y = 0; y < im.height; y += 3) {
    for (int x = 0; x < im.width; x += 3) {
      total++;
      if (im.getPixel(x, y).a > 40) visible++;
    }
  }

  return total == 0 ? 0 : visible / total;
}

/// ================================================================
/// 📄 PDF BUILDER (TOP-LEVEL — background isolate ma chale)
///
/// args:
///   title, date, perPage (1/4/6/9), showDetails,
///   totals: {count, gross, net},
///   items: [{name, code, gross, less, net, image(Uint8List)}]
/// ================================================================

Future<Uint8List> _buildBatchPdf(Map<String, dynamic> args) async {
  final String title = args["title"] as String;
  final String date = args["date"] as String;
  final int perPage = args["perPage"] as int;
  final bool showDetails = args["showDetails"] as bool;
  final Map totals = args["totals"] as Map;
  final List items = args["items"] as List;

  final PdfColor gold = PdfColor.fromHex("#C9A227");
  final PdfColor ink = PdfColor.fromHex("#1A1A1F");
  final PdfColor muted = PdfColor.fromHex("#8B8B93");
  final PdfColor line = PdfColor.fromHex("#ECE7DA");
  final PdfColor soft = PdfColor.fromHex("#FBF8F1");

  final int cols = perPage == 1 ? 1 : (perPage == 9 ? 3 : 2);
  final int rows = (perPage / cols).ceil();

  const double margin = 28;
  const double headerH = 46;
  const double footerH = 22;
  const double gap = 10;

  final double contentW = PdfPageFormat.a4.width - margin * 2;
  final double contentH =
      PdfPageFormat.a4.height - margin * 2 - headerH - footerH;

  final double cellW = (contentW - (cols - 1) * gap) / cols;
  final double cellH = (contentH - (rows - 1) * gap) / rows;

  // Column pramane font size
  final double nameSize = cols == 1 ? 16 : (cols == 2 ? 10 : 8);
  final double labelSize = cols == 1 ? 8.5 : (cols == 2 ? 6.5 : 5.5);
  final double valueSize = cols == 1 ? 12 : (cols == 2 ? 8.5 : 7);
  final double detailsH =
  !showDetails ? 0 : (cols == 1 ? 74 : (cols == 2 ? 48 : 40));

  final pw.Document doc = pw.Document(title: title, author: "Ornasphere");

  final int pageCount = (items.length / perPage).ceil();

  pw.Widget column(String label, String value, {bool highlight = false}) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: labelSize,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: valueSize,
              fontWeight: pw.FontWeight.bold,
              color: highlight ? gold : ink,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget cell(Map it) {
    final double less = double.tryParse(it["less"].toString()) ?? 0;
    final bool hasLess = less > 0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: line, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          /// IMAGE
          pw.Expanded(
            child: pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Container(
                width: cellW,
                color: soft,
                alignment: pw.Alignment.center,
                child: pw.Image(
                  pw.MemoryImage(it["image"] as Uint8List),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ),

          /// GOLD PATTI
          pw.Container(height: 1.4, color: gold),

          /// DETAILS
          if (showDetails)
            pw.Container(
              height: detailsH,
              padding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    (it["name"] as String).toUpperCase(),
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: nameSize,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                      letterSpacing: 0.6,
                    ),
                  ),
                  pw.SizedBox(height: cols == 1 ? 8 : 4),
                  pw.Row(
                    children: [
                      column("CODE", it["code"] as String),
                      column("G.WT", it["gross"] as String),
                      // Less hoy to j L.WT + N.WT (4 column),
                      // nahi to fakt CODE + G.WT (2 column)
                      if (hasLess) ...[
                        column("L.WT", it["less"] as String),
                        column("N.WT", it["net"] as String, highlight: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  for (int p = 0; p < pageCount; p++) {
    final List pageItems = items.sublist(
      p * perPage,
      ((p + 1) * perPage).clamp(0, items.length),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(margin),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              /// HEADER
              pw.Container(
                height: headerH,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: ink,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        pw.Text(
                          "Items ${totals["count"]}   |   "
                              "G.WT ${totals["gross"]}   |   N.WT ${totals["net"]}",
                          style: pw.TextStyle(fontSize: 8, color: muted),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      date,
                      style: pw.TextStyle(fontSize: 8, color: muted),
                    ),
                    pw.Spacer(),
                    pw.Container(height: 1.6, color: gold),
                  ],
                ),
              ),

              pw.SizedBox(height: gap),

              /// GRID
              pw.SizedBox(
                height: contentH - gap,
                child: pw.Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final dynamic it in pageItems)
                      pw.SizedBox(
                        width: cellW,
                        height: cellH - gap / rows,
                        child: cell(it as Map),
                      ),
                  ],
                ),
              ),

              /// FOOTER
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Ornasphere",
                    style: pw.TextStyle(fontSize: 7.5, color: muted),
                  ),
                  pw.Text(
                    "Page ${p + 1} / $pageCount",
                    style: pw.TextStyle(fontSize: 7.5, color: muted),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  return doc.save();
}

enum _BgState { pending, processing, done, failed }

class _BatchEntry {
  _BatchEntry(this.item) : id = item["id"].toString();

  final Map<String, dynamic> item;
  final String id;

  _BgState state = _BgState.pending;

  /// Background vagarni transparent PNG
  File? pngFile;

  /// HD original JPG (BG fail thay to fallback)
  File? sourceFile;

  /// Chalu processing nu Future (share vakhte wait karva)
  Future<void>? job;

  /// PNG ni size (model layout mate)
  Size? pngSize;

  /// Photo na alag tukda (set → necklace + earring)
  JewelParts? parts;

  /// 👩 Model par size / position
  final JewelAdjust adjust = JewelAdjust();

  /// User e haath thi badlel type (null = name parthi auto)
  JewelType? typeOverride;

  /// 🖌️ Edit mate: trim pehla ni aakhi PNG (original jetli size)
  File? fullPngFile;

  /// Cache vali mukhya PNG (edit pachi ahiya save → farithi kholo to edit male)
  File? mainPngFile;

  /// ✨ Aa item no potano background (prompt / selected images mate).
  /// null = upar select karel common background (_bg)
  BgTemplate? bg;

  JewelType get type =>
      typeOverride ?? JewelTypeDetector.detect(item["item_name"]?.toString());
}

class BatchImageScreen extends StatefulWidget {
  const BatchImageScreen({Key? key, required this.items}) : super(key: key);

  final List<Map<String, dynamic>> items;

  @override
  State<BatchImageScreen> createState() => _BatchImageScreenState();
}

class _BatchImageScreenState extends State<BatchImageScreen> {
  /// =========================================================
  /// SETTINGS
  /// =========================================================

  /// 🔥 FULL HD ma background remove ghanu memory le che (1 image ~200MB)
  /// → ek vakhte 1 j (phone crash na thay). Saro phone hoy to 2 kari shako.
  static const int _concurrency = 1;

  /// Share / PDF image banavvanu halku kaam → 2 ek saathe
  static const int _shareConcurrency = 2;

  /// 🔥 FULL HD output (share + PDF) — 1920px
  static const int _maxWidth = 1920;

  /// 🔥 Share image HAMESHA Full HD pahodi (1920px) — nani image HQ
  /// upscale thay, caption text ekdam sharp rahe
  static const int _shareMinWidth = 1920;

  /// 🔥 Halku sharpen (0 = bandh, 0.35 = natural crisp)
  static const double _sharpenAmount = 0.35;

  /// Share design badlay tyare ++ (fakt share cache refresh — BG farithi
  /// kadhvu na pade)
  static const int _shareVersion = 3; // 3 → less na hoy to CODE + G.WT j

  /// Background / model compose design-quality badlay tyare ++
  /// (fakt compose + share cache refresh — BG farithi kadhvu na pade)
  /// 2 → model 1920×2400 + JPG 97
  static const int _composeVersion = 2;

  /// 🔥 Default strength — ochhi rakhi che jethi item sahej pan na kapay
  /// (background thodu rahe to brush thi kadhi shakay, pan item kapay
  ///  e pachhu na aave)
  static const double _defaultStrength = 20;

  /// Cutout ma ochhama ochhi aatli jagya jewellery hovi joie
  /// (ena thi ochhu → jewellery kapai gai → ochhi strength thi farithi)
  static const double _minCoverage = 0.008;

  /// Aatlathi vadhare → background kadhayu j nathi → vadhu strength
  static const double _maxCoverage = 0.97;

  /// Design / logic badlay tyare ++ (juni cache ignore thay)
  /// 9 → background compose JPG 97 (juni 92 vaali refresh)
  static const int _cacheVersion = 9;

  /// =========================================================
  /// STATE
  /// =========================================================

  late final List<_BatchEntry> _entries;
  final Set<String> _selectedIds = {};

  /// Pasand karel background (rang athva template)
  BgTemplate _bg = BgTemplate.solid(const Color(0xffFFFFFF));

  /// 0 = Colors, 1 = Templates, 2 = Model
  int _bgTab = 0;

  /// Templates tab ni category
  String _tplCategory = BgCategory.all;

  /// 👩 Model try-on (Necklace / Earring mate)
  bool _useModel = false;
  ModelTemplate _model = ModelLibrary.models.first;
  String _modelStyle = ModelStyle.all;

  /// Aa item par kayo background lagse (potano hoy to e, nahi to common)
  BgTemplate _bgFor(_BatchEntry e) => e.bg ?? _bg;

  List<_BatchEntry> get _selectedEntries =>
      _entries.where((e) => _selectedIds.contains(e.id)).toList();

  /// 🎨 Background lagavo:
  ///  • koi image select hoy → fakt selected images par
  ///  • kai select na hoy  → badhi images par (common)
  void _applyBg(BgTemplate t) {
    setState(() {
      final sel = _selectedEntries;
      if (sel.isEmpty) {
        _bg = t;
        for (final e in _entries) {
          e.bg = null;
        }
      } else {
        for (final e in sel) {
          e.bg = t;
        }
      }
    });
  }

  /// Tile par ✓ — selected images (ke common) aa background vapre che?
  bool _isActiveBg(BgTemplate t) {
    final sel = _selectedEntries;
    if (sel.isEmpty) return _bg == t && _entries.every((e) => e.bg == null);
    return sel.every((e) => _bgFor(e) == t);
  }

  bool get _hasReadyImages =>
      _entries.any((e) => e.state == _BgState.done && e.pngFile != null);

  /// ✨ Prompt lakho → background bane → selected (ke badhi) images par
  Future<void> _openPromptBackground() async {
    if (_isProcessing && !_hasReadyImages) {
      AppMessage.error(context, "Please wait — background removal is still running");
      return;
    }
    final BgTemplate? t = await PromptBackground.open(context);
    if (t == null || !mounted) return;
    final int sel = _selectedIds.length;
    setState(() {
      _myTemplates.removeWhere((e) => e == t);
      _myTemplates.insert(0, t);
      _tplCategory = BgCategory.all;
    });
    _applyBg(t);
    AppMessage.success(
      context,
      sel == 0
          ? "Prompt background applied to all ${_entries.length} images"
          : "Prompt background applied to $sel selected image${sel == 1 ? "" : "s"}",
    );
  }

  Widget _buildPromptBar() {
    final int sel = _selectedIds.length;
    final bool locked = _isProcessing && !_hasReadyImages;
    final String target = sel == 0 ? "all ${_entries.length} images" : "$sel selected";

    return GestureDetector(
      onTap: _isSharing ? null : _openPromptBackground,
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Container(
          margin: const EdgeInsets.only(right: 4, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryDark.withOpacity(0.72)],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locked ? "Removing background… prompt unlocks soon" : "Type a prompt for background",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Applies to $target • tap images to select",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sel == 0 ? "ALL" : "$sel",
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _modelApplies(_BatchEntry e) =>
      _useModel && e.type != JewelType.other;

  /// User e banavel custom rang / gallery backgrounds
  final List<Color> _customColors = [];
  final List<BgTemplate> _myTemplates = [];

  final ImagePicker _picker = ImagePicker();
  bool _bgShadow = true;
  double _bgStrength = _defaultStrength;

  /// Strength badlay tyare ++ → juna chalu kaam nu result ignore
  int _generation = 0;

  bool _isSharing = false;
  bool _isDisposed = false;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  late final Future<Directory> _cacheDirFuture = _getCacheDir();

  final List<Future<void> Function()> _queue = [];
  int _active = 0;

  /// Share / PDF mate alag pool (BG remove ni line ma ubhu na rahe)
  final List<Future<void> Function()> _shareQueue = [];
  int _shareActive = 0;

  /// =========================================================
  /// INIT
  /// =========================================================

  @override
  void initState() {
    super.initState();

    _entries = widget.items.map((e) => _BatchEntry(e)).toList();

    _processAll();

    /// Gallery mathi umerel real models load
    ModelStore.load().then((list) {
      ModelLibrary.custom
        ..clear()
        ..addAll(list);
      _safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _queue.clear();
    _shareQueue.clear();
    _dio.close(force: true);
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// =========================================================
  /// HELPERS
  /// =========================================================

  String _stableHash(String input) {
    int hash = 0x811c9dc5;

    for (final int c in input.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash.toRadixString(16);
  }

  Future<Directory> _getCacheDir() async {
    final Directory tmp = await getTemporaryDirectory();
    final Directory dir = Directory("${tmp.path}/batch_bg_cache");

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  int get _doneCount => _entries
      .where((e) => e.state == _BgState.done || e.state == _BgState.failed)
      .length;

  bool get _isProcessing => _doneCount < _entries.length;

  /// =========================================================
  /// 🚀 WORKER POOL
  /// =========================================================

  Future<T> _runInPool<T>(Future<T> Function() task) {
    final Completer<T> completer = Completer<T>();

    _queue.add(() async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    _pump();

    return completer.future;
  }

  void _pump() {
    while (!_isDisposed && _active < _concurrency && _queue.isNotEmpty) {
      final Future<void> Function() job = _queue.removeAt(0);

      _active++;

      job().whenComplete(() {
        _active--;
        _pump();
      });
    }
  }

  /// Share / PDF image mate alag worker pool
  Future<T> _runInSharePool<T>(Future<T> Function() task) {
    final Completer<T> completer = Completer<T>();

    _shareQueue.add(() async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    _pumpShare();

    return completer.future;
  }

  void _pumpShare() {
    while (!_isDisposed &&
        _shareActive < _shareConcurrency &&
        _shareQueue.isNotEmpty) {
      final Future<void> Function() job = _shareQueue.removeAt(0);

      _shareActive++;

      job().whenComplete(() {
        _shareActive--;
        _pumpShare();
      });
    }
  }

  /// =========================================================
  /// 🔥 SMART BG REMOVE (HD)
  ///
  /// 1) Sidhu HD image par background kadho (autoCrop OFF →
  ///    output source jetli j size → brush editor barabar chale)
  /// 2) Result check:
  ///    - jewellery bahu ochhi bachi / error → ochhi strength thi farithi
  ///    - background kadhayu j nathi → vadhu strength thi ek vaar
  /// =========================================================

  Future<Uint8List> _removeBgHd(Uint8List hdSrc, double strength) async {
    final double base = strength.clamp(10.0, 80.0);

    Future<Uint8List> run(double s) => JewelleryBgRemover.removeBackground(
      hdSrc,
      strength: s,
      maxSide: 4000, // HD source ne farithi nani na kare
      autoCrop: false,
    );

    /// Try order: user strength → ochhi → vadhu ochhi
    final List<double> tries = [
      base,
      (base * 0.7).clamp(10.0, 80.0),
      (base * 0.45).clamp(8.0, 80.0),
    ];

    Uint8List? best;
    double bestScore = -1;
    Object? lastError;
    bool triedStronger = false;

    for (final double s in tries) {
      try {
        final Uint8List cut = await run(s);
        final double cov = await compute(_alphaCoverage, cut);

        debugPrint("🔍 BG TRY s=${s.toStringAsFixed(0)} → coverage "
            "${(cov * 100).toStringAsFixed(1)}%");

        /// ✅ Barabar result
        if (cov >= _minCoverage && cov <= _maxCoverage) {
          best = cut;
          break;
        }

        /// Background kadhayu j nathi → ek vaar vadhu strength
        if (cov > _maxCoverage) {
          if (!triedStronger) {
            triedStronger = true;
            try {
              final Uint8List strong =
              await run((base * 1.5).clamp(10.0, 80.0));
              final double c2 = await compute(_alphaCoverage, strong);

              if (c2 >= _minCoverage && c2 <= _maxCoverage) {
                best = strong;
                break;
              }
            } catch (e) {
              lastError = e;
            }
          }

          best ??= cut;
          break;
        }

        /// Bahu ochhi jewellery bachi → sauthi vadhu vaalu rakho,
        /// pachi ochhi strength thi farithi try
        if (cov > bestScore) {
          best = cut;
          bestScore = cov;
        }
      } catch (e) {
        lastError = e;
        debugPrint("⚠️ BG TRY FAILED s=$s => $e");
      }
    }

    if (best == null) {
      throw lastError ?? Exception("Background remove failed");
    }

    return best;
  }

  /// =========================================================
  /// 💎 BACKGROUND REMOVE — BADHI ITEMS
  /// =========================================================

  void _processAll() {
    for (final _BatchEntry e in _entries) {
      if (e.state == _BgState.pending) {
        _enqueue(e);
      }
    }
  }

  void _enqueue(_BatchEntry e) {
    final int gen = _generation;

    e.job = _runInPool(() => _processEntry(e, gen)).catchError((_) {});
  }

  Future<void> _processEntry(_BatchEntry e, int gen) async {
    if (_isDisposed || gen != _generation) return;

    _safeSetState(() => e.state = _BgState.processing);

    final String url = e.item["image_url"]?.toString().trim() ?? "";
    final int strength = _bgStrength.round();

    try {
      if (url.isEmpty) throw Exception("No image url");

      final Directory dir = await _cacheDirFuture;

      final String srcKey = _stableHash("$url|$_maxWidth|v$_cacheVersion");
      final String pngKey = _stableHash(
        "$url|$_maxWidth|s$strength|v$_cacheVersion",
      );

      final File srcFile = File("${dir.path}/${e.id}_${srcKey}_src.jpg");
      final File pngFile = File("${dir.path}/${e.id}_$pngKey.png");

      /// 🖌️ Edit mate trim pehla ni aakhi PNG
      final File fullFile = File("${dir.path}/${e.id}_${pngKey}_full.png");

      /// ⚡ CACHE HIT — pehla bani gayu che
      if (await pngFile.exists() && await pngFile.length() > 0) {
        if (gen != _generation) return;

        final Uint8List cachedPng = await pngFile.readAsBytes();
        final Size? cachedSize = await ModelComposer.readSize(cachedPng);
        final JewelParts? cachedParts = await JewelSplitter.split(cachedPng);

        _safeSetState(() {
          e.sourceFile = srcFile.existsSync() ? srcFile : null;
          e.pngFile = pngFile;
          e.mainPngFile = pngFile;
          e.fullPngFile = fullFile.existsSync() ? fullFile : null;
          e.pngSize = cachedSize;
          e.parts = cachedParts;
          e.state = _BgState.done;
        });
        return;
      }

      /// 1) SOURCE IMAGE (cache athva download + HD sudhi nani)
      Uint8List src;

      if (await srcFile.exists() && await srcFile.length() > 0) {
        src = await srcFile.readAsBytes();
      } else {
        final Response<List<int>> res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );

        final List<int>? data = res.data;

        if (data == null || data.isEmpty) throw Exception("Empty image");

        final Uint8List raw =
        data is Uint8List ? data : Uint8List.fromList(data);

        /// 🔥 HQ: nani hoy to original j, moti hoy to cubic + q97
        src = await compute(_hqSource, {
          "raw": raw,
          "maxW": _maxWidth,
        });

        await srcFile.writeAsBytes(src, flush: true);
      }

      if (_isDisposed || gen != _generation) return;

      _safeSetState(() => e.sourceFile = srcFile);

      /// 2) 🔥 SMART BACKGROUND REMOVE (sidhu HD par)
      final Uint8List removed = await _removeBgHd(src, strength.toDouble());

      if (_isDisposed || gen != _generation) return;

      /// 🖌️ Edit mate aakhi PNG save (HD source jetli j size)
      await fullFile.writeAsBytes(removed, flush: true);

      /// 3) Aaspas ni khali jagya kadho → podium / floor par barabar bese
      final Uint8List png = await BgComposer.trimTransparent(removed);

      await pngFile.writeAsBytes(png, flush: true);

      final Size? pngSize = await ModelComposer.readSize(png);

      /// 4) Tukda shodho (set → necklace + earring alag)
      final JewelParts? parts = await JewelSplitter.split(png);

      if (gen != _generation) return;

      _safeSetState(() {
        e.pngFile = pngFile;
        e.mainPngFile = pngFile;
        e.fullPngFile = fullFile;
        e.pngSize = pngSize;
        e.parts = parts;
        e.state = _BgState.done;
      });
    } catch (err) {
      debugPrint("❌ BATCH BG ERROR [${e.id}] => $err");

      if (gen != _generation) return;

      _safeSetState(() => e.state = _BgState.failed);
    }
  }

  void _retry(_BatchEntry e) {
    setState(() {
      e.state = _BgState.pending;
      e.pngFile = null;
    });

    _enqueue(e);
  }

  /// =========================================================
  /// 🖌️ BRUSH EDITOR — baki rahel background kadho / restore
  /// =========================================================

  Future<void> _openEraseEditor(_BatchEntry e) async {
    if (e.pngFile == null || e.sourceFile == null || e.mainPngFile == null) {
      AppMessage.error(context, "Image is not ready yet");
      return;
    }

    File? full = e.fullPngFile;

    /// Juni cache ma aakhi PNG nathi → ek vaar farithi banavo
    if (full == null || !await full.exists()) {
      final ValueNotifier<String> progress =
      ValueNotifier("Preparing editor...");
      final VoidCallback close = _showLoader(progress);

      try {
        final Uint8List removed = await _removeBgHd(
          await e.sourceFile!.readAsBytes(),
          _bgStrength,
        );

        full = File(e.mainPngFile!.path.replaceAll(".png", "_full.png"));
        await full.writeAsBytes(removed, flush: true);
        e.fullPngFile = full;
      } catch (err) {
        debugPrint("❌ EDITOR PREPARE ERROR => $err");
        close();
        if (mounted) AppMessage.error(context, "Unable to open editor");
        return;
      } finally {
        close();
        Future.delayed(const Duration(milliseconds: 400), progress.dispose);
      }
    }

    if (!mounted) return;

    final Uint8List? edited = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => BgEraseEditorScreen(
          cutoutFile: full!,
          originalFile: e.sourceFile!,
          title: _meta(e.item)["name"]!,
        ),
      ),
    );

    if (edited == null || !mounted) return;

    try {
      /// Aakhi PNG update → farithi edit karo to aagal thi chalu
      await full!.writeAsBytes(edited, flush: true);

      final Uint8List trimmed = await BgComposer.trimTransparent(edited);

      /// Mukhya cache file → batch farithi kholo to edit vali j aave
      await e.mainPngFile!.writeAsBytes(trimmed, flush: true);

      /// Screen par navi file (juni image cache ma na atke)
      final Directory dir = await _cacheDirFuture;
      final File view = File(
        "${dir.path}/${e.id}_edit_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await view.writeAsBytes(trimmed, flush: true);

      final Size? size = await ModelComposer.readSize(trimmed);
      final JewelParts? parts = await JewelSplitter.split(trimmed);

      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();

      _safeSetState(() {
        e.pngFile = view;
        e.pngSize = size;
        e.parts = parts;
      });

      if (mounted) AppMessage.success(context, "Background updated");
    } catch (err) {
      debugPrint("❌ EDITOR APPLY ERROR => $err");
      if (mounted) AppMessage.error(context, "Unable to apply changes");
    }
  }

  /// Strength badlay → badhi images farithi (cache thi source turant)
  void _reprocessAll() {
    _generation++;
    _queue.clear();

    setState(() {
      for (final _BatchEntry e in _entries) {
        e.state = _BgState.pending;
        e.pngFile = null;
      }
    });

    _processAll();
  }

  /// =========================================================
  /// SHARE META (gallery jevu j)
  /// =========================================================

  Map<String, String> _meta(Map<String, dynamic> item) {
    final String name = item["item_name"]?.toString().trim().isNotEmpty == true
        ? item["item_name"].toString().trim()
        : "Item";

    final String code = item["label_code"]?.toString().trim().isNotEmpty == true
        ? item["label_code"].toString().trim()
        : (item["qr_code"]?.toString().trim() ?? "-");

    String fmt(String key) =>
        (double.tryParse(item[key]?.toString() ?? "0") ?? 0)
            .toStringAsFixed(3);

    final String gross = fmt("gross_weight");
    final String net = fmt("net_weight");

    double lessVal =
        double.tryParse(item["other_weight"]?.toString() ?? "") ?? 0;

    if (lessVal <= 0) {
      final double diff =
          (double.tryParse(gross) ?? 0) - (double.tryParse(net) ?? 0);
      if (diff > 0.0005) lessVal = diff;
    }

    return {
      "name": name,
      "code": code,
      "gross": gross,
      "net": net,
      "less": lessVal.toStringAsFixed(3),
    };
  }

  /// =========================================================
  /// EK ITEM → FINAL SHARE JPG (BG rang + shadow + caption)
  /// =========================================================

  Future<XFile?> _buildShareFile(_BatchEntry e) async {
    if (_isDisposed) return null;

    final File? base = e.pngFile ?? e.sourceFile;
    if (base == null) return null;

    final Map<String, String> m = _meta(e.item);
    final Directory dir = await _cacheDirFuture;

    final String key = _stableHash(
      "${base.path}|${_bgFor(e).cacheKey}|$_bgShadow|"
          "${_modelApplies(e) ? "m_${_model.id}_${e.type.name}_${e.adjust.key}" : "bg"}|"
          "${m["name"]}|${m["code"]}|${m["gross"]}|${m["less"]}|${m["net"]}|"
          "v$_cacheVersion|share$_shareVersion|c$_composeVersion",
    );

    final File out = File("${dir.path}/${e.id}_${key}_share.jpg");

    if (await out.exists() && await out.length() > 0) {
      return XFile(out.path, mimeType: "image/jpeg");
    }

    /// 1) Template / rang / model par (cache saathe — PDF pan e j vapre)
    final Uint8List? composed = await _composedBytes(e);
    if (composed == null) return null;

    final Uint8List imageBytes = composed;

    /// 2) Caption
    Uint8List finalBytes;

    try {
      /// 🔥 FULL HD caption (1920px, sharpen, JPG 95)
      finalBytes = await _addCaptionHQ(
        imageBytes: imageBytes,
        name: m["name"]!,
        code: m["code"]!,
        grossWt: m["gross"]!,
        netWt: m["net"]!,
        lessWt: m["less"]!,
      );
    } catch (err) {
      debugPrint("❌ BATCH CAPTION ERROR [${e.id}] => $err");
      finalBytes = imageBytes;
    }

    await out.writeAsBytes(finalBytes, flush: true);

    /// 🔍 Final size console ma (HD check mate)
    try {
      final ui.ImmutableBuffer dbgBuf =
      await ui.ImmutableBuffer.fromUint8List(finalBytes);
      final ui.ImageDescriptor dbgDesc =
      await ui.ImageDescriptor.encoded(dbgBuf);
      debugPrint("📐 SHARE SIZE [${e.id}] => "
          "${dbgDesc.width} x ${dbgDesc.height}");
      dbgDesc.dispose();
      dbgBuf.dispose();
    } catch (_) {}

    return XFile(out.path, mimeType: "image/jpeg");
  }

  /// =========================================================
  /// 💎 HQ CAPTION BELOW IMAGE (Stock Gallery jevi j design)
  ///
  /// - Darek image → 1920px (Full HD) pahodi, nani hoy to HQ upscale
  /// - FilterQuality.high + anti-alias
  /// - Image bhaag par halku sharpen + JPG 95 (isolate ma)
  /// =========================================================

  Future<Uint8List> _addCaptionHQ({
    required Uint8List imageBytes,
    required String name,
    required String code,
    required String grossWt,
    required String netWt,
    String lessWt = "",
  }) async {
    final ui.ImmutableBuffer buffer =
    await ui.ImmutableBuffer.fromUint8List(imageBytes);
    final ui.ImageDescriptor descriptor =
    await ui.ImageDescriptor.encoded(buffer);
    final ui.Codec codec = await descriptor.instantiateCodec(
      targetWidth: descriptor.width > _maxWidth ? _maxWidth : null,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();
    final double scale = srcW < _shareMinWidth ? _shareMinWidth / srcW : 1.0;

    final double w = (srcW * scale).roundToDouble();
    final double imgHeight = (srcH * scale).roundToDouble();

    const Color inkColor = Color(0xff1A1A1F);
    const Color labelColor = Color(0xff9A9AA2);
    const Color goldColor = Color(0xffC9A227);
    const Color colDividerColor = Color(0xffECE7DA);

    final double lessValue = double.tryParse(lessWt) ?? 0;
    final bool hasLess = lessValue > 0;

    final List<List<String>> columns = [
      ["CODE", code],
      ["G.WT", grossWt],
      // Less hoy to j L.WT + N.WT (4 column), nahi to CODE + G.WT (2)
      if (hasLess) ["L.WT", lessWt],
      if (hasLess) ["N.WT", netWt],
    ];

    final int colCount = columns.length;
    final double colWidth = w / colCount;

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
    )..layout(maxWidth: w * 0.92);

    TextPainter painter(String text, TextStyle style, double maxW) {
      return TextPainter(
        text: TextSpan(text: text, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: "…",
      )..layout(maxWidth: maxW);
    }

    final List<TextPainter> labels = [
      for (final c in columns)
        painter(
          c[0],
          TextStyle(
            color: labelColor,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: labelFontSize * 0.14,
          ),
          colWidth - 8,
        ),
    ];

    final List<TextPainter> values = [
      for (int i = 0; i < colCount; i++)
        painter(
          columns[i][1],
          TextStyle(
            color: (hasLess && i == colCount - 1) ? goldColor : inkColor,
            fontSize: valueFontSize,
            fontWeight: FontWeight.w700,
          ),
          colWidth - 12,
        ),
    ];

    final double rowLabelHeight =
    labels.map((p) => p.height).reduce((a, b) => a > b ? a : b);
    final double rowValueHeight =
    values.map((p) => p.height).reduce((a, b) => a > b ? a : b);

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
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, totalHeight));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, totalHeight),
      Paint()..color = Colors.white,
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH(0, 0, w, imgHeight),
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, imgHeight, w, goldBarHeight),
      Paint()..color = goldColor,
    );

    double y = imgHeight + goldBarHeight + topPadding;

    namePainter.paint(canvas, Offset((w - namePainter.width) / 2, y));
    y += namePainter.height + afterNameGap;

    final double cx = w / 2;
    final double cy = y + ornamentDiamond;
    final Paint goldLine = Paint()
      ..color = goldColor
      ..strokeWidth = (w * 0.0012).clamp(1.0, 2.0);

    canvas.drawLine(
      Offset(cx - ornamentDiamond - ornamentGap - ornamentLineLen, cy),
      Offset(cx - ornamentDiamond - ornamentGap, cy),
      goldLine,
    );
    canvas.drawLine(
      Offset(cx + ornamentDiamond + ornamentGap, cy),
      Offset(cx + ornamentDiamond + ornamentGap + ornamentLineLen, cy),
      goldLine,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - ornamentDiamond)
        ..lineTo(cx + ornamentDiamond, cy)
        ..lineTo(cx, cy + ornamentDiamond)
        ..lineTo(cx - ornamentDiamond, cy)
        ..close(),
      Paint()..color = goldColor,
    );

    y += ornamentHeight + afterOrnamentGap;

    final double rowTopY = y;

    for (int i = 0; i < colCount; i++) {
      final double centerX = colWidth * (i + 0.5);
      labels[i].paint(canvas, Offset(centerX - labels[i].width / 2, rowTopY));
      values[i].paint(
        canvas,
        Offset(
          centerX - values[i].width / 2,
          rowTopY + rowLabelHeight + labelValueGap,
        ),
      );
    }

    final Paint divider = Paint()
      ..color = colDividerColor
      ..strokeWidth = (w * 0.0012).clamp(1.0, 2.0);

    for (int i = 1; i < colCount; i++) {
      canvas.drawLine(
        Offset(colWidth * i, rowTopY),
        Offset(
          colWidth * i,
          rowTopY + rowLabelHeight + labelValueGap + rowValueHeight,
        ),
        divider,
      );
    }

    final ui.Picture picture = recorder.endRecording();
    final int outW = w.toInt();
    final int outH = totalHeight.ceil();
    final ui.Image finalImage = await picture.toImage(outW, outH);
    final ByteData? raw =
    await finalImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    image.dispose();
    finalImage.dispose();
    picture.dispose();

    if (raw == null) throw Exception("Image export failed");

    return compute(_encodeShareJpg, {
      "w": outW,
      "h": outH,
      "rgba": raw.buffer.asUint8List(),
      "sharpH": imgHeight.toInt(),
      "amount": _sharpenAmount,
    });
  }

  /// =========================================================
  /// 🔥 WHATSAPP SHARE
  /// =========================================================

  Future<void> _shareWhatsApp() async {
    if (_isSharing) return;

    final List<_BatchEntry> selected =
    _entries.where((e) => _selectedIds.contains(e.id)).toList();

    if (selected.isEmpty) {
      AppMessage.error(context, "Please select at least one item");
      return;
    }

    /// 🔥 Photo (HD) ke Document (original quality)?
    final bool? asDocument = await _askShareMode(selected.length);
    if (asDocument == null || !mounted) return;

    _isSharing = true;

    final ValueNotifier<String> progress = ValueNotifier("Please wait...");
    final VoidCallback closeLoader = _showLoader(progress);

    int sharedCount = 0;
    int failedCount = 0;
    bool shared = false;

    try {
      /// 1) Haju BG remove chalu hoy e puru thay tyan sudhi wait
      final int pendingCount = selected
          .where((e) =>
      e.state == _BgState.pending || e.state == _BgState.processing)
          .length;

      if (pendingCount > 0) {
        progress.value = "Removing background ($pendingCount left)...";

        await Future.wait(
          selected.map((e) => e.job ?? Future<void>.value()),
        );
      }

      /// 2) Final images banavo
      int done = 0;
      final int total = selected.length;
      progress.value = "Preparing 0 / $total";

      final List<XFile?> results = await Future.wait(
        selected.map((e) {
          return _runInSharePool(() => _buildShareFile(e))
              .catchError((_) => null)
              .then((f) {
            done++;
            progress.value = "Preparing $done / $total";
            return f;
          });
        }),
      );

      List<XFile> files = results.whereType<XFile>().toList();

      sharedCount = files.length;
      failedCount = results.length - files.length;

      /// 📄 Document mode → code naam saathe copy (WhatsApp compress na kare)
      if (asDocument && files.isNotEmpty) {
        progress.value = "Preparing documents...";
        files = await _asDocuments(selected, results);
      }

      closeLoader();

      if (files.isEmpty) {
        if (mounted) AppMessage.error(context, "No images available to share");
        return;
      }

      final ShareResult result = await Share.shareXFiles(
        files,
        subject: "Stock Items",
      );

      if (!asDocument && mounted) {
        /// Photo mode → HD yaad apavo
        debugPrint("ℹ️ Photo mode: WhatsApp ma HD button dabavo");
      }

      shared = result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.unavailable;
    } catch (err, st) {
      debugPrint("❌ BATCH SHARE ERROR => $err\n$st");
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
  /// 📤 SHARE MODE — Photo (HD) / Document (original quality)
  ///
  /// - Photo: image hamesha 1920px+ → WhatsApp ma HD button chalu
  ///   rahe (WhatsApp HD pote dabavvu pade — app thi auto on nathi thatu)
  /// - Document: WhatsApp kai pan compress nathi kartu → 100% same
  /// =========================================================

  Future<bool?> _askShareMode(int count) {
    Widget option({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Share $count item(s)",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              option(
                icon: Icons.photo_rounded,
                color: const Color(0xff25D366),
                title: "Image (Full HD)",
                subtitle:
                "Shows as a photo in the chat • Tap the HD button in WhatsApp",
                onTap: () => Navigator.pop(sheetContext, false),
              ),
              const SizedBox(height: 10),
              option(
                icon: Icons.insert_drive_file_rounded,
                color: AppColors.primaryDark,
                title: "Document (Original quality)",
                subtitle:
                "WhatsApp won't compress it • 100% original quality",
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Share files ne item CODE naam saathe document tarike taiyar karo
  /// (daa.ta. OWG13.jpg) — WhatsApp aa file ne compress nathi kartu
  Future<List<XFile>> _asDocuments(
      List<_BatchEntry> entries,
      List<XFile?> results,
      ) async {
    final Directory base = await _cacheDirFuture;
    final Directory dir = Directory("${base.path}/share_docs");

    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    await dir.create(recursive: true);

    final Set<String> used = {};
    final List<XFile> out = [];

    for (int i = 0; i < entries.length && i < results.length; i++) {
      final XFile? f = results[i];
      if (f == null) continue;

      String name = _meta(entries[i].item)["code"]!
          .replaceAll(RegExp(r"[^A-Za-z0-9_-]"), "_");
      if (name.isEmpty || name == "_") name = "Item_${i + 1}";

      String fileName = "$name.jpg";
      int n = 2;
      while (used.contains(fileName)) {
        fileName = "${name}_$n.jpg";
        n++;
      }
      used.add(fileName);

      final File copy = await File(f.path).copy("${dir.path}/$fileName");

      /// Generic type → WhatsApp "Document" tarike mokle
      out.add(XFile(
        copy.path,
        name: fileName,
        mimeType: "application/octet-stream",
      ));
    }

    return out;
  }

  VoidCallback _showLoader(ValueNotifier<String> progress) {
    bool open = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Color(0xff25D366),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Preparing images",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<String>(
                    valueListenable: progress,
                    builder: (_, v, __) => Text(
                      v,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return () {
      if (!open) return;
      open = false;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    };
  }

  /// =========================================================
  /// 📄 SAVE AS PDF — background set karya pachi catalogue PDF
  /// =========================================================

  /// Background / model saathe ni image (caption vagar) — cache saathe
  Future<Uint8List?> _composedBytes(_BatchEntry e) async {
    final File? base = e.pngFile ?? e.sourceFile;
    if (base == null) return null;

    final Uint8List raw = await base.readAsBytes();

    // Background remove na thayu hoy to original j
    if (e.pngFile == null) return raw;

    final Directory dir = await _cacheDirFuture;

    final String key = _stableHash(
      "${base.path}|${_bgFor(e).cacheKey}|$_bgShadow|"
          "${_modelApplies(e) ? "m_${_model.id}_${e.type.name}_${e.adjust.key}" : "bg"}|"
          "comp_v$_cacheVersion|c$_composeVersion",
    );

    final File out = File("${dir.path}/${e.id}_${key}_comp.jpg");

    if (await out.exists() && await out.length() > 0) {
      return out.readAsBytes();
    }

    final Uint8List bytes = _modelApplies(e)
        ? await ModelComposer.compose(
      raw,
      _model,
      e.type,
      e.adjust,
      parts: e.parts,
      shadow: _bgShadow,
    )
        : await BgComposer.compose(
      raw,
      _bgFor(e),
      shadow: _bgShadow,
    );

    await out.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  Future<void> _askSavePdf() async {
    if (_isSharing) return;

    if (_entries.isEmpty) {
      AppMessage.error(context, "No items in batch");
      return;
    }

    final int selCount = _selectedIds.length;

    final TextEditingController titleController =
    TextEditingController(text: "Stock Catalogue");

    bool onlySelected = selCount > 0;
    int perPage = 4;
    bool showDetails = true;

    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Widget choice({
              required String label,
              required bool selected,
              required VoidCallback onTap,
              IconData? icon,
              bool enabled = true,
            }) {
              return Expanded(
                child: GestureDetector(
                  onTap: enabled ? onTap : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !enabled
                          ? Colors.grey.shade100
                          : (selected ? AppColors.primaryDark : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected && enabled
                            ? AppColors.primaryDark
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 18,
                            color: !enabled
                                ? Colors.grey
                                : (selected
                                ? Colors.white
                                : AppColors.primaryDark),
                          ),
                          const SizedBox(height: 3),
                        ],
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: !enabled
                                  ? Colors.grey
                                  : (selected
                                  ? Colors.white
                                  : AppColors.primaryDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget label(String t) => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xffE53E5A).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xffE53E5A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Save as PDF",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      label("Title"),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),

                      label("Items"),
                      Row(
                        children: [
                          choice(
                            label: "Selected ($selCount)",
                            selected: onlySelected,
                            enabled: selCount > 0,
                            onTap: () => setSheet(() => onlySelected = true),
                          ),
                          choice(
                            label: "All (${_entries.length})",
                            selected: !onlySelected,
                            onTap: () => setSheet(() => onlySelected = false),
                          ),
                        ],
                      ),

                      label("Items per page"),
                      Row(
                        children: [
                          choice(
                            label: "1",
                            icon: Icons.crop_portrait_rounded,
                            selected: perPage == 1,
                            onTap: () => setSheet(() => perPage = 1),
                          ),
                          choice(
                            label: "4",
                            icon: Icons.grid_view_rounded,
                            selected: perPage == 4,
                            onTap: () => setSheet(() => perPage = 4),
                          ),
                          choice(
                            label: "6",
                            icon: Icons.view_module_rounded,
                            selected: perPage == 6,
                            onTap: () => setSheet(() => perPage = 6),
                          ),
                          choice(
                            label: "9",
                            icon: Icons.apps_rounded,
                            selected: perPage == 9,
                            onTap: () => setSheet(() => perPage = 9),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppColors.primaryDark,
                        title: const Text(
                          "Show name, code & weights",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: showDetails,
                        onChanged: (v) => setSheet(() => showDetails = v),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Create PDF",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffE53E5A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
    );

    final String title = titleController.text.trim().isEmpty
        ? "Stock Catalogue"
        : titleController.text.trim();

    titleController.dispose();

    if (ok != true || !mounted) return;

    final List<_BatchEntry> items = onlySelected
        ? _entries.where((e) => _selectedIds.contains(e.id)).toList()
        : List<_BatchEntry>.from(_entries);

    await _createPdf(
      items: items,
      title: title,
      perPage: perPage,
      showDetails: showDetails,
    );
  }

  Future<void> _createPdf({
    required List<_BatchEntry> items,
    required String title,
    required int perPage,
    required bool showDetails,
  }) async {
    _isSharing = true;

    final ValueNotifier<String> progress = ValueNotifier("Please wait...");
    final VoidCallback closeLoader = _showLoader(progress);

    File? pdfFile;
    int skipped = 0;

    try {
      /// 1) Haju BG remove chalu hoy e puru thay tyan sudhi wait
      final int pending = items
          .where((e) =>
      e.state == _BgState.pending || e.state == _BgState.processing)
          .length;

      if (pending > 0) {
        progress.value = "Removing background ($pending left)...";
        await Future.wait(items.map((e) => e.job ?? Future<void>.value()));
      }

      /// 2) Darek item ni image (background / model saathe)
      int done = 0;
      final int total = items.length;
      progress.value = "Preparing 0 / $total";

      final List<Uint8List?> images = await Future.wait(
        items.map((e) {
          return _runInSharePool(() => _composedBytes(e))
              .catchError((_) => null)
              .then((b) {
            done++;
            progress.value = "Preparing $done / $total";
            return b;
          });
        }),
      );

      double grossSum = 0;
      double netSum = 0;

      final List<Map<String, dynamic>> pdfItems = [];

      for (int i = 0; i < items.length; i++) {
        final Uint8List? image = images[i];

        if (image == null) {
          skipped++;
          continue;
        }

        final Map<String, String> m = _meta(items[i].item);

        grossSum += double.tryParse(m["gross"]!) ?? 0;
        netSum += double.tryParse(m["net"]!) ?? 0;

        pdfItems.add({
          "name": m["name"]!,
          "code": m["code"]!,
          "gross": m["gross"]!,
          "less": m["less"]!,
          "net": m["net"]!,
          "image": image,
        });
      }

      if (pdfItems.isEmpty) {
        closeLoader();
        if (mounted) AppMessage.error(context, "No images available for PDF");
        return;
      }

      /// 3) PDF banavo (background isolate — UI hang na thay)
      progress.value = "Creating PDF...";

      final DateTime now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, "0");
      final String dateText =
          "${two(now.day)}-${two(now.month)}-${now.year}  ${two(now.hour)}:${two(now.minute)}";

      final Uint8List bytes = await compute(_buildBatchPdf, {
        "title": title,
        "date": dateText,
        "perPage": perPage,
        "showDetails": showDetails,
        "totals": {
          "count": pdfItems.length,
          "gross": grossSum.toStringAsFixed(3),
          "net": netSum.toStringAsFixed(3),
        },
        "items": pdfItems,
      });

      /// 4) Save (app documents → kayam rahe)
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory("${docs.path}/batch_pdf");
      if (!await dir.exists()) await dir.create(recursive: true);

      final String safeTitle = title
          .replaceAll(RegExp(r"[^A-Za-z0-9 _-]"), "")
          .trim()
          .replaceAll(RegExp(r"\s+"), "_");

      pdfFile = File(
        "${dir.path}/${safeTitle.isEmpty ? "Catalogue" : safeTitle}_"
            "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.pdf",
      );

      await pdfFile.writeAsBytes(bytes, flush: true);
    } catch (err, st) {
      debugPrint("❌ PDF CREATE ERROR => $err\n$st");
      closeLoader();
      if (mounted) AppMessage.error(context, "Unable to create PDF");
      return;
    } finally {
      closeLoader();
      _isSharing = false;
      Future.delayed(const Duration(milliseconds: 400), progress.dispose);
    }

    if (!mounted || pdfFile == null) return;

    if (skipped > 0) {
      AppMessage.error(context, "$skipped item(s) skipped (no image)");
    }

    _showPdfReady(pdfFile);
  }

  /// PDF taiyar → Open / Share
  void _showPdfReady(File file) {
    final String name = file.path.split("/").last;
    final double sizeMb = file.lengthSync() / (1024 * 1024);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xff2FAE60).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xff2FAE60),
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "PDF saved",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                "$name  •  ${sizeMb.toStringAsFixed(1)} MB",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          final result = await OpenFile.open(file.path);
                          if (result.type != ResultType.done && mounted) {
                            AppMessage.error(context, "Unable to open PDF");
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text("Open"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await Share.shareXFiles(
                            [XFile(file.path, mimeType: "application/pdf")],
                            subject: name,
                          );
                        },
                        icon: const Icon(Icons.share_rounded,
                            size: 18, color: Colors.white),
                        label: const Text(
                          "Share",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff25D366),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  /// =========================================================
  /// SELECT ALL
  /// =========================================================

  bool get _allSelected =>
      _entries.isNotEmpty && _selectedIds.length == _entries.length;

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_entries.map((e) => e.id));
      }
    });
  }

  /// =========================================================
  /// BUILD
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildBgOptions(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: _entries.length,
                itemBuilder: (_, i) => _buildCard(_entries[i]),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final int total = _entries.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
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
              const Expanded(
                child: Text(
                  "Batch with Image",
                  style: TextStyle(
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
                child: Text(
                  "Selected: ${_selectedIds.length}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          if (_isProcessing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? null : _doneCount / total,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Removing BG $_doneCount / $total",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// =========================================================
  /// 🎨 BACKGROUND OPTIONS — Colors | Templates | Model
  /// =========================================================

  Widget _buildBgOptions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ✨ PROMPT BAR — prompt → background → selected images
          _buildPromptBar(),

          /// TABS — Colors | Templates | Model
          Container(
            padding: const EdgeInsets.all(3),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _tabChip("Colors", Icons.palette_outlined, 0),
                _tabChip("Templates", Icons.wallpaper_rounded, 1),
                _tabChip("Model", Icons.face_retouching_natural_rounded, 2),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// LIST
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _bgTab == 0
                ? _buildColorList()
                : _bgTab == 1
                ? _buildTemplateList()
                : _buildModelList(),
          ),

          /// STRENGTH + SHADOW
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
                  onChanged: _isSharing
                      ? null
                      : (v) => setState(() => _bgStrength = v),
                  onChangeEnd: (_) => _reprocessAll(),
                ),
              ),
              const Text(
                "Shadow",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _bgShadow,
                  activeColor: AppColors.primaryDark,
                  onChanged: (v) => setState(() => _bgShadow = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, IconData icon, int index) {
    final bool selected = _bgTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bgTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : AppColors.primaryDark,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------------------------------------------------
  /// COLORS TAB — custom (+) + user rang + 24 ready rang
  /// ---------------------------------------------------------

  Widget _buildColorList() {
    final List<Color> all = [..._customColors, ...BgLibrary.colors];

    return SizedBox(
      key: const ValueKey("colors"),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _addColorTile(),
          ...all.map(_colorSwatch),
        ],
      ),
    );
  }

  Widget _addColorTile() {
    return GestureDetector(
      onTap: _openCustomColorSheet,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 16, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    final BgTemplate t = BgTemplate.solid(color);
    final bool selected = _isActiveBg(t);
    final bool dark = color.computeLuminance() < 0.4;

    return GestureDetector(
      onTap: () => _applyBg(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
          Icons.check_rounded,
          size: 17,
          color: dark ? Colors.white : AppColors.primaryDark,
        )
            : null,
      ),
    );
  }

  /// ---------------------------------------------------------
  /// TEMPLATES TAB — gallery (+) + my photos + assets + ready
  /// ---------------------------------------------------------

  Widget _buildTemplateList() {
    final List<BgTemplate> ready = _tplCategory == BgCategory.all
        ? BgLibrary.templates
        : BgLibrary.templates
        .where((t) => t.category == _tplCategory)
        .toList();

    final List<BgTemplate> all = [
      if (_tplCategory == BgCategory.all) ..._myTemplates,
      if (_tplCategory == BgCategory.all) ...BgLibrary.assetTemplates,
      ...ready,
    ];

    return Column(
      key: const ValueKey("templates"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// CATEGORY CHIPS
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: BgCategory.list.map(_categoryChip).toList(),
          ),
        ),

        const SizedBox(height: 10),

        /// TILES
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _galleryTile(),
              ...all.map(_templateTile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(String cat) {
    final bool selected = _tplCategory == cat;
    final int count = cat == BgCategory.all
        ? BgLibrary.templates.length
        : BgLibrary.templates.where((t) => t.category == cat).length;

    return GestureDetector(
      onTap: () => setState(() => _tplCategory = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cat == BgCategory.ai) ...[
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: selected ? Colors.white : AppColors.primaryDark,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              "$cat ($count)",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _galleryTile() {
    return GestureDetector(
      onTap: _pickGalleryBackground,
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryDark.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primaryDark,
                size: 22,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Gallery",
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateTile(BgTemplate t) {
    final bool selected = _isActiveBg(t);

    return GestureDetector(
      onTap: () => _applyBg(t),
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 58,
              height: 58,
              padding: EdgeInsets.all(selected ? 2 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primaryDark : AppColors.border,
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 8 : 11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BgTemplateView(template: t),
                    if (selected)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primaryDark : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gallery mathi potani background image
  Future<void> _pickGalleryBackground() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (picked == null || !mounted) return;

      final BgTemplate t = BgTemplate.file(picked.path);

      setState(() {
        _myTemplates.removeWhere((e) => e == t);
        _myTemplates.insert(0, t);
      });
      _applyBg(t);
    } catch (e) {
      debugPrint("❌ BG PICK ERROR => $e");
      if (mounted) AppMessage.error(context, "Unable to pick image");
    }
  }

  /// ---------------------------------------------------------
  /// 🎨 CUSTOM COLOR PICKER (Hue / Saturation / Lightness)
  /// ---------------------------------------------------------

  void _openCustomColorSheet() {
    final HSLColor start = HSLColor.fromColor(
      _bg.kind == BgKind.solid ? _bg.colors.first : const Color(0xffE6EEF6),
    );

    double hue = start.hue;
    double sat = start.saturation;
    double light = start.lightness;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final Color color = HSLColor.fromAHSL(1, hue, sat, light).toColor();

            Widget sliderRow(
                String label,
                double value,
                double max,
                List<Color> track,
                ValueChanged<double> onChanged,
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
                  const SizedBox(height: 6),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(colors: track),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 0,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white,
                          overlayColor: Colors.black12,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 11,
                            elevation: 3,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: max,
                          onChanged: onChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    /// TITLE + PREVIEW
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Custom Colour",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    sliderRow(
                      "Hue",
                      hue,
                      360,
                      [
                        for (int h = 0; h <= 360; h += 60)
                          HSLColor.fromAHSL(1, h.toDouble(), 1, 0.5).toColor(),
                      ],
                          (v) => setSheet(() => hue = v),
                    ),
                    const SizedBox(height: 10),
                    sliderRow(
                      "Saturation",
                      sat,
                      1,
                      [
                        HSLColor.fromAHSL(1, hue, 0, light).toColor(),
                        HSLColor.fromAHSL(1, hue, 1, light).toColor(),
                      ],
                          (v) => setSheet(() => sat = v),
                    ),
                    const SizedBox(height: 10),
                    sliderRow(
                      "Lightness",
                      light,
                      1,
                      [
                        Colors.black,
                        HSLColor.fromAHSL(1, hue, sat, 0.5).toColor(),
                        Colors.white,
                      ],
                          (v) => setSheet(() => light = v),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _customColors.removeWhere(
                                  (c) => c.value == color.value,
                            );
                            _customColors.insert(0, color);
                          });
                          _applyBg(BgTemplate.solid(color));
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Use this colour",
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
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================================
  /// 👩 MODEL TAB — Off + model list
  /// =========================================================

  Widget _buildModelList() {
    final int neckCount =
        _entries.where((e) => e.type == JewelType.necklace).length;
    final int earCount =
        _entries.where((e) => e.type == JewelType.earring).length;
    final int setCount = _entries.where((e) => e.type == JewelType.set).length;

    final List<ModelTemplate> models = ModelLibrary.byStyle(_modelStyle);

    return Column(
      key: const ValueKey("models"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// STYLE CHIPS
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ModelStyle.list.map(_modelStyleChip).toList(),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _modelOffTile(),
              _addModelTile(),
              ...models.map(_modelTile),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: Text(
            "Necklace $neckCount → neck  •  Earring $earCount → ears  •  "
                "Set $setCount → both. Others use the background. "
                "Long-press your model to edit.",
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _modelStyleChip(String style) {
    final bool selected = _modelStyle == style;
    final int count = ModelLibrary.byStyle(style).length;

    return GestureDetector(
      onTap: () => setState(() => _modelStyle = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Text(
          "$style ($count)",
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// ➕ Real model photo umero (gallery → points set)
  Widget _addModelTile() {
    return GestureDetector(
      onTap: _addRealModel,
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryDark.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primaryDark,
                size: 22,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Add Model",
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRealModel() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 3000,
        imageQuality: 100,
      );

      if (picked == null || !mounted) return;

      final String path = await ModelStore.importPhoto(picked.path);

      if (!mounted) return;

      final ModelTemplate? m = await Navigator.push<ModelTemplate>(
        context,
        MaterialPageRoute(
          builder: (_) => ModelCalibrateScreen(photoPath: path),
        ),
      );

      if (m == null) {
        await ModelStore.deletePhoto(
          ModelTemplate(id: "tmp", name: "", filePath: path),
        );
        return;
      }

      ModelLibrary.custom.insert(0, m);
      await ModelStore.save(ModelLibrary.custom);

      _safeSetState(() {
        _model = m;
        _useModel = true;
      });

      if (mounted) AppMessage.success(context, "Model \"${m.name}\" added");
    } catch (err) {
      debugPrint("❌ ADD MODEL ERROR => $err");
      if (mounted) AppMessage.error(context, "Unable to add model");
    }
  }

  /// Long-press → edit points / delete
  void _customModelMenu(ModelTemplate m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text("Edit points"),
              onTap: () async {
                Navigator.pop(sheetContext);

                final ModelTemplate? updated =
                await Navigator.push<ModelTemplate>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ModelCalibrateScreen(
                      photoPath: m.filePath!,
                      existing: m,
                    ),
                  ),
                );

                if (updated == null) return;

                final int i = ModelLibrary.custom.indexOf(m);
                if (i != -1) ModelLibrary.custom[i] = updated;
                await ModelStore.save(ModelLibrary.custom);

                _safeSetState(() {
                  if (_model == m) _model = updated;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                "Delete model",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);

                ModelLibrary.custom.remove(m);
                await ModelStore.save(ModelLibrary.custom);
                await ModelStore.deletePhoto(m);

                _safeSetState(() {
                  if (_model == m) {
                    _model = ModelLibrary.models.first;
                    _useModel = false;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSection(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelOffTile() {
    final bool selected = !_useModel;

    return GestureDetector(
      onTap: () => setState(() => _useModel = false),
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryDark.withOpacity(0.10)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primaryDark : AppColors.border,
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: Icon(
                Icons.block_rounded,
                color: selected ? AppColors.primaryDark : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Off",
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primaryDark : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelTile(ModelTemplate m) {
    final bool selected = _useModel && _model == m;

    return GestureDetector(
      onTap: () => setState(() {
        _model = m;
        _useModel = true;
      }),
      onLongPress: m.isCustom ? () => _customModelMenu(m) : null,
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 58,
              height: 58,
              padding: EdgeInsets.all(selected ? 2 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primaryDark : AppColors.border,
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 8 : 11),
                child: ModelThumb(model: m),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              m.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primaryDark : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// 🎚️ ADJUST SHEET — type, size, position, pair
  /// =========================================================

  void _openAdjustSheet(_BatchEntry e) {
    if (e.pngFile == null || e.pngSize == null) {
      AppMessage.error(context, "Image is still processing");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            void update(VoidCallback fn) {
              setSheet(fn);
              setState(() {});
            }

            final JewelType type = e.type;
            final bool onModel = type != JewelType.other;
            final bool isEar = type == JewelType.earring;
            final bool isSet = type == JewelType.set;

            Widget slider(
                String label,
                double value,
                double min,
                double max,
                ValueChanged<double> onChanged,
                ) {
              return Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
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

            Widget typeChip(JewelType t) {
              final bool sel = type == t;

              return Expanded(
                child: GestureDetector(
                  onTap: () => update(() {
                    e.typeOverride = t;
                    e.adjust.reset();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryDark : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppColors.primaryDark : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t.icon,
                          size: 15,
                          color: sel ? Colors.white : AppColors.primaryDark,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                sel ? Colors.white : AppColors.primaryDark,
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

            final int sameTypeCount =
                _entries.where((x) => x.type == type && x != e).length;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// TITLE
                      Row(
                        children: [
                          const Icon(
                            Icons.face_retouching_natural_rounded,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _meta(e.item)["name"]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),

                      /// PREVIEW
                      Center(
                        child: SizedBox(
                          height: 290,
                          child: AspectRatio(
                            aspectRatio: 0.8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: onModel
                                  ? ModelPreview(
                                model: _model,
                                png: e.pngFile!,
                                pngSize: e.pngSize!,
                                type: type,
                                adjust: e.adjust,
                                parts: e.parts,
                                adjustKey: e.adjust.key,
                              )
                                  : JewelOnBackground(
                                template: _bgFor(e),
                                png: e.pngFile!,
                                shadow: _bgShadow,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      /// TYPE
                      const Text(
                        "Jewellery type",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          typeChip(JewelType.necklace),
                          typeChip(JewelType.earring),
                          typeChip(JewelType.set),
                          typeChip(JewelType.other),
                        ],
                      ),

                      if (onModel) ...[
                        const SizedBox(height: 10),

                        if (isSet)
                          _sheetSection("Necklace", Icons.all_inclusive_rounded),

                        slider("Size", e.adjust.scale, 0.4, 2.0,
                                (v) => update(() => e.adjust.scale = v)),
                        slider("Up / Down", e.adjust.dy, -0.15, 0.30,
                                (v) => update(() => e.adjust.dy = v)),
                        slider(isEar ? "Spread" : "Left / Right",
                            e.adjust.dx, -0.12, 0.12,
                                (v) => update(() => e.adjust.dx = v)),

                        /// 🔥 SET — earring alag adjust
                        if (isSet) ...[
                          _sheetSection("Earrings", Icons.hearing_rounded),
                          slider("Size", e.adjust.earScale, 0.4, 2.5,
                                  (v) => update(() => e.adjust.earScale = v)),
                          slider("Up / Down", e.adjust.earDy, -0.10, 0.15,
                                  (v) => update(() => e.adjust.earDy = v)),
                          slider("Spread", e.adjust.earDx, -0.10, 0.10,
                                  (v) => update(() => e.adjust.earDx = v)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              (e.parts?.count ?? 0) >= 2
                                  ? "Found ${e.parts!.count} pieces in photo — "
                                  "biggest = necklace, side pieces = earrings."
                                  : "Could not find separate earrings in this "
                                  "photo, so it is shown as a necklace.",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],

                        if (isEar)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: AppColors.primaryDark,
                            title: const Text(
                              "Photo has a pair (2 earrings)",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              "On: use both earrings • Off: mirror one earring",
                              style: TextStyle(fontSize: 10.5),
                            ),
                            value: e.adjust.isPair(e.pngSize!),
                            onChanged: (v) => update(() => e.adjust.pair = v),
                          ),

                        if (sameTypeCount > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                update(() {
                                  for (final _BatchEntry x in _entries) {
                                    if (x != e && x.type == type) {
                                      x.adjust.copyFrom(e.adjust);
                                    }
                                  }
                                });
                                AppMessage.success(
                                  context,
                                  "Applied to $sameTypeCount ${type.label.toLowerCase()}(s)",
                                );
                              },
                              icon: const Icon(Icons.copy_all_rounded, size: 18),
                              label: Text(
                                "Apply to all ${type.label}s ($sameTypeCount)",
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryDark,
                              ),
                            ),
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            "This item will use the selected background, "
                                "not the model.",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      /// RESET + DONE
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () => update(() {
                                  e.adjust.reset();
                                  e.typeOverride = null;
                                }),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Reset",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Done",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
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
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================================
  /// GRID CARD
  /// =========================================================

  Widget _buildCard(_BatchEntry e) {
    final bool isSelected = _selectedIds.contains(e.id);
    final Map<String, String> m = _meta(e.item);
    final String url = e.item["image_url"]?.toString().trim() ?? "";

    Widget preview;

    if (e.state == _BgState.done && e.pngFile != null) {
      preview = (_modelApplies(e) && e.pngSize != null)
          ? ModelPreview(
        model: _model,
        png: e.pngFile!,
        pngSize: e.pngSize!,
        type: e.type,
        adjust: e.adjust,
        parts: e.parts,
        adjustKey: e.adjust.key,
      )
          : JewelOnBackground(
        template: _bgFor(e),
        png: e.pngFile!,
        shadow: _bgShadow,
      );
    } else {
      final Widget original = e.sourceFile != null
          ? Image.file(e.sourceFile!, fit: BoxFit.cover, cacheWidth: 450)
          : (url.isNotEmpty
          ? Image.network(url,
          fit: BoxFit.cover,
          cacheWidth: 450,
          errorBuilder: (_, __, ___) => const SizedBox.shrink())
          : const SizedBox.shrink());

      preview = Stack(
        fit: StackFit.expand,
        children: [
          original,
          if (e.state == _BgState.pending || e.state == _BgState.processing)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
            ),
          if (e.state == _BgState.failed)
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: InkWell(
                onTap: () => _retry(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "BG failed • Retry",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(e.id);
          } else {
            _selectedIds.add(e.id);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gradientBlue : AppColors.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.gradientBlue
                              : Colors.white.withOpacity(0.9),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gradientBlue
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                            size: 15, color: Colors.white)
                            : null,
                      ),
                    ),

                    /// 👩 MODEL MODE — type + adjust chip
                    if (_useModel && e.state == _BgState.done)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: GestureDetector(
                          onTap: () => _openAdjustSheet(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(e.type.icon,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  e.type.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.tune_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    /// 🖌️ EDIT — brush thi background sudharo
                    if (e.state == _BgState.done && e.pngFile != null)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: GestureDetector(
                          onTap: () => _openEraseEditor(e),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.brush_rounded,
                              size: 16,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m["name"]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${m["code"]}  •  N.WT ${m["net"]}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                    const TextStyle(fontSize: 10.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// BOTTOM BAR — SELECT ALL + SAVE PDF + WHATSAPP
  /// =========================================================

  Widget _buildBottomBar() {
    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? fill,
    }) {
      final bool outlined = fill == null;

      return Expanded(
        child: SizedBox(
          height: 48,
          child: Material(
            color: outlined ? Colors.white : fill,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: outlined
                    ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                )
                    : null,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color:
                          outlined ? AppColors.primaryDark : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                            outlined ? AppColors.primaryDark : Colors.white,
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
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          btn(
            icon: _allSelected
                ? Icons.close_rounded
                : Icons.select_all_rounded,
            label: _allSelected ? "Clear All" : "Select All",
            onTap: _toggleSelectAll,
          ),
          const SizedBox(width: 8),
          btn(
            icon: Icons.picture_as_pdf_rounded,
            label: "Save PDF",
            fill: const Color(0xffE53E5A),
            onTap: _askSavePdf,
          ),
          const SizedBox(width: 8),
          btn(
            icon: Icons.share_rounded,
            label: "WhatsApp (${_selectedIds.length})",
            fill: const Color(0xff25D366),
            onTap: _shareWhatsApp,
          ),
        ],
      ),
    );
  }
}
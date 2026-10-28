import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'JewelleryCaptionComposer.dart';

/// ================================================================
/// 👩 MODEL TEMPLATES (VIRTUAL TRY-ON)
///
/// - Item name parthi type olkhay: Chain / Necklace → gala par,
///   Earring / Tops / Jhumka → kaan par (banne baju)
/// - 🔥 SET (Necklace + Earring ek j photo ma): photo na tukda
///   alag pade — sauthi moto tukdo gala par, ena pachhi na 2 nana
///   tukda kaan par (photo ma game tya hoy — necklace ni andar pan)
/// - ✂️ SET: gala par fakt necklace j rahe — earring / tukda /
///   tikka bhusai jay (pixel level — chain kapati nathi)
/// - Earring image ma jodi (2) hoy to banne alag olkhay,
///   ek j hoy to bije kaan par mirror thay
/// - Real model photo (Traditional / Western) gallery mathi umero,
///   gala ane kaan par tap kari points set karo
/// - Model code thi j bane (mannequin bust + model look)
/// - Potano model photo (asset) pan vaparay — anchor points aapo
/// - Preview ane final share image ek j layout thi bane
///
/// 🔥 HQ:
///  - Final model image 1920 × 2400 (pehla 1000 × 1250)
///  - Model photo 2400px sudhi (nani hoy to moti nahi)
///  - JPG quality 97 (pehla 92)
/// ================================================================

/// =========================================================
/// JEWEL TYPE
/// =========================================================

enum JewelType { necklace, earring, set, other }

extension JewelTypeX on JewelType {
  String get label {
    switch (this) {
      case JewelType.necklace:
        return "Necklace";
      case JewelType.earring:
        return "Earring";
      case JewelType.set:
        return "Set";
      case JewelType.other:
        return "Other";
    }
  }

  IconData get icon {
    switch (this) {
      case JewelType.necklace:
        return Icons.all_inclusive_rounded;
      case JewelType.earring:
        return Icons.hearing_rounded;
      case JewelType.set:
        return Icons.auto_awesome_mosaic_rounded;
      case JewelType.other:
        return Icons.diamond_outlined;
    }
  }
}

class JewelTypeDetector {
  JewelTypeDetector._();

  /// Pakka necklace shabdo
  static const List<String> _neckStrong = [
    "necklace", "neckless", "necklec", "chain", "mangalsutra", "mangal sutra",
    "pendant", "pendent", "choker", "haar", "rani haar", "kanthi", "tanmaniya",
  ];

  static const List<String> _ear = [
    "earring", "earrings", "ear ring", "ear rings", "tops", "jhumka", "jhumki",
    "jumka", "jumki", "bali", "balis", "stud", "studs", "kanser", "latkan",
    "hoop", "hoops", "chandbali", "earcuff", "ear cuff", "drops",
  ];

  /// Necklace + earring saathe
  static const List<String> _set = [
    "set", "necklace set", "bridal set", "jewellery set", "jewelry set",
    "combo", "har set",
  ];

  /// Nabda shabdo (chhelle check)
  static const List<String> _neckWeak = ["mala", "locket", "har"];

  static JewelType detect(String? name) {
    final String n = (name ?? "").toLowerCase();

    final Set<String> tokens = n
        .split(RegExp(r"[^a-z]+"))
        .where((e) => e.isNotEmpty)
        .toSet();

    bool hit(List<String> keys) => keys.any(
          (k) => k.contains(" ") ? n.contains(k) : tokens.contains(k),
    );

    final bool neck = hit(_neckStrong);
    final bool ear = hit(_ear);

    // "Necklace with earrings", "Choker set" → SET
    if ((neck && ear) || hit(_set)) return JewelType.set;
    if (neck) return JewelType.necklace;
    if (ear) return JewelType.earring;
    if (hit(_neckWeak)) return JewelType.necklace;

    return JewelType.other;
  }

  /// 🔥 Photo joi ne type sudharo (tukda malya pachhi call karo):
  ///  - SET pan photo ma earring nathi (fakt chain / mangalsutra)
  ///    → NECKLACE (gala par)
  ///  - OTHER pan photo ma necklace + earring alag dekhay → SET
  static JewelType refine(JewelType t, JewelParts? parts) {
    if (parts == null) return t;

    final bool ears = ModelLayout.hasEarrings(parts);

    if (t == JewelType.set && !ears) return JewelType.necklace;
    if (t == JewelType.other && ears) return JewelType.set;

    return t;
  }

  /// Name + photo banne parthi type (sauthi saru)
  static JewelType detectWithParts(String? name, JewelParts? parts) =>
      refine(detect(name), parts);
}

/// =========================================================
/// PER-ITEM ADJUST (size / position / pair)
/// =========================================================

class JewelAdjust {
  /// Necklace (athva fakt earring hoy to earring)
  double scale = 1.0;
  double dx = 0.0; // necklace: dabe-jamne, earring: vadhu dur / najik
  double dy = 0.0; // upar-niche

  /// SET mate earring alag
  double earScale = 1.0;
  double earDx = 0.0;
  double earDy = 0.0;

  bool? pair; // null = auto detect

  /// 🌟 Necklace ni golai (0 = sapat, 1 = vadhu gol)
  double wrap = 0.6;

  /// ✨ AI LOOK — contrast + rang + chamak (glow)
  /// 0 = original, 0.6 = default, 1 = vadhu
  double enhance = 0.6;

  void reset() {
    enhance = 0.6;
    wrap = 0.6;
    scale = 1.0;
    dx = 0.0;
    dy = 0.0;
    earScale = 1.0;
    earDx = 0.0;
    earDy = 0.0;
    pair = null;
  }

  void copyFrom(JewelAdjust o) {
    enhance = o.enhance;
    wrap = o.wrap;
    scale = o.scale;
    dx = o.dx;
    dy = o.dy;
    earScale = o.earScale;
    earDx = o.earDx;
    earDy = o.earDy;
    pair = o.pair;
  }

  /// Jodi photo hoy to image pahodi hoy
  bool isPair(Size png) => pair ?? (png.width / png.height > 0.95);

  String get key =>
      "${scale.toStringAsFixed(2)}_${dx.toStringAsFixed(3)}_"
          "${dy.toStringAsFixed(3)}_${earScale.toStringAsFixed(2)}_"
          "${earDx.toStringAsFixed(3)}_${earDy.toStringAsFixed(3)}_${pair ?? 'a'}_"
          "w${wrap.toStringAsFixed(2)}_e${enhance.toStringAsFixed(2)}";

  Map<String, dynamic> toJson() => {
    "scale": scale,
    "dx": dx,
    "dy": dy,
    "earScale": earScale,
    "earDx": earDx,
    "earDy": earDy,
    "wrap": wrap,
    "enhance": enhance,
  };

  static JewelAdjust fromJson(Map<String, dynamic> j) {
    double d(String k, double def) =>
        (j[k] is num) ? (j[k] as num).toDouble() : def;

    return JewelAdjust()
      ..scale = d("scale", 1.0)
      ..dx = d("dx", 0.0)
      ..dy = d("dy", 0.0)
      ..earScale = d("earScale", 1.0)
      ..earDx = d("earDx", 0.0)
      ..earDy = d("earDy", 0.0)
      ..wrap = d("wrap", 0.6)
      ..enhance = d("enhance", 0.6);
  }
}

/// =========================================================
/// 💾 DEFAULT ADJUST — ek vaar set karo, badha item ma auto
///
/// Model + type (Necklace / Earring / Set) pramane size /
/// position yaad rakhe. Pachhi e model par je pan item muko
/// e AAPMELE e j rite bese — kai adjust karvanu nahi.
///
/// Vapro:
///   1) App khule tyare:  await AdjustDefaults.load();
///   2) Item/model badlay: AdjustDefaults.apply(adjust, model, type);
///   3) Sheet ma "Save as default" button: AdjustDefaultButton(...)
///   4) Reset:            AdjustDefaults.reset(adjust, model, type);
/// =========================================================

class AdjustDefaults {
  AdjustDefaults._();

  static final Map<String, JewelAdjust> _map = {};
  static bool _loaded = false;

  static String _key(ModelTemplate m, JewelType t) => "${m.id}|${t.name}";

  static Future<File> _file() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory("${docs.path}/batch_models");
    if (!await dir.exists()) await dir.create(recursive: true);
    return File("${dir.path}/adjust_defaults.json");
  }

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final File f = await _file();
      if (await f.exists()) {
        final Map data = jsonDecode(await f.readAsString()) as Map;
        data.forEach((k, v) {
          if (v is Map) {
            _map[k.toString()] =
                JewelAdjust.fromJson(Map<String, dynamic>.from(v));
          }
        });
      }
    } catch (e) {
      debugPrint("❌ ADJUST DEFAULT LOAD ERROR => $e");
    }
    _loaded = true;
  }

  static Future<void> _persist() async {
    try {
      final File f = await _file();
      await f.writeAsString(
        jsonEncode(_map.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (e) {
      debugPrint("❌ ADJUST DEFAULT SAVE ERROR => $e");
    }
  }

  /// Aa model + type no default save karel che?
  static bool has(ModelTemplate m, JewelType t) => _map.containsKey(_key(m, t));

  /// Saved default lagavo (na hoy to adjust jem che em rahe).
  /// Item par user e kai badlyu na hoy tyare call karo.
  static bool apply(JewelAdjust target, ModelTemplate m, JewelType t) {
    final JewelAdjust? d = _map[_key(m, t)];
    if (d == null) return false;

    final bool? pair = target.pair;
    target.copyFrom(d);
    target.pair = pair; // jodi item pramane j rahe
    return true;
  }

  /// Hal nu adjust aa model + type mate default banavo
  static Future<void> save(
      JewelAdjust from,
      ModelTemplate m,
      JewelType t,
      ) async {
    _map[_key(m, t)] = JewelAdjust()..copyFrom(from);
    await _persist();
  }

  /// Default kadhi nakho (factory value par pacho)
  static Future<void> clear(ModelTemplate m, JewelType t) async {
    _map.remove(_key(m, t));
    await _persist();
  }

  /// Reset = saved default (hoy to), nahi to factory value
  static void reset(JewelAdjust target, ModelTemplate m, JewelType t) {
    target.reset();
    apply(target, m, t);
  }

  /// Ek model + type nu default badha item par ek saathe
  static void applyToAll(
      Iterable<JewelAdjust> items,
      ModelTemplate m,
      JewelType t,
      ) {
    for (final JewelAdjust a in items) {
      apply(a, m, t);
    }
  }
}

/// "Save as default" button — adjust sheet ma Done ni upar muko
class AdjustDefaultButton extends StatefulWidget {
  const AdjustDefaultButton({
    Key? key,
    required this.adjust,
    required this.model,
    required this.type,
    this.color,
    this.onSaved,
  }) : super(key: key);

  final JewelAdjust adjust;
  final ModelTemplate model;
  final JewelType type;
  final Color? color;

  /// Save pachhi (jem ke badha item par apply karva)
  final VoidCallback? onSaved;

  @override
  State<AdjustDefaultButton> createState() => _AdjustDefaultButtonState();
}

class _AdjustDefaultButtonState extends State<AdjustDefaultButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final Color c = widget.color ?? Theme.of(context).colorScheme.primary;
    final bool saved = AdjustDefaults.has(widget.model, widget.type);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withOpacity(0.35), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _busy
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: c),
        )
            : Icon(
          saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
          size: 20,
        ),
        label: Text(
          saved
              ? "Update default (${widget.type.label})"
              : "Save as default (${widget.type.label})",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: _busy
            ? null
            : () async {
          setState(() => _busy = true);
          await AdjustDefaults.save(
            widget.adjust,
            widget.model,
            widget.type,
          );
          if (!mounted) return;
          setState(() => _busy = false);
          widget.onSaved?.call();
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                "${widget.model.name} par badha ${widget.type.label} "
                    "have aa rite j set thase",
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

/// =========================================================
/// ✂️ JEWEL PARTS — photo na alag alag tukda (isolate ma)
///
/// Transparent PNG ma je je vastu ek-bija thi alag che e
/// shodhe (necklace, 2 earring...). Moti thi nani kram ma.
/// (Fakt olakhva mate nani copy vapre — quality par asar nathi)
/// =========================================================

class JewelParts {
  const JewelParts(this.rects, this.areas);

  /// 0..1 fraction (image na), moti thi nani
  final List<Rect> rects;
  final List<double> areas;

  int get count => rects.length;
}

/// Nani copy par label map + tukda (split ane erase banne vapre)
class _Labeled {
  _Labeled(this.w, this.h, this.label, this.comps);

  final int w;
  final int h;
  final Int32List label;

  /// [x, y, w, h, area, labelId] — moti thi nani
  final List<List<double>> comps;
}

_Labeled? _labelParts(img.Image im) {
  // 🔥 400px (pehla 260) — necklace ni najik padel earring pan
  // alag tukda tarike olkhay (chain na mani to pan jodai j rahe)
  final double sc = math.min(1.0, 400 / math.max(im.width, im.height));

  final img.Image small = sc < 1
      ? img.copyResize(
    im,
    width: math.max(1, (im.width * sc).round()),
    height: math.max(1, (im.height * sc).round()),
    interpolation: img.Interpolation.average,
  )
      : im;

  final int w = small.width;
  final int h = small.height;
  if (w <= 0 || h <= 0) return null;

  // 1) Mask (alpha)
  final Uint8List mask = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (small.getPixel(x, y).a > 40) mask[y * w + x] = 1;
    }
  }

  // 2) Dilate — chain na mani/kadi jodai jay
  const int r = 2;
  final Uint8List dil = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (mask[y * w + x] == 0) continue;
      for (int dy = -r; dy <= r; dy++) {
        final int yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (int dx = -r; dx <= r; dx++) {
          final int xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          dil[yy * w + xx] = 1;
        }
      }
    }
  }

  // 3) Connected components
  final Int32List label = Int32List(w * h);
  final Int32List queue = Int32List(w * h);
  final List<List<double>> comps = [];
  int next = 0;
  int total = 0;

  for (int i = 0; i < w * h; i++) {
    if (dil[i] == 0 || label[i] != 0) continue;

    next++;
    int head = 0, tail = 0;
    queue[tail++] = i;
    label[i] = next;

    int minX = w, minY = h, maxX = 0, maxY = 0, area = 0;

    while (head < tail) {
      final int p = queue[head++];
      final int px = p % w;
      final int py = p ~/ w;

      if (mask[p] == 1) area++;
      if (px < minX) minX = px;
      if (px > maxX) maxX = px;
      if (py < minY) minY = py;
      if (py > maxY) maxY = py;

      for (int dy = -1; dy <= 1; dy++) {
        final int ny = py + dy;
        if (ny < 0 || ny >= h) continue;
        for (int dx = -1; dx <= 1; dx++) {
          final int nx = px + dx;
          if (nx < 0 || nx >= w) continue;
          final int q = ny * w + nx;
          if (dil[q] == 1 && label[q] == 0) {
            label[q] = next;
            queue[tail++] = q;
          }
        }
      }
    }

    total += area;

    // Dilation thi vadhel kinaro pacho
    minX = math.min(maxX, minX + r);
    minY = math.min(maxY, minY + r);
    maxX = math.max(minX, maxX - r);
    maxY = math.max(minY, maxY - r);

    comps.add([
      minX / w,
      minY / h,
      (maxX - minX + 1) / w,
      (maxY - minY + 1) / h,
      area.toDouble(),
      next.toDouble(), // 🔥 label id (erase mate)
    ]);
  }

  // 4) Dhool / nana kan kadho
  final double minArea = total * 0.004;
  comps.removeWhere((c) => c[4] < minArea);
  comps.sort((a, b) => b[4].compareTo(a[4]));

  return _Labeled(w, h, label, comps.take(8).toList());
}

List<List<double>> _splitPartsIsolate(Uint8List bytes) {
  try {
    final img.Image? im = img.decodePng(bytes);
    if (im == null) return const [];

    final _Labeled? l = _labelParts(im);
    if (l == null) return const [];

    return l.comps.map((c) => c.sublist(0, 5)).toList();
  } catch (_) {
    return const [];
  }
}

/// ✂️ SET: fakt necklace (sauthi moto tukdo) j rakho, baaki BADHU bhuso
///
/// Set photo ma necklace thi alag padel darek vastu (earring,
/// earring na tukda, tikka, dhool) gala par na aave. Chain sathe
/// jodayel pendant necklace no j bhag che etle e rahe che.
/// (Rectangle nahi — pixel level, etle chain kapati nathi)
Uint8List? necklaceOnlyIsolate(Uint8List bytes) {
  try {
    final img.Image? im0 = img.decodePng(bytes);
    if (im0 == null) return null;

    final img.Image im =
    im0.numChannels == 4 ? im0 : im0.convert(numChannels: 4);

    final _Labeled? l = _labelParts(im);
    if (l == null || l.comps.isEmpty) return null;

    final int keep = l.comps[0][5].toInt();

    final double fx = l.w / im.width;
    final double fy = l.h / im.height;

    for (int y = 0; y < im.height; y++) {
      final int sy = math.min(l.h - 1, (y * fy).floor());
      for (int x = 0; x < im.width; x++) {
        final int sx = math.min(l.w - 1, (x * fx).floor());
        if (l.label[sy * l.w + sx] != keep) {
          im.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    return img.encodePng(im, level: 1);
  } catch (_) {
    return null;
  }
}

class JewelSplitter {
  JewelSplitter._();

  static Future<JewelParts?> split(Uint8List png) async {
    final List<List<double>> raw = await compute(_splitPartsIsolate, png);
    if (raw.isEmpty) return null;

    return JewelParts(
      raw.map((c) => Rect.fromLTWH(c[0], c[1], c[2], c[3])).toList(),
      raw.map((c) => c[4]).toList(),
    );
  }
}

/// =========================================================
/// MODEL TEMPLATE
///
/// Badha anchor 4:5 canvas na fraction ma (0..1):
///   neckTop     → necklace no upar no chhedo (gala no niche bhag)
///   neckWidth   → necklace ni default pahodai (canvas width na %)
///   earY        → kaan ni bunt (earring no upar no chhedo)
///   leftEarX / rightEarX → banne kaan
///   earHeight   → earring ni default unchai (canvas height na %)
/// =========================================================

class ModelStyle {
  ModelStyle._();

  static const String all = "All";
  static const String traditional = "Traditional";
  static const String western = "Western";
  static const String mannequin = "Mannequin";

  static const List<String> list = [all, traditional, western, mannequin];
}

class ModelTemplate {
  const ModelTemplate({
    required this.id,
    required this.name,
    this.style = ModelStyle.mannequin,
    this.bg = const [Color(0xffF8F3EA), Color(0xffE8DDCB)],
    this.body = const Color(0xffF1E6D4),
    this.hair,
    this.velvet = false,
    this.assetPath,
    this.filePath,
    this.neckTop = 0.480,
    this.neckWidth = 0.40,
    this.neckCenterX = 0.5,
    this.maxBottom = 0.945,
    this.earY = 0.290,
    this.rightEarY,
    this.leftEarX = 0.352,
    this.rightEarX = 0.648,
    this.showLeftEar = true,
    this.showRightEar = true,
    this.earHeight = 0.136,
  });

  final String id;
  final String name;
  final String style;
  final List<Color> bg;
  final Color body;
  final Color? hair;
  final bool velvet;

  /// Real model photo (asset athva gallery mathi umerel)
  final String? assetPath;
  final String? filePath;

  final double neckTop;
  final double neckWidth;
  final double neckCenterX;
  final double maxBottom;

  /// Dabo kaan (photo ma dabi baju)
  final double earY;
  final double leftEarX;

  /// Jamno kaan (null = earY j)
  final double? rightEarY;
  final double rightEarX;

  /// Mohu thodu fervel hoy to ek j kaan dekhay
  final bool showLeftEar;
  final bool showRightEar;

  final double earHeight;

  bool get isPhoto => assetPath != null || filePath != null;

  bool get isCustom => filePath != null;

  bool get bodyDark => !isPhoto && body.computeLuminance() < 0.15;

  double get rEarY => rightEarY ?? earY;

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "style": style,
    "filePath": filePath,
    "neckTop": neckTop,
    "neckWidth": neckWidth,
    "neckCenterX": neckCenterX,
    "maxBottom": maxBottom,
    "earY": earY,
    "rightEarY": rightEarY,
    "leftEarX": leftEarX,
    "rightEarX": rightEarX,
    "showLeftEar": showLeftEar,
    "showRightEar": showRightEar,
    "earHeight": earHeight,
  };

  static ModelTemplate fromJson(Map<String, dynamic> j) {
    double d(String k, double def) =>
        (j[k] is num) ? (j[k] as num).toDouble() : def;

    return ModelTemplate(
      id: j["id"].toString(),
      name: j["name"]?.toString() ?? "My Model",
      style: j["style"]?.toString() ?? ModelStyle.traditional,
      filePath: j["filePath"]?.toString(),
      neckTop: d("neckTop", 0.5),
      neckWidth: d("neckWidth", 0.38),
      neckCenterX: d("neckCenterX", 0.5),
      maxBottom: d("maxBottom", 0.96),
      earY: d("earY", 0.3),
      rightEarY:
      j["rightEarY"] is num ? (j["rightEarY"] as num).toDouble() : null,
      leftEarX: d("leftEarX", 0.36),
      rightEarX: d("rightEarX", 0.64),
      showLeftEar: j["showLeftEar"] != false,
      showRightEar: j["showRightEar"] != false,
      earHeight: d("earHeight", 0.12),
    );
  }

  @override
  bool operator ==(Object other) => other is ModelTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// =========================================================
/// 💾 CUSTOM MODEL STORE (app documents ma JSON + photo copy)
/// =========================================================

class ModelStore {
  ModelStore._();

  static Future<Directory> _dir() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory("${docs.path}/batch_models");
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<ModelTemplate>> load() async {
    try {
      final File f = File("${(await _dir()).path}/models.json");
      if (!await f.exists()) return [];

      final List data = jsonDecode(await f.readAsString()) as List;

      return data
          .whereType<Map>()
          .map((e) => ModelTemplate.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.filePath != null && File(m.filePath!).existsSync())
          .toList();
    } catch (e) {
      debugPrint("❌ MODEL LOAD ERROR => $e");
      return [];
    }
  }

  static Future<void> save(List<ModelTemplate> models) async {
    final File f = File("${(await _dir()).path}/models.json");
    await f.writeAsString(
      jsonEncode(models.map((m) => m.toJson()).toList()),
    );
  }

  /// Picker ni temp file delete thai jay — etle app ma copy
  static Future<String> importPhoto(String srcPath) async {
    final Directory dir = await _dir();
    final String ext = srcPath.toLowerCase().endsWith(".png") ? "png" : "jpg";
    final String path =
        "${dir.path}/model_${DateTime.now().millisecondsSinceEpoch}.$ext";
    await File(srcPath).copy(path);
    return path;
  }

  static Future<void> deletePhoto(ModelTemplate m) async {
    try {
      if (m.filePath != null) await File(m.filePath!).delete();
    } catch (_) {}
  }
}

class ModelLibrary {
  ModelLibrary._();

  static const List<ModelTemplate> models = [
    ModelTemplate(
      id: "m_ivory_bust",
      name: "Ivory Bust",
      bg: [Color(0xffF8F3EA), Color(0xffE6DAC6)],
      body: Color(0xffF2E7D5),
    ),
    ModelTemplate(
      id: "m_black_velvet",
      name: "Black Velvet",
      bg: [Color(0xffF6F0E5), Color(0xffDCCDB2)],
      body: Color(0xff1D1D21),
      velvet: true,
    ),
    ModelTemplate(
      id: "m_maroon_velvet",
      name: "Maroon Velvet",
      bg: [Color(0xffFBF6EE), Color(0xffEAD9C2)],
      body: Color(0xff6E1528),
      velvet: true,
    ),
    ModelTemplate(
      id: "m_royal_velvet",
      name: "Royal Blue",
      bg: [Color(0xffF0F4FA), Color(0xffD2DCEC)],
      body: Color(0xff17295A),
      velvet: true,
    ),
    ModelTemplate(
      id: "m_ivory_dark",
      name: "Ivory on Black",
      bg: [Color(0xff2E2E33), Color(0xff0D0D0F)],
      body: Color(0xffF0E6D6),
    ),
    ModelTemplate(
      id: "m_model_fair",
      name: "Model Fair",
      bg: [Color(0xffFCF2EB), Color(0xffEFDACB)],
      body: Color(0xffEDC4A5),
      hair: Color(0xff2B1A12),
    ),
    ModelTemplate(
      id: "m_model_wheat",
      name: "Model Wheatish",
      bg: [Color(0xffFBF3EA), Color(0xffE9D6C2)],
      body: Color(0xffCC926C),
      hair: Color(0xff1E120C),
    ),
    ModelTemplate(
      id: "m_model_dusky",
      name: "Model Dusky",
      bg: [Color(0xffF5EEE6), Color(0xffDCCAB6)],
      body: Color(0xff9C6648),
      hair: Color(0xff140C08),
    ),
  ];

  /// 🔥 Potana model photo (optional)
  ///
  /// - Photo 4:5 (jem ke 1920×2400) rakho, saamethi lidhel
  /// - assets/models/ ma muko ane pubspec.yaml ma umero
  /// - Anchor: photo ma gala / kaan kya che e fraction ma lakho
  ///   (x = dabe thi % , y = upar thi %)
  static final List<ModelTemplate> assetModels = [
    // ModelTemplate(
    //   id: "m_bride",
    //   name: "Bride",
    //   assetPath: "assets/models/bride.jpg",
    //   neckTop: 0.50,
    //   neckWidth: 0.38,
    //   earY: 0.30,
    //   leftEarX: 0.36,
    //   rightEarX: 0.64,
    //   earHeight: 0.12,
    // ),
  ];

  /// Gallery mathi umerel real models (app khule tyare load)
  static final List<ModelTemplate> custom = [];

  static List<ModelTemplate> get all => [...custom, ...assetModels, ...models];

  static List<ModelTemplate> byStyle(String style) => style == ModelStyle.all
      ? all
      : all.where((m) => m.style == style).toList();
}

/// =========================================================
/// 🖌️ MANNEQUIN / MODEL PAINTER (reference 1000 × 1250,
/// koi pan size par scale thay — vector, etle HD ma pan sharp)
/// =========================================================

class ModelPainter {
  ModelPainter._();

  static const double refW = 1000;
  static const double refH = 1250;

  static Color _shade(Color c, double amount) {
    final HSLColor h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static void paint(
      Canvas canvas,
      Size size,
      ModelTemplate m, {
        ui.Image? image,
      }) {
    final Rect full = Offset.zero & size;

    if (m.isPhoto) {
      canvas.drawRect(full, Paint()..color = const Color(0xffEDEDED));
      if (image != null) {
        paintImage(
          canvas: canvas,
          rect: full,
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        );
      }
      return;
    }

    canvas.save();
    canvas.scale(size.width / refW, size.height / refH);

    const Rect rect = Rect.fromLTWH(0, 0, refW, refH);
    final Color b = m.body;
    final bool darkBg = m.bg.last.computeLuminance() < 0.2;

    // ---------- BACKGROUND
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: m.bg,
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 0.8,
          colors: [
            Colors.white.withOpacity(darkBg ? 0.10 : 0.55),
            Colors.white.withOpacity(0),
          ],
        ).createShader(rect),
    );

    // ---------- EARS (head ni pachhal)
    for (final double x in const [352.0, 648.0]) {
      final Rect ear = Rect.fromCenter(
        center: Offset(x, 318),
        width: 50,
        height: 104,
      );
      canvas.drawOval(ear, Paint()..color = _shade(b, -0.06));
      canvas.drawOval(
        ear.deflate(12),
        Paint()..color = _shade(b, -0.12).withOpacity(0.35),
      );
    }

    // ---------- NECK
    final Path neck = Path()
      ..moveTo(425, 400)
      ..cubicTo(432, 480, 428, 560, 412, 615)
      ..lineTo(588, 615)
      ..cubicTo(572, 560, 568, 480, 575, 400)
      ..close();

    const Rect neckRect = Rect.fromLTWH(410, 400, 180, 220);

    canvas.drawPath(
      neck,
      Paint()
        ..shader = LinearGradient(
          stops: const [0, 0.5, 1],
          colors: [_shade(b, -0.12), _shade(b, 0.03), _shade(b, -0.12)],
        ).createShader(neckRect),
    );

    // Chin no padchhayo
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(500, 470), width: 170, height: 60),
      Paint()
        ..color = Colors.black.withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // ---------- BODY (shoulders + chest)
    final Path body = Path()
      ..moveTo(418, 590)
      ..cubicTo(400, 665, 255, 690, 165, 742)
      ..cubicTo(100, 778, 72, 860, 60, refH + 10)
      ..lineTo(940, refH + 10)
      ..cubicTo(928, 860, 900, 778, 835, 742)
      ..cubicTo(745, 690, 600, 665, 582, 590)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          stops: const [0, 0.25, 0.5, 0.75, 1],
          colors: [
            _shade(b, -0.13),
            b,
            _shade(b, 0.05),
            b,
            _shade(b, -0.14),
          ],
        ).createShader(rect),
    );

    // Upar thi niche halko andharo (depth)
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0),
            Colors.black.withOpacity(0.12),
          ],
        ).createShader(const Rect.fromLTWH(0, 600, refW, 650)),
    );

    // Velvet chamak
    if (m.velvet) {
      canvas.drawPath(
        body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 0.15),
            radius: 0.45,
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0),
            ],
          ).createShader(rect),
      );
    }

    // Collar bones
    final Paint bone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = _shade(b, -0.10).withOpacity(m.velvet ? 0.0 : 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(
      Path()
        ..moveTo(445, 668)
        ..quadraticBezierTo(340, 650, 240, 708),
      bone,
    );
    canvas.drawPath(
      Path()
        ..moveTo(555, 668)
        ..quadraticBezierTo(660, 650, 760, 708),
      bone,
    );

    // ---------- HEAD
    const Rect head = Rect.fromLTWH(350, 100, 300, 380);

    canvas.drawOval(
      head,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.9,
          colors: [_shade(b, 0.08), b, _shade(b, -0.10)],
          stops: const [0, 0.55, 1],
        ).createShader(head),
    );

    // ---------- HAIR (model look)
    if (m.hair != null) {
      final Color h = m.hair!;

      // Bun
      canvas.drawCircle(
        const Offset(500, 108),
        72,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [_shade(h, 0.10), h],
          ).createShader(
              Rect.fromCircle(center: const Offset(500, 108), radius: 72)),
      );

      // Pachhal valelo vaal (kaan khulla rahe)
      final Path hair = Path()
        ..moveTo(346, 300)
        ..cubicTo(330, 110, 670, 110, 654, 300)
        ..cubicTo(640, 215, 360, 215, 346, 300)
        ..close();

      canvas.drawPath(
        hair,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_shade(h, 0.08), h],
          ).createShader(const Rect.fromLTWH(330, 110, 340, 190)),
      );

      // Halki chamak
      canvas.drawPath(
        Path()
          ..moveTo(420, 160)
          ..quadraticBezierTo(500, 135, 585, 165),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.restore();
  }
}

/// =========================================================
/// 📐 LAYOUT — jewellery kya ane ketli moti
/// =========================================================

class JewelPlacement {
  const JewelPlacement({
    required this.src,
    required this.dst,
    this.flip = false,
    this.kind = JewelType.necklace,
  });

  /// Necklace (golai + fade) ke Earring (hook)
  final JewelType kind;

  /// Source image no bhag (0..1 fraction)
  final Rect src;

  /// Canvas par jagya (pixels)
  final Rect dst;

  /// Horizontal mirror (ek j earring → bije kaan)
  final bool flip;
}

class ModelLayout {
  ModelLayout._();

  static const Rect _full = Rect.fromLTWH(0, 0, 1, 1);
  static const Rect _halfL = Rect.fromLTWH(0, 0, 0.5, 1);
  static const Rect _halfR = Rect.fromLTWH(0.5, 0, 0.5, 1);

  static List<JewelPlacement> place({
    required ModelTemplate model,
    required Size canvas,
    required JewelType type,
    required Size jewel,
    required JewelAdjust adjust,
    JewelParts? parts,
  }) {
    if (jewel.width <= 0 || jewel.height <= 0) return const [];

    switch (type) {
      case JewelType.necklace:
        return [
          _necklace(model, canvas, jewel, _full, adjust),
        ];

      case JewelType.earring:
        return _earringOnly(model, canvas, jewel, adjust, parts);

      case JewelType.set:
      // 🔥 Photo ma earring j nathi (chain / mangalsutra) → necklace
        if (!hasEarrings(parts)) {
          return [_necklace(model, canvas, jewel, _full, adjust)];
        }
        return _set(model, canvas, jewel, adjust, parts);

      case JewelType.other:
        return const [];
    }
  }

  /// ✂️ SET ma kya tukda earring che (parts index).
  ///
  /// 🔥 Rule (seedho):
  ///   - Sauthi moto tukdo (index 0) = NECKLACE → gala par
  ///   - Ena pachhi na 2 nana tukda (index 1, 2) = EARRING → kaan par
  ///   - Fakt 1 nano tukdo hoy → e j earring, bije kaan par mirror
  ///   - Baaki (3 thi vadhu) na nana tukda gala parthi bhusai jay
  ///
  /// Khali list = earring nathi malya (aakhu necklace).
  static List<int> setEarIndices(JewelParts? parts) {
    if (parts == null || parts.count < 2) return const [];

    final double neckArea = parts.areas[0];

    // 🔥 Chain na tutela tukda / dhool earring na gani lo:
    // earring necklace na ochhama ochha 5% jetli hoy
    final List<int> cand = [
      for (int i = 1; i < parts.count; i++)
        if (parts.areas[i] >= neckArea * 0.05) i,
    ];

    if (cand.isEmpty) return const [];

    // parts pehla thi j moti → nani kram ma che
    if (cand.length >= 2) return cand.take(2).toList();

    // Fakt ek j tukdo → pakki earring hoy tyare j (8%+), nahi to
    // e chain no tukdo/pendant che → aakhi image necklace
    return parts.areas[cand[0]] >= neckArea * 0.08 ? [cand[0]] : const [];
  }

  /// 🔥 Image ma earring che ke nahi?
  /// (SET select karyu hoy pan photo ma fakt chain / mangalsutra hoy)
  static bool hasEarrings(JewelParts? parts) =>
      setEarIndices(parts).isNotEmpty;

  // ---------------------------------------------------------
  // NECKLACE
  // ---------------------------------------------------------

  static JewelPlacement _necklace(
      ModelTemplate model,
      Size canvas,
      Size jewel,
      Rect src,
      JewelAdjust adjust,
      ) {
    final double pw = jewel.width * src.width;
    final double ph = jewel.height * src.height;

    double w = model.neckWidth * canvas.width * adjust.scale;
    double h = w * ph / pw;

    final double top = (model.neckTop + adjust.dy) * canvas.height;
    final double maxH = model.maxBottom * canvas.height - top;

    // Lambo haar hoy to niche bahar na jay
    if (maxH > 0 && h > maxH) {
      h = maxH;
      w = h * pw / ph;
    }

    final double cx = (model.neckCenterX + adjust.dx) * canvas.width;

    return JewelPlacement(src: src, dst: Rect.fromLTWH(cx - w / 2, top, w, h));
  }

  // ---------------------------------------------------------
  // EARRINGS — be src (left / right) ne kaan par muke
  // ---------------------------------------------------------

  static List<JewelPlacement> _ears({
    required ModelTemplate model,
    required Size canvas,
    required Size jewel,
    required Rect srcL,
    required Rect srcR,
    required bool mirrorRight,
    required double Function(Rect src) heightFor,
    required double dx,
    required double dy,
  }) {
    final List<JewelPlacement> out = [];

    JewelPlacement one(Rect src, double xFrac, double yFrac, bool flip) {
      final double h = heightFor(src);
      final double w =
          h * (jewel.width * src.width) / (jewel.height * src.height);
      final double cx = xFrac * canvas.width;
      final double top = (yFrac + dy) * canvas.height;
      return JewelPlacement(
        src: src,
        dst: Rect.fromLTWH(cx - w / 2, top, w, h),
        flip: flip,
        kind: JewelType.earring,
      );
    }

    if (model.showLeftEar) {
      out.add(one(srcL, model.leftEarX - dx, model.earY, false));
    }

    if (model.showRightEar) {
      out.add(one(srcR, model.rightEarX + dx, model.rEarY, mirrorRight));
    }

    return out;
  }

  /// Be tukda lagbhag sarkha hoy to e jodi
  static List<Rect>? _pairFromParts(JewelParts? parts, {int skip = 0}) {
    if (parts == null || parts.count < skip + 2) return null;

    final double a1 = parts.areas[skip];
    final double a2 = parts.areas[skip + 1];

    if (a2 < a1 * 0.45) return null;

    final Rect r1 = parts.rects[skip];
    final Rect r2 = parts.rects[skip + 1];

    return r1.center.dx <= r2.center.dx ? [r1, r2] : [r2, r1];
  }

  static List<JewelPlacement> _earringOnly(
      ModelTemplate model,
      Size canvas,
      Size jewel,
      JewelAdjust adjust,
      JewelParts? parts,
      ) {
    Rect srcL = _full;
    Rect srcR = _full;
    bool mirror = true;

    final List<Rect>? found =
    adjust.pair == false ? null : _pairFromParts(parts);

    if (found != null) {
      // 🔥 Photo ma 2 earring alag dekhaya
      srcL = found[0];
      srcR = found[1];
      mirror = false;
    } else if (adjust.isPair(jewel)) {
      srcL = _halfL;
      srcR = _halfR;
      mirror = false;
    }

    final double baseH = model.earHeight * canvas.height * adjust.scale;

    // Banne earring sarkhi unchai, pan potana proportion ma
    final double tallest = math.max(
      jewel.height * srcL.height,
      jewel.height * srcR.height,
    );

    return _ears(
      model: model,
      canvas: canvas,
      jewel: jewel,
      srcL: srcL,
      srcR: srcR,
      mirrorRight: mirror,
      heightFor: (src) => baseH * (jewel.height * src.height) / tallest,
      dx: adjust.dx,
      dy: adjust.dy,
    );
  }

  /// 🔥 SET: vachche no moto tukdo = necklace, baju na = earring
  static List<JewelPlacement> _set(
      ModelTemplate model,
      Size canvas,
      Size jewel,
      JewelAdjust adjust,
      JewelParts? parts,
      ) {
    if (parts == null || parts.count < 2) {
      // Tukda na malya → aakhu necklace tarike
      return [_necklace(model, canvas, jewel, _full, adjust)];
    }

    final Rect neckSrc0 = parts.rects[0];
    final List<int> earIdx = setEarIndices(parts);

    if (earIdx.isEmpty) {
      return [_necklace(model, canvas, jewel, _full, adjust)];
    }

    final int e1 = earIdx[0];
    final int? e2 = earIdx.length > 1 ? earIdx[1] : null;

    // ✂️ Necklace = fakt sauthi moto tukdo. Baaki na alag tukda
    // (earring na tukda, tikka...) have gala par umerata nathi —
    // neck image ma e bhusai jay che (necklaceOnlyIsolate).
    final Rect neckSrc = neckSrc0;

    final JewelPlacement neck =
    _necklace(model, canvas, jewel, neckSrc, adjust);

    Rect srcL = parts.rects[e1];
    Rect srcR = parts.rects[e1];
    bool mirror = true;

    if (e2 != null) {
      final Rect a = parts.rects[e1];
      final Rect b = parts.rects[e2];
      srcL = a.center.dx <= b.center.dx ? a : b;
      srcR = a.center.dx <= b.center.dx ? b : a;
      mirror = false;
    }

    // 🔥 Earring ni default size = model na kaan pramane (earHeight),
    // fakt "Earring" item jevi j. Photo ma earring necklace karta
    // nani/moti hoy to pan kaan par barobar j dekhay.
    final double baseH = model.earHeight * canvas.height;

    // Banne earring sarkhi unchai, pan potana proportion ma
    final double tallest = math.max(
      jewel.height * srcL.height,
      jewel.height * srcR.height,
    );

    final List<JewelPlacement> ears = _ears(
      model: model,
      canvas: canvas,
      jewel: jewel,
      srcL: srcL,
      srcR: srcR,
      mirrorRight: mirror,
      heightFor: (src) =>
      baseH * (jewel.height * src.height) / tallest * adjust.earScale,
      dx: adjust.earDx,
      dy: adjust.earDy,
    );

    return [neck, ...ears];
  }
}

/// =========================================================
/// 👀 PREVIEW WIDGETS (fakt screen par dekhadva — nani size
/// thi fast. Share / PDF ni quality par asar nathi)
/// =========================================================

/// Fakt model (tile thumbnail mate)
class ModelView extends StatelessWidget {
  const ModelView({Key? key, required this.model}) : super(key: key);

  final ModelTemplate model;

  @override
  Widget build(BuildContext context) {
    if (model.assetPath != null) {
      return Image.asset(
        model.assetPath!,
        fit: BoxFit.cover,
        cacheWidth: 700,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.grey),
      );
    }

    if (model.filePath != null) {
      return Image.file(
        File(model.filePath!),
        fit: BoxFit.cover,
        cacheWidth: 700,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.grey),
      );
    }

    return SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(painter: _ModelPainter(model)),
      ),
    );
  }
}

class _ModelPainter extends CustomPainter {
  _ModelPainter(this.m);

  final ModelTemplate m;

  @override
  void paint(Canvas canvas, Size size) => ModelPainter.paint(canvas, size, m);

  @override
  bool shouldRepaint(_ModelPainter old) => old.m.id != m.id;
}

/// Model thumbnail — 4:5 ne square tile ma cover
class ModelThumb extends StatelessWidget {
  const ModelThumb({Key? key, required this.model}) : super(key: key);

  final ModelTemplate model;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.3),
        child: SizedBox(
          width: 400,
          height: 500,
          child: ModelView(model: model),
        ),
      ),
    );
  }
}

/// Model + jewellery (grid card / adjust sheet) — realistic
class ModelPreview extends StatefulWidget {
  const ModelPreview({
    Key? key,
    required this.model,
    required this.png,
    required this.pngSize,
    required this.type,
    required this.adjust,
    this.parts,
    this.adjustKey,
  }) : super(key: key);

  final ModelTemplate model;
  final File png;
  final Size pngSize;
  final JewelType type;
  final JewelAdjust adjust;
  final JewelParts? parts;

  /// Adjust badlay tyare rebuild thay e mate
  final String? adjustKey;

  static const Size ref = Size(400, 500);

  @override
  State<ModelPreview> createState() => _ModelPreviewState();
}

class _ModelPreviewState extends State<ModelPreview> {
  ui.Image? _jewel;

  /// ✂️ SET mate earring vagar ni necklace image
  ui.Image? _neck;

  Color? _tint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ModelPreview old) {
    super.didUpdateWidget(old);
    if (old.png.path != widget.png.path ||
        old.model.id != widget.model.id ||
        old.type != widget.type ||
        old.parts != widget.parts) {
      _load();
    }
  }

  Future<void> _load() async {
    final ui.Image? image = await JewelImageCache.get(widget.png);
    final Color tint = await ModelLighting.tintFor(widget.model);

    ui.Image? neck;
    if (widget.type == JewelType.set) {
      final List<int> ears = ModelLayout.setEarIndices(widget.parts);
      if (ears.isNotEmpty) {
        neck = await SetNeckCache.preview(widget.png);
      }
    }

    if (!mounted) return;
    setState(() {
      _jewel = image;
      _neck = neck;
      _tint = tint;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Size ref = ModelPreview.ref;

    final List<JewelPlacement> placements = ModelLayout.place(
      model: widget.model,
      canvas: ref,
      type: widget.type,
      jewel: widget.pngSize,
      adjust: widget.adjust,
      parts: widget.parts,
    );

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: widget.type == JewelType.earring
            ? const Alignment(0, -0.4)
            : Alignment.center,
        child: SizedBox(
          width: ref.width,
          height: ref.height,
          child: Stack(
            children: [
              Positioned.fill(child: ModelView(model: widget.model)),
              if (_jewel != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RealJewelPainter(
                        jewel: _jewel!,
                        neckJewel:
                        widget.type == JewelType.set ? _neck : null,
                        placements: placements,
                        model: widget.model,
                        wrap: widget.adjust.wrap,
                        enhance: widget.adjust.enhance,
                        tint: _tint,
                        repaintKey:
                        "${widget.model.id}|${widget.type.name}|${widget.adjust.key}",
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
}

/// =========================================================
/// 🌟 REALISTIC RENDER (FREE — phone ma j, AI vagar)
///
/// 1) Necklace ne gala/chhati na golai par vaalo (mesh warp)
/// 2) Upar na chheda gala pachhal chhupay (soft fade)
/// 3) Model na prakash/rang pramane jewellery no tone match
/// 4) Aakar pramane soft shadow
/// 5) Earring no hook kaan ni bunt ma jato dekhay
/// 6) ✨ AI LOOK — contrast + rang + chamakta bhag par glow
/// =========================================================

/// Preview mate nani (700px) jewellery cache — fakt screen mate
class JewelImageCache {
  JewelImageCache._();

  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image?>> _loading = {};

  static Future<ui.Image?> get(File file) {
    final String key = file.path;

    final ui.Image? hit = _cache[key];
    if (hit != null) return Future.value(hit);

    return _loading.putIfAbsent(key, () async {
      try {
        final Uint8List bytes = await file.readAsBytes();
        final ui.ImmutableBuffer buf =
        await ui.ImmutableBuffer.fromUint8List(bytes);
        final ui.ImageDescriptor d = await ui.ImageDescriptor.encoded(buf);
        final ui.Codec codec = await d.instantiateCodec(
          targetWidth: d.width > 700 ? 700 : null,
        );
        final ui.Image image = (await codec.getNextFrame()).image;
        codec.dispose();
        d.dispose();
        buf.dispose();

        if (_cache.length >= 40) _cache.remove(_cache.keys.first);
        _cache[key] = image;
        return image;
      } catch (_) {
        return null;
      } finally {
        _loading.remove(key);
      }
    });
  }
}

/// ✂️ SET preview mate — earring bhusel necklace image (700px)
class SetNeckCache {
  SetNeckCache._();

  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image?>> _loading = {};

  static Future<ui.Image?> preview(File file) {
    final String key = "${file.path}|neck";

    final ui.Image? hit = _cache[key];
    if (hit != null) return Future.value(hit);

    return _loading.putIfAbsent(key, () async {
      try {
        final Uint8List png = await file.readAsBytes();
        final Uint8List? out = await compute(necklaceOnlyIsolate, png);
        if (out == null) return null;

        final ui.ImmutableBuffer buf =
        await ui.ImmutableBuffer.fromUint8List(out);
        final ui.ImageDescriptor d = await ui.ImageDescriptor.encoded(buf);
        final ui.Codec codec = await d.instantiateCodec(
          targetWidth: d.width > 700 ? 700 : null,
        );
        final ui.Image image = (await codec.getNextFrame()).image;
        codec.dispose();
        d.dispose();
        buf.dispose();

        if (_cache.length >= 20) _cache.remove(_cache.keys.first);
        _cache[key] = image;
        return image;
      } catch (_) {
        return null;
      } finally {
        _loading.remove(key);
      }
    });
  }

  /// File badlay (navo PNG) tyare juno cache kadho
  static void evict(String path) {
    _cache.removeWhere((k, _) => k.startsWith("$path|"));
  }
}

class ModelLighting {
  ModelLighting._();

  static final Map<String, Color> _tints = {};

  /// Jewellery par lagavvano "modulate" rang (light match)
  ///
  /// 🔥 HQ: sonu jhankhu na pade e mate ochhama ochhu 90% prakash,
  /// ane fakt 8% model no rang
  static Future<Color> tintFor(ModelTemplate m) async {
    final Color? hit = _tints[m.id];
    if (hit != null) return hit;

    Color sample;

    if (!m.isPhoto) {
      sample = Color.lerp(m.body, m.bg.last, 0.5)!;
    } else {
      sample = await _samplePhoto(m) ?? const Color(0xffD8C4AE);
    }

    final double lum = sample.computeLuminance();

    // Andharo photo → jewellery thodi jhankhi, ujaas → normal
    final double bright = (0.90 + lum * 0.30).clamp(0.90, 1.0);

    // 8% model no rang (warm/cool light) jewellery ma
    final Color mixed = Color.lerp(Colors.white, sample, 0.08)!;

    final Color tint = Color.fromARGB(
      255,
      (mixed.red * bright).round().clamp(0, 255),
      (mixed.green * bright).round().clamp(0, 255),
      (mixed.blue * bright).round().clamp(0, 255),
    );

    _tints[m.id] = tint;
    return tint;
  }

  static Future<Color?> _samplePhoto(ModelTemplate m) async {
    try {
      final Uint8List bytes = m.assetPath != null
          ? (await rootBundle.load(m.assetPath!)).buffer.asUint8List()
          : await File(m.filePath!).readAsBytes();

      final ui.Codec codec =
      await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final ui.Image image = (await codec.getNextFrame()).image;
      codec.dispose();

      final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final int w = image.width;
      final int h = image.height;
      image.dispose();

      if (data == null) return null;

      // 🔥 Share image jevo j 4:5 "cover" crop → points photo par
      // jya muk ya che tya j gala no rang lo (pehla andaj thi hatu)
      double cw = w.toDouble(), ch = h.toDouble(), ox = 0, oy = 0;
      if (w / h > 0.8) {
        cw = h * 0.8;
        ox = (w - cw) / 2;
      } else {
        ch = w / 0.8;
        oy = (h - ch) / 2;
      }

      final double nx = m.neckCenterX;
      final int x0 = (ox + cw * (nx - 0.20)).round().clamp(0, w - 1);
      final int x1 = (ox + cw * (nx + 0.20)).round().clamp(0, w - 1);
      final int y0 = (oy + ch * (m.neckTop - 0.08)).round().clamp(0, h - 1);
      final int y1 = (oy + ch * (m.neckTop + 0.18)).round().clamp(0, h - 1);

      int r = 0, g = 0, b = 0, n = 0;

      for (int y = y0; y <= y1; y++) {
        for (int x = x0; x <= x1; x++) {
          final int i = (y * w + x) * 4;
          r += data.getUint8(i);
          g += data.getUint8(i + 1);
          b += data.getUint8(i + 2);
          n++;
        }
      }

      if (n == 0) return null;

      return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
    } catch (_) {
      return null;
    }
  }
}

class JewelRealism {
  JewelRealism._();

  static final Float64List _identity = Float64List.fromList(const [
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);

  /// Source → destination mesh (necklace mate golai)
  static ui.Vertices _mesh(
      Rect srcPx,
      Rect dst, {
        required double wrap,
      }) {
    const int cols = 24;
    const int rows = 10;

    final double theta = 0.15 + wrap * 0.95; // golai
    final double squash = 1 - 0.10 * wrap; // aagal thi joie etle thodu tunku
    final double cx = dst.center.dx;
    final double half = dst.width / 2;
    final double radius = half / math.sin(theta);

    final List<Offset> pos = [];
    final List<Offset> tex = [];

    for (int r = 0; r <= rows; r++) {
      final double v = r / rows;

      for (int c = 0; c <= cols; c++) {
        final double u = c / cols;
        final double t = u * 2 - 1; // -1..1

        final double x = wrap > 0.01
            ? cx + radius * math.sin(t * theta)
            : dst.left + u * dst.width;

        // Baju na bhag thoda upar (gala taraf) jay
        final double lift = dst.height * 0.05 * wrap * t * t * (1 - v);
        final double y = dst.top + v * dst.height * squash - lift;

        pos.add(Offset(x, y));
        tex.add(
            Offset(srcPx.left + u * srcPx.width, srcPx.top + v * srcPx.height));
      }
    }

    final List<int> idx = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int i = r * (cols + 1) + c;
        idx.addAll([i, i + 1, i + cols + 1, i + 1, i + cols + 2, i + cols + 1]);
      }
    }

    return ui.Vertices(
      ui.VertexMode.triangles,
      pos,
      textureCoordinates: tex,
      indices: idx,
    );
  }

  // ---------------------------------------------------------
  // ✨ AI LOOK — color matrix (phone ma j, AI vagar)
  // ---------------------------------------------------------

  static const double _lr = 0.2126;
  static const double _lg = 0.7152;
  static const double _lb = 0.0722;

  /// Tint (light match) + contrast + saturation + brightness
  /// → ek j matrix (fast)
  static List<double> _lookMatrix(Color? tint, double e) {
    final double tr = (tint?.red ?? 255) / 255;
    final double tg = (tint?.green ?? 255) / 255;
    final double tb = (tint?.blue ?? 255) / 255;

    final double c = 1 + 0.30 * e; // contrast
    final double s = 1 + 0.25 * e; // saturation (sonu vadhu sonu)
    final double br = 5 * e; // halko ujaas (0..255)

    final double sr = (1 - s) * _lr;
    final double sg = (1 - s) * _lg;
    final double sb = (1 - s) * _lb;

    List<double> row(int i) => [
      (sr + (i == 0 ? s : 0)) * tr * c,
      (sg + (i == 1 ? s : 0)) * tg * c,
      (sb + (i == 2 ? s : 0)) * tb * c,
      0,
      128 * (1 - c) + br,
    ];

    return [
      ...row(0),
      ...row(1),
      ...row(2),
      0, 0, 0, 1, 0,
    ];
  }

  /// Fakt chamakta bhag (stone / polish) → garam safed highlight
  static List<double> _glowMatrix({
    double gain = 3.2,
    double thr = 165,
  }) {
    List<double> row(double warm) => [
      _lr * gain * warm,
      _lg * gain * warm,
      _lb * gain * warm,
      0,
      -thr * gain * warm,
    ];

    return [
      ...row(1.0),
      ...row(0.94),
      ...row(0.80),
      0, 0, 0, 1, 0,
    ];
  }

  static void draw(
      Canvas canvas,
      ui.Image jewel,
      JewelPlacement p, {
        required ModelTemplate model,
        required Size canvasSize,
        required double wrap,
        Color? tint,
        bool shadow = true,
        double enhance = 0.6,
      }) {
    final double e = enhance.clamp(0.0, 1.0);
    final double k = canvasSize.width / 1000;
    final bool isNeck = p.kind == JewelType.necklace;

    final Rect srcPx = Rect.fromLTWH(
      p.src.left * jewel.width,
      p.src.top * jewel.height,
      p.src.width * jewel.width,
      p.src.height * jewel.height,
    );

    final ui.Vertices verts = _mesh(srcPx, p.dst, wrap: isNeck ? wrap : 0);

    ImageShader shader() => ImageShader(
      jewel,
      TileMode.clamp,
      TileMode.clamp,
      _identity,
      filterQuality: FilterQuality.high,
    );

    final Rect layer = p.dst.inflate(p.dst.width * 0.15 + 30 * k);

    canvas.save();

    if (p.flip) {
      canvas.translate(p.dst.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }

    canvas.saveLayer(layer, Paint());

    // 1) SHADOW — aakar pramane, skin par halko
    if (shadow) {
      final double op = model.isPhoto ? 0.30 : (model.bodyDark ? 0.45 : 0.28);

      canvas.save();
      canvas.translate(2 * k, (isNeck ? 7 : 5) * k);
      canvas.drawVertices(
        verts,
        BlendMode.srcOver,
        Paint()
          ..shader = shader()
          ..colorFilter = ColorFilter.mode(
            Colors.black.withOpacity(op),
            BlendMode.srcIn,
          )
          ..imageFilter =
          ui.ImageFilter.blur(sigmaX: 4.5 * k, sigmaY: 4.5 * k),
      );
      canvas.restore();
    }

    // 2) JEWELLERY (light match + ✨ contrast / rang)
    final Paint jp = Paint()
      ..shader = shader()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    if (e > 0.01) {
      jp.colorFilter = ColorFilter.matrix(_lookMatrix(tint, e));
    } else if (tint != null) {
      jp.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }

    canvas.drawVertices(verts, BlendMode.srcOver, jp);

    // 2.5) ✨ HIGHLIGHT — chamakta bhag par soft glow (bloom)
    // + halki tikhi chamak → AI / studio photo jevo look
    if (e > 0.01) {
      // Soft glow (jewellery ni aaspaas halko prakash)
      canvas.drawVertices(
        verts,
        BlendMode.plus,
        Paint()
          ..shader = shader()
          ..color = Colors.white.withOpacity((0.42 * e).clamp(0.0, 1.0))
          ..colorFilter = ColorFilter.matrix(_glowMatrix())
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: (isNeck ? 5.0 : 3.5) * k,
            sigmaY: (isNeck ? 5.0 : 3.5) * k,
          ),
      );

      // Tikhi chamak (stone / polish crisp dekhay)
      canvas.drawVertices(
        verts,
        BlendMode.screen,
        Paint()
          ..shader = shader()
          ..color = Colors.white.withOpacity((0.28 * e).clamp(0.0, 1.0))
          ..colorFilter = ColorFilter.matrix(_glowMatrix(gain: 2.4, thr: 150)),
      );
    }

    // 3) Upar na chheda gala pachhal (fade)
    if (isNeck && wrap > 0.05) {
      final double neckHalf = model.neckWidth * canvasSize.width * 0.21;
      final double fadeH = p.dst.height * (0.10 + 0.10 * wrap);
      final double cx = p.dst.center.dx;

      final Rect left = Rect.fromLTRB(
        layer.left,
        layer.top,
        cx - neckHalf,
        p.dst.top + fadeH,
      );
      final Rect right = Rect.fromLTRB(
        cx + neckHalf,
        layer.top,
        layer.right,
        p.dst.top + fadeH,
      );

      for (final Rect r in [left, right]) {
        if (r.width <= 0 || r.height <= 0) continue;

        canvas.drawRect(
          r,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.95 * wrap.clamp(0.0, 1.0)),
                Colors.black.withOpacity(0),
              ],
            ).createShader(r)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, neckHalf * 0.35),
        );
      }
    }

    // 4) Earring hook kaan ma jato dekhay
    if (!isNeck) {
      final double topGap = p.dst.top - layer.top;
      final Rect hook = Rect.fromLTWH(
        layer.left,
        layer.top,
        layer.width,
        topGap + p.dst.height * 0.07,
      );

      if (hook.height > 0) {
        canvas.drawRect(
          hook,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0),
              ],
              stops: [
                0,
                (topGap / hook.height).clamp(0.0, 1.0),
                1,
              ],
            ).createShader(hook),
        );
      }
    }

    canvas.restore(); // layer
    canvas.restore(); // flip
  }
}

/// =========================================================
/// ✨ HIGHLIGHT BUTTON — adjust sheet ma muko
///
/// Off / Soft / AI / Max — "Jewellery type" jeva j button.
/// Dabavo etle adjust.enhance badlay ane preview turant
/// badlay (onChanged ma setState karo).
/// =========================================================

class HighlightLevel {
  const HighlightLevel(this.label, this.value, this.icon);

  final String label;
  final double value;
  final IconData icon;

  static const List<HighlightLevel> all = [
    HighlightLevel("Off", 0.0, Icons.block_rounded),
    HighlightLevel("Soft", 0.35, Icons.light_mode_outlined),
    HighlightLevel("AI", 0.6, Icons.auto_awesome_rounded),
    HighlightLevel("Max", 1.0, Icons.flare_rounded),
  ];

  /// Hal na value ne sauthi najik level
  static HighlightLevel nearest(double v) {
    HighlightLevel best = all.first;
    for (final HighlightLevel l in all) {
      if ((l.value - v).abs() < (best.value - v).abs()) best = l;
    }
    return best;
  }
}

class HighlightButton extends StatelessWidget {
  const HighlightButton({
    Key? key,
    required this.adjust,
    required this.onChanged,
    this.title = "Highlight",
    this.color,
  }) : super(key: key);

  final JewelAdjust adjust;

  /// Ahiya parent ma setState(() {}) karo
  final VoidCallback onChanged;

  final String title;

  /// null = app no primary color
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Theme.of(context).colorScheme.primary;
    final HighlightLevel sel = HighlightLevel.nearest(adjust.enhance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 20, color: c),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < HighlightLevel.all.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _LevelChip(
                  level: HighlightLevel.all[i],
                  selected: HighlightLevel.all[i] == sel,
                  color: c,
                  onTap: () {
                    adjust.enhance = HighlightLevel.all[i].value;
                    onChanged();
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.level,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final HighlightLevel level;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withOpacity(0.18),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                level.icon,
                size: 18,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  level.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview painter (grid card / adjust sheet)
class _RealJewelPainter extends CustomPainter {
  _RealJewelPainter({
    required this.jewel,
    this.neckJewel,
    required this.placements,
    required this.model,
    required this.wrap,
    required this.tint,
    required this.repaintKey,
    this.enhance = 0.6,
  });

  /// ✨ AI look ni taakat
  final double enhance;

  final ui.Image jewel;

  /// ✂️ SET: earring vagar ni necklace (null = jewel j vapro)
  final ui.Image? neckJewel;

  final List<JewelPlacement> placements;
  final ModelTemplate model;
  final double wrap;
  final Color? tint;
  final String repaintKey;

  @override
  void paint(Canvas canvas, Size size) {
    for (final JewelPlacement p in placements) {
      final ui.Image src =
      (p.kind == JewelType.necklace && neckJewel != null)
          ? neckJewel!
          : jewel;

      JewelRealism.draw(
        canvas,
        src,
        p,
        model: model,
        canvasSize: size,
        wrap: wrap,
        tint: tint,
        enhance: enhance,
      );
    }
  }

  @override
  bool shouldRepaint(_RealJewelPainter old) =>
      old.repaintKey != repaintKey ||
          old.jewel != jewel ||
          old.neckJewel != neckJewel ||
          old.tint != tint;
}

/// =========================================================
/// 🧩 COMPOSER — model + jewellery → JPG (🔥 1920 × 2400 HD)
/// =========================================================

class ModelComposer {
  ModelComposer._();

  /// 🔥 Full HD (4:5) — caption pachi pan upscale na thay
  static const Size outSize = Size(1920, 2400);

  /// 🔥 JPG quality (pachi caption ma farithi JPG thay che)
  static const int jpgQuality = 97;

  /// Model photo ni max size (nani hoy to moti nahi kare)
  static const int maxModelPhotoWidth = 2400;

  static String? _imgKey;
  static ui.Image? _img;

  static Future<ui.Image?> _loadModelImage(ModelTemplate m) async {
    if (!m.isPhoto) return null;
    if (_imgKey == m.id && _img != null) return _img;

    final Uint8List bytes = m.assetPath != null
        ? (await rootBundle.load(m.assetPath!)).buffer.asUint8List()
        : await File(m.filePath!).readAsBytes();

    final ui.ImmutableBuffer buf = await ui.ImmutableBuffer.fromUint8List(bytes);
    final ui.ImageDescriptor desc = await ui.ImageDescriptor.encoded(buf);

    final ui.Codec codec = await desc.instantiateCodec(
      targetWidth: desc.width > maxModelPhotoWidth ? maxModelPhotoWidth : null,
    );
    final ui.Image image = (await codec.getNextFrame()).image;

    codec.dispose();
    desc.dispose();
    buf.dispose();

    /// Juni model photo memory mathi kadho
    _img?.dispose();

    _imgKey = m.id;
    _img = image;

    return image;
  }

  /// PNG ni size (preview layout mate)
  static Future<Size?> readSize(Uint8List bytes) async {
    try {
      final ui.ImmutableBuffer buf =
      await ui.ImmutableBuffer.fromUint8List(bytes);
      final ui.ImageDescriptor d = await ui.ImageDescriptor.encoded(buf);
      final Size s = Size(d.width.toDouble(), d.height.toDouble());
      d.dispose();
      buf.dispose();
      return s;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> compose(
      Uint8List transparentPng,
      ModelTemplate model,
      JewelType type,
      JewelAdjust adjust, {
        JewelParts? parts,
        bool shadow = true,
        int quality = jpgQuality,
      }) async {
    /// Jewellery FULL resolution ma (preview jevi nani nahi)
    final ui.Codec codec = await ui.instantiateImageCodec(transparentPng);
    final ui.Image jewel = (await codec.getNextFrame()).image;
    codec.dispose();

    final double jw = jewel.width.toDouble();
    final double jh = jewel.height.toDouble();

    final List<JewelPlacement> placements = ModelLayout.place(
      model: model,
      canvas: outSize,
      type: type,
      jewel: Size(jw, jh),
      adjust: adjust,
      parts: parts,
    );

    /// ✂️ SET: necklace mate earring vagar ni image (full HD)
    ui.Image? neckJewel;
    if (type == JewelType.set) {
      final List<int> ears = ModelLayout.setEarIndices(parts);
      if (ears.isNotEmpty) {
        final Uint8List? nb =
        await compute(necklaceOnlyIsolate, transparentPng);
        if (nb != null) {
          final ui.Codec c = await ui.instantiateImageCodec(nb);
          neckJewel = (await c.getNextFrame()).image;
          c.dispose();
        }
      }
    }

    final ui.Image? modelImage = await _loadModelImage(model);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Offset.zero & outSize);

    // 1) MODEL
    ModelPainter.paint(canvas, outSize, model, image: modelImage);

    // 2) JEWELLERY — realistic (golai, fade, light match, shadow)
    final Color tint = await ModelLighting.tintFor(model);

    for (final JewelPlacement p in placements) {
      JewelRealism.draw(
        canvas,
        (p.kind == JewelType.necklace && neckJewel != null)
            ? neckJewel
            : jewel,
        p,
        model: model,
        canvasSize: outSize,
        wrap: adjust.wrap,
        tint: tint,
        shadow: shadow,
        enhance: adjust.enhance,
      );
    }

    final ui.Picture picture = recorder.endRecording();
    final int w = outSize.width.toInt();
    final int h = outSize.height.toInt();

    final ui.Image out = await picture.toImage(w, h);
    final ByteData? raw =
    await out.toByteData(format: ui.ImageByteFormat.rawRgba);

    jewel.dispose();
    neckJewel?.dispose();
    out.dispose();
    picture.dispose();

    if (raw == null) throw Exception("Model compose failed");

    /// 🔥 HQ JPG (97)
    return compute(encodeRgbaToJpgIsolate, {
      "w": w,
      "h": h,
      "rgba": raw.buffer.asUint8List(),
      "q": quality,
    });
  }
}

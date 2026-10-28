import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import '../Extra/JewelleryBgRemover.dart';
import 'LiveTryOnScreen.dart';
import 'TryOnRender.dart';

/// ================================================================
/// 💍 VIRTUAL TRY-ON
///
/// 1. Item ni image download → background remove → transparent PNG
/// 2. Image mathi alag tukda (pieces) kadho ane olkho:
///    - 1 item (necklace)            → sidhu GALA ma
///    - 3 item: 1 moto + 2 nana      → SET: moto GALA ma, nana banne KAAN ma
///    - 2 sarkha nana item           → banne KAAN ma (earrings)
/// 3. Live camera ma j gothvay; capture pachi e j jagya e photo ma aave
///    Bangle / Bracelet → haath olkhi ne KAAND par, Ring → AANGLI par
///    (haath halave to saathe khase; aangli thi khasavo to manual)
/// 4. Photo par: 1 aangli = khasavo, 2 aangli = nanu-motu + fervo,
///    tap = biju piece pasand
/// 5. Save (gallery) / Share (WhatsApp)
/// ================================================================

enum TryOnType { set, necklace, earrings, bangle, ring }

/// Photo ne seedhi (EXIF rotation) + nani karo — isolate ma
/// flip = true → selfie camera jevo arisa (mirror) photo
Map<String, dynamic> _normalizePhoto(Map<String, dynamic> args) {
  final Uint8List bytes = args["bytes"] as Uint8List;
  final bool flip = args["flip"] as bool? ?? false;

  img.Image? image = img.decodeImage(bytes);
  if (image == null) throw Exception("Invalid photo");

  image = img.bakeOrientation(image);

  if (flip) image = img.flipHorizontal(image);

  const int maxSide = 1600;
  if (math.max(image.width, image.height) > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }

  return {
    "jpg": Uint8List.fromList(img.encodeJpg(image, quality: 92)),
    "w": image.width,
    "h": image.height,
  };
}

/// Decode karelo piece
class _Piece {
  final Uint8List png;
  final ui.Image image;

  _Piece(this.png, this.image);

  double get aspect => image.height / image.width;
  double get area => image.width.toDouble() * image.height.toDouble();

  TryOnPiece toLive() => TryOnPiece(png: png, aspect: aspect);
}

class _Layer {
  final TryOnSlot slot; // kyu piece (gala / kaan / hath)
  Offset center; // photo pixel ma
  double width; // photo pixel ma
  double rotation; // radians
  bool flip;

  _Layer({
    required this.slot,
    required this.center,
    required this.width,
    this.rotation = 0,
    this.flip = false,
  });
}

class TryOnScreen extends StatefulWidget {
  final String imageUrl;
  final String itemName;
  final TryOnType? initialType;

  const TryOnScreen({
    super.key,
    required this.imageUrl,
    this.itemName = "",
    this.initialType,
  });

  /// Item na naam parthi type nu anuman
  static TryOnType guessType(String name) {
    final String n = name.toLowerCase();

    bool has(List<String> words) => words.any(n.contains);

    if (RegExp(r'\bset\b').hasMatch(n)) return TryOnType.set;

    // ⚠️ "earring" ma "ring" pan che → earrings pehla check
    if (has(["earring", "jhum", "tops", "bali", "kaan", "stud", "drop"])) {
      return TryOnType.earrings;
    }
    if (has(["bangle", "kada", "kangan", "bracelet", "chudi", "bala"])) {
      return TryOnType.bangle;
    }
    if (has(["ring", "anguthi", "vinti"])) {
      return TryOnType.ring;
    }
    return TryOnType.necklace;
  }

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  static const Color _stage = Color(0xff16161A);

  late TryOnType _type;

  /// =========================================================
  /// JEWELLERY PIECES
  /// =========================================================
  _Piece? _whole; // aakhi image (background vagar)
  List<_Piece> _parts = []; // alag tukda, moto → nano

  /// Set (1 moto + 2 nana) malyo hoy to
  _Piece? _setNeck, _setEarL, _setEarR;

  /// 2 sarkha nana (fakt earrings) malya hoy to
  _Piece? _pairL, _pairR;

  bool get _hasSet => _setNeck != null;
  bool get _hasPair => _pairL != null;

  /// Haal kya kayu piece pehrvanu: gala / kaan / hath
  Map<TryOnSlot, _Piece> _slots = {};

  /// Badha decode karela ui.Image — dispose mate
  final List<ui.Image> _owned = [];

  /// Photo
  File? _photo;
  Size? _photoSize;

  /// Layers (photo par)
  List<_Layer> _layers = [];
  int _active = 0;

  bool _loadingPiece = true;
  bool _busy = false;
  String? _error;

  /// Screen ↔ photo mapping
  double _viewScale = 1;
  Offset _viewOffset = Offset.zero;

  /// Gesture start values
  Offset _gStartFocal = Offset.zero;
  Offset _gStartCenter = Offset.zero;
  double _gStartWidth = 0;
  double _gStartRot = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TryOnScreen.guessType(widget.itemName);
    _loadPiece();
  }

  @override
  void dispose() {
    for (final ui.Image im in _owned) {
      im.dispose();
    }
    super.dispose();
  }

  /// =========================================================
  /// JEWELLERY → TRANSPARENT PNG → PIECES OLKHO
  /// =========================================================

  Future<_Piece> _decode(Uint8List png) async {
    final ui.Image im = await decodeUiImage(png);
    _owned.add(im);
    return _Piece(png, im);
  }

  Future<void> _loadPiece() async {
    setState(() {
      _loadingPiece = true;
      _error = null;
    });

    try {
      final Response<List<int>> res = await Dio().get<List<int>>(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final Uint8List bytes = Uint8List.fromList(res.data ?? []);
      if (bytes.isEmpty) throw Exception("Empty image");

      final Uint8List png =
      await JewelleryBgRemover.removeBackground(bytes, strength: 32);

      _whole = await _decode(png);

      // Image mathi alag tukda
      List<Uint8List> raw = [];
      try {
        raw = await JewelleryBgRemover.extractPieces(png);
      } catch (e) {
        debugPrint("PIECE SPLIT ERROR => $e");
      }

      final List<_Piece> parts = [];
      for (final Uint8List b in raw) {
        try {
          parts.add(await _decode(b));
        } catch (e) {
          debugPrint("PIECE DECODE ERROR => $e");
        }
      }

      // Moto → nano, ane dhool jeva nana tukda (2% thi ochha) kadhi nakho
      parts.sort((a, b) => b.area.compareTo(a.area));
      if (parts.isNotEmpty) {
        final double maxArea = parts.first.area;
        parts.removeWhere((p) => p.area < maxArea * 0.02);
      }
      _parts = parts;

      _classifyParts();
      _pickDefaultType();
      _applyAutoPiece();
    } catch (e) {
      debugPrint("TRY-ON LOAD ERROR => $e");
      if (mounted) {
        setState(() => _error = "Could not prepare the jewellery image.");
      }
    } finally {
      if (mounted) setState(() => _loadingPiece = false);
    }
  }

  /// Tukda parthi olkho:
  ///  - 3+ tukda: 1 moto + 2 lagbhag sarkha nana → SET
  ///  - 2 tukda lagbhag sarkha → earrings ni jodi
  ///  - baki → 1 item (sauthi moto)
  void _classifyParts() {
    _setNeck = _setEarL = _setEarR = null;
    _pairL = _pairR = null;

    final List<_Piece> p = _parts;

    double ratio(_Piece a, _Piece b) =>
        math.max(a.area, b.area) / math.max(1.0, math.min(a.area, b.area));

    if (p.length >= 3 &&
        p[0].area >= p[1].area * 2.2 && // moto piece nana karta ghanu moto
        ratio(p[1], p[2]) <= 2.0) {
      // banne nana lagbhag sarkha
      _setNeck = p[0];
      _setEarL = p[1];
      _setEarR = p[2];
      return;
    }

    if (p.length == 2 && ratio(p[0], p[1]) <= 1.6) {
      _pairL = p[0];
      _pairR = p[1];
    }
  }

  /// Image joi ne default type
  void _pickDefaultType() {
    final TryOnType? init = widget.initialType;

    // Set malyo ane bahar thi bangle/ring/earrings kahyu nathi → SET
    // (naam parthi bangle / ring / bracelet lagtu hoy to haath j rahe)
    if (_hasSet &&
        (_type == TryOnType.necklace || _type == TryOnType.set) &&
        (init == null || init == TryOnType.necklace || init == TryOnType.set)) {
      _type = TryOnType.set;
      return;
    }

    // Set na malyo pan "set" kahyu hatu → necklace
    if (_type == TryOnType.set && !_hasSet) {
      _type = TryOnType.necklace;
    }

    // 2 sarkha nana tukda ane type nakki nathi → earrings
    if (_hasPair && init == null && _type == TryOnType.necklace) {
      _type = TryOnType.earrings;
    }
  }

  /// Type pramane kya kayu piece
  void _applyAutoPiece() {
    final _Piece? first = _parts.isNotEmpty ? _parts.first : _whole;
    final Map<TryOnSlot, _Piece> m = {};

    switch (_type) {
      case TryOnType.set:
        if (_hasSet) {
          m[TryOnSlot.neck] = _setNeck!;
          m[TryOnSlot.earLeft] = _setEarL!;
          m[TryOnSlot.earRight] = _setEarR!;
        } else if (first != null) {
          m[TryOnSlot.neck] = first;
        }
        break;

      case TryOnType.necklace:
        final _Piece? n = _hasSet ? _setNeck : first;
        if (n != null) m[TryOnSlot.neck] = n;
        break;

      case TryOnType.earrings:
        if (_hasSet) {
          m[TryOnSlot.earLeft] = _setEarL!;
          m[TryOnSlot.earRight] = _setEarR!;
        } else if (_hasPair) {
          m[TryOnSlot.earLeft] = _pairL!;
          m[TryOnSlot.earRight] = _pairR!;
        } else if (first != null) {
          m[TryOnSlot.earLeft] = first;
          m[TryOnSlot.earRight] = first;
        }
        break;

      case TryOnType.bangle:
      case TryOnType.ring:
        if (first != null) m[TryOnSlot.hand] = first;
        break;
    }

    if (mounted) setState(() => _slots = m);
  }

  /// User e jate pasand karelo piece (crop / aakhi image)
  void _useCustomPiece(_Piece p) {
    // Set ma ek j piece hoy nahi → necklace tarike
    if (_type == TryOnType.set) _type = TryOnType.necklace;

    final Map<TryOnSlot, _Piece> m = {};
    switch (_type) {
      case TryOnType.set:
      case TryOnType.necklace:
        m[TryOnSlot.neck] = p;
        break;
      case TryOnType.earrings:
        m[TryOnSlot.earLeft] = p;
        m[TryOnSlot.earRight] = p;
        break;
      case TryOnType.bangle:
      case TryOnType.ring:
        m[TryOnSlot.hand] = p;
        break;
    }

    setState(() => _slots = m);
  }

  /// Set mathi fakt joitu piece (daa.ta. ek earring) crop
  Future<void> _choosePiece() async {
    if (_whole == null || _busy) return;

    try {
      final Directory dir = await getTemporaryDirectory();
      final File src = File(
        "${dir.path}/tryon_piece_${DateTime.now().microsecondsSinceEpoch}.png",
      );
      await src.writeAsBytes(_whole!.png);

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: src.path,
        compressFormat: ImageCompressFormat.png,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: "Select one piece",
            toolbarColor: AppColors.primaryDark,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: "Select one piece"),
        ],
      );

      if (cropped == null) return;

      _useCustomPiece(await _decode(await File(cropped.path).readAsBytes()));
      if (_photo != null) await _autoPlace();
    } catch (e) {
      debugPrint("PIECE CROP ERROR => $e");
      if (mounted) AppMessage.error(context, "Unable to select piece");
    }
  }

  Future<void> _useWholeImage() async {
    if (_whole == null) return;
    _useCustomPiece(_whole!);
    if (_photo != null) await _autoPlace();
  }

  /// =========================================================
  /// PHOTO
  /// =========================================================

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? x = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 95,
    );

    if (x == null) return;

    await _usePhotoFile(x.path);
  }

  /// Live camera ke picker mathi aavelo photo vapro
  /// [live] aave to live ma je jagya e jewellery hati e j jagya e muko
  Future<void> _usePhotoFile(
      String path, {
        bool mirror = false,
        LiveTryOnResult? live,
      }) async {
    setState(() => _busy = true);

    try {
      final Uint8List bytes = await File(path).readAsBytes();
      final Map<String, dynamic> norm = await compute(
        _normalizePhoto,
        <String, dynamic>{"bytes": bytes, "flip": mirror},
      );

      final Directory dir = await getTemporaryDirectory();
      final File f = File(
        "${dir.path}/tryon_photo_${DateTime.now().microsecondsSinceEpoch}.jpg",
      );
      await f.writeAsBytes(norm["jpg"] as Uint8List);

      setState(() {
        _photo = f;
        _photoSize = Size(
          (norm["w"] as int).toDouble(),
          (norm["h"] as int).toDouble(),
        );
      });

      // Live ma je jagya e hatu e j jagya e → navesar auto-place nahi
      if (live != null &&
          live.layers.isNotEmpty &&
          !live.previewSize.isEmpty) {
        _applyLiveLayers(live);
      } else {
        await _autoPlace();
      }
    } catch (e) {
      debugPrint("TRY-ON PHOTO ERROR => $e");
      if (mounted) AppMessage.error(context, "Unable to open photo");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Live preview ni position → photo pixel ma
  void _applyLiveLayers(LiveTryOnResult live) {
    final Size ps = _photoSize!;
    final double previewAspect =
        live.previewSize.width / live.previewSize.height;
    final double photoAspect = ps.width / ps.height;

    // Preview ane photo nu ratio alag hoy to vachche no bhaag j preview ma dekhato
    double rw = ps.width, rh = ps.height, ox = 0, oy = 0;
    if (photoAspect > previewAspect) {
      rw = ps.height * previewAspect;
      ox = (ps.width - rw) / 2;
    } else {
      rh = ps.width / previewAspect;
      oy = (ps.height - rh) / 2;
    }

    final List<_Layer> layers = live.layers
        .where((l) => _slots.containsKey(l.slot))
        .map((l) => _Layer(
      slot: l.slot,
      center: Offset(ox + l.center.dx * rw, oy + l.center.dy * rh),
      width: l.width * rw,
      rotation: l.rotation,
    ))
        .toList();

    setState(() {
      _layers = layers;
      _active = 0;
    });
  }

  /// =========================================================
  /// 📸 LIVE CAMERA (badha type)
  /// =========================================================

  bool get _supportsLive => true;

  bool get _isFaceType =>
      _type == TryOnType.set ||
          _type == TryOnType.necklace ||
          _type == TryOnType.earrings;

  Future<void> _openCamera() async {
    if (_slots.isEmpty || _busy) return;

    final LiveTryOnResult? res = await Navigator.push<LiveTryOnResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTryOnScreen(
          type: _type,
          pieces: {
            for (final MapEntry<TryOnSlot, _Piece> e in _slots.entries)
              e.key: e.value.toLive(),
          },
        ),
      ),
    );

    if (res == null || !mounted) return;

    // Front camera preview arisa jevo hato → photo pan e j rite
    await _usePhotoFile(res.path, mirror: res.mirrored, live: res);
  }

  /// =========================================================
  /// 🤖 AUTO PLACE (chehro olkhi ne) — gallery photo / "Auto fit"
  /// Set hoy to necklace + earrings banne saathe
  /// =========================================================

  Future<void> _autoPlace() async {
    if (_photo == null || _photoSize == null) return;

    final Size s = _photoSize!;
    final _Piece? neck = _slots[TryOnSlot.neck];
    final _Piece? earL = _slots[TryOnSlot.earLeft];
    final _Piece? earR = _slots[TryOnSlot.earRight];
    final _Piece? hand = _slots[TryOnSlot.hand];
    final bool hasEars = earL != null || earR != null;

    Face? face;

    if (neck != null || hasEars) {
      final FaceDetector detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      try {
        final List<Face> faces =
        await detector.processImage(InputImage.fromFilePath(_photo!.path));

        if (faces.isNotEmpty) {
          face = faces.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >=
              b.boundingBox.width * b.boundingBox.height
              ? a
              : b);
        }
      } catch (e) {
        debugPrint("FACE DETECT ERROR => $e");
      } finally {
        await detector.close();
      }

      if (face == null && mounted) {
        AppMessage.error(
          context,
          "Face not found. Move the jewellery into place by hand.",
        );
      }
    }

    final List<_Layer> layers = [];

    // ---------------- NECKLACE (gala) ----------------
    if (neck != null) {
      if (face != null) {
        final Rect r = face.boundingBox;

        double chinY = r.bottom;
        final List<math.Point<int>>? pts =
            face.contours[FaceContourType.face]?.points;
        if (pts != null && pts.isNotEmpty) {
          chinY = pts.map((p) => p.y.toDouble()).reduce(math.max);
        }

        final double w = r.width * 1.3;
        final double h = w * neck.aspect;

        layers.add(_Layer(
          slot: TryOnSlot.neck,
          center: Offset(r.center.dx, chinY - r.height * 0.06 + h / 2),
          width: w,
        ));
      } else {
        layers.add(_Layer(
          slot: TryOnSlot.neck,
          center: Offset(s.width / 2, s.height * 0.68),
          width: s.width * 0.55,
        ));
      }
    }

    // ---------------- EARRINGS (banne kaan) ----------------
    if (hasEars) {
      final _Piece pa = (earL ?? earR)!;
      final _Piece pb = (earR ?? earL)!;

      if (face != null) {
        final Rect r = face.boundingBox;
        final double w = r.width * 0.18;

        Offset pt(math.Point<int> p) => Offset(p.x.toDouble(), p.y.toDouble());

        // Lob ni unchai = naak na niche thi thodu niche (live jevu j)
        final math.Point<int>? nb =
            face.landmarks[FaceLandmarkType.noseBase]?.position;
        final double lobeY = earLobeY(r, nb == null ? null : pt(nb).dy);

        // 1) Chehra ni kinari parthi lob
        final List<math.Point<int>>? facePts =
            face.contours[FaceContourType.face]?.points;
        List<Offset>? lobes = facePts == null
            ? null
            : findEarLobes(facePts.map(pt).toList(), r, lobeY);

        // 2) Contour na male to ear landmark (x) + lobeY
        if (lobes == null) {
          Offset lm(FaceLandmarkType t, double fallbackX) {
            final math.Point<int>? p = face!.landmarks[t]?.position;
            return Offset(p != null ? p.x.toDouble() : fallbackX, lobeY);
          }

          final Offset a = lm(FaceLandmarkType.leftEar, r.left);
          final Offset b = lm(FaceLandmarkType.rightEar, r.right);
          lobes = a.dx <= b.dx ? [a, b] : [b, a];
        }

        // Hook lob par → earring tya thi seedhu niche latke
        Offset hang(Offset lobe, double aspect) {
          final double h = w * aspect;
          return Offset(lobe.dx, lobe.dy + h / 2 - h * 0.04);
        }

        layers.add(_Layer(
          slot: TryOnSlot.earLeft,
          center: hang(lobes[0], pa.aspect),
          width: w,
        ));
        layers.add(_Layer(
          slot: TryOnSlot.earRight,
          center: hang(lobes[1], pb.aspect),
          width: w,
        ));
      } else {
        layers.add(_Layer(
          slot: TryOnSlot.earLeft,
          center: Offset(s.width * 0.35, s.height * 0.45),
          width: s.width * 0.12,
        ));
        layers.add(_Layer(
          slot: TryOnSlot.earRight,
          center: Offset(s.width * 0.65, s.height * 0.45),
          width: s.width * 0.12,
        ));
      }
    }

    // ---------------- BANGLE / BRACELET / RING ----------------
    if (hand != null) {
      final bool isRing = _type == TryOnType.ring;
      HandPlacement? hp;

      // Photo ma haath olkho (kaand / aangli)
      final PoseDetector pd = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.single,
          model: PoseDetectionModel.accurate,
        ),
      );
      try {
        final List<Pose> poses =
        await pd.processImage(InputImage.fromFilePath(_photo!.path));
        if (poses.isNotEmpty) {
          hp = placeOnHand(
            poses.first,
            ring: isRing,
            map: (x, y) => Offset(x, y),
          );
        }
      } catch (e) {
        debugPrint("HAND DETECT ERROR => $e");
      } finally {
        await pd.close();
      }

      if (hp != null) {
        layers.add(_Layer(
          slot: TryOnSlot.hand,
          center: hp.center,
          width: hp.width,
          rotation: hp.rotation,
        ));
      } else {
        if (mounted) {
          AppMessage.error(
            context,
            "Hand not found. Move the jewellery into place by hand.",
          );
        }
        layers.add(_Layer(
          slot: TryOnSlot.hand,
          center: Offset(s.width / 2, s.height / 2),
          width: s.width * (isRing ? 0.14 : 0.45),
        ));
      }
    }

    if (!mounted) return;

    setState(() {
      _layers = layers;
      _active = 0;
    });
  }

  /// =========================================================
  /// GESTURES
  /// =========================================================

  void _onScaleStart(ScaleStartDetails d) {
    if (_layers.isEmpty) return;
    final _Layer l = _layers[_active];
    _gStartFocal = d.focalPoint;
    _gStartCenter = l.center;
    _gStartWidth = l.width;
    _gStartRot = l.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_layers.isEmpty || _photoSize == null) return;
    final _Layer l = _layers[_active];

    setState(() {
      l.center = _gStartCenter + (d.focalPoint - _gStartFocal) / _viewScale;
      l.width = (_gStartWidth * d.scale)
          .clamp(20.0, _photoSize!.width * 3)
          .toDouble();
      l.rotation = _gStartRot + d.rotation;
    });
  }

  /// Tap → najik nu piece pasand
  void _selectAt(Offset local) {
    if (_layers.length < 2) return;

    final Offset p = (local - _viewOffset) / _viewScale;
    int best = _active;
    double bestD = double.infinity;

    for (int i = 0; i < _layers.length; i++) {
      final double d = (_layers[i].center - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }

    setState(() => _active = best);
  }

  void _flipActive() {
    if (_layers.isEmpty) return;
    setState(() => _layers[_active].flip = !_layers[_active].flip);
  }

  /// =========================================================
  /// FINAL IMAGE (asli photo resolution par)
  /// =========================================================

  Future<File?> _renderToFile() async {
    if (_photo == null || _slots.isEmpty) return null;

    final Uint8List photoBytes = await _photo!.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(photoBytes);
    final ui.Image photo = (await codec.getNextFrame()).image;

    final ui.PictureRecorder rec = ui.PictureRecorder();
    final Canvas canvas = Canvas(rec);

    canvas.drawImage(photo, Offset.zero, Paint());

    final Paint paint = Paint()..filterQuality = FilterQuality.high;

    for (final _Layer l in _layers) {
      final _Piece? piece = _slots[l.slot];
      if (piece == null) continue;

      final double w = l.width;
      final double h = w * piece.aspect;

      canvas.save();
      canvas.translate(l.center.dx, l.center.dy);
      canvas.rotate(l.rotation);
      if (l.flip) canvas.scale(-1, 1);

      final Rect dst =
      Rect.fromCenter(center: Offset.zero, width: w, height: h);

      if (l.slot == TryOnSlot.neck) {
        paintWornNecklace(canvas, piece.image, dst);
      } else {
        canvas.drawImageRect(
          piece.image,
          Rect.fromLTWH(
            0,
            0,
            piece.image.width.toDouble(),
            piece.image.height.toDouble(),
          ),
          dst,
          paint,
        );
      }
      canvas.restore();
    }

    final ui.Image out =
    await rec.endRecording().toImage(photo.width, photo.height);
    final ByteData? data = await out.toByteData(format: ui.ImageByteFormat.png);

    photo.dispose();
    out.dispose();

    if (data == null) return null;

    final Directory dir = await getTemporaryDirectory();
    final File f = File(
      "${dir.path}/tryon_${DateTime.now().millisecondsSinceEpoch}.png",
    );
    await f.writeAsBytes(data.buffer.asUint8List());
    return f;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      bool access = await Gal.hasAccess();
      if (!access) access = await Gal.requestAccess();
      if (!access) {
        if (mounted) {
          AppMessage.error(context, "Gallery permission is required");
        }
        return;
      }

      final File? f = await _renderToFile();
      if (f == null) return;

      await Gal.putImage(f.path, album: "Ornasphere");
      if (mounted) AppMessage.success(context, "Saved to gallery");
    } catch (e) {
      debugPrint("TRY-ON SAVE ERROR => $e");
      if (mounted) AppMessage.error(context, "Unable to save image");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final File? f = await _renderToFile();
      if (f == null) return;

      await Share.shareXFiles(
        [XFile(f.path, mimeType: "image/png")],
        text: widget.itemName,
      );
    } catch (e) {
      debugPrint("TRY-ON SHARE ERROR => $e");
      if (mounted) AppMessage.error(context, "Unable to share image");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// =========================================================
  /// BUILD
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _stage,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _typeSelector(),
            Expanded(child: _stageArea()),
            if (_photo != null) _bottomTools(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Try on",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.itemName.isNotEmpty)
                  Text(
                    widget.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_photo != null)
            TextButton.icon(
              onPressed: _busy ? null : () => _showPhotoSourceSheet(),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text("New photo"),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    const Map<TryOnType, List<dynamic>> meta = {
      TryOnType.set: ["Set", Icons.auto_awesome_outlined],
      TryOnType.necklace: ["Necklace", Icons.diamond_outlined],
      TryOnType.earrings: ["Earrings", Icons.hearing_outlined],
      TryOnType.bangle: ["Bangle / Bracelet", Icons.circle_outlined],
      TryOnType.ring: ["Ring", Icons.radio_button_checked],
    };

    // "Set" chip fakt set malyo hoy tyare j
    final List<TryOnType> types = TryOnType.values
        .where((t) => t != TryOnType.set || _hasSet)
        .toList();

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: types.map((t) {
          final bool selected = t == _type;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _busy || _loadingPiece
                  ? null
                  : () async {
                setState(() => _type = t);
                _applyAutoPiece();
                if (_photo != null) await _autoPlace();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryDark
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryDark
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      meta[t]![1] as IconData,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      meta[t]![0] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stageArea() {
    if (_loadingPiece) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14),
            Text(
              "Preparing jewellery...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadPiece,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text("Try again"),
            ),
          ],
        ),
      );
    }

    if (_photo == null) return _emptyState();

    return Stack(
      children: [
        Positioned.fill(child: _canvas()),
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _emptyState() {
    // Set hoy to aakhi image, nahi to pasand thayelo piece
    final Uint8List? preview = _type == TryOnType.set
        ? _whole?.png
        : (_slots.isEmpty ? _whole?.png : _slots.values.first.png);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (preview != null)
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Image.memory(preview, fit: BoxFit.contain),
            ),
          const SizedBox(height: 22),
          const Text(
            "See it on you",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _type == TryOnType.set
                ? "Necklace goes on your neck and earrings on your ears. Keep your face and neck visible."
                : _isFaceType
                ? "Take a front-facing photo with your neck and ears visible."
                : _type == TryOnType.ring
                ? "Raise your hand near your chest. The ring goes on your finger automatically."
                : "Raise your hand near your chest. The bangle goes on your wrist automatically.",
            textAlign: TextAlign.center,
            style:
            TextStyle(color: Colors.white.withOpacity(0.6), height: 1.4),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _bigButton(
                  icon: _supportsLive
                      ? Icons.videocam_rounded
                      : Icons.photo_camera_rounded,
                  label: _supportsLive ? "Live camera" : "Take photo",
                  filled: true,
                  onTap: _openCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigButton(
                  icon: Icons.photo_library_outlined,
                  label: "Gallery",
                  filled: false,
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(
          colors: [AppColors.primaryDark, AppColors.secondaryDark],
        )
            : null,
        color: filled ? null : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: filled ? null : Border.all(color: Colors.white24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Photo + jewellery layers
  Widget _canvas() {
    return LayoutBuilder(
      builder: (context, c) {
        final Size ps = _photoSize!;
        final double sc =
        math.min(c.maxWidth / ps.width, c.maxHeight / ps.height);
        final double dw = ps.width * sc;
        final double dh = ps.height * sc;
        final double ox = (c.maxWidth - dw) / 2;
        final double oy = (c.maxHeight - dh) / 2;

        _viewScale = sc;
        _viewOffset = Offset(ox, oy);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _selectAt(d.localPosition),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: SizedBox(
            width: c.maxWidth,
            height: c.maxHeight,
            child: Stack(
              children: [
                Positioned(
                  left: ox,
                  top: oy,
                  width: dw,
                  height: dh,
                  child: Image.file(_photo!, fit: BoxFit.fill),
                ),
                for (int i = 0; i < _layers.length; i++)
                  _layerWidget(i, sc, ox, oy),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _layerWidget(int i, double sc, double ox, double oy) {
    final _Layer l = _layers[i];
    final _Piece? piece = _slots[l.slot];
    if (piece == null) return const SizedBox.shrink();

    final double w = l.width * sc;
    final double h = w * piece.aspect;
    final bool active = i == _active && _layers.length > 1;

    return Positioned(
      left: ox + l.center.dx * sc - w / 2,
      top: oy + l.center.dy * sc - h / 2,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: l.rotation,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(l.flip ? -1 : 1, 1, 1),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: active
                    ? Border.all(color: Colors.white.withOpacity(0.8))
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: l.slot == TryOnSlot.neck
                  ? CustomPaint(painter: WornNecklacePainter(piece.image))
                  : Image.memory(
                piece.png,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomTools() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _layers.length > 1
                ? "Tap a piece to select it. Drag to move, pinch to resize, twist to rotate."
                : "Drag to move. Pinch to resize. Twist to rotate.",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55), fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tool(Icons.crop_rounded, "Piece", _choosePiece),
              _tool(Icons.layers_outlined, "Whole image", _useWholeImage),
              _tool(Icons.auto_fix_high_rounded, "Auto fit", _autoPlace),
              _tool(Icons.flip_rounded, "Flip", _flipActive),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bigButton(
                  icon: Icons.download_rounded,
                  label: "Save",
                  filled: false,
                  onTap: _save,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigButton(
                  icon: Icons.share_rounded,
                  label: "Share",
                  filled: true,
                  onTap: _share,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1F1F24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: _bigButton(
                  icon: Icons.photo_camera_rounded,
                  label: "Camera",
                  filled: true,
                  onTap: () {
                    Navigator.pop(sheet);
                    _openCamera();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigButton(
                  icon: Icons.photo_library_outlined,
                  label: "Gallery",
                  filled: false,
                  onTap: () {
                    Navigator.pop(sheet);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
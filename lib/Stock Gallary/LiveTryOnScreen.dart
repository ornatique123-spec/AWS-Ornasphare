import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import 'TryOnRender.dart';
import 'TryOnScreen.dart';

/// ================================================================
/// 📸 LIVE TRY-ON — PHASE 2 (LIVE CAMERA)
///
/// - Necklace → hadapchi ni niche gala par
/// - Earrings → banne kaan par
/// - SET (1 moto + 2 nana) → moto gala ma, nana banne kaan ma — saathe
/// - Bangle / Ring → user aangli thi kaand / aangli par gothve
/// - Capture → photo + LIVE ni position TryOnScreen ma pachhi jay
///   (live ma je jagya e dekhayu e j jagya e photo ma aave)
///
/// Navigator.pop(context, LiveTryOnResult) thi result return thay.
/// ================================================================

/// Jewellery kya pehrvani: gala, dabo kaan, jamno kaan, hath
/// earLeft = screen / photo ni DABI baju no kaan, earRight = JAMNI baju
enum TryOnSlot { neck, earLeft, earRight, hand }

/// =========================================================
/// 👂 KAAN NI LOB (earring latkavvani jagya) SHODHO
///
/// ML Kit no "ear" landmark kaan nu chhidra nathi, ane ghanu khase che.
/// Etle chehra ni kinari (face contour) ne [lobeY] unchai par kapi ne
/// dabi / jamni kinari leiye, ane thodu bahar khasaviye — tya lob hoy.
/// [contour] ane [box] same coordinate ma (screen ke photo).
/// Return: [dabi lob, jamni lob] ke null.
/// =========================================================
List<Offset>? findEarLobes(List<Offset> contour, Rect box, double lobeY) {
  if (contour.length < 6) return null;

  final double cx = box.center.dx;
  double? leftX, rightX;

  for (int i = 0; i < contour.length; i++) {
    final Offset a = contour[i];
    final Offset b = contour[(i + 1) % contour.length];

    // Aa tukdo lobeY ni line ne kape che?
    if ((a.dy - lobeY) * (b.dy - lobeY) > 0) continue;

    final double dy = b.dy - a.dy;
    final double t = dy.abs() < 1e-6 ? 0.0 : (lobeY - a.dy) / dy;
    final double x = a.dx + (b.dx - a.dx) * t;

    if (x < cx) {
      leftX = leftX == null ? x : math.min(leftX, x);
    } else {
      rightX = rightX == null ? x : math.max(rightX, x);
    }
  }

  if (leftX == null || rightX == null) return null;

  // Lob gaal ni kinari thi thodi pachhad / bahar hoy
  final double push = box.width * 0.04;
  return [Offset(leftX - push, lobeY), Offset(rightX + push, lobeY)];
}

/// Lob ni unchai: naak na niche thi thodu niche
double earLobeY(Rect box, double? noseBaseY) =>
    (noseBaseY ?? box.top + box.height * 0.6) + box.height * 0.04;

/// =========================================================
/// ✋ HATH PAR JAGYA (bangle / bracelet → kaand, ring → aangli)
/// =========================================================
class HandPlacement {
  final Offset center;
  final double width;
  final double rotation;

  const HandPlacement(this.center, this.width, this.rotation);
}

/// ML Kit pose mathi kaand (wrist) + tarjani (index) + tachli (pinky)
/// leine bangle / ring ni jagya, size ane angle.
/// [map] = image coordinates → screen / photo coordinates.
/// Banne haath dekhay to jeno kaand vadhu saaf dekhay e haath.
HandPlacement? placeOnHand(
    Pose pose, {
      required bool ring,
      required Offset Function(double x, double y) map,
      double minLikelihood = 0.5,
    }) {
  HandPlacement? side(
      PoseLandmarkType wT,
      PoseLandmarkType iT,
      PoseLandmarkType pT,
      ) {
    final PoseLandmark? w = pose.landmarks[wT];
    final PoseLandmark? i = pose.landmarks[iT];
    final PoseLandmark? p = pose.landmarks[pT];
    if (w == null || i == null || p == null) return null;
    if (w.likelihood < minLikelihood) return null;
    // Aangli na point pan thoda saaf hova joie, nahi to ulta-sulta kude
    if (i.likelihood < minLikelihood * 0.6 ||
        p.likelihood < minLikelihood * 0.6) {
      return null;
    }

    final Offset wrist = map(w.x, w.y);
    final Offset index = map(i.x, i.y);
    final Offset pinky = map(p.x, p.y);

    // Kaand → aangli na mool (knuckle) taraf ni disha
    final Offset knuckles = (index + pinky) / 2;
    final Offset d = knuckles - wrist;
    final double len = d.distance;
    if (len < 4) return null;
    final Offset n = d / len;

    // Hath ni pahodai (aashare)
    final double span = (index - pinky).distance;

    // Bangle / ring hath ni disha ne aadu (perpendicular) rahe
    double rot = math.atan2(n.dy, n.dx) + math.pi / 2;
    while (rot > math.pi / 2) {
      rot -= math.pi;
    }
    while (rot <= -math.pi / 2) {
      rot += math.pi;
    }

    if (!ring) {
      // Bangle / bracelet: kaand thi thodu kooni (elbow) taraf
      final double wristW = math.max(span * 1.3, len * 0.9) * 1.15;
      final Offset c = wrist - n * (len * 0.12);
      return HandPlacement(c, wristW, rot);
    }

    // Ring: anamika (ring finger) — tarjani thi tachli taraf ~2/3,
    // knuckle thi thodu aagal
    final Offset base = Offset.lerp(index, pinky, 0.62)!;
    final Offset c = base + n * (len * 0.35);
    return HandPlacement(c, math.max(span * 0.42, 10), rot);
  }

  HandPlacement? best;
  double bestScore = -1;

  for (final List<PoseLandmarkType> s in const [
    [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftIndex,
      PoseLandmarkType.leftPinky,
    ],
    [
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightIndex,
      PoseLandmarkType.rightPinky,
    ],
  ]) {
    final HandPlacement? h = side(s[0], s[1], s[2]);
    final double score = pose.landmarks[s[0]]?.likelihood ?? 0;
    if (h != null && score > bestScore) {
      best = h;
      bestScore = score;
    }
  }

  return best;
}

/// Ek piece (transparent PNG) + teni unchai/pahodai
class TryOnPiece {
  final Uint8List png;
  final double aspect; // height / width

  const TryOnPiece({required this.png, required this.aspect});
}

/// Live ma dekhati jewellery ni position — preview na 0..1 bhaag ma
class LiveTryOnLayer {
  final TryOnSlot slot;
  final Offset center; // x / previewWidth, y / previewHeight
  final double width; // width / previewWidth
  final double rotation; // radians

  const LiveTryOnLayer({
    required this.slot,
    required this.center,
    required this.width,
    required this.rotation,
  });
}

/// Capture nu result: photo + live ni position
class LiveTryOnResult {
  final String path;
  final Size previewSize;
  final List<LiveTryOnLayer> layers;

  /// Front camera hoy to preview arisa jevo (mirror) hato
  final bool mirrored;

  const LiveTryOnResult({
    required this.path,
    required this.previewSize,
    required this.layers,
    required this.mirrored,
  });
}

class LiveTryOnScreen extends StatefulWidget {
  final TryOnType type;

  /// Kya kayu piece: neck / earLeft / earRight / hand
  final Map<TryOnSlot, TryOnPiece> pieces;

  const LiveTryOnScreen({
    super.key,
    required this.type,
    required this.pieces,
  });

  @override
  State<LiveTryOnScreen> createState() => _LiveTryOnScreenState();
}

class _LiveTryOnScreenState extends State<LiveTryOnScreen> {
  CameraController? _controller;
  CameraDescription? _camera;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  /// Hath (kaand / aangli) olakhva — bangle / bracelet / ring
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  bool _processing = false;
  bool _capturing = false;
  String? _error;

  /// Chhello malelo chehro (camera image coordinates ma)
  Face? _face;
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  DateTime _lastFaceAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Smooth (dhrujvanu ochhu) — screen coordinates ma
  Offset? _sNeck;
  double _sNeckW = 0;
  Offset? _sEarA; // screen ni dabi baju no kaan → earLeft piece
  Offset? _sEarB; // screen ni jamni baju no kaan → earRight piece
  double _sEarW = 0;
  double _sAngle = 0;

  static const double _smooth = 0.35; // 0 = kadi na khase, 1 = koi smoothing nahi

  /// User adjust (live): size ane upar/niche
  double _sizeAdj = 1.0; // 0.7 – 1.6
  bool _tooClose = false; // pendant camera ni bahar?
  double _dropAdj = 0.0; // -0.15 – 0.45 (chehra ni unchai na bhaag ma)

  /// =========================================================
  /// 🔧 AUTO-CALIBRATION + DIAGNOSTICS
  /// =========================================================
  List<int> _rotCandidates = const [270];
  int _rotIndex = 0;
  bool _rotLocked = false;
  int _framesSinceFace = 0;

  int _frames = 0;
  int _detected = 0;
  String _diag = "starting...";
  String _lastError = "";
  bool _showDiag = false;

  ui.Image? _neckImage; // necklace painter mate

  Size? _canvasSize; // preview nu screen par nu size

  bool _loggedFormat = false;

  /// =========================================================
  /// PIECES
  /// =========================================================
  TryOnPiece? get _neck => widget.pieces[TryOnSlot.neck];
  TryOnPiece? get _earL => widget.pieces[TryOnSlot.earLeft];
  TryOnPiece? get _earR => widget.pieces[TryOnSlot.earRight];
  TryOnPiece? get _hand => widget.pieces[TryOnSlot.hand];

  bool get _hasEars => _earL != null || _earR != null;

  /// Chehro olakhvo pade? (necklace / earrings / set)
  bool get _isFace => _neck != null || _hasEars;

  /// =========================================================
  /// ✋ BANGLE / BRACELET / RING
  /// Auto: haath olkhi ne kaand / aangli par, haath saathe khase.
  /// User aangli thi khasave etle Manual (tya j rahe); chip thi
  /// pachhu Auto.
  /// =========================================================
  CameraLensDirection _lens = CameraLensDirection.front;

  /// Chhella thoda frame na pose → median thi dhrujvanu band
  final List<Pose> _poseHist = [];
  static const int _poseHistLen = 5;

  DateTime _lastHandAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _handAuto = true;

  bool get _handVisible =>
      DateTime.now().difference(_lastHandAt).inMilliseconds < 700;

  Offset? _hCenter;
  double _hWidth = 0;
  double _hRot = 0;

  Offset _hgStartFocal = Offset.zero;
  Offset _hgStartCenter = Offset.zero;
  double _hgStartWidth = 0;
  double _hgStartRot = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // Selfie camera: chehro ane haath (khabha sathe) banne olkhay.
    // Hath mate pachhlo camera pan switch kari shakay.
    _lens = CameraLensDirection.front;

    final TryOnPiece? neck = _neck;
    if (neck != null) {
      decodeUiImage(neck.png).then((im) {
        if (mounted) {
          setState(() => _neckImage = im);
        } else {
          im.dispose();
        }
      });
    }
    _initCamera();
  }

  @override
  void dispose() {
    final CameraController? c = _controller;
    if (c != null && c.value.isStreamingImages) {
      c.stopImageStream().catchError((_) {});
    }
    _controller?.dispose();
    _detector.close();
    _poseDetector.close();
    _neckImage?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// =========================================================
  /// CAMERA
  /// =========================================================

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cams = await availableCameras();

      _camera = cams.firstWhere(
            (c) => c.lensDirection == _lens,
        orElse: () => cams.first,
      );
      _lens = _camera!.lensDirection;

      final CameraController controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) return;

      _controller = controller;

      final int sensor = _camera!.sensorOrientation;
      _rotCandidates = <int>{
        sensor,
        (360 - sensor) % 360,
        270,
        90,
        0,
        180,
      }.toList();

      // Chehro ke haath olakhva frame stream
      _rotIndex = 0;
      _rotLocked = false;
      _framesSinceFace = 0;
      await controller.startImageStream(_onFrame);

      setState(() {});
    } catch (e) {
      debugPrint("LIVE CAMERA ERROR => $e");
      if (mounted) {
        setState(() =>
        _error = "Camera could not be opened. Check camera permission.");
      }
    }
  }

  /// Front ↔ back camera (bangle / ring mate)
  Future<void> _switchCamera() async {
    if (_capturing) return;
    final CameraController? old = _controller;
    setState(() => _controller = null);
    await old?.dispose();

    _lens = _lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _initCamera();
  }

  /// =========================================================
  /// ✋ HATH GESTURES (bangle / ring)
  /// =========================================================

  void _ensureHandLayer(Size canvas) {
    if (_hCenter != null && _hWidth > 0) return;
    _hCenter = Offset(canvas.width / 2, canvas.height * 0.55);
    _hWidth = canvas.width * (widget.type == TryOnType.bangle ? 0.55 : 0.18);
  }

  static double _wrapHalfPi(double a) {
    while (a > math.pi / 2) {
      a -= math.pi;
    }
    while (a < -math.pi / 2) {
      a += math.pi;
    }
    return a;
  }

  static double _median(List<double> v) {
    final List<double> s = [...v]..sort();
    final int m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  /// Pose → haath par jagya (auto), SthIR:
  ///  1. Chhella 5 frame no MEDIAN → ek-be kharab frame ganay nahi
  ///  2. Dead zone → nani dhrujaari ignore
  ///  3. Adaptive smoothing → dhimu hoy to ekdam sthir, motu khase to saathe
  void _updateHand(Size canvas) {
    if (!_handAuto || !_handVisible || _poseHist.isEmpty || _imageSize == null) {
      return;
    }

    final bool ring = widget.type == TryOnType.ring;
    final List<HandPlacement> list = [];
    for (final Pose p in _poseHist) {
      final HandPlacement? hp = placeOnHand(
        p,
        ring: ring,
        map: (x, y) => Offset(_tx(x, canvas), _ty(y, canvas)),
      );
      if (hp != null) list.add(hp);
    }
    if (list.isEmpty) return;

    // ---------- 1) MEDIAN ----------
    final double rot0 = list.first.rotation;
    final Offset tCenter = Offset(
      _median(list.map((h) => h.center.dx).toList()),
      _median(list.map((h) => h.center.dy).toList()),
    );
    final double tWidth = _median(list.map((h) => h.width).toList()) * _sizeAdj;
    final double tRot = _wrapHalfPi(
      rot0 +
          _median(list.map((h) => _wrapHalfPi(h.rotation - rot0)).toList()),
    );

    // Pehli vaar → sidhu tya j
    if (_hCenter == null || _hWidth <= 0) {
      _hCenter = tCenter;
      _hWidth = tWidth;
      _hRot = tRot;
      return;
    }

    // ---------- 2+3) CENTER: dead zone + adaptive ----------
    final double move = (tCenter - _hCenter!).distance;
    final double dead = canvas.width * 0.012; // ~1% → dhrujaari
    if (move > dead) {
      // Motu khasvanu → jaldi saathe (0.45), nanu → dhimu (0.08)
      final double a = ((move - dead) / (canvas.width * 0.08))
          .clamp(0.08, 0.45)
          .toDouble();
      _hCenter = Offset.lerp(_hCenter, tCenter, a);
    }

    // ---------- SIZE: 4% thi ochho farak ignore ----------
    final double rel = (tWidth - _hWidth).abs() / _hWidth;
    if (rel > 0.04) {
      _hWidth = _hWidth + (tWidth - _hWidth) * 0.12;
    }

    // ---------- ANGLE: ~4° thi ochho farak ignore ----------
    final double diff = _wrapHalfPi(tRot - _hRot);
    if (diff.abs() > 0.07) {
      final double a = (diff.abs() / 0.6).clamp(0.08, 0.35).toDouble();
      _hRot = _wrapHalfPi(_hRot + diff * a);
    }
  }

  void _onHandScaleStart(ScaleStartDetails d) {
    if (_hCenter == null) return;
    // User e jate khasavyu → Manual
    _handAuto = false;
    _hgStartFocal = d.localFocalPoint;
    _hgStartCenter = _hCenter!;
    _hgStartWidth = _hWidth;
    _hgStartRot = _hRot;
  }

  void _onHandScaleUpdate(ScaleUpdateDetails d) {
    final Size? cv = _canvasSize;
    if (_hCenter == null || cv == null) return;

    setState(() {
      _hCenter = _hgStartCenter + (d.localFocalPoint - _hgStartFocal);
      _hWidth = (_hgStartWidth * d.scale).clamp(24.0, cv.width * 1.5).toDouble();
      _hRot = _hgStartRot + d.rotation;
    });
  }

  /// =========================================================
  /// FRAME → FACE
  /// =========================================================

  Future<void> _onFrame(CameraImage image) async {
    _frames++;
    if (_processing || _capturing || !mounted) return;
    _processing = true;

    try {
      final InputImage? input = _toInputImage(image);
      if (input == null) {
        _lastError = "frame skipped (format)";
        return;
      }

      bool found = false;

      if (_isFace) {
        // ---------------- CHEHRO ----------------
        final List<Face> faces = await _detector.processImage(input);
        if (!mounted) return;

        if (faces.isNotEmpty) {
          found = true;
          _face = faces.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >=
              b.boundingBox.width * b.boundingBox.height
              ? a
              : b);
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          _lastFaceAt = DateTime.now();
        }
      } else {
        // ---------------- HAATH (pose) ----------------
        final List<Pose> poses = await _poseDetector.processImage(input);
        if (!mounted) return;

        if (poses.isNotEmpty) {
          final Pose pose = poses.first;
          final bool hasHand = placeOnHand(
            pose,
            ring: widget.type == TryOnType.ring,
            map: (x, y) => Offset(x, y),
          ) !=
              null;
          if (hasHand) {
            found = true;
            // Lambo gap pachhi juna pose kadhi nakho
            if (!_handVisible) _poseHist.clear();
            _poseHist.add(pose);
            if (_poseHist.length > _poseHistLen) _poseHist.removeAt(0);
            _imageSize =
                Size(image.width.toDouble(), image.height.toDouble());
            _lastHandAt = DateTime.now();
          }
        }
      }

      if (!found) {
        _framesSinceFace++;

        // Haju disha lock nathi ane kai malyu nathi → biji disha try
        if (!_rotLocked && _framesSinceFace >= 12) {
          _framesSinceFace = 0;
          _rotIndex = (_rotIndex + 1) % _rotCandidates.length;
        }
      } else {
        _framesSinceFace = 0;
        _rotLocked = true;
        _detected++;
      }

      setState(() {});
    } catch (e) {
      debugPrint("FACE FRAME ERROR => $e");
      _lastError = e.toString();
      if (mounted) setState(() {});
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final CameraDescription? cam = _camera;
    if (cam == null) return null;

    final int rotDeg = _rotCandidates[_rotIndex % _rotCandidates.length];
    final InputImageRotation? rotation =
    InputImageRotationValue.fromRawValue(rotDeg);
    if (rotation == null) return null;
    _rotation = rotation;

    final Size size = Size(image.width.toDouble(), image.height.toDouble());

    _diag = "fmt ${image.format.raw} | planes ${image.planes.length} | "
        "${image.width}x${image.height} | p0 ${image.planes.first.bytes.length}"
        "/${image.planes.first.bytesPerRow} | rot $rotDeg${_rotLocked ? " (locked)" : ""}";

    // iOS → BGRA (ek j plane)
    if (Platform.isIOS) {
      if (image.planes.isEmpty) return null;
      final Plane plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // ANDROID → hamesha NV21 banavo
    final int fullNv21 = image.width * image.height * 3 ~/ 2;
    final Plane p0 = image.planes.first;

    final Uint8List nv21 = image.planes.length == 1 ||
        (p0.bytesPerRow == image.width && p0.bytes.length >= fullNv21)
        ? _packSinglePlane(image)
        : _yuv420ToNv21(image);

    if (!_loggedFormat) {
      _loggedFormat = true;
      debugPrint(
        "LIVE CAMERA FORMAT => raw=${image.format.raw} "
            "planes=${image.planes.length} size=${image.width}x${image.height} "
            "sensor=${cam.sensorOrientation}",
      );
    }

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  /// NV21 ek plane — row ma padding hoy to kadhi nakho
  Uint8List _packSinglePlane(CameraImage image) {
    final Plane p = image.planes.first;
    final int w = image.width;
    final int h = image.height;
    final int expected = w * h + (w * h) ~/ 2;

    if (p.bytesPerRow == w && p.bytes.length >= expected) {
      return p.bytes.length == expected
          ? p.bytes
          : Uint8List.sublistView(p.bytes, 0, expected);
    }

    final Uint8List out = Uint8List(expected);
    int o = 0;
    final int rows = h + h ~/ 2;
    for (int r = 0; r < rows; r++) {
      final int start = r * p.bytesPerRow;
      if (start + w > p.bytes.length) break;
      out.setRange(o, o + w, p.bytes, start);
      o += w;
    }
    return out;
  }

  /// YUV_420_888 (3 plane) → NV21 (Y + VU interleaved)
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int w = image.width;
    final int h = image.height;
    final int uvW = w ~/ 2;
    final int uvH = h ~/ 2;

    final Uint8List out = Uint8List(w * h + uvW * uvH * 2);

    final Plane y = image.planes[0];
    int o = 0;
    for (int r = 0; r < h; r++) {
      final int start = r * y.bytesPerRow;
      if (start + w > y.bytes.length) break;
      out.setRange(o, o + w, y.bytes, start);
      o += w;
    }
    o = w * h;

    final Plane u = image.planes[1];
    final Plane v = image.planes[2];
    final int uRow = u.bytesPerRow, uPix = u.bytesPerPixel ?? 1;
    final int vRow = v.bytesPerRow, vPix = v.bytesPerPixel ?? 1;

    for (int r = 0; r < uvH; r++) {
      for (int c = 0; c < uvW; c++) {
        final int vi = r * vRow + c * vPix;
        final int ui = r * uRow + c * uPix;
        out[o++] = vi < v.bytes.length ? v.bytes[vi] : 128;
        out[o++] = ui < u.bytes.length ? u.bytes[ui] : 128;
      }
    }

    return out;
  }

  /// =========================================================
  /// CAMERA COORDINATES → SCREEN
  /// =========================================================

  double _tx(double x, Size canvas) {
    final Size img = _imageSize!;
    final bool front = _camera?.lensDirection == CameraLensDirection.front;

    switch (_rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvas.width / (Platform.isIOS ? img.width : img.height);
      case InputImageRotation.rotation270deg:
        return canvas.width -
            x * canvas.width / (Platform.isIOS ? img.width : img.height);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        final double v = x * canvas.width / img.width;
        return front ? canvas.width - v : v;
    }
  }

  double _ty(double y, Size canvas) {
    final Size img = _imageSize!;

    switch (_rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvas.height / (Platform.isIOS ? img.height : img.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * canvas.height / img.height;
    }
  }

  Offset _pt(math.Point<int> p, Size canvas) =>
      Offset(_tx(p.x.toDouble(), canvas), _ty(p.y.toDouble(), canvas));

  Offset _lerpO(Offset? a, Offset b) =>
      a == null ? b : Offset.lerp(a, b, _smooth)!;

  double _lerpD(double a, double b) => a == 0 ? b : a + (b - a) * _smooth;

  /// =========================================================
  /// FACE → JEWELLERY POSITION (screen coordinates)
  /// Set hoy to necklace ane earrings banne saathe gothvay
  /// =========================================================

  void _updateTargets(Size canvas) {
    final Face? face = _face;
    if (face == null || _imageSize == null) return;

    final Rect r = face.boundingBox;

    final double x1 = _tx(r.left, canvas), x2 = _tx(r.right, canvas);
    final double y1 = _ty(r.top, canvas), y2 = _ty(r.bottom, canvas);
    final Rect box = Rect.fromLTRB(
      math.min(x1, x2),
      math.min(y1, y2),
      math.max(x1, x2),
      math.max(y1, y2),
    );

    // Mathu nami gayu hoy to → aankh ni line no angle
    final math.Point<int>? le =
        face.landmarks[FaceLandmarkType.leftEye]?.position;
    final math.Point<int>? re =
        face.landmarks[FaceLandmarkType.rightEye]?.position;

    double angle = 0;
    if (le != null && re != null) {
      final Offset a = _pt(le, canvas), b = _pt(re, canvas);
      angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      if (angle > math.pi / 2) angle -= math.pi;
      if (angle < -math.pi / 2) angle += math.pi;
    }
    _sAngle = _sAngle + (angle - _sAngle) * _smooth;

    // ---------------- NECKLACE (moto piece) ----------------
    final TryOnPiece? neck = _neck;
    if (neck != null) {
      double chinY = box.bottom;
      double chinX = box.center.dx;
      final List<math.Point<int>>? pts =
          face.contours[FaceContourType.face]?.points;
      if (pts != null && pts.isNotEmpty) {
        Offset low = _pt(pts.first, canvas);
        for (final p in pts) {
          final Offset o = _pt(p, canvas);
          if (o.dy > low.dy) low = o;
        }
        chinY = low.dy;
        chinX = low.dx;
      }

      final double w = box.width * 1.3 * _sizeAdj;
      final double h = w * neck.aspect;

      _sNeckW = _lerpD(_sNeckW, w);
      _sNeck = _lerpO(
        _sNeck,
        Offset(
            chinX, chinY - box.height * 0.06 + box.height * _dropAdj + h / 2),
      );

      _tooClose = _sNeck!.dy + h / 2 > canvas.height * 1.02;
    } else {
      _tooClose = false;
    }

    // ---------------- EARRINGS (nana piece) ----------------
    if (_hasEars) {
      final TryOnPiece pa = (_earL ?? _earR)!;
      final TryOnPiece pb = (_earR ?? _earL)!;
      final double w = box.width * 0.18 * _sizeAdj;

      // Lob ni unchai = naak na niche thi thodu niche
      final math.Point<int>? nb =
          face.landmarks[FaceLandmarkType.noseBase]?.position;
      final double lobeY = earLobeY(box, nb == null ? null : _pt(nb, canvas).dy);

      // 1) Chehra ni kinari parthi lob
      final List<math.Point<int>>? facePts =
          face.contours[FaceContourType.face]?.points;
      List<Offset>? lobes = facePts == null
          ? null
          : findEarLobes(
          facePts.map((p) => _pt(p, canvas)).toList(), box, lobeY);

      // 2) Contour na male to ear landmark (x) + lobeY
      if (lobes == null) {
        Offset lm(FaceLandmarkType t, double fallbackX) {
          final math.Point<int>? p = face.landmarks[t]?.position;
          return Offset(p != null ? _pt(p, canvas).dx : fallbackX, lobeY);
        }

        final Offset a = lm(FaceLandmarkType.leftEar, box.left);
        final Offset b = lm(FaceLandmarkType.rightEar, box.right);
        lobes = a.dx <= b.dx ? [a, b] : [b, a];
      }

      // Earring no hook lob par → aakhu earring tya thi niche latke
      final double drop = box.height * _dropAdj;
      Offset hang(Offset lobe, double aspect) {
        final double h = w * aspect;
        return Offset(lobe.dx, lobe.dy + drop + h / 2 - h * 0.04);
      }

      _sEarW = _lerpD(_sEarW, w);
      _sEarA = _lerpO(_sEarA, hang(lobes[0], pa.aspect));
      _sEarB = _lerpO(_sEarB, hang(lobes[1], pb.aspect));
    }
  }

  bool get _faceVisible =>
      DateTime.now().difference(_lastFaceAt).inMilliseconds < 600;

  /// =========================================================
  /// CAPTURE → photo + live position TryOnScreen ma pachhi
  /// =========================================================

  List<LiveTryOnLayer> _snapshotLayers() {
    final Size? cv = _canvasSize;
    if (cv == null || cv.isEmpty) return [];

    LiveTryOnLayer norm(TryOnSlot slot, Offset c, double w, double rot) =>
        LiveTryOnLayer(
          slot: slot,
          center: Offset(c.dx / cv.width, c.dy / cv.height),
          width: w / cv.width,
          rotation: rot,
        );

    // Bangle / ring → user e gothvelu j
    if (!_isFace) {
      if (_hand == null || _hCenter == null || _hWidth <= 0) return [];
      return [norm(TryOnSlot.hand, _hCenter!, _hWidth, _hRot)];
    }

    if (!_faceVisible) return [];

    final List<LiveTryOnLayer> out = [];

    if (_neck != null && _sNeck != null && _sNeckW > 0) {
      out.add(norm(TryOnSlot.neck, _sNeck!, _sNeckW, _sAngle));
    }

    if (_hasEars && _sEarA != null && _sEarB != null && _sEarW > 0) {
      // Earrings hamesha seedha niche latke → rotation 0
      out.add(norm(TryOnSlot.earLeft, _sEarA!, _sEarW, 0));
      out.add(norm(TryOnSlot.earRight, _sEarB!, _sEarW, 0));
    }

    return out;
  }

  Future<void> _capture() async {
    final CameraController? c = _controller;
    if (c == null || _capturing) return;

    // Stream bandh thay e pehla j position lai lo
    final List<LiveTryOnLayer> layers = _snapshotLayers();
    final Size previewSize = _canvasSize ?? Size.zero;
    final bool mirrored = _lens == CameraLensDirection.front;

    setState(() => _capturing = true);

    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      final XFile shot = await c.takePicture();
      if (!mounted) return;

      Navigator.pop(
        context,
        LiveTryOnResult(
          path: shot.path,
          previewSize: previewSize,
          layers: layers,
          mirrored: mirrored,
        ),
      );
    } catch (e) {
      debugPrint("CAPTURE ERROR => $e");
      if (mounted) {
        AppMessage.error(context, "Unable to take photo");
        setState(() => _capturing = false);
        try {
          await c.startImageStream(_onFrame);
        } catch (_) {}
      }
    }
  }

  /// =========================================================
  /// BUILD
  /// =========================================================

  String get _hint {
    switch (widget.type) {
      case TryOnType.set:
        return "Keep your face, ears and neck in view";
      case TryOnType.necklace:
        return "Keep your neck and chest in view";
      case TryOnType.earrings:
        return "Keep both ears visible";
      case TryOnType.bangle:
        return "Raise your hand near your chest. The bangle follows your wrist. Drag to adjust.";
      case TryOnType.ring:
        return "Raise your hand near your chest. The ring follows your finger. Drag to adjust.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? c = _controller;
    final bool ready = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            /// ================= TOP BAR =================
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  _roundBtn(Icons.close_rounded, () => Navigator.pop(context)),
                  const Spacer(),
                  if (ready && _isFace)
                    GestureDetector(
                      onLongPress: () => setState(() => _showDiag = !_showDiag),
                      child: AnimatedOpacity(
                        opacity: _faceVisible ? 0 : 1,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Finding your face...",
                            style:
                            TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                  /// ✋ Auto / Manual (bangle / bracelet / ring)
                  if (ready && !_isFace)
                    GestureDetector(
                      onTap: () => setState(() => _handAuto = !_handAuto),
                      onLongPress: () => setState(() => _showDiag = !_showDiag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _handAuto && _handVisible
                              ? AppColors.primaryDark.withOpacity(0.85)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _handAuto
                                  ? Icons.back_hand_outlined
                                  : Icons.pan_tool_alt_outlined,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !_handAuto
                                  ? "Manual · tap for auto"
                                  : _handVisible
                                  ? "Following your hand"
                                  : "Finding your hand...",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!_isFace)
                    _roundBtn(Icons.cameraswitch_rounded, _switchCamera)
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),

            /// ================= CAMERA =================
            Expanded(
              child: Stack(
                children: [
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else if (!ready)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    Center(child: _previewWithJewellery(c)),

                  /// Pendant screen thi bahar jay to sujhav
                  if (ready && _faceVisible && _tooClose)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Hold the phone a little farther away",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  /// 🔧 DIAGNOSTICS
                  if (_showDiag)
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "frames $_frames | faces $_detected\n$_diag"
                              "${_lastError.isEmpty ? "" : "\nerr: $_lastError"}",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10.5,
                            fontFamily: "monospace",
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            /// ================= BOTTOM CONTROLS =================
            if (ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _adjustPanel(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _hint,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        _captureButton(),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      onTap: _capture,
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.secondaryDark],
            ),
          ),
          child: _capturing
              ? const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
              : const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  /// Preview tena sacha ratio ma + upar jewellery
  Widget _previewWithJewellery(CameraController c) {
    final double ratio = 1 / c.value.aspectRatio;

    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (context, box) {
          final Size canvas = Size(box.maxWidth, box.maxHeight);
          _canvasSize = canvas;

          // ✋ Bangle / ring → hamesha dekhay, aangli thi khasavo
          if (!_isFace) {
            final TryOnPiece? hand = _hand;
            _ensureHandLayer(canvas);
            _updateHand(canvas);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onHandScaleStart,
              onScaleUpdate: _onHandScaleUpdate,
              child: Stack(
                children: [
                  Positioned.fill(child: CameraPreview(c)),
                  if (hand != null) _piece(_hCenter!, _hWidth, _hRot, hand),
                ],
              ),
            );
          }

          if (_faceVisible) _updateTargets(canvas);

          return Stack(
            children: [
              Positioned.fill(child: CameraPreview(c)),
              if (_faceVisible) ..._jewelleryLayers(),
            ],
          );
        },
      ),
    );
  }

  /// Ek piece (shadow sathe) — earrings, bangle, ring
  Widget _piece(Offset center, double w, double angle, TryOnPiece p) {
    final double h = w * p.aspect;
    return Positioned(
      left: center.dx - w / 2,
      top: center.dy - h / 2,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              /// Chamdi / kapda par halki shadow
              Transform.translate(
                offset: Offset(0, w * 0.012 + 1.5),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.38),
                      BlendMode.srcIn,
                    ),
                    child: Image.memory(
                      p.png,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              Image.memory(
                p.png,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Necklace (gala) + earrings (kaan) — set hoy to banne saathe
  List<Widget> _jewelleryLayers() {
    final List<Widget> out = [];

    // ---------------- NECKLACE ----------------
    final TryOnPiece? neck = _neck;
    if (neck != null && _sNeck != null && _sNeckW > 0) {
      final ui.Image? im = _neckImage;
      if (im == null) {
        out.add(_piece(_sNeck!, _sNeckW, _sAngle, neck));
      } else {
        final double w = _sNeckW;
        final double h = w * neck.aspect;
        out.add(Positioned(
          left: _sNeck!.dx - w / 2,
          top: _sNeck!.dy - h / 2,
          width: w,
          height: h,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: _sAngle,
              child: CustomPaint(painter: WornNecklacePainter(im)),
            ),
          ),
        ));
      }
    }

    // ---------------- EARRINGS ----------------
    if (_hasEars && _sEarA != null && _sEarB != null && _sEarW > 0) {
      // Earrings seedha niche latke (gravity) → mathu name to pan fare nahi
      out.add(_piece(_sEarA!, _sEarW, 0, (_earL ?? _earR)!));
      out.add(_piece(_sEarB!, _sEarW, 0, (_earR ?? _earL)!));
    }

    return out;
  }

  /// Size + Upar/Niche — live sudharo
  Widget _adjustPanel() {
    Widget row(String label, double value, double min, double max,
        ValueChanged<double> onChanged) {
      return Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (v) => setState(() => onChanged(v)),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row("Size", _sizeAdj, 0.7, 1.6, (v) => _sizeAdj = v),
          // Upar / niche fakt chehra mate (haath ma aangli thi khasavo)
          if (_isFace) ...[
            const SizedBox(height: 6),
            row("Position", _dropAdj, -0.15, 0.45, (v) => _dropAdj = v),
          ],
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
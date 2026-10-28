import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';

/// ================================================================
/// 🖌️ BACKGROUND ERASE EDITOR
///
/// Background remove pachi je bhag baki rahi gayo hoy e brush
/// thi kadho, ane bhool thi jewellery kapai gai hoy to "Restore"
/// brush thi pachhi lavo.
///
/// - 1 aangli  = brush
/// - 2 aangli  = zoom / move
/// - Undo / Redo (chhella 20 stroke)
/// - Checker / White / Black background — leftover tarat dekhay
/// - Restore mode ma original halko dekhay
///
/// 🔥 FIX:
///  - Ghana stroke pachi pan smooth: juna stroke image ma "bake"
///    thai jay (darek frame ma 100 stroke farithi dorvana nahi)
///  - Bake pachi pan Save barabar thay (pehla strokes khali hoy
///    to change save j nahota thata)
///  - Full HD image par pan aakhi resolution ma PNG save (lossless)
///
/// Save karo etle edited transparent PNG (Uint8List) return thay.
/// ================================================================

enum _BrushMode { erase, restore }

enum _PreviewBg { checker, white, black }

class _Stroke {
  _Stroke(this.mode, this.radius);

  final _BrushMode mode;

  /// Image pixel ma radius
  final double radius;

  final List<Offset> points = [];

  Path get path {
    final Path p = Path();
    if (points.isEmpty) return p;

    p.moveTo(points.first.dx, points.first.dy);

    if (points.length == 1) {
      // Ek tap → gol tapku
      p.lineTo(points.first.dx + 0.01, points.first.dy);
    } else {
      for (int i = 1; i < points.length; i++) {
        p.lineTo(points[i].dx, points[i].dy);
      }
    }

    return p;
  }
}

class BgEraseEditorScreen extends StatefulWidget {
  const BgEraseEditorScreen({
    Key? key,
    required this.cutoutFile,
    required this.originalFile,
    this.title = "Edit Background",
  }) : super(key: key);

  /// Background remove thayel transparent PNG (trim pehla ni)
  final File cutoutFile;

  /// Original photo (restore mate)
  final File originalFile;

  final String title;

  @override
  State<BgEraseEditorScreen> createState() => _BgEraseEditorScreenState();
}

class _BgEraseEditorScreenState extends State<BgEraseEditorScreen> {
  /// Aatla thi vadhu stroke thay to juna stroke image ma bake
  static const int _maxLiveStrokes = 20;

  /// Ek vaar ma ketla bake karva
  static const int _bakeChunk = 10;

  ui.Image? _cutout;
  ui.Image? _original;
  bool _loading = true;
  bool _saving = false;
  bool _baking = false;

  /// Koi stroke image ma bake thayo che? (undo na thai shake evo change)
  bool _baked = false;

  final List<_Stroke> _strokes = [];
  final List<_Stroke> _redo = [];
  _Stroke? _current;

  _BrushMode _mode = _BrushMode.erase;
  _PreviewBg _previewBg = _PreviewBg.checker;
  double _brushPx = 26; // screen par brush size

  /// View transform
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  Size _viewSize = Size.zero;

  /// Gesture state
  bool _zooming = false;
  double _startZoom = 1.0;
  Offset _startImagePoint = Offset.zero;
  Offset? _cursor;

  /// Painter ne repaint karva
  final ValueNotifier<int> _tick = ValueNotifier(0);

  bool get _hasChanges => _strokes.isNotEmpty || _baked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick.dispose();
    _cutout?.dispose();
    _original?.dispose();
    super.dispose();
  }

  Future<ui.Image> _decode(File f) async {
    final ui.Codec codec = await ui.instantiateImageCodec(await f.readAsBytes());
    final ui.Image image = (await codec.getNextFrame()).image;
    codec.dispose();
    return image;
  }

  Future<void> _load() async {
    try {
      final ui.Image cut = await _decode(widget.cutoutFile);
      final ui.Image orig = await _decode(widget.originalFile);

      if (!mounted) {
        cut.dispose();
        orig.dispose();
        return;
      }

      setState(() {
        _cutout = cut;
        _original = orig;
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ EDITOR LOAD ERROR => $e");
      if (mounted) {
        AppMessage.error(context, "Unable to open image");
        Navigator.pop(context);
      }
    }
  }

  /// =========================================================
  /// VIEW MATH (screen ⇄ image)
  /// =========================================================

  double _fitScale(Size view) {
    final ui.Image image = _cutout!;
    return math.min(view.width / image.width, view.height / image.height) *
        0.92;
  }

  double _scale(Size view) => _fitScale(view) * _zoom;

  Offset _origin(Size view, {double? zoom, Offset? pan}) {
    final ui.Image image = _cutout!;
    final double s = _fitScale(view) * (zoom ?? _zoom);
    return Offset(
      (view.width - image.width * s) / 2,
      (view.height - image.height * s) / 2,
    ) +
        (pan ?? _pan);
  }

  Offset _toImage(Offset local) =>
      (local - _origin(_viewSize)) / _scale(_viewSize);

  /// =========================================================
  /// GESTURES
  /// =========================================================

  void _onScaleStart(ScaleStartDetails d) {
    if (_baking || _saving) return;

    if (d.pointerCount >= 2) {
      _beginZoom(d.localFocalPoint);
      return;
    }

    _zooming = false;

    _current = _Stroke(_mode, _brushPx / _scale(_viewSize))
      ..points.add(_toImage(d.localFocalPoint));

    _cursor = d.localFocalPoint;
    _tick.value++;
  }

  void _beginZoom(Offset focal) {
    // Bijee aangli aavi → chalu stroke radd
    _current = null;
    _cursor = null;
    _zooming = true;
    _startZoom = _zoom;
    _startImagePoint = _toImage(focal);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_baking || _saving) return;

    if (d.pointerCount >= 2 && !_zooming) {
      _beginZoom(d.localFocalPoint);
    }

    if (_zooming) {
      final double newZoom = (_startZoom * d.scale).clamp(1.0, 8.0);

      // Aangli niche no image point tyaj rahe
      final double s = _fitScale(_viewSize) * newZoom;
      final Offset base = _origin(_viewSize, zoom: newZoom, pan: Offset.zero);
      final Offset wantOrigin = d.localFocalPoint - _startImagePoint * s;

      setState(() {
        _zoom = newZoom;
        _pan = wantOrigin - base;
      });
      return;
    }

    final _Stroke? s = _current;
    if (s == null) return;

    s.points.add(_toImage(d.localFocalPoint));
    _cursor = d.localFocalPoint;
    _tick.value++;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final _Stroke? s = _current;

    _current = null;
    _cursor = null;
    _zooming = false;

    if (s != null && s.points.isNotEmpty) {
      setState(() {
        _strokes.add(s);
        _redo.clear(); // navo stroke → redo radd
      });
      _bakeIfNeeded();
    }

    _tick.value++;
  }

  void _undo() {
    if (_strokes.isEmpty || _baking) return;
    setState(() => _redo.add(_strokes.removeLast()));
    _tick.value++;
  }

  void _redoStroke() {
    if (_redo.isEmpty || _baking) return;
    setState(() => _strokes.add(_redo.removeLast()));
    _tick.value++;
  }

  void _resetView() {
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  /// =========================================================
  /// 🔥 BAKE — juna stroke cutout image ma kayam mate
  /// (ghana stroke pachi pan editor dhimo na pade)
  /// =========================================================

  Future<void> _bakeIfNeeded() async {
    if (_baking || _strokes.length <= _maxLiveStrokes) return;

    _baking = true;

    try {
      final ui.Image cut = _cutout!;
      final List<_Stroke> chunk = _strokes.take(_bakeChunk).toList();

      final ui.Image baked = await _renderFull(cut, chunk);

      if (!mounted) {
        baked.dispose();
        return;
      }

      setState(() {
        _cutout = baked;
        _strokes.removeRange(0, chunk.length);
        _baked = true;
      });

      cut.dispose();
      _tick.value++;
    } catch (e) {
      debugPrint("⚠️ EDITOR BAKE ERROR => $e");
    } finally {
      _baking = false;
    }
  }

  /// Cutout + strokes → aakhi resolution ni navi image
  Future<ui.Image> _renderFull(ui.Image cut, List<_Stroke> strokes) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    EditorRender.paintContent(canvas, cut, _original!, strokes);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image out = await picture.toImage(cut.width, cut.height);
    picture.dispose();

    return out;
  }

  /// =========================================================
  /// SAVE — aakhi resolution ma render → PNG (lossless)
  /// =========================================================

  Future<void> _save() async {
    if (_saving || _cutout == null) return;

    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);

    // Chalu bake puru thay tyan sudhi rah juo
    while (_baking) {
      await Future.delayed(const Duration(milliseconds: 30));
    }

    try {
      final ui.Image out = await _renderFull(_cutout!, _strokes);
      final ByteData? data =
      await out.toByteData(format: ui.ImageByteFormat.png);

      out.dispose();

      if (data == null) throw Exception("PNG export failed");

      if (!mounted) return;
      Navigator.pop(context, data.buffer.asUint8List());
    } catch (e) {
      debugPrint("❌ EDITOR SAVE ERROR => $e");
      if (mounted) {
        setState(() => _saving = false);
        AppMessage.error(context, "Unable to save changes");
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Discard changes?"),
        content: const Text("Your brush changes will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Keep editing"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Discard", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return ok == true;
  }

  /// =========================================================
  /// BUILD
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xff1C1C21),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(child: _canvasArea()),
              _toolPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    Widget iconBtn(IconData icon, VoidCallback? onTap, {String? tip}) {
      return IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon),
        color: Colors.white,
        disabledColor: Colors.white24,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      color: const Color(0xff141418),
      child: Row(
        children: [
          iconBtn(Icons.arrow_back_rounded, () async {
            if (await _confirmDiscard() && mounted) Navigator.pop(context);
          }),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          iconBtn(Icons.undo_rounded, _strokes.isEmpty ? null : _undo,
              tip: "Undo"),
          iconBtn(Icons.redo_rounded, _redo.isEmpty ? null : _redoStroke,
              tip: "Redo"),
          const SizedBox(width: 4),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _saving || _loading ? null : _save,
              icon: _saving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check_rounded,
                  size: 18, color: Colors.white),
              label: const Text(
                "Save",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                disabledBackgroundColor: Colors.white24,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvasArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        _viewSize = Size(box.maxWidth, box.maxHeight);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _EditorPainter(
                      repaint: _tick,
                      cutout: _cutout!,
                      original: _original!,
                      strokes: _strokes,
                      current: () => _current,
                      mode: _mode,
                      previewBg: _previewBg,
                      scale: _scale(_viewSize),
                      origin: _origin(_viewSize),
                      cursor: () => _cursor,
                      brushPx: _brushPx,
                    ),
                  ),
                ),
              ),
            ),

            /// Zoom badge + reset
            if (_zoom > 1.01)
              Positioned(
                right: 10,
                top: 10,
                child: GestureDetector(
                  onTap: _resetView,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${_zoom.toStringAsFixed(1)}x",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.zoom_out_map_rounded,
                            size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _toolPanel() {
    Widget modeBtn(_BrushMode m, IconData icon, String label, Color color) {
      final bool sel = _mode == m;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _mode = m);
            _tick.value++;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: sel ? color : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? color : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget bgChip(_PreviewBg bg) {
      final bool sel = _previewBg == bg;

      return GestureDetector(
        onTap: () {
          setState(() => _previewBg = bg);
          _tick.value++;
        },
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg == _PreviewBg.white
                ? Colors.white
                : bg == _PreviewBg.black
                ? Colors.black
                : null,
            border: Border.all(
              color: sel ? AppColors.primaryDark : Colors.white38,
              width: sel ? 2.5 : 1,
            ),
          ),
          child: bg == _PreviewBg.checker
              ? ClipOval(
            child: CustomPaint(painter: _MiniCheckerPainter()),
          )
              : null,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: const BoxDecoration(
        color: Color(0xff141418),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              modeBtn(_BrushMode.erase, Icons.auto_fix_normal_rounded, "Erase",
                  const Color(0xffE53E5A)),
              modeBtn(_BrushMode.restore, Icons.healing_rounded, "Restore",
                  const Color(0xff2FAE60)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 4),
              const Icon(Icons.brush_rounded, size: 16, color: Colors.white70),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                  ),
                  child: Slider(
                    value: _brushPx,
                    min: 6,
                    max: 90,
                    onChanged: (v) => setState(() => _brushPx = v),
                  ),
                ),
              ),

              /// Brush size preview
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Container(
                    width: (_brushPx * 0.45).clamp(4.0, 40.0),
                    height: (_brushPx * 0.45).clamp(4.0, 40.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  "1 finger = brush  •  2 fingers = zoom / move",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
              ),
              bgChip(_PreviewBg.checker),
              bgChip(_PreviewBg.white),
              bgChip(_PreviewBg.black),
            ],
          ),
        ],
      ),
    );
  }
}

/// ================================================================
/// RENDER — preview ane save banne mate ek j code (image pixel ma)
/// ================================================================

class EditorRender {
  EditorRender._();

  static void paintContent(
      Canvas c,
      ui.Image cutout,
      ui.Image original,
      List<_Stroke> strokes, {
        _Stroke? current,
      }) {
    final Rect full = Rect.fromLTWH(
      0,
      0,
      cutout.width.toDouble(),
      cutout.height.toDouble(),
    );

    final Rect origSrc = Rect.fromLTWH(
      0,
      0,
      original.width.toDouble(),
      original.height.toDouble(),
    );

    c.saveLayer(full, Paint());
    c.drawImage(
        cutout, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    void apply(_Stroke s) {
      final Path path = s.path;

      final Paint brush = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.radius * 2
        ..color = Colors.black
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.radius * 0.18);

      if (s.mode == _BrushMode.erase) {
        c.drawPath(path, brush..blendMode = BlendMode.dstOut);
      } else {
        // Restore: stroke ni ander original photo pacho
        final Rect b =
        path.getBounds().inflate(s.radius * 1.5).intersect(full);
        if (b.isEmpty) return;

        c.saveLayer(b, Paint());
        c.drawPath(path, brush);
        c.drawImageRect(
          original,
          origSrc,
          full,
          Paint()
            ..blendMode = BlendMode.srcIn
            ..filterQuality = FilterQuality.high,
        );
        c.restore();
      }
    }

    for (final _Stroke s in strokes) {
      apply(s);
    }
    if (current != null && current.points.isNotEmpty) apply(current);

    c.restore();
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required Listenable repaint,
    required this.cutout,
    required this.original,
    required this.strokes,
    required this.current,
    required this.mode,
    required this.previewBg,
    required this.scale,
    required this.origin,
    required this.cursor,
    required this.brushPx,
  }) : super(repaint: repaint);

  final ui.Image cutout;
  final ui.Image original;
  final List<_Stroke> strokes;
  final _Stroke? Function() current;
  final _BrushMode mode;
  final _PreviewBg previewBg;
  final double scale;
  final Offset origin;
  final Offset? Function() cursor;
  final double brushPx;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect imgRect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      cutout.width * scale,
      cutout.height * scale,
    );

    // 1) Preview background (fakt image na vistar ma)
    final Rect visible = imgRect.intersect(Offset.zero & size);

    if (!visible.isEmpty) {
      if (previewBg == _PreviewBg.checker) {
        canvas.drawRect(visible, Paint()..color = Colors.white);
        const double cell = 12;
        final Paint grey = Paint()..color = const Color(0xffDADAE0);

        final int startX = ((visible.left - imgRect.left) / cell).floor();
        final int startY = ((visible.top - imgRect.top) / cell).floor();
        final int endX = ((visible.right - imgRect.left) / cell).ceil();
        final int endY = ((visible.bottom - imgRect.top) / cell).ceil();

        canvas.save();
        canvas.clipRect(visible);
        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            if ((x + y).isEven) continue;
            canvas.drawRect(
              Rect.fromLTWH(
                imgRect.left + x * cell,
                imgRect.top + y * cell,
                cell,
                cell,
              ),
              grey,
            );
          }
        }
        canvas.restore();
      } else {
        canvas.drawRect(
          visible,
          Paint()
            ..color =
            previewBg == _PreviewBg.white ? Colors.white : Colors.black,
        );
      }
    }

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    // 2) Restore mode → original halko dekhay
    if (mode == _BrushMode.restore) {
      canvas.drawImageRect(
        original,
        Rect.fromLTWH(
            0, 0, original.width.toDouble(), original.height.toDouble()),
        Rect.fromLTWH(0, 0, cutout.width.toDouble(), cutout.height.toDouble()),
        Paint()..color = Colors.white.withOpacity(0.28),
      );
    }

    // 3) Edited jewellery
    EditorRender.paintContent(
      canvas,
      cutout,
      original,
      strokes,
      current: current(),
    );

    canvas.restore();

    // 4) Brush cursor
    final Offset? c = cursor();
    if (c != null) {
      final double r = brushPx;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = mode == _BrushMode.erase
              ? const Color(0xffE53E5A)
              : const Color(0xff2FAE60),
      );
    }
  }

  @override
  bool shouldRepaint(_EditorPainter old) => true;
}

class _MiniCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    const double cell = 6;
    final Paint grey = Paint()..color = const Color(0xffC8C8CE);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        if (((x / cell).floor() + (y / cell).floor()).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), grey);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MiniCheckerPainter old) => false;
}

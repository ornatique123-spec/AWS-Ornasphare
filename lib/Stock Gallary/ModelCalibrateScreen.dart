import 'dart:io';

import 'package:flutter/material.dart';

import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import 'BatchModelTemplates.dart';

/// ================================================================
/// 📍 MODEL CALIBRATE — real model photo par points set karo
///
/// 1) Gala (necklace kya bese)  2) Dabo kaan  3) Jamno kaan
/// Tap karo etle point muki ne aagal na step par jay.
/// Mohu fervel hoy ane ek kaan na dekhay to "Not visible".
/// Save karo etle ModelTemplate return thay (screen e save kare).
///
/// 🔥 FIX:
///  - Page scroll karta bhool thi point muki jato hato → have
///    aangli UPADO tyare j point mukay (onTapUp)
///  - Aangli DABAVI ne khencho → point khasay + 🔍 magnifier
///    (aangli niche shu che e moto dekhay → kaan ni bunt ekdam sachi)
///  - Photo preview sharp (1400px), share jevo j 4:5 crop
/// ================================================================

enum _Step { neck, leftEar, rightEar }

class ModelCalibrateScreen extends StatefulWidget {
  const ModelCalibrateScreen({
    Key? key,
    required this.photoPath,
    this.existing,
  }) : super(key: key);

  final String photoPath;
  final ModelTemplate? existing;

  @override
  State<ModelCalibrateScreen> createState() => _ModelCalibrateScreenState();
}

class _ModelCalibrateScreenState extends State<ModelCalibrateScreen> {
  static const Color _gold = Color(0xffC9A227);

  /// 🔍 Magnifier
  static const double _loupeSize = 104;
  static const double _loupeGap = 86;

  _Step _step = _Step.neck;

  Offset? _neck;
  Offset? _leftEar;
  Offset? _rightEar;
  bool _leftVisible = true;
  bool _rightVisible = true;

  double _neckWidth = 0.38;
  double _earHeight = 0.11;

  String _style = ModelStyle.traditional;
  final TextEditingController _nameController =
  TextEditingController(text: "My Model");

  /// Aangli khenchati hoy tyare (magnifier mate)
  Offset? _drag;

  @override
  void initState() {
    super.initState();

    final ModelTemplate? m = widget.existing;
    if (m != null) {
      _neck = Offset(m.neckCenterX, m.neckTop);
      _leftEar = m.showLeftEar ? Offset(m.leftEarX, m.earY) : null;
      _rightEar = m.showRightEar ? Offset(m.rightEarX, m.rEarY) : null;
      _leftVisible = m.showLeftEar;
      _rightVisible = m.showRightEar;
      _neckWidth = m.neckWidth;
      _earHeight = m.earHeight;
      _style = m.style;
      _nameController.text = m.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _hint {
    switch (_step) {
      case _Step.neck:
        return "Tap the centre of the neck, where the necklace should start "
            "(just above the collar bones). Press & drag to fine-tune.";
      case _Step.leftEar:
        return "Tap the ear lobe on the LEFT side of the photo. "
            "Press & drag to fine-tune.";
      case _Step.rightEar:
        return "Tap the ear lobe on the RIGHT side of the photo. "
            "Press & drag to fine-tune.";
    }
  }

  /// =========================================================
  /// POINT SET
  /// =========================================================

  Offset _frac(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  /// Chalu step no point muko (advance = aagal na step par jao)
  void _setPoint(Offset local, Size size, {required bool advance}) {
    final Offset f = _frac(local, size);

    setState(() {
      switch (_step) {
        case _Step.neck:
          _neck = f;
          if (advance) _step = _Step.leftEar;
          break;
        case _Step.leftEar:
          _leftEar = f;
          _leftVisible = true;
          if (advance) _step = _Step.rightEar;
          break;
        case _Step.rightEar:
          _rightEar = f;
          _rightVisible = true;
          break;
      }
    });
  }

  void _advance() {
    setState(() {
      if (_step == _Step.neck) {
        _step = _Step.leftEar;
      } else if (_step == _Step.leftEar) {
        _step = _Step.rightEar;
      }
    });
  }

  void _markNotVisible() {
    setState(() {
      if (_step == _Step.leftEar) {
        _leftVisible = false;
        _leftEar = null;
        _step = _Step.rightEar;
      } else if (_step == _Step.rightEar) {
        _rightVisible = false;
        _rightEar = null;
      }
    });

    if (!_leftVisible && !_rightVisible) {
      AppMessage.error(context, "At least one ear must be visible");
    }
  }

  bool get _ready =>
      _neck != null &&
          (_leftEar != null || !_leftVisible) &&
          (_rightEar != null || !_rightVisible) &&
          (_leftVisible || _rightVisible);

  void _save() {
    if (!_ready) {
      AppMessage.error(context, "Please set the neck and at least one ear");
      return;
    }

    // Na dekhato kaan → bija kaan parthi andaj (gala ni saame baju)
    final Offset l = _leftEar ??
        Offset(_neck!.dx - (_rightEar!.dx - _neck!.dx), _rightEar!.dy);
    final Offset r = _rightEar ??
        Offset(_neck!.dx + (_neck!.dx - _leftEar!.dx), _leftEar!.dy);

    final ModelTemplate m = ModelTemplate(
      id: widget.existing?.id ??
          "custom_${DateTime.now().millisecondsSinceEpoch}",
      name: _nameController.text.trim().isEmpty
          ? "My Model"
          : _nameController.text.trim(),
      style: _style,
      filePath: widget.photoPath,
      neckTop: _neck!.dy,
      neckCenterX: _neck!.dx,
      neckWidth: _neckWidth,
      maxBottom: 0.97,
      earY: l.dy.clamp(0.0, 1.0),
      leftEarX: l.dx.clamp(0.0, 1.0),
      rightEarY: r.dy.clamp(0.0, 1.0),
      rightEarX: r.dx.clamp(0.0, 1.0),
      showLeftEar: _leftVisible,
      showRightEar: _rightVisible,
      earHeight: _earHeight,
    );

    Navigator.pop(context, m);
  }

  /// =========================================================
  /// BUILD
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                /// Khenchati vakhte page scroll na thay
                physics: _drag != null
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepChips(),
                    const SizedBox(height: 8),
                    Text(
                      _hint,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_step != _Step.neck)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _markNotVisible,
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 16),
                          label: const Text("This ear is not visible"),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _photo(),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        "Only this 4:5 area is used in the final image",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sliders(),
                    const SizedBox(height: 10),
                    _details(),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
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
              "Set Model Points",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepChips() {
    Widget chip(String label, _Step s, bool done) {
      final bool sel = _step == s;

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _step = s),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 14,
                  color: sel
                      ? Colors.white
                      : (done ? Colors.green : Colors.grey),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : AppColors.primaryDark,
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

    return Row(
      children: [
        chip("1. Neck", _Step.neck, _neck != null),
        chip("2. Left ear", _Step.leftEar, _leftEar != null || !_leftVisible),
        chip("3. Right ear", _Step.rightEar,
            _rightEar != null || !_rightVisible),
      ],
    );
  }

  /// 4:5 photo — final share image jevu j crop
  Widget _photo() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 0.8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (context, box) {
                final Size size = Size(box.maxWidth, box.maxHeight);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  /// Aangli UPADO tyare j point (scroll vakhte bhool nahi)
                  onTapUp: (d) =>
                      _setPoint(d.localPosition, size, advance: true),

                  /// Dabavi ne khencho → point khasay + magnifier
                  onPanStart: (d) {
                    setState(() => _drag = d.localPosition);
                    _setPoint(d.localPosition, size, advance: false);
                  },
                  onPanUpdate: (d) {
                    setState(() => _drag = d.localPosition);
                    _setPoint(d.localPosition, size, advance: false);
                  },
                  onPanEnd: (_) {
                    setState(() => _drag = null);
                    _advance();
                  },
                  onPanCancel: () => setState(() => _drag = null),

                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(widget.photoPath),
                        fit: BoxFit.cover,
                        cacheWidth: 1400,
                        filterQuality: FilterQuality.high,
                      ),
                      CustomPaint(
                        painter: _GuidePainter(
                          neck: _neck,
                          leftEar: _leftVisible ? _leftEar : null,
                          rightEar: _rightVisible ? _rightEar : null,
                          neckWidth: _neckWidth,
                          earHeight: _earHeight,
                          gold: _gold,
                          active: _step,
                        ),
                      ),
                      if (_drag != null) _loupe(_drag!),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 🔍 Aangli niche no bhag moto dekhay (aangli upar, athva
  /// upar jagya na hoy to niche)
  Widget _loupe(Offset p) {
    final double centerY =
    p.dy < _loupeSize + _loupeGap ? p.dy + _loupeGap : p.dy - _loupeGap;

    return Positioned(
      left: p.dx - _loupeSize / 2,
      top: centerY - _loupeSize / 2,
      child: IgnorePointer(
        child: RawMagnifier(
          size: const Size(_loupeSize, _loupeSize),
          magnificationScale: 2.4,
          focalPointOffset: Offset(0, p.dy - centerY),
          decoration: const MagnifierDecoration(
            shape: CircleBorder(
              side: BorderSide(color: _gold, width: 2.5),
            ),
            shadows: [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _sliders() {
    Widget row(String label, double v, double min, double max,
        ValueChanged<double> onChanged) {
      return Row(
        children: [
          SizedBox(
            width: 110,
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
              value: v.clamp(min, max),
              min: min,
              max: max,
              activeColor: AppColors.primaryDark,
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          row("Necklace width", _neckWidth, 0.18, 0.70,
                  (v) => setState(() => _neckWidth = v)),
          row("Earring size", _earHeight, 0.05, 0.25,
                  (v) => setState(() => _earHeight = v)),
          Text(
            "Gold guide = default size. Each item can still be fine-tuned later.",
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _details() {
    Widget styleChip(String s) {
      final bool sel = _style == s;

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _style = s),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryDark : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? AppColors.primaryDark : AppColors.border,
              ),
            ),
            child: Text(
              s,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : AppColors.primaryDark,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: "Model name",
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            styleChip(ModelStyle.traditional),
            styleChip(ModelStyle.western),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _ready ? _save : null,
          icon: const Icon(Icons.check_rounded, color: Colors.white),
          label: const Text(
            "Save Model",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            disabledBackgroundColor: Colors.grey.shade400,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo par gold guide: necklace ni U ane earring ni drop
/// (chalu step no point moto dekhay)
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.neck,
    required this.leftEar,
    required this.rightEar,
    required this.neckWidth,
    required this.earHeight,
    required this.gold,
    required this.active,
  });

  final Offset? neck;
  final Offset? leftEar;
  final Offset? rightEar;
  final double neckWidth;
  final double earHeight;
  final Color gold;
  final _Step active;

  @override
  void paint(Canvas canvas, Size s) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = gold.withOpacity(0.9);

    final Paint dot = Paint()..color = gold;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;

    void point(Offset c, bool isActive) {
      final double r = isActive ? 8 : 6;
      canvas.drawCircle(c, r, dot);
      canvas.drawCircle(c, r, ring);
      if (isActive) {
        canvas.drawCircle(
          c,
          r + 6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withOpacity(0.8),
        );
      }
    }

    if (neck != null) {
      final Offset c = Offset(neck!.dx * s.width, neck!.dy * s.height);
      final double w = neckWidth * s.width;

      // Necklace U guide
      final Path u = Path()
        ..moveTo(c.dx - w / 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy + w * 0.75, c.dx + w / 2, c.dy);
      canvas.drawPath(u, line);

      point(c, active == _Step.neck);
    }

    final List<MapEntry<Offset?, _Step>> ears = [
      MapEntry(leftEar, _Step.leftEar),
      MapEntry(rightEar, _Step.rightEar),
    ];

    for (final MapEntry<Offset?, _Step> e in ears) {
      if (e.key == null) continue;

      final Offset p = Offset(e.key!.dx * s.width, e.key!.dy * s.height);
      final double h = earHeight * s.height;

      canvas.drawLine(p, p + Offset(0, h * 0.75), line);
      canvas.drawCircle(p + Offset(0, h * 0.82), h * 0.12, line);

      point(p, active == e.value);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => true;
}

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ================================================================
/// 💍 NECKLACE NE "GALA MA PAHERELO" DEKHADVO
///
/// Aakaar image jevo j rahe — left / right vaalvanu NATHI.
/// Chontadelo (sticker) na lage e mate fakt prakash / padchhayo:
///  1. Upar gala pase padchhayo → chain gala ni pachhad jati lage
///  2. Sauthi upar na tip halka gayab
///  3. Chamdi / kapda par contact shadow
///
/// Vaaleli asar joie to WornNecklaceStyle.curved vapro.
/// Live camera, photo screen ane final save — traney ma aa j.
/// ================================================================

class WornNecklaceStyle {
  /// Upar ni pahodai — niche ni pahodai no ketlo bhaag (1.0 = sapat)
  final double neckRatio;

  /// Image ni unchai no ketlo bhaag sudhi gala ni asar (pachhi sapat)
  final double curveEnd;

  /// Gala gol hovathi upar na chheda ketla dabay (0 = nahi, 1 = vadhu)
  final double wrap;

  /// Upar no ketlo bhaag gala ni pachhad halko gayab (0 = nahi)
  final double fade;

  /// Upar gala pase padchhayo (0 = nahi)
  final double depth;

  /// Chamdi par shadow (0 = nahi)
  final double shadowOpacity;

  /// Default = AAKAAR image jevo j (left / right koi vaalvanu nahi),
  /// pan gala ma paherelo lage:
  ///  - upar gala pase padchhayo (depth)
  ///  - sauthi upar na tip gala ni pachhad halka gayab (fade)
  ///  - chamdi / kapda par contact shadow
  const WornNecklaceStyle({
    this.neckRatio = 1.0,
    this.curveEnd = 0.42,
    this.wrap = 0.0,
    this.fade = 0.08,
    this.depth = 0.35,
    this.shadowOpacity = 0.42,
  });

  /// Gala ni aaspas vaaleli asar (joie to j vaparvi)
  static const WornNecklaceStyle curved = WornNecklaceStyle(
    neckRatio: 0.64,
    wrap: 0.7,
    fade: 0.06,
    depth: 0.32,
    shadowOpacity: 0.38,
  );

  /// Bilkul sapat (image jevo j)
  static const WornNecklaceStyle flat = WornNecklaceStyle(
    neckRatio: 1.0,
    wrap: 0.0,
    fade: 0.0,
    depth: 0.0,
    shadowOpacity: 0.3,
  );

  bool get _bends => neckRatio < 0.999 || wrap > 0.001;
}

double _smoothstep(double t) {
  final double x = t.clamp(0.0, 1.0).toDouble();
  return x * x * (3 - 2 * x);
}

/// Gol gala par vaalvu: vachche pahodu, chheda dabaya (foreshortening)
/// x: -0.5..0.5, a: 0..1  →  -0.5..0.5
double _wrapX(double x, double a) {
  if (a < 0.001) return x;
  final double k = math.pi * a;
  return math.sin(x * k) / (2 * math.sin(k / 2));
}

ui.Vertices _buildNeckMesh(
    ui.Image img,
    Rect dst,
    WornNecklaceStyle style,
    ) {
  const int cols = 20;
  const int rows = 30;

  final List<Offset> pos = [];
  final List<Offset> tex = [];
  final List<int> idx = [];

  for (int r = 0; r <= rows; r++) {
    final double v = r / rows;

    // 0 = sauthi upar (gala), 1 = curveEnd ane niche (chhati, sapat)
    final double t =
    v >= style.curveEnd ? 1.0 : _smoothstep(v / style.curveEnd);

    final double s = style.neckRatio + (1 - style.neckRatio) * t;
    final double a = style.wrap * (1 - t);

    for (int c = 0; c <= cols; c++) {
      final double u = c / cols;
      final double x = _wrapX(u - 0.5, a);

      pos.add(Offset(
        dst.center.dx + x * dst.width * s,
        dst.top + v * dst.height,
      ));
      tex.add(Offset(u * img.width, v * img.height));
    }
  }

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final int a = r * (cols + 1) + c;
      final int b = a + 1;
      final int d = a + (cols + 1);
      final int e = d + 1;
      idx.addAll([a, b, d, b, e, d]);
    }
  }

  return ui.Vertices(
    ui.VertexMode.triangles,
    pos,
    textureCoordinates: tex,
    indices: idx,
  );
}

/// [dst] = necklace no aakho bhaag canvas par.
/// Canvas pehle thi rotate kareli hoy to chale.
void paintWornNecklace(
    Canvas canvas,
    ui.Image img,
    Rect dst, {
      WornNecklaceStyle style = const WornNecklaceStyle(),
    }) {
  final Rect src =
  Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

  final ui.Vertices? mesh =
  style._bends ? _buildNeckMesh(img, dst, style) : null;

  final Paint texture = Paint()
    ..filterQuality = FilterQuality.medium
    ..shader = mesh == null
        ? null
        : ImageShader(
      img,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );

  void drawPiece() {
    if (mesh != null) {
      canvas.drawVertices(mesh, BlendMode.srcOver, texture);
    } else {
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }

  final Rect bounds = dst.inflate(dst.width * 0.1);

  // Upar na chheda gala ni pachhad → halka gayab
  void applyFade() {
    if (style.fade <= 0.001) return;
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, dst.top),
          Offset(0, dst.top + dst.height * style.fade),
          [const Color(0x00000000), const Color(0xFF000000)],
        ),
    );
  }

  // Gala pase padchhayo — fakt necklace upar j (srcATop)
  void applyDepth() {
    if (style.depth <= 0.001) return;
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.linear(
          Offset(0, dst.top),
          Offset(0, dst.top + dst.height * style.curveEnd * 0.8),
          [
            Colors.black.withOpacity(style.depth),
            Colors.black.withOpacity(0),
          ],
        ),
    );
  }

  // ---------------- CONTACT SHADOW (chamdi / kapda par) ----------------
  if (style.shadowOpacity > 0) {
    final double off = dst.width * 0.014 + 1.5;
    final double blur = math.max(2.0, dst.width * 0.006);

    canvas.saveLayer(
      bounds.shift(Offset(0, off)),
      Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
        ..colorFilter = ColorFilter.mode(
          Colors.black.withOpacity(style.shadowOpacity),
          BlendMode.srcIn,
        ),
    );
    canvas.translate(0, off);
    drawPiece();
    canvas.translate(0, -off);
    applyFade();
    canvas.restore();
  }

  // ---------------- NECKLACE ----------------
  canvas.saveLayer(bounds, Paint());
  drawPiece();
  applyDepth();
  applyFade();
  canvas.restore();
}

/// Widget mate — aapela size ma aakho necklace (rotation bahar thi)
class WornNecklacePainter extends CustomPainter {
  final ui.Image image;
  final WornNecklaceStyle style;

  WornNecklacePainter(this.image, {this.style = const WornNecklaceStyle()});

  @override
  void paint(Canvas canvas, Size size) {
    paintWornNecklace(canvas, image, Offset.zero & size, style: style);
  }

  @override
  bool shouldRepaint(covariant WornNecklacePainter old) =>
      old.image != image || old.style != style;
}

/// PNG bytes → ui.Image
Future<ui.Image> decodeUiImage(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

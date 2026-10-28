import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// ================================================================
/// RGBA → JPG (TOP-LEVEL — background isolate ma chale)
///
/// - "q"      → JPG quality (default 95)
/// - "sharpH" → upar thi aatli height sudhi halku sharpen
///              (fakt image bhaag — caption text par nahi)
/// - "amount" → sharpen ketlu (0 = bandh, 0.35 = natural crisp)
/// ================================================================

Uint8List encodeRgbaToJpgIsolate(Map<String, dynamic> a) {
  final int w = a["w"] as int;
  final int h = a["h"] as int;
  final int q = (a["q"] as int?) ?? 95;
  final int sharpH = (a["sharpH"] as int?) ?? 0;
  final double amount = ((a["amount"] as num?) ?? 0).toDouble();

  final Uint8List px = Uint8List.fromList(a["rgba"] as Uint8List);

  /// 🔥 Halku unsharp sharpen (3x3) — sonu / nakshi / stone crisp
  if (amount > 0 && sharpH > 2 && w > 2) {
    final int rows = sharpH > h ? h : sharpH;
    final Uint8List src = Uint8List.fromList(px.sublist(0, w * rows * 4));

    for (int y = 1; y < rows - 1; y++) {
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

  return Uint8List.fromList(img.encodeJpg(image, quality: q));
}

/// ================================================================
/// 💎 JEWELLERY CAPTION COMPOSER — HQ
///
/// StockGalleryScreen ma je caption design che e j design ahiya.
///
/// 🔥 HQ sudhara (juna call pan same chale — API same che):
///  - Default maxWidth 900 → 1600
///  - Nani image minWidth (1080) sudhi HQ upscale → text sharp
///  - drawImageRect + FilterQuality.high (pehla plain drawImage)
///  - JPG quality 85 → 95
///  - Image bhaag par halku sharpen (optional)
/// ================================================================

class JewelleryCaptionComposer {
  JewelleryCaptionComposer._();

  /// Default settings (ek j jagya e badlo)
  static const int defaultMaxWidth = 1600;
  static const int defaultMinWidth = 1080;
  static const int defaultQuality = 95;
  static const double defaultSharpen = 0.35;

  /// Moti image ne decode vakhte j nani kari JPG banave.
  /// Nani image hoy to ORIGINAL bytes j pacha (0 loss).
  static Future<Uint8List> downscaleToJpg(
      Uint8List bytes, {
        int maxWidth = defaultMaxWidth,
      }) async {
    final ui.ImmutableBuffer buffer =
    await ui.ImmutableBuffer.fromUint8List(bytes);
    final ui.ImageDescriptor descriptor =
    await ui.ImageDescriptor.encoded(buffer);

    if (descriptor.width <= maxWidth) {
      descriptor.dispose();
      buffer.dispose();
      return bytes;
    }

    final ui.Codec codec =
    await descriptor.instantiateCodec(targetWidth: maxWidth);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    final int w = image.width;
    final int h = image.height;

    final ByteData? raw =
    await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    image.dispose();

    if (raw == null) return bytes;

    return compute(encodeRgbaToJpgIsolate, {
      "w": w,
      "h": h,
      "rgba": raw.buffer.asUint8List(),
      "q": 97,
    });
  }

  /// Image niche premium caption (gallery share jevu j design)
  ///
  /// [maxWidth]  moti image aatli sudhi nani thay
  /// [minWidth]  nani image aatli sudhi HQ upscale (0 = upscale nahi)
  /// [quality]   final JPG quality
  /// [sharpen]   image bhaag par sharpen (0 = bandh)
  static Future<Uint8List> addCaptionBelowImage({
    required Uint8List imageBytes,
    required String name,
    required String code,
    required String grossWt,
    required String netWt,
    String lessWt = "",
    int maxWidth = defaultMaxWidth,
    int minWidth = defaultMinWidth,
    int quality = defaultQuality,
    double sharpen = defaultSharpen,
  }) async {
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

    /// 🔥 Nani image → minWidth sudhi HQ upscale
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();

    final double scale =
    (minWidth > 0 && srcW < minWidth) ? minWidth / srcW : 1.0;

    final double w = (srcW * scale).roundToDouble();
    final double imgHeight = (srcH * scale).roundToDouble();

    const Color captionBg = Colors.white;
    const Color inkColor = Color(0xff1A1A1F);
    const Color labelColor = Color(0xff9A9AA2);
    const Color goldColor = Color(0xffC9A227);
    const Color colDividerColor = Color(0xffECE7DA);

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

    TextPainter buildLabel(String text) {
      return TextPainter(
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
      )..layout(maxWidth: colWidth - 8);
    }

    TextPainter buildValue(String text, {bool highlight = false}) {
      return TextPainter(
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
      )..layout(maxWidth: colWidth - 12);
    }

    final List<TextPainter> labels =
    columns.map((c) => buildLabel(c[0])).toList();

    final List<TextPainter> values = [
      for (int i = 0; i < colCount; i++)
        buildValue(columns[i][1], highlight: hasLess && i == colCount - 1),
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
      Paint()..color = captionBg,
    );

    /// 🔥 HQ draw (upscale hoy to pan smooth)
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

    final double dividerBottom =
        rowTopY + rowLabelHeight + labelValueGap + rowValueHeight;

    final Paint colDividerPaint = Paint()
      ..color = colDividerColor
      ..strokeWidth = (w * 0.0012).clamp(1.0, 2.0);

    for (int i = 1; i < colCount; i++) {
      canvas.drawLine(
        Offset(colWidth * i, rowTopY),
        Offset(colWidth * i, dividerBottom),
        colDividerPaint,
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

    return compute(encodeRgbaToJpgIsolate, {
      "w": outW,
      "h": outH,
      "rgba": raw.buffer.asUint8List(),
      "q": quality,
      "sharpH": imgHeight.toInt(),
      "amount": sharpen,
    });
  }
}
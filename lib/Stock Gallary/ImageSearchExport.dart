import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';

/// ================================================================
/// 📤 IMAGE SEARCH EXPORT
///
/// 📄 PDF  — AI Report jevu (navy + gold header, logo, page no.)
///    1) Upar: tame upload kareli photo + kul match
///    2) EXACT MATCH vala item (photo + detail)
///    3) SIMILAR ITEMS (photo + detail + % match)
///
/// 📲 WhatsApp — dar image ni niche detail (naam, label, wajan,
///    status, % match) image ma j chhapai ne aave (HD JPG)
///    Pehli image = tame upload kareli photo
/// ================================================================

/// Ek item + teno match (exact / %)
class ExportItem {
  final Map<String, dynamic> item;
  final bool exact;
  final double score; // 0..1
  ExportItem(this.item, {required this.exact, required this.score});
}

class ImageSearchExport {
  // ---------- colors (AI report jeva) ----------
  static const _navy = PdfColor.fromInt(0xff0F2A4A);
  static const _gold = PdfColor.fromInt(0xffC9A24A);
  static const _cream = PdfColor.fromInt(0xffFBF9F4);
  static const _line = PdfColor.fromInt(0xffE6E0D2);
  static const _ink = PdfColor.fromInt(0xff1B2433);
  static const _grey = PdfColor.fromInt(0xff6B7487);
  static const _green = PdfColor.fromInt(0xff1E7B3A);
  static const _blue = PdfColor.fromInt(0xff2F4A78);
  static const _red = PdfColor.fromInt(0xffB3261E);

  static String get _site =>
      ApiConstants.baseUrl.replaceFirst(RegExp(r'api/?$'), '');

  // ================================================================
  // HELPERS
  // ================================================================

  static String s(dynamic v, [String f = "-"]) {
    final t = v?.toString().trim() ?? "";
    return t.isEmpty || t == "null" ? f : t;
  }

  static bool inStock(Map m) => !(m["is_sold"]?.toString() == "1" ||
      s(m["stock_status"], "").toLowerCase().contains("out"));

  static String? imageUrl(Map m) {
    for (final k in ["image_url", "image", "thumbnail_url", "photo_url"]) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty && v != "null") return v.trim();
    }
    return null;
  }

  static final Dio _dio = Dio(BaseOptions(
    responseType: ResponseType.bytes,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 40),
  ));

  /// Dar vakhte taajo token (login badlay to juno token na jay)
  static Future<void> _token() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dio.options.headers.remove("Authorization");
      for (final k in ["token", "access_token", "auth_token", "api_token"]) {
        final t = prefs.getString(k);
        if (t != null && t.isNotEmpty) {
          _dio.options.headers["Authorization"] = "Bearer $t";
          return;
        }
      }
    } catch (_) {}
  }

  /// Item ni asli photo (image_url → image_download_url)
  static Future<Uint8List?> download(Map m) async {
    await _token();
    for (final url in [imageUrl(m), m["image_download_url"]?.toString()]) {
      if (url == null || url.isEmpty || url == "null") continue;
      try {
        final res = await _dio.get<List<int>>(url);
        final d = res.data;
        if (d != null && d.length > 64 && d.first != 0x7B) {
          return d is Uint8List ? d : Uint8List.fromList(d);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Native decode → nani (width px) → JPG (PDF nani rahe)
  static Future<Uint8List?> shrinkJpg(Uint8List bytes, int width) async {
    ui.Codec? codec;
    ui.Image? im;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
      im = (await codec.getNextFrame()).image;
      final bd = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) return null;
      return await compute(_rgbaToJpg, {
        "w": im.width,
        "h": im.height,
        "rgba": bd.buffer.asUint8List(),
        "q": 85,
      });
    } catch (_) {
      return null;
    } finally {
      im?.dispose();
      codec?.dispose();
    }
  }

  /// Ek sathe N kaam (progress sathe)
  static Future<List<T?>> _pool<T>(
      int count,
      Future<T?> Function(int i) job, {
        int parallel = 4,
        void Function(int done)? onDone,
      }) async {
    final List<T?> out = List.filled(count, null);
    int next = 0, done = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= count) return;
        try {
          out[i] = await job(i);
        } catch (_) {}
        done++;
        onDone?.call(done);
      }
    }

    await Future.wait(List.generate(parallel, (_) => worker()));
    return out;
  }

  static Future<({String name, String place, pw.MemoryImage? logo})>
  _brand() async {
    String name = 'Ornasphere', place = '', logoUrl = '';
    try {
      final p = await SharedPreferences.getInstance();
      String v(String k) {
        final x = (p.getString(k) ?? '').trim();
        return (x == '-' || x == 'null') ? '' : x;
      }

      if (v('companyName').isNotEmpty) name = v('companyName');
      place = [v('city'), v('state')].where((e) => e.isNotEmpty).join(', ');
      logoUrl = v('companyLogo');
    } catch (_) {}

    pw.MemoryImage? logo;
    if (logoUrl.isNotEmpty) {
      try {
        final u = logoUrl.startsWith('http')
            ? logoUrl
            : '$_site${logoUrl.replaceFirst(RegExp(r'^/'), '')}';
        final res = await _dio.get<List<int>>(u);
        if (res.data != null && res.data!.length > 100) {
          logo = pw.MemoryImage(Uint8List.fromList(res.data!));
        }
      } catch (_) {}
    }
    if (logo == null) {
      try {
        final b = await rootBundle.load('assets/static/logo.png');
        logo = pw.MemoryImage(b.buffer.asUint8List());
      } catch (_) {}
    }
    return (name: name, place: place, logo: logo);
  }

  // ================================================================
  // 📄 PDF
  // ================================================================

  static Future<File> buildPdf({
    required File query,
    required List<ExportItem> exact,
    required List<ExportItem> similar,
    int scanned = 0,
    void Function(int done, int total)? onProgress,
  }) async {
    final brand = await _brand();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final all = [...exact, ...similar];

    // Photo (nani JPG) — 4 ek sathe
    final Uint8List? qBytes = await shrinkJpg(await query.readAsBytes(), 700);
    final photos = await _pool<Uint8List>(all.length, (i) async {
      final raw = await download(all[i].item);
      return raw == null ? null : await shrinkJpg(raw, 500);
    }, onDone: (d) => onProgress?.call(d, all.length));

    final Map<int, pw.MemoryImage?> imgOf = {
      for (int i = 0; i < all.length; i++)
        i: photos[i] == null ? null : pw.MemoryImage(photos[i]!),
    };

    final doc = pw.Document();
    const double gap = 8;
    final double cardW = (PdfPageFormat.a4.width - 44 - gap * 2) / 3;

    pw.Widget sectionBar(String title, int n, PdfColor c) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: c,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(children: [
        pw.Text(title,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.6)),
        pw.Spacer(),
        pw.Text("$n item${n == 1 ? '' : 's'}",
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
      ]),
    );

    pw.Widget card(ExportItem e, pw.MemoryImage? image) {
      final m = e.item;
      final bool st = inStock(m);
      final PdfColor badge = e.exact ? _green : _blue;
      return pw.Container(
        width: cardW,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: e.exact ? _green : _line, width: e.exact ? 1.2 : 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Stack(children: [
            pw.Container(
              height: 140,
              color: _cream,
              alignment: pw.Alignment.center,
              child: image == null
                  ? pw.Text("No photo", style: const pw.TextStyle(color: _grey, fontSize: 8))
                  : pw.Image(image, fit: pw.BoxFit.contain),
            ),
            pw.Positioned(
              left: 5,
              top: 5,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: badge,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  e.exact ? "EXACT" : "${(e.score * 100).round()}% MATCH",
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          ]),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(7, 6, 7, 7),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(s(m["item_name"]),
                  maxLines: 1,
                  style: pw.TextStyle(
                      fontSize: 9.5, color: _ink, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text("Label: ${s(m["label_code"] ?? m["qr_code"])}",
                  style: const pw.TextStyle(fontSize: 8, color: _grey)),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("Gross Wt", style: const pw.TextStyle(fontSize: 6.8, color: _grey)),
                    pw.Text("${s(m["gross_weight"])} g",
                        style: pw.TextStyle(fontSize: 8.5, color: _ink, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("Net Wt", style: const pw.TextStyle(fontSize: 6.8, color: _grey)),
                    pw.Text("${s(m["net_weight"])} g",
                        style: pw.TextStyle(fontSize: 8.5, color: _ink, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: st ? const PdfColor.fromInt(0xffE7F5EC) : const PdfColor.fromInt(0xffFBE9E8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(st ? "In Stock" : "Sold",
                      style: pw.TextStyle(
                          fontSize: 7, color: st ? _green : _red, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Spacer(),
                pw.Text(s(m["company_name"], ""),
                    maxLines: 1, style: const pw.TextStyle(fontSize: 7, color: _grey)),
              ]),
            ]),
          ),
        ]),
      );
    }

    /// 3-3 card ni line (MultiPage page todi shake)
    List<pw.Widget> rows(List<ExportItem> list, int startIndex) {
      final out = <pw.Widget>[];
      for (int i = 0; i < list.length; i += 3) {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: gap),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            for (int j = 0; j < 3; j++) ...[
              if (j > 0) pw.SizedBox(width: gap),
              i + j < list.length
                  ? card(list[i + j], imgOf[startIndex + i + j])
                  : pw.SizedBox(width: cardW),
            ],
          ]),
        ));
      }
      return out;
    }

    /// Tamari photo — exact card jevdo j card (gold border)
    pw.Widget searchedCard() => pw.Container(
      width: cardW,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _gold, width: 1.4),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Stack(children: [
          pw.Container(
            height: 140,
            color: _cream,
            alignment: pw.Alignment.center,
            child: qBytes == null
                ? pw.Text("Photo", style: const pw.TextStyle(color: _grey, fontSize: 8))
                : pw.Image(pw.MemoryImage(qBytes), fit: pw.BoxFit.contain),
          ),
          pw.Positioned(
            left: 5,
            top: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const pw.BoxDecoration(
                color: _navy,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text("SEARCHED",
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
            ),
          ),
        ]),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(7, 6, 7, 7),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text("Searched Photo",
                style: pw.TextStyle(fontSize: 9.5, color: _navy, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("Exact", style: const pw.TextStyle(fontSize: 6.8, color: _grey)),
                  pw.Text("${exact.length}",
                      style: pw.TextStyle(fontSize: 9, color: _green, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("Similar", style: const pw.TextStyle(fontSize: 6.8, color: _grey)),
                  pw.Text("${similar.length}",
                      style: pw.TextStyle(fontSize: 9, color: _blue, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
            ]),
            pw.SizedBox(height: 5),
            pw.Text(made, style: const pw.TextStyle(fontSize: 7, color: _grey)),
          ]),
        ),
      ]),
    );

    /// Line: [cards...] khali jagya SizedBox thi bharo
    pw.Widget line(List<pw.Widget> cards) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: gap),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        for (int j = 0; j < 3; j++) ...[
          if (j > 0) pw.SizedBox(width: gap),
          j < cards.length ? cards[j] : pw.SizedBox(width: cardW),
        ],
      ]),
    );

    // 🔥 Pehli line: Searched photo + 2 exact (ek j row ma)
    final List<pw.Widget> firstRow = [
      searchedCard(),
      for (int i = 0; i < exact.length && i < 2; i++) card(exact[i], imgOf[i]),
    ];
    // Baki na exact (3 thi aagal) — niche 3-3 ma
    final List<ExportItem> moreExact = exact.length > 2 ? exact.sublist(2) : [];

    final content = <pw.Widget>[
      sectionBar(
        exact.isEmpty ? "SEARCHED PHOTO · NO EXACT MATCH" : "SEARCHED PHOTO & EXACT MATCH",
        exact.length,
        exact.isEmpty ? _navy : _green,
      ),
      line(firstRow),
      ...rows(moreExact, 2),

      if (similar.isNotEmpty) ...[
        sectionBar("SIMILAR ITEMS", similar.length, _blue),
        ...rows(similar, exact.length),
      ],
      if (all.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Text("No matching item found.",
              style: const pw.TextStyle(color: _grey, fontSize: 10)),
        ),
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 500,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("${brand.name} · Image Search Report",
              style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          pw.Text("Page ${ctx.pageNumber} / ${ctx.pagesCount}",
              style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        ],
      ),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/Image_Search_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  static pw.Widget _header(({String name, String place, pw.MemoryImage? logo}) brand) =>
      pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(
              color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Row(children: [
            if (brand.logo != null)
              pw.Container(
                width: 38,
                height: 38,
                margin: const pw.EdgeInsets.only(right: 10),
                padding: const pw.EdgeInsets.all(3),
                decoration: const pw.BoxDecoration(
                    color: PdfColors.white, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Image(brand.logo!, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(brand.name,
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                if (brand.place.isNotEmpty)
                  pw.Text(brand.place,
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8.5)),
              ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("IMAGE SEARCH REPORT",
                  style: pw.TextStyle(color: _gold, fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text("Exact & similar items",
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
            ]),
          ]),
        ),
        pw.Container(height: 2, color: _gold, margin: const pw.EdgeInsets.only(top: 3, bottom: 8)),
      ]);

  // ================================================================
  // 📲 WHATSAPP — image + niche detail (image ma j chhapai)
  // ================================================================

  static const double _W = 1080;

  static ui.Paragraph _para(
      String t,
      double size,
      Color c, {
        FontWeight w = FontWeight.w600,
        double maxW = _W - 80,
        int maxLines = 1,
        TextAlign align = TextAlign.left,
        double spacing = 0,
      }) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      maxLines: maxLines,
      ellipsis: "…",
      fontSize: size,
      fontWeight: w,
      textAlign: align,
    ))
      ..pushStyle(ui.TextStyle(
          color: c, fontSize: size, fontWeight: w, letterSpacing: spacing))
      ..addText(t);
    return pb.build()..layout(ui.ParagraphConstraints(width: maxW));
  }

  // WhatsApp card colors
  static const Color _cNavy = Color(0xff0F2A4A);
  static const Color _cGold = Color(0xffC9A24A);
  static const Color _cInk = Color(0xff1B2433);
  static const Color _cGrey = Color(0xff7A8296);
  static const Color _cSoft = Color(0xffF6F8FC);
  static const Color _cBorder = Color(0xffDFE6F2);

  /// ✨ Photo + premium detail panel → HD JPG
  static Future<Uint8List?> renderCard({
    required Uint8List photo,
    required String title,
    required List<(String, String)> rows,
    String? badge,
    Color badgeColor = const Color(0xff16A34A),
    String footer = "",
    Color? statusColor,
    String? statusText,
  }) async {
    ui.Codec? codec;
    ui.Image? src;
    try {
      codec = await ui.instantiateImageCodec(photo, targetWidth: _W.toInt());
      src = (await codec.getNextFrame()).image;

      final double imgH =
      (src.height * _W / src.width).clamp(600.0, 1350.0).toDouble();

      const double pad = 44;
      const double strip = 8;
      const double cellH = 112;
      const double footH = 84;
      final int rowLines = (rows.length / 2).ceil();
      final double gridH = rowLines * cellH;
      final double panelH = strip + 34 + 64 + 26 + gridH + 34 +
          (footer.isEmpty ? 10 : footH);
      final double H = imgH + panelH;

      final rec = ui.PictureRecorder();
      final c = Canvas(rec, Rect.fromLTWH(0, 0, _W, H));
      c.drawRect(Rect.fromLTWH(0, 0, _W, H), Paint()..color = Colors.white);

      // ---- photo (contain, aachho background)
      c.drawRect(Rect.fromLTWH(0, 0, _W, imgH),
          Paint()..color = const Color(0xffF7F7F9));
      final double sc = (imgH / src.height < _W / src.width)
          ? imgH / src.height
          : _W / src.width;
      final double dw = src.width * sc, dh = src.height * sc;
      c.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        Rect.fromLTWH((_W - dw) / 2, (imgH - dh) / 2, dw, dh),
        Paint()..filterQuality = FilterQuality.high,
      );

      // ---- badge (EXACT / 87% MATCH) — shadow sathe pill
      if (badge != null) {
        final bp = _para(badge, 30, Colors.white,
            w: FontWeight.w800, maxW: 600, spacing: 1.2);
        final double bw = bp.longestLine + 52;
        final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(32, 32, bw, 62), const Radius.circular(31));
        c.drawShadow(Path()..addRRect(r), Colors.black, 8, false);
        c.drawRRect(r, Paint()..color = badgeColor);
        c.drawCircle(Offset(32 + 26, 32 + 31), 7, Paint()..color = Colors.white);
        c.drawParagraph(bp, Offset(32 + 40, 32 + (62 - bp.height) / 2));
      }

      // ---- gold gradient patti
      final stripRect = Rect.fromLTWH(0, imgH, _W, strip);
      c.drawRect(
        stripRect,
        Paint()
          ..shader = ui.Gradient.linear(
            stripRect.topLeft,
            stripRect.topRight,
            const [Color(0xffB8892E), Color(0xffE9CF86), Color(0xffB8892E)],
            const [0, 0.5, 1],
          ),
      );

      double y = imgH + strip + 34;

      // ---- status pill (jamni baju)
      double statusW = 0;
      if (statusText != null) {
        final Color sc2 = statusColor ?? const Color(0xff16A34A);
        final sp = _para(statusText.toUpperCase(), 26, sc2,
            w: FontWeight.w800, maxW: 400, spacing: 1);
        statusW = sp.longestLine + 70;
        final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(_W - pad - statusW, y + 6, statusW, 52),
            const Radius.circular(26));
        c.drawRRect(r, Paint()..color = sc2.withOpacity(0.10));
        c.drawRRect(
            r,
            Paint()
              ..color = sc2.withOpacity(0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        c.drawCircle(Offset(r.left + 28, r.top + 26), 8, Paint()..color = sc2);
        c.drawParagraph(sp, Offset(r.left + 46, r.top + (52 - sp.height) / 2));
      }

      // ---- title
      final tp = _para(title, 46, _cInk,
          w: FontWeight.w800,
          maxW: _W - pad * 2 - (statusW > 0 ? statusW + 24 : 0));
      c.drawParagraph(tp, Offset(pad, y + (64 - tp.height) / 2));
      y += 64 + 26;

      // ---- detail grid (ek j card, andar divider)
      if (rows.isNotEmpty) {
        final gridRect = Rect.fromLTWH(pad, y, _W - pad * 2, gridH);
        final gr = RRect.fromRectAndRadius(gridRect, const Radius.circular(18));
        c.drawRRect(gr, Paint()..color = _cSoft);
        c.save();
        c.clipRRect(gr);

        // dabi baju navy accent
        c.drawRect(Rect.fromLTWH(pad, y, 8, gridH), Paint()..color = _cNavy);

        final divider = Paint()
          ..color = _cBorder
          ..strokeWidth = 2;
        const double inner = 8; // accent pachhi
        final double fullW = gridRect.width - inner;
        final double colW = fullW / 2;

        for (int i = 0; i < rows.length; i++) {
          final int line = i ~/ 2;
          final int col = i % 2;
          final bool alone = i == rows.length - 1 && rows.length.isOdd;
          final double cw = alone ? fullW : colW;
          final double x = pad + inner + col * colW;
          final double yy = y + line * cellH;

          c.drawParagraph(
            _para(rows[i].$1.toUpperCase(), 22, _cGrey,
                w: FontWeight.w700, maxW: cw - 56, spacing: 1.4),
            Offset(x + 30, yy + 18),
          );
          c.drawParagraph(
            _para(rows[i].$2, 38, i == 0 ? _cNavy : _cInk,
                w: FontWeight.w800, maxW: cw - 56),
            Offset(x + 30, yy + 52),
          );

          // vertical divider
          if (col == 0 && !alone) {
            c.drawLine(Offset(x + colW, yy + 20),
                Offset(x + colW, yy + cellH - 20), divider);
          }
        }
        // horizontal divider
        for (int l = 1; l < rowLines; l++) {
          c.drawLine(Offset(pad + inner + 24, y + l * cellH),
              Offset(gridRect.right - 24, y + l * cellH), divider);
        }
        c.restore();
        c.drawRRect(
            gr,
            Paint()
              ..color = _cBorder
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      y += gridH + 34;

      // ---- footer — navy patti + gold brand
      if (footer.isNotEmpty) {
        final fr = Rect.fromLTWH(0, H - footH, _W, footH);
        c.drawRect(fr, Paint()..color = _cNavy);
        c.drawRect(Rect.fromLTWH(0, H - footH, _W, 3),
            Paint()..color = _cGold);
        final fp = _para(footer, 26, Colors.white,
            w: FontWeight.w700,
            maxW: _W - pad * 2,
            align: TextAlign.center,
            spacing: 1);
        c.drawParagraph(fp, Offset(pad, H - footH + 3 + (footH - 3 - fp.height) / 2));
      }

      final pic = rec.endRecording();
      final out = await pic.toImage(_W.toInt(), H.toInt());
      final bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
      final int ow = out.width, oh = out.height;
      out.dispose();
      if (bd == null) return null;

      return await compute(_rgbaToJpg, {
        "w": ow,
        "h": oh,
        "rgba": bd.buffer.asUint8List(),
        "q": 92,
      });
    } catch (e) {
      debugPrint("❌ RENDER CARD ERROR => $e");
      return null;
    } finally {
      src?.dispose();
      codec?.dispose();
    }
  }

  /// WhatsApp mate badhi image (pehli = tamari photo)
  static Future<List<File>> buildShareImages({
    required File query,
    required List<ExportItem> items,
    int exactCount = 0,
    int similarCount = 0,
    void Function(int done, int total)? onProgress,
  }) async {
    String brand = "";
    try {
      final p = await SharedPreferences.getInstance();
      brand = (p.getString("companyName") ?? "").trim();
    } catch (_) {}

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final List<File> files = [];
    final int total = items.length + 1;

    // 1) Tamari photo
    final qCard = await renderCard(
      photo: await query.readAsBytes(),
      title: "Searched Photo",
      badge: "SEARCH",
      badgeColor: const Color(0xff2F4A78),
      rows: [
        ("Exact match", "$exactCount"),
        ("Similar items", "$similarCount"),
      ],
      footer: brand,
    );
    if (qCard != null) {
      final f = File("${dir.path}/img_search_${stamp}_0.jpg");
      await f.writeAsBytes(qCard, flush: true);
      files.add(f);
    }
    onProgress?.call(1, total);

    // 2) Dar item — photo + detail
    final cards = await _pool<File>(items.length, (i) async {
      final e = items[i];
      final m = e.item;
      final raw = await download(m);
      if (raw == null) return null;
      final bool st = inStock(m);
      final String huid = s(m["huid"]);
      final bytes = await renderCard(
        photo: raw,
        title: s(m["item_name"]),
        badge: e.exact ? "EXACT MATCH" : "${(e.score * 100).round()}% MATCH",
        badgeColor: e.exact ? const Color(0xff16A34A) : const Color(0xff2F4A78),
        statusText: st ? "In Stock" : "Sold",
        statusColor: st ? const Color(0xff16A34A) : const Color(0xffDC2626),
        rows: [
          ("Label Code", s(m["label_code"] ?? m["qr_code"])),
          if (huid != "-") ("HUID", huid),
          ("Gross Wt", "${s(m["gross_weight"])} g"),
          ("Net Wt", "${s(m["net_weight"])} g"),
        ],
        footer: [brand, s(m["company_name"], "")]
            .where((x) => x.isNotEmpty)
            .toSet()
            .join("  •  "),
      );
      if (bytes == null) return null;
      final f = File("${dir.path}/img_search_${stamp}_${i + 1}.jpg");
      await f.writeAsBytes(bytes, flush: true);
      return f;
    }, onDone: (d) => onProgress?.call(d + 1, total));

    files.addAll(cards.whereType<File>());
    return files;
  }
}

/// compute() mate top-level — RGBA → JPG
Uint8List _rgbaToJpg(Map<String, dynamic> a) {
  // Premultiplied alpha → safed background (transparent PNG kali na thay)
  final Uint8List px = a["rgba"] as Uint8List;
  for (int i = 0; i < px.length; i += 4) {
    final int al = px[i + 3];
    if (al == 255) continue;
    final int add = 255 - al;
    px[i] = (px[i] + add).clamp(0, 255);
    px[i + 1] = (px[i + 1] + add).clamp(0, 255);
    px[i + 2] = (px[i + 2] + add).clamp(0, 255);
    px[i + 3] = 255;
  }
  final image = img.Image.fromBytes(
    width: a["w"] as int,
    height: a["h"] as int,
    bytes: px.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: a["q"] as int));
}
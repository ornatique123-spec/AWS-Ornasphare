import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;


import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Api_Constant/ApiConstants.dart';
import 'AiEnglish.dart';
import 'ai_core.dart';

/// =======================================================================
///  📄 AI PDF — Ask AI na koi pan javab ni list ni PDF
///
///   • "photo vagar na item"          → list → 📄 PDF button
///   • "photo vagar na item ni pdf"   → list + PDF sidhi bane
///   • "aaje nu vechan pdf"           → bill ni list ni PDF
///
///  PDF ma: title, tarikh, saransh (stats), item mujab saransh (section),
///  ane puri list (Sr · Barcode · Item · Weight · Status + details).
///  File: Ask AI/core/ai_pdf.dart
/// =======================================================================
class AiPdf {
  /// Sawal ma PDF mangi che?
  static bool wantsPdf(String q) {
    final t = ' ${q.toLowerCase()} ';
    return [' pdf', 'p d f', ' pdf ', 'पीडीएफ', 'પીડીએફ', ' report banav', ' list banav', ' print kar', ' chhap']
        .any(t.contains);
  }

  /// "photo sathe" / "image vadi" / "with image" → photo vali PDF
  static bool wantsImages(String q) {
    final t = ' ${q.toLowerCase()} ';
    final photo = [' photo', ' image', ' imej', ' pic', ' foto', 'ફોટો', 'ફોટા', 'ઇમેજ', 'फोटो', 'इमेज'].any(t.contains);
    final neg = [' vagar', ' vina', ' bina', ' without', ' nathi', ' baki', ' no photo', 'વગર', 'વિના', 'बिना']
        .any(t.contains);
    return photo && !neg;
  }

  static bool hasImages(AiAnswer a) => a.items.any((r) => _url(r) != null);

  /// Puro URL: "storage/x.jpg" / "/storage/x.jpg" → "https://ornasphere.com/storage/x.jpg"
  static String? _url(AiRecord r) => _urlOf(r.imageUrl?.toString() ?? '');

  static String? _urlOf(String raw) {
    var u = raw.trim();
    if (u.isEmpty || u == 'null' || u == '-') return null;
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('http')) return u.replaceAll(' ', '%20');
    final host = ApiConstants.baseUrl.replaceAll(RegExp(r'api/?$'), ''); // https://ornasphere.com/
    final path = u.startsWith('/') ? u.substring(1) : u;
    return (host + path).replaceAll(' ', '%20');
  }

  /// Chhelli PDF ma ketla photo aavya / na aavya (UI ma kahva)
  static int lastPhotosOk = 0, lastPhotosFailed = 0;

  // ---------------------------------------------------------------------
  //  📷 Photo download (6 ek sathe) + nani karo (PDF halki rahe)
  // ---------------------------------------------------------------------
  static final Map<String, Uint8List> _imgCache = {};

  static Future<Map<String, pw.MemoryImage>> _loadImages(
      List<AiRecord> items,
      void Function(int done, int total)? onProgress,
      ) async {
    final urls = items.map(_url).whereType<String>().toSet().toList();
    final out = <String, pw.MemoryImage>{};
    var done = 0;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.bytes,
      followRedirects: true,
      validateStatus: (s) => s != null && s < 400,
    ));
    var failed = 0;
    Future<void> one(String u) async {
      try {
        var bytes = _imgCache[u];
        if (bytes == null) {
          Response<List<int>> res;
          try {
            res = await dio.get<List<int>>(u);
          } catch (_) {
            // http blocked hoy to https thi fari
            if (!u.startsWith('http://')) rethrow;
            res = await dio.get<List<int>>(u.replaceFirst('http://', 'https://'));
          }
          final data = res.data;
          if (data != null && data.isNotEmpty) {
            bytes = await _shrink(Uint8List.fromList(data));
            if (bytes != null) _imgCache[u] = bytes;
          }
        }
        if (bytes != null) {
          out[u] = pw.MemoryImage(bytes);
        } else {
          failed++;
        }
      } catch (e) {
        failed++;
        debugPrint('📷 PDF photo fail: $u → $e');
      }
      done++;
      onProgress?.call(done, urls.length);
    }

    for (var i = 0; i < urls.length; i += 6) {
      await Future.wait(urls.skip(i).take(6).map(one));
    }
    dio.close(force: true);
    lastPhotosOk = out.length;
    lastPhotosFailed = failed;
    debugPrint('📷 PDF photo: ${out.length} aavya, $failed na aavya (kul ${urls.length})');
    return out;
  }

  /// 260px PNG (Flutter no j decoder — navu package nathi joitu)
  static Future<Uint8List?> _shrink(Uint8List raw, {int width = 260}) async {
    try {
      final codec = await ui.instantiateImageCodec(raw, targetWidth: width);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  //  🏢 BRAND — company name / logo / city (login vakhte prefs ma save thay che)
  // ---------------------------------------------------------------------
  static pw.MemoryImage? _logoCache;
  static String? _logoUrlCache;

  static Future<({String name, String place, pw.MemoryImage? logo})> _brand() async {
    String name = 'Ornasphere', place = '';
    String logoUrl = '';
    try {
      final p = await SharedPreferences.getInstance();
      String v(String k) {
        final s = (p.getString(k) ?? '').trim();
        return (s == '-' || s == 'null') ? '' : s;
      }

      if (v('companyName').isNotEmpty) name = v('companyName');
      place = [v('city'), v('state')].where((e) => e.isNotEmpty).join(', ');
      logoUrl = v('companyLogo');
    } catch (_) {}

    pw.MemoryImage? logo;
    if (logoUrl.isNotEmpty && logoUrl == _logoUrlCache && _logoCache != null) {
      logo = _logoCache;
    } else if (logoUrl.isNotEmpty) {
      try {
        final u = _urlOf(logoUrl);
        if (u != null) {
          final res = await Dio(BaseOptions(
            responseType: ResponseType.bytes,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          )).get<List<int>>(u);
          final png = res.data == null ? null : await _shrink(Uint8List.fromList(res.data!), width: 320);
          if (png != null) {
            logo = pw.MemoryImage(png);
            _logoCache = logo;
            _logoUrlCache = logoUrl;
          }
        }
      } catch (e) {
        debugPrint('🏢 PDF logo fail: $e');
      }
    }
    if (logo == null) {
      // app no logo (assets/static/logo.png)
      try {
        final b = await rootBundle.load('assets/static/logo.png');
        logo = pw.MemoryImage(b.buffer.asUint8List());
      } catch (_) {}
    }
    return (name: name, place: place, logo: logo);
  }

  // 🎨 Premium palette — navy + gold
  static const _navy = PdfColor.fromInt(0xff0F2A4A);
  static const _navy2 = PdfColor.fromInt(0xff1C3F6E);
  static const _gold = PdfColor.fromInt(0xffC9A24A);
  static const _goldSoft = PdfColor.fromInt(0xffF6EEDB);
  static const _cream = PdfColor.fromInt(0xffFBF9F4);
  static const _line = PdfColor.fromInt(0xffE6E0D2);
  static const _ink = PdfColor.fromInt(0xff1B2433);
  static const _grey = PdfColor.fromInt(0xff6B7487);

  /// PDF banavo → file path
  /// [withImages] = darek row ma item no photo
  static Future<File> build(
      AiAnswer a, {
        String? title,
        bool withImages = false,
        void Function(int done, int total)? onProgress,
      }) async {
    final brand = await _brand();
    final now = DateTime.now();
    final reportTitle = _safe(title ?? (a.itemsTitle?.toString().isNotEmpty == true ? a.itemsTitle.toString() : 'Report'));
    final filter = _safe(a.filterLabel?.toString() ?? '');
    final items = a.items;
    final hasSub = items.any((r) => _s(r.subtitle).isNotEmpty);
    final hasBadge = items.any((r) => _s(r.badge).isNotEmpty);
    lastPhotosOk = 0;
    lastPhotosFailed = 0;
    final photos = withImages ? await _loadImages(items, onProgress) : const <String, pw.MemoryImage>{};
    final showPhoto = withImages && photos.isNotEmpty;

    final doc = pw.Document(title: '$reportTitle - ${brand.name}', author: brand.name, creator: 'Ornasphere Ask AI');

    pw.Widget cell(String s,
        {bool bold = false, PdfColor color = _ink, pw.TextAlign align = pw.TextAlign.left, double size = 8.6}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(_safe(s),
              textAlign: align,
              style: pw.TextStyle(fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : null)),
        );

    pw.Widget logoBox(double size) => pw.Container(
      width: size,
      height: size,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(size * 0.2),
        border: pw.Border.all(color: _gold, width: 1),
      ),
      alignment: pw.Alignment.center,
      child: brand.logo != null
          ? pw.Image(brand.logo!, fit: pw.BoxFit.contain)
          : pw.Text(brand.name.isEmpty ? 'O' : brand.name[0].toUpperCase(),
          style: pw.TextStyle(fontSize: size * 0.45, fontWeight: pw.FontWeight.bold, color: _navy)),
    );

    // ---- page 1: big header ----
    pw.Widget bigHeader() => pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_navy, _navy2], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          logoBox(54),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_safe(brand.name).toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1.2)),
              if (brand.place.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(_safe(brand.place), style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xffD6DEEA))),
              ],
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(color: _gold, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text('AI REPORT',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 1)),
            ),
            pw.SizedBox(height: 6),
            pw.Text(_dt(now), style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xffD6DEEA))),
          ]),
        ]),
      ),
      pw.SizedBox(height: 14),
      // title strip
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const pw.BoxDecoration(
          color: _cream,
          border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(reportTitle, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _navy)),
              if (filter.isNotEmpty && filter != reportTitle) ...[
                pw.SizedBox(height: 2),
                pw.Text(filter, style: const pw.TextStyle(fontSize: 9, color: _grey)),
              ],
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('${items.length}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _gold)),
            pw.Text(items.length == 1 ? 'entry' : 'entries', style: const pw.TextStyle(fontSize: 8, color: _grey)),
          ]),
        ]),
      ),
      pw.SizedBox(height: 12),
    ]);

    // ---- page 2+: slim header ----
    pw.Widget slimHeader() => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 1))),
      child: pw.Row(children: [
        logoBox(22),
        pw.SizedBox(width: 8),
        pw.Text(_safe(brand.name), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
        pw.Spacer(),
        pw.Text(reportTitle, style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ]),
    );

    pw.Widget sectionTitle(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(children: [
        pw.Container(width: 3, height: 12, color: _gold),
        pw.SizedBox(width: 6),
        pw.Text(_safe(t).toUpperCase(),
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.6)),
      ]),
    );

    final headers = [
      '#',
      if (showPhoto) 'Photo',
      'Barcode / Name',
      if (hasSub) 'Item / Detail',
      'Weight',
      if (hasBadge) 'Status',
    ];

    pw.Widget badge(String s) {
      final t = _safe(s);
      final low = t.toLowerCase();
      final good = low.contains('stock') || low.contains('available') || low.contains('approved');
      final warn = low.contains('approval') || low.contains('pending');
      final bg = good ? const PdfColor.fromInt(0xffE6F4EA) : (warn ? _goldSoft : const PdfColor.fromInt(0xffFDECEC));
      final fg = good ? const PdfColor.fromInt(0xff1E7B3A) : (warn ? const PdfColor.fromInt(0xff8A6A1F) : const PdfColor.fromInt(0xffB3261E));
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Text(t, style: pw.TextStyle(fontSize: 7.5, color: fg, fontWeight: pw.FontWeight.bold)),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 30),
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: _gold, width: 5)),
              ),
            ),
          ),
        ),
        header: (ctx) => ctx.pageNumber == 1 ? bigHeader() : slimHeader(),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8))),
          child: pw.Row(children: [
            pw.Text('${_safe(brand.name)}  |  Generated by Ornasphere Ask AI  |  ${_dt(now)}',
                style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
            pw.Spacer(),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7.5, color: _navy, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        build: (ctx) => [
          // ---- summary cards ----
          if (a.stats.isNotEmpty) ...[
            sectionTitle('Summary'),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: a.stats
                  .map((s) => pw.Container(
                width: 122,
                padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: _line, width: 0.8),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_safe(s.label).toUpperCase(),
                      style: const pw.TextStyle(fontSize: 6.8, color: _grey, letterSpacing: 0.5)),
                  pw.SizedBox(height: 3),
                  pw.Text(_safe(s.value),
                      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _navy)),
                ]),
              ))
                  .toList(),
            ),
            pw.SizedBox(height: 14),
          ],

          // ---- sections (item wise, customer wise…) ----
          for (final s in a.sections.where((s) => s.rows.isNotEmpty)) ...[
            sectionTitle(s.title),
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _line, width: 0.8),
              ),
              child: pw.Table(
                border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
                columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.6), 2: pw.FlexColumnWidth(3.4)},
                children: [
                  for (var i = 0; i < s.rows.length; i++)
                    pw.TableRow(
                      decoration: i.isOdd ? const pw.BoxDecoration(color: _cream) : null,
                      children: [
                        cell(s.rows[i].title, bold: true),
                        cell(s.rows[i].value, color: _navy, bold: true, align: pw.TextAlign.right),
                        cell(s.rows[i].sub ?? '', color: _grey, size: 8),
                      ],
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // ---- main list ----
          if (items.isNotEmpty) ...[
            sectionTitle(a.itemsTitle?.toString() ?? 'Details'),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _line, width: 0.5),
                bottom: pw.BorderSide(color: _line, width: 0.8),
              ),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              columnWidths: () {
                final w = <int, pw.TableColumnWidth>{};
                var c = 0;
                w[c++] = const pw.FixedColumnWidth(24);
                if (showPhoto) w[c++] = const pw.FixedColumnWidth(66);
                w[c++] = const pw.FlexColumnWidth(2.4);
                if (hasSub) w[c++] = const pw.FlexColumnWidth(3.2);
                w[c++] = const pw.FlexColumnWidth(1.3);
                if (hasBadge) w[c++] = const pw.FlexColumnWidth(1.4);
                return w;
              }(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _navy),
                  repeat: true,
                  children: headers
                      .map((h) => cell(h.toUpperCase(), bold: true, color: PdfColors.white, size: 7.6))
                      .toList(),
                ),
                for (var i = 0; i < items.length; i++)
                  pw.TableRow(
                    decoration: i.isOdd ? const pw.BoxDecoration(color: _cream) : null,
                    children: [
                      cell('${i + 1}', color: _grey, size: 8),
                      if (showPhoto)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: photos[_url(items[i]) ?? ''] != null
                              ? pw.Container(
                            width: 58,
                            height: 58,
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: _line, width: 0.8),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 6,
                              verticalRadius: 6,
                              child: pw.Image(photos[_url(items[i])]!, fit: pw.BoxFit.cover),
                            ),
                          )
                              : pw.Container(
                            width: 58,
                            height: 58,
                            alignment: pw.Alignment.center,
                            decoration: pw.BoxDecoration(color: _cream, borderRadius: pw.BorderRadius.circular(6)),
                            child: pw.Text('No photo', style: const pw.TextStyle(fontSize: 6.5, color: _grey)),
                          ),
                        ),
                      cell(_s(items[i].title), bold: true),
                      if (hasSub) cell(_s(items[i].subtitle), color: _grey, size: 8),
                      cell(_s(items[i].value), color: _navy, bold: true, align: pw.TextAlign.right),
                      if (hasBadge) _s(items[i].badge).isEmpty ? pw.SizedBox() : badge(_s(items[i].badge)),
                    ],
                  ),
              ],
            ),
          ],

          // ---- closing note ----
          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.Text('— End of report —', style: const pw.TextStyle(fontSize: 8, color: _grey)),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final name = '${_fileName(brand.name)}_${_fileName(reportTitle)}${showPhoto ? '_photo' : ''}_${now.millisecondsSinceEpoch}.pdf';
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  /// PDF banavi ne "Kholo / Share" puchho
  /// [withImages] null = list ma photo hoy to puchho (Photo sathe / vagar)
  static Future<void> makeAndShow(BuildContext context, AiAnswer a, {String? title, bool? withImages}) async {
    final messenger = ScaffoldMessenger.of(context);
    var photo = withImages ?? false;
    if (withImages == null && hasImages(a)) {
      final pick = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Which PDF do you want?',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xff1B2433))),
              const SizedBox(height: 12),
              _choice(ctx, Icons.photo_library_rounded, 'With photos', 'Item photo in every row · takes a little time',
                  true),
              const SizedBox(height: 8),
              _choice(ctx, Icons.table_rows_rounded, 'List only', 'No photos · faster, smaller file', false),
            ]),
          ),
        ),
      );
      if (pick == null) return;
      photo = pick;
    }
    if (photo && !hasImages(a)) photo = false;

    final progress = ValueNotifier<String>(photo ? '📷 Loading photos…' : '📄 Creating PDF…');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(minutes: 5),
        behavior: SnackBarBehavior.floating,
        content: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (_, v, __) => Text(v),
        ),
      ));
    File f;
    try {
      f = await build(a, title: title, withImages: photo, onProgress: (d, t) {
        progress.value = d >= t ? '📄 Creating PDF…' : '📷 Loading photos… $d / $t';
      });
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not create PDF: $e'), behavior: SnackBarBehavior.floating));
      return;
    }
    messenger.hideCurrentSnackBar();
    if (photo && lastPhotosOk == 0) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text('⚠️ Photos could not be downloaded ($lastPhotosFailed) — PDF was created without photos. '
            'Please check the internet / image links.'),
      ));
    } else if (photo && lastPhotosFailed > 0) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('📷 $lastPhotosOk photos loaded, $lastPhotosFailed failed (marked "No photo").'),
      ));
    }
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Color(0xffD9534F), size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('PDF is ready',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xff1B2433))),
                    Text('${a.items.length} entries · ${f.path.split('/').last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xff6B7487))),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      OpenFile.open(f.path);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xff1F4E99),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], subject: title ?? a.itemsTitle);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share / WhatsApp'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _choice(BuildContext ctx, IconData icon, String title, String sub, bool value) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => Navigator.pop(ctx, value),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE4EAF5)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xff1F4E99)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xff1B2433))),
            Text(sub, style: const TextStyle(fontSize: 11.5, color: Color(0xff6B7487))),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xff6B7487)),
      ]),
    ),
  );

  // ---------------------------------------------------------------------
  static String _s(Object? v) => v?.toString() ?? '';

  /// PDF na default font ma emoji / Gujarati nathi → saaf karo
  static String _safe(String s) => AiEnglish.fix(s) // 🇬🇧 PDF ma pan English j
      .replaceAll('₹', 'Rs. ')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('·', '|')
      .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();

  static String _fileName(String s) {
    final f = _safe(s).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return f.isEmpty ? 'AskAI' : (f.length > 40 ? f.substring(0, 40) : f);
  }

  static String _dt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

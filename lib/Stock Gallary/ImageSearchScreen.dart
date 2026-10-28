// import 'dart:convert';
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'dart:ui' as ui;
//
// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart' show compute;
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:open_file/open_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Api_Constant/ApiConstants.dart';
// import '../Api_Constant/api_helper.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/AppMessage.dart';
// import 'ImageSearchExport.dart';
//
// /// ================================================================
// /// 🔎 IMAGE SEARCH — fakt Flutter app side (backend ma kai nahi)
// ///
// /// ⚡ FAST VERSION (1900+ image mate)
// ///  • Native decoder — image sidhi 128px ma decode (full size nahi)
// ///  • 10 image ek sathe download
// ///  • Stock na page pan 10-10 ek sathe
// ///  🎯 Background game te hoy — fakt ITEM j jovay (tamari photo ane
// ///     database ni photo banne ma background kadhi nakhay)
// ///  ✅ Exact ma fakt 1 j — sauthi sacho ane bija thi chokhkho aagal
// ///  • Screen khulta j background ma scan sharu (photo pasand karo e
// ///    pahela j moṭa bhaag nu kaam thai gayu hoy)
// ///  • Scan chalu hoy tyare pan result dekhay (live)
// ///  • Fingerprint nano (~100 akshar) phone ma save — biji vaar
// ///    fakt navi image j scan thay, baki turant
// /// ================================================================
//
// /// ---------------------------------------------------------------
// /// FINGERPRINT
// /// ---------------------------------------------------------------
// class ImgPrint {
//   final int dHash; // 8×8 aakar
//   final int aHash;
//   final List<double> hist; // 64 bin rang (hue × ujas), sum = 1
//   final Uint8List d16; // 16×16 jhinu aakar (256 bit)
//   final List<double> accent; // 12 bin — sona sivay na rang (meena, nang)
//
//   const ImgPrint(this.dHash, this.aHash, this.hist, this.d16, this.accent);
//
//   String encode() {
//     final Uint8List h = Uint8List(64);
//     for (int i = 0; i < 64; i++) {
//       h[i] = (hist[i] * 255).round().clamp(0, 255);
//     }
//     final Uint8List ac = Uint8List(12);
//     for (int i = 0; i < 12; i++) {
//       ac[i] = (accent[i] * 1020).round().clamp(0, 255);
//     }
//     return "${dHash.toRadixString(16)}|${aHash.toRadixString(16)}|"
//         "${base64Encode(h)}|${base64Encode(d16)}|${base64Encode(ac)}";
//   }
//
//   static ImgPrint? decode(String s) {
//     try {
//       final p = s.split("|");
//       if (p.length != 5) return null; // juno format → farithi scan
//       final Uint8List h = base64Decode(p[2]);
//       final Uint8List d = base64Decode(p[3]);
//       final Uint8List ac = base64Decode(p[4]);
//       if (h.length != 64 || d.length != 32 || ac.length != 12) return null;
//       return ImgPrint(
//         int.parse(p[0], radix: 16),
//         int.parse(p[1], radix: 16),
//         [for (final v in h) v / 255],
//         d,
//         [for (final v in ac) v / 1020],
//       );
//     } catch (_) {
//       return null;
//     }
//   }
// }
//
// /// ================================================================
// /// 🎯 BACKGROUND GME TE HOY — fakt item ne j olkho
// ///
// ///  1) Photo nu aspect sachvi 128px ma decode
// ///  2) Kinara (border) na rang thi background olkho (4 baju — gradient
// ///     / be rang no background pan chale)
// ///  3) Background vala pixel → safed, item ni aaju-baju crop (square)
// ///  4) Rang (histogram) fakt item na pixel thi — background no rang
// ///     match ma gnay nahi
// ///  Background bahu bhid-bhad vado hoy to (olkhay nahi) → puri photo
// ///  Tamari photo mate 4 roop (auto, 75% zoom, 55% zoom, puri) — je
// ///  sauthi saru match thay e levay
// /// ================================================================
//
// const int _dec = 128;
//
// Future<({Uint8List px, int w, int h})?> _decodeRgba(Uint8List bytes,
//     [int maxSide = _dec]) async {
//   ui.ImmutableBuffer? buf;
//   ui.Codec? codec;
//   ui.Image? image;
//   try {
//     buf = await ui.ImmutableBuffer.fromUint8List(bytes);
//     final desc = await ui.ImageDescriptor.encoded(buf);
//     final int iw = desc.width, ih = desc.height;
//     if (iw <= 0 || ih <= 0) return null;
//     final double sc = maxSide / (iw > ih ? iw : ih);
//     final int tw = (iw * sc).round().clamp(8, maxSide);
//     final int th = (ih * sc).round().clamp(8, maxSide);
//     codec = await desc.instantiateCodec(targetWidth: tw, targetHeight: th);
//     image = (await codec.getNextFrame()).image;
//     final ByteData? data =
//     await image.toByteData(format: ui.ImageByteFormat.rawRgba);
//     if (data == null) return null;
//     return (px: data.buffer.asUint8List(), w: image.width, h: image.height);
//   } catch (_) {
//     return null;
//   } finally {
//     image?.dispose();
//     codec?.dispose();
//     buf?.dispose();
//   }
// }
//
// /// Stock ni image — auto background kadhi ne
// Future<ImgPrint?> _makePrint(Uint8List bytes) async {
//   final d = await _decodeRgba(bytes);
//   if (d == null) return null;
//   try {
//     return _printFromRgba(d.px, d.w, d.h);
//   } catch (_) {
//     return null;
//   }
// }
//
// /// 📱 Screenshot hoy to kinara na kaala patta (status bar, app bar,
// ///    button bar) kapi nakho — fakt photo vado bhaag j rahe
// ({Uint8List px, int w, int h}) _trimDark(Uint8List px, int w, int h) {
//   bool darkRow(int y, int x0, int x1) {
//     int c = 0;
//     for (int x = x0; x < x1; x++) {
//       final int i = (y * w + x) * 4;
//       if (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2] < 50) c++;
//     }
//     return c >= (x1 - x0) * 0.8;
//   }
//
//   bool darkCol(int x, int y0, int y1) {
//     int c = 0;
//     for (int y = y0; y < y1; y++) {
//       final int i = (y * w + x) * 4;
//       if (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2] < 50) c++;
//     }
//     return c >= (y1 - y0) * 0.8;
//   }
//
//   int y0 = 0, y1 = h, x0 = 0, x1 = w;
//   while (y0 < (h * 0.45).floor() && darkRow(y0, x0, x1)) y0++;
//   while (y1 > h - (h * 0.45).floor() && darkRow(y1 - 1, x0, x1)) y1--;
//   while (x0 < (w * 0.45).floor() && darkCol(x0, y0, y1)) x0++;
//   while (x1 > w - (w * 0.45).floor() && darkCol(x1 - 1, y0, y1)) x1--;
//   if (y0 == 0 && y1 == h && x0 == 0 && x1 == w) return (px: px, w: w, h: h);
//
//   final int nw = x1 - x0, nh = y1 - y0;
//   final Uint8List out = Uint8List(nw * nh * 4);
//   for (int y = 0; y < nh; y++) {
//     out.setRange(y * nw * 4, (y + 1) * nw * 4, px, ((y + y0) * w + x0) * 4);
//   }
//   return (px: out, w: nw, h: nh);
// }
//
// /// ================================================================
// /// 🔍 FINE CHECK — upar na 12 item ne vadhu jhinvat thi sarkhavo
// ///  (40×40 gray, thodu khasvu chalavi lye) → e j photo hoy to 0.85+,
// ///  biju sarkhu ghareṇu hoy to ochhu → Exact pakku
// /// ================================================================
// const int _fN = 40;
//
// Float64List _fineDesc(Uint8List rgb, Uint8List fg, int w, int bx0, int by0,
//     int bx1, int by1, int rx0, int ry0, int rx1, int ry1, double scale) {
//   final double bw = (bx1 - bx0).toDouble(), bh = (by1 - by0).toDouble();
//   final double sl = (bw > bh ? bw : bh) * 1.06 * scale;
//   final double sx0 = (bx0 + bx1) / 2 - sl / 2;
//   final double sy0 = (by0 + by1) / 2 - sl / 2;
//   final double st = sl / _fN;
//   final Float64List g = Float64List(_fN * _fN);
//   for (int ty = 0; ty < _fN; ty++) {
//     for (int tx = 0; tx < _fN; tx++) {
//       double s = 0;
//       for (int k = 0; k < 4; k++) {
//         final int xi = (sx0 + (tx + ((k & 1) + 0.5) / 2) * st).floor();
//         final int yi = (sy0 + (ty + ((k >> 1) + 0.5) / 2) * st).floor();
//         if (xi < rx0 || yi < ry0 || xi >= rx1 || yi >= ry1 || fg[yi * w + xi] == 0) {
//           s += 255;
//         } else {
//           final int i = yi * w + xi;
//           s += 0.299 * rgb[i * 3] + 0.587 * rgb[i * 3 + 1] + 0.114 * rgb[i * 3 + 2];
//         }
//       }
//       g[ty * _fN + tx] = s / 4;
//     }
//   }
//   return g;
// }
//
// /// Ek photo → fine desc (zoom/segment roop, ane maap pramane)
// List<Float64List> _fineFrom(Uint8List px, int w, int h,
//     List<(double, bool)> views, List<double> scales) {
//   final out = <Float64List>[];
//   for (final v in views) {
//     try {
//       _printFromRgba(px, w, h, zoom: v.$1, segment: v.$2,
//           onSeg: (rgb, fg, bx0, by0, bx1, by1, rx0, ry0, rx1, ry1) {
//             for (final sc in scales) {
//               out.add(_fineDesc(rgb, fg, w, bx0, by0, bx1, by1, rx0, ry0, rx1, ry1, sc));
//             }
//           });
//     } catch (_) {}
//   }
//   return out;
// }
//
// /// Normalized correlation (±2 khasvu) — 1 = ekdam same
// double _ncc(Float64List a, Float64List b) {
//   double best = -1;
//   for (int dy = -2; dy <= 2; dy++) {
//     for (int dx = -2; dx <= 2; dx++) {
//       final int ya = dy > 0 ? dy : 0, yb = dy < 0 ? -dy : 0;
//       final int xa = dx > 0 ? dx : 0, xb = dx < 0 ? -dx : 0;
//       final int hh = _fN - dy.abs(), ww = _fN - dx.abs();
//       double sa = 0, sb = 0;
//       for (int y = 0; y < hh; y++) {
//         for (int x = 0; x < ww; x++) {
//           sa += a[(y + ya) * _fN + x + xa];
//           sb += b[(y + yb) * _fN + x + xb];
//         }
//       }
//       final double ma = sa / (hh * ww), mb = sb / (hh * ww);
//       double num = 0, da = 0, db = 0;
//       for (int y = 0; y < hh; y++) {
//         for (int x = 0; x < ww; x++) {
//           final double p = a[(y + ya) * _fN + x + xa] - ma;
//           final double q = b[(y + yb) * _fN + x + xb] - mb;
//           num += p * q;
//           da += p * p;
//           db += q * q;
//         }
//       }
//       if (da > 0 && db > 0) {
//         final double v = num / math.sqrt(da * db);
//         if (v > best) best = v;
//       }
//     }
//   }
//   return best;
// }
//
// /// Kinar (edge) — gol ghaṭṭ "blob" sathe khoṭi sarkhamni na thay
// Float64List _gradDesc(Float64List d) {
//   final Float64List g = Float64List(_fN * _fN);
//   for (int y = 1; y < _fN - 1; y++) {
//     for (int x = 1; x < _fN - 1; x++) {
//       final double gx = d[y * _fN + x + 1] - d[y * _fN + x - 1];
//       final double gy = d[(y + 1) * _fN + x] - d[(y - 1) * _fN + x];
//       g[y * _fN + x] = math.sqrt(gx * gx + gy * gy);
//     }
//   }
//   return g;
// }
//
// /// Sarkhamni (khasvu nahi)
// double _nccFlat(Float64List a, Float64List b) {
//   final int n = a.length;
//   double sa = 0, sb = 0;
//   for (int i = 0; i < n; i++) {
//     sa += a[i];
//     sb += b[i];
//   }
//   final double ma = sa / n, mb = sb / n;
//   double num = 0, da = 0, db = 0;
//   for (int i = 0; i < n; i++) {
//     final double p = a[i] - ma, q = b[i] - mb;
//     num += p * q;
//     da += p * p;
//     db += q * q;
//   }
//   return (da > 0 && db > 0) ? num / math.sqrt(da * db) : -1;
// }
//
// /// Fakt rang: sona no shade + meena / nang (jagya vagar)
// double _colourSim(ImgPrint q, ImgPrint t) {
//   double hS = 0;
//   for (int i = 0; i < 64; i++) {
//     hS += q.hist[i] < t.hist[i] ? q.hist[i] : t.hist[i];
//   }
//   double diff = 0, tot = 0;
//   for (int i = 0; i < 12; i++) {
//     diff += (q.accent[i] - t.accent[i]).abs();
//     tot += q.accent[i] + t.accent[i];
//   }
//   final double acS = 1 - (diff / (tot > 0.03 ? tot : 0.03)).clamp(0.0, 1.0);
//   return hS * 0.5 + acS * 0.5;
// }
//
// /// RGBA no tukdo
// Uint8List _cropRgba(Uint8List px, int w, int x0, int y0, int cw, int ch) {
//   final Uint8List out = Uint8List(cw * ch * 4);
//   for (int y = 0; y < ch; y++) {
//     out.setRange(y * cw * 4, (y + 1) * cw * 4, px, ((y + y0) * w + x0) * 4);
//   }
//   return out;
// }
//
// /// 🖼️ Tamari photo na ghana "baari" (window) — background / props / model
// ///    hoy to pan koi ek baari ma fakt item j aave → e j stock sathe male
// List<Float64List> _queryFineViews(Uint8List px, int w, int h) {
//   final out = <Float64List>[
//     ..._fineFrom(px, w, h,
//         const [(1.0, true), (0.75, true), (0.55, true), (1.0, false)], const [1.0]),
//   ];
//   for (final sc in const [0.9, 0.8, 0.7, 0.6]) {
//     for (final ox in const [-0.1, 0.0, 0.1]) {
//       for (final oy in const [-0.1, 0.0, 0.1]) {
//         final int cw = (w * sc).round(), ch = (h * sc).round();
//         if (cw < 24 || ch < 24) continue;
//         final int x0 = ((w - cw) / 2 + ox * w).round().clamp(0, w - cw);
//         final int y0 = ((h - ch) / 2 + oy * h).round().clamp(0, h - ch);
//         final sub = _cropRgba(px, w, x0, y0, cw, ch);
//         out.addAll(_fineFrom(sub, cw, ch, const [(1.0, true), (1.0, false)], const [1.0]));
//       }
//     }
//   }
//   return out;
// }
//
// /// Zero-mean, unit-length (sarkhamni = sidho gunakar)
// Float32List _normFine(List<double> a) {
//   final int n = a.length;
//   double s = 0;
//   for (final v in a) {
//     s += v;
//   }
//   final double m = s / n;
//   double q = 0;
//   for (final v in a) {
//     q += (v - m) * (v - m);
//   }
//   final double d = q > 0 ? math.sqrt(q) : 1;
//   final Float32List out = Float32List(n);
//   for (int i = 0; i < n; i++) {
//     out[i] = (a[i] - m) / d;
//   }
//   return out;
// }
//
// /// compute() — badha stock × badha baari → dar stock no best (ane kai baari)
// Map<String, dynamic> _screenWork(Map<String, dynamic> a) {
//   final Float32List q = a["q"] as Float32List; // V × L (normalized)
//   final int nv = a["v"] as int;
//   final Uint8List db = a["db"] as Uint8List; // N × L
//   final int n = a["n"] as int;
//   const int L = _fN * _fN;
//   final Float32List best = Float32List(n);
//   final Int32List bestV = Int32List(n);
//   final Float32List t = Float32List(L);
//   for (int k = 0; k < n; k++) {
//     final int off = k * L;
//     double s = 0;
//     for (int i = 0; i < L; i++) {
//       s += db[off + i];
//     }
//     final double m = s / L;
//     double qq = 0;
//     for (int i = 0; i < L; i++) {
//       final double v = db[off + i] - m;
//       t[i] = v;
//       qq += v * v;
//     }
//     final double d = qq > 0 ? math.sqrt(qq) : 1;
//     double b = -2;
//     int bv = 0;
//     for (int v = 0; v < nv; v++) {
//       final int qo = v * L;
//       double dot = 0;
//       for (int i = 0; i < L; i++) {
//         dot += q[qo + i] * t[i];
//       }
//       dot /= d;
//       if (dot > b) {
//         b = dot;
//         bv = v;
//       }
//     }
//     best[k] = b;
//     bestV[k] = bv;
//   }
//   return {"best": best, "view": bestV};
// }
//
// /// Stock image → 40×40 jhini olakh (byte ma — save karva)
// Uint8List? _fineBytes(Uint8List px, int w, int h) {
//   final f = _fineFrom(px, w, h, const [(1.0, true)], const [1.0]);
//   if (f.isEmpty) return null;
//   final out = Uint8List(_fN * _fN);
//   for (int i = 0; i < out.length; i++) {
//     out[i] = f.first[i].round().clamp(0, 255);
//   }
//   return out;
// }
//
// /// 🧵 ALAG THREAD — fingerprint + jhini olakh (UI atke nahi, badha core vapray)
// (ImgPrint?, Uint8List?) _heavyScan(
//     (Uint8List?, int, int, Uint8List?, int, int) a) {
//   ImgPrint? p;
//   Uint8List? f;
//   if (a.$1 != null) {
//     try {
//       p = _printFromRgba(a.$1!, a.$2, a.$3);
//     } catch (_) {}
//   }
//   if (a.$4 != null) {
//     try {
//       f = _fineBytes(a.$4!, a.$5, a.$6);
//     } catch (_) {}
//   }
//   return (p, f);
// }
//
// /// 🧵 Alag thread — save/load nu JSON kaam
// String _jsonOf(Object? o) => jsonEncode(o);
//
// String _encodeFine(Map<String, Uint8List> m) =>
//     jsonEncode({for (final e in m.entries) e.key: base64Encode(e.value)});
//
// Map<String, Uint8List> _decodeFine(String raw) {
//   final Map<String, Uint8List> out = {};
//   try {
//     final Map j = jsonDecode(raw) as Map;
//     j.forEach((k, v) {
//       try {
//         final b = base64Decode(v as String);
//         if (b.length == _fN * _fN) out[k as String] = b;
//       } catch (_) {}
//     });
//   } catch (_) {}
//   return out;
// }
//
// /// Tamari photo — 4 roop (je sauthi saru male e)
// Future<List<ImgPrint>> _makeQueryPrints(Uint8List bytes) async {
//   final d0 = await _decodeRgba(bytes);
//   if (d0 == null) return [];
//   final d = _trimDark(d0.px, d0.w, d0.h); // 📱 screenshot na kaala patta
//   final out = <ImgPrint>[];
//   for (final v in const [
//     (1.0, true),   // auto
//     (0.75, true),  // vachche no bhaag
//     (0.55, true),  // vadhu zoom (item nanu hoy to)
//     (1.0, false),  // puri photo
//   ]) {
//     try {
//       out.add(_printFromRgba(d.px, d.w, d.h, zoom: v.$1, segment: v.$2));
//     } catch (_) {}
//   }
//   return out;
// }
//
// /// Segment pachhi (rgb, fg, item box, region) — fine check mate
// typedef _SegCb = void Function(Uint8List rgb, Uint8List fg, int bx0, int by0,
//     int bx1, int by1, int rx0, int ry0, int rx1, int ry1);
//
// ImgPrint _printFromRgba(Uint8List px, int w, int h,
//     {double zoom = 1, bool segment = true, _SegCb? onSeg}) {
//   final int total = w * h;
//
//   // ---- 1) Safed par RGB (transparent PNG)
//   final Uint8List rgb = Uint8List(total * 3);
//   for (int i = 0; i < total; i++) {
//     final int a = px[i * 4 + 3];
//     rgb[i * 3] = (px[i * 4] + 255 - a).clamp(0, 255);
//     rgb[i * 3 + 1] = (px[i * 4 + 1] + 255 - a).clamp(0, 255);
//     rgb[i * 3 + 2] = (px[i * 4 + 2] + 255 - a).clamp(0, 255);
//   }
//
//   // ---- 2) Zoom → vachche no bhaag j
//   int rx0 = 0, ry0 = 0, rw = w, rh = h;
//   if (zoom < 1) {
//     rw = (w * zoom).round().clamp(8, w);
//     rh = (h * zoom).round().clamp(8, h);
//     rx0 = (w - rw) ~/ 2;
//     ry0 = (h - rh) ~/ 2;
//   }
//   final int rx1 = rx0 + rw, ry1 = ry0 + rh;
//
//   // ---- 3) Background olkho (kinara na rang)
//   final Uint8List fg = Uint8List(total); // 1 = item
//   for (int y = ry0; y < ry1; y++) {
//     for (int x = rx0; x < rx1; x++) {
//       fg[y * w + x] = 1;
//     }
//   }
//   int bx0 = rx0, by0 = ry0, bx1 = rx1, by1 = ry1;
//
//   if (segment) {
//     final int bt = ((rw < rh ? rw : rh) ~/ 24).clamp(2, 8);
//
//     List<int> median(Iterable<int> idx) {
//       final r = <int>[], g = <int>[], b = <int>[];
//       for (final i in idx) {
//         r.add(rgb[i * 3]);
//         g.add(rgb[i * 3 + 1]);
//         b.add(rgb[i * 3 + 2]);
//       }
//       r.sort();
//       g.sort();
//       b.sort();
//       final m = r.length ~/ 2;
//       return [r[m], g[m], b[m]];
//     }
//
//     Iterable<int> side(int xa, int xb, int ya, int yb) sync* {
//       for (int y = ya; y < yb; y++) {
//         for (int x = xa; x < xb; x++) {
//           yield y * w + x;
//         }
//       }
//     }
//
//     final sides = [
//       side(rx0, rx1, ry0, ry0 + bt), // upar
//       side(rx0, rx1, ry1 - bt, ry1), // niche
//       side(rx0, rx0 + bt, ry0, ry1), // dabe
//       side(rx1 - bt, rx1, ry0, ry1), // jamne
//     ];
//     final List<List<int>> bg = [for (final sd in sides) median(sd)];
//
//     int dist(int i) {
//       int best = 1 << 30;
//       for (final c in bg) {
//         final int dr = rgb[i * 3] - c[0];
//         final int dg = rgb[i * 3 + 1] - c[1];
//         final int db = rgb[i * 3 + 2] - c[2];
//         final int d = dr * dr + dg * dg + db * db;
//         if (d < best) best = d;
//       }
//       return best;
//     }
//
//     // Border pote ketlo badlay chhe → threshold
//     final List<int> bd = [for (final sd in sides) for (final i in sd) dist(i)]
//       ..sort();
//     final int p90 = bd[(bd.length * 0.9).floor().clamp(0, bd.length - 1)];
//     final int thr = (p90 * 9 ~/ 4) > 28 * 28 ? p90 * 9 ~/ 4 : 28 * 28;
//
//     // Kinara no rang "rang vagar no" (safed / grey / kalo / silk)?
//     final List<int> bs = [
//       for (final sd in sides)
//         for (final i in sd) _sat(rgb, i),
//     ]..sort();
//     final int bMed = bs[bs.length ~/ 2];
//     final int bP90 = bs[(bs.length * 0.9).floor().clamp(0, bs.length - 1)];
//     final bool neutralBg = bMed < 25;
//     final int satThr = bP90 * 2 > 35 ? bP90 * 2 : 35;
//     final int strict = p90 * 4 > 60 * 60 ? p90 * 4 : 60 * 60;
//
//     final Uint8List mask = Uint8List(total);
//     final List<int> rowC = List.filled(h, 0);
//     int cnt = 0;
//     for (int y = ry0; y < ry1; y++) {
//       for (int x = rx0; x < rx1; x++) {
//         final int i = y * w + x;
//         final int r = rgb[i * 3], g = rgb[i * 3 + 1], bl = rgb[i * 3 + 2];
//         final int mn = r < g ? (r < bl ? r : bl) : (g < bl ? g : bl);
//         final bool on;
//         if (neutralBg) {
//           // 🎯 Sadu background → sona / meena / rang vala pixel = item
//           //    (silk ni chamak, padchhayo ganay nahi)
//           on = mn < 235 && (_sat(rgb, i) > satThr || dist(i) > strict);
//         } else {
//           // Rangin background (lakdu, velvet, haath) → kinara thi alag
//           // Ekdam safed (hira / chamak) → background ganay: safed background
//           // vali stock photo ma pan e dekhatu nathi, etle banne sarkha rahe
//           on = mn < 215 && dist(i) > thr;
//         }
//         if (on) {
//           mask[i] = 1;
//           rowC[y]++;
//           cnt++;
//         }
//       }
//     }
//
//     final double frac = cnt / (rw * rh);
//     if (frac >= 0.02 && frac <= 0.92) {
//       // 📌 Sauthi moṭo bhaag j (niche/upar lakhan, naam, patti — chhoḍo)
//       final int minR = (rw * 0.015).ceil().clamp(1, 1 << 20);
//       final yb = _bestBand(rowC, ry0, ry1, minR,
//           (rh * 0.03).round().clamp(2, 1 << 20));
//       if (yb != null) {
//         final List<int> colC = List.filled(w, 0);
//         for (int y = yb.$1; y <= yb.$2; y++) {
//           for (int x = rx0; x < rx1; x++) {
//             if (mask[y * w + x] == 1) colC[x]++;
//           }
//         }
//         final xb = _bestBand(
//             colC,
//             rx0,
//             rx1,
//             ((yb.$2 - yb.$1 + 1) * 0.015).ceil().clamp(1, 1 << 20),
//             (rw * 0.03).round().clamp(2, 1 << 20));
//         if (xb != null && xb.$2 - xb.$1 >= 4 && yb.$2 - yb.$1 >= 4) {
//           bx0 = xb.$1;
//           by0 = yb.$1;
//           bx1 = xb.$2 + 1;
//           by1 = yb.$2 + 1;
//           // Box bahar nu (lakhan vagere) ganay nahi
//           fg.fillRange(0, total, 0);
//           for (int y = by0; y < by1; y++) {
//             for (int x = bx0; x < bx1; x++) {
//               fg[y * w + x] = mask[y * w + x];
//             }
//           }
//         }
//       }
//     }
//     // nahi to → puri photo (background olkhayo nahi)
//   }
//
//   onSeg?.call(rgb, fg, bx0, by0, bx1, by1, rx0, ry0, rx1, ry1);
//
//   // ---- 4) Item ni aaju-baju square crop → 64×64
//   const int n = 64;
//   final double bw = (bx1 - bx0).toDouble(), bh = (by1 - by0).toDouble();
//   final double sideLen = (bw > bh ? bw : bh) * 1.06;
//   final double sx0 = (bx0 + bx1) / 2 - sideLen / 2;
//   final double sy0 = (by0 + by1) / 2 - sideLen / 2;
//   final double step = sideLen / n;
//
//   final List<double> gray = List.filled(n * n, 0);
//   final List<double> hist = List.filled(64, 0);
//   final List<double> accent = List.filled(12, 0);
//   int hc = 0;
//
//   for (int ty = 0; ty < n; ty++) {
//     for (int tx = 0; tx < n; tx++) {
//       double gs = 0;
//       for (int k = 0; k < 4; k++) {
//         final int xi = (sx0 + (tx + ((k & 1) + 0.5) / 2) * step).floor();
//         final int yi = (sy0 + (ty + ((k >> 1) + 0.5) / 2) * step).floor();
//         if (xi < rx0 || yi < ry0 || xi >= rx1 || yi >= ry1) {
//           gs += 255;
//           continue;
//         }
//         final int i = yi * w + xi;
//         if (fg[i] == 0) {
//           gs += 255; // background → safed
//           continue;
//         }
//         final int r = rgb[i * 3], g = rgb[i * 3 + 1], b = rgb[i * 3 + 2];
//         gs += 0.299 * r + 0.587 * g + 0.114 * b;
//         _colorBins(r, g, b, hist, accent);
//         hc++;
//       }
//       gray[ty * n + tx] = gs / 4;
//     }
//   }
//   if (hc == 0) {
//     hist[63] = 1;
//   } else {
//     for (int i = 0; i < 64; i++) {
//       hist[i] /= hc;
//     }
//     for (int i = 0; i < 12; i++) {
//       accent[i] /= hc;
//     }
//   }
//
//   // ---- d16: 17×16 block → 256 bit (jhini design)
//   final List<double> e = List.filled(17 * 16, 0);
//   for (int y = 0; y < n; y++) {
//     final int by = (y * 16) ~/ n;
//     for (int x = 0; x < n; x++) {
//       e[by * 17 + (x * 17) ~/ n] += gray[y * n + x];
//     }
//   }
//   final Uint8List d16 = Uint8List(32);
//   int bit = 0;
//   for (int y = 0; y < 16; y++) {
//     for (int x = 0; x < 16; x++) {
//       if (e[y * 17 + x] < e[y * 17 + x + 1]) {
//         d16[bit >> 3] |= 1 << (7 - (bit & 7));
//       }
//       bit++;
//     }
//   }
//
//   // ---- dHash: 9×8 block average, baju-baju sarkhamni
//   final List<double> d = List.filled(9 * 8, 0);
//   final List<int> dc = List.filled(9 * 8, 0);
//   for (int y = 0; y < n; y++) {
//     final int by = (y * 8) ~/ n;
//     for (int x = 0; x < n; x++) {
//       final int bx = (x * 9) ~/ n;
//       d[by * 9 + bx] += gray[y * n + x];
//       dc[by * 9 + bx]++;
//     }
//   }
//   for (int i = 0; i < d.length; i++) {
//     d[i] /= dc[i];
//   }
//   int dh = 0;
//   for (int y = 0; y < 8; y++) {
//     for (int x = 0; x < 8; x++) {
//       dh = (dh << 1) | (d[y * 9 + x] < d[y * 9 + x + 1] ? 1 : 0);
//     }
//   }
//
//   // ---- aHash: 8×8 block average vs kul average
//   final List<double> a = List.filled(64, 0);
//   for (int y = 0; y < n; y++) {
//     for (int x = 0; x < n; x++) {
//       a[(y >> 3) * 8 + (x >> 3)] += gray[y * n + x];
//     }
//   }
//   double avg = 0;
//   for (final v in a) {
//     avg += v;
//   }
//   avg /= 64;
//   int ah = 0;
//   for (final v in a) {
//     ah = (ah << 1) | (v >= avg ? 1 : 0);
//   }
//
//   return ImgPrint(dh, ah, hist, d16, accent);
// }
//
// int _sat(Uint8List rgb, int i) {
//   final int r = rgb[i * 3], g = rgb[i * 3 + 1], b = rgb[i * 3 + 2];
//   final int mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
//   final int mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
//   return mx - mn;
// }
//
// /// Lagatar bhare line no sauthi moṭo patto (nana gap chalavi lye)
// (int, int)? _bestBand(List<int> cnt, int lo, int hi, int minV, int tol) {
//   (int, int)? best;
//   int bestMass = 0;
//   int start = -1, end = -1, mass = 0, gap = 0;
//   void close() {
//     if (start >= 0 && mass > bestMass) {
//       bestMass = mass;
//       best = (start, end);
//     }
//     start = -1;
//     mass = 0;
//     gap = 0;
//   }
//
//   for (int i = lo; i < hi; i++) {
//     if (cnt[i] >= minV) {
//       if (start < 0) start = i;
//       end = i;
//       mass += cnt[i];
//       gap = 0;
//     } else if (start >= 0) {
//       gap++;
//       if (gap > tol) close();
//     }
//   }
//   close();
//   return best;
// }
//
// int _hamming(int a, int b) {
//   int x = a ^ b;
//   int c = 0;
//   while (x != 0) {
//     x &= x - 1;
//     c++;
//   }
//   return c;
// }
//
// /// Rang → bin (HSV). Sonu / meena / nang alag olkhay
// void _colorBins(int r, int g, int b, List<double> hist, List<double> accent) {
//   final int mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
//   final int mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
//   final double v = mx / 255;
//   final double sat = mx == 0 ? 0 : (mx - mn) / mx;
//   double h = 0; // 0..360
//   if (mx != mn) {
//     final double c = (mx - mn).toDouble();
//     if (mx == r) {
//       h = 60 * (((g - b) / c) % 6);
//     } else if (mx == g) {
//       h = 60 * (((b - r) / c) + 2);
//     } else {
//       h = 60 * (((r - g) / c) + 4);
//     }
//     if (h < 0) h += 360;
//   }
//   if (sat > 0.2 && v > 0.15) {
//     final int hb = (h / 360 * 16).floor() % 16;
//     final int vb = (v * 3).floor().clamp(0, 2);
//     hist[hb * 3 + vb] += 1;
//   } else {
//     hist[48 + (v * 16).floor().clamp(0, 15)] += 1;
//   }
//   // Sona (pilo) sivay no ghaṭṭ rang = meena / nang
//   if (sat > 0.35 && v > 0.25 && !(h >= 22 && h <= 58)) {
//     accent[(h / 360 * 12).floor() % 12] += 1;
//   }
// }
//
// /// 0..255 ma ketla 1 bit
// final List<int> _pop8 = List<int>.generate(256, (i) {
//   int c = 0, x = i;
//   while (x != 0) {
//     x &= x - 1;
//     c++;
//   }
//   return c;
// });
//
// int _hamBytes(Uint8List a, Uint8List b) {
//   int c = 0;
//   for (int i = 0; i < a.length && i < b.length; i++) {
//     c += _pop8[a[i] ^ b[i]];
//   }
//   return c;
// }
//
// /// 0..1 — 1 = ekdam sarkhu
// ///   aakar (8 + 16 grid) + ujas + rang + meena/nang no rang
// double _similarity(ImgPrint q, ImgPrint t) {
//   final double d8 = 1 - _hamming(q.dHash, t.dHash) / 64;
//   final double d16 = 1 - _hamBytes(q.d16, t.d16) / 256;
//   final double aS = 1 - _hamming(q.aHash, t.aHash) / 64;
//   double hS = 0;
//   for (int i = 0; i < 64; i++) {
//     hS += q.hist[i] < t.hist[i] ? q.hist[i] : t.hist[i];
//   }
//   double diff = 0, tot = 0;
//   for (int i = 0; i < 12; i++) {
//     diff += (q.accent[i] - t.accent[i]).abs();
//     tot += q.accent[i] + t.accent[i];
//   }
//   final double acS = 1 - (diff / (tot > 0.03 ? tot : 0.03)).clamp(0.0, 1.0);
//   return d8 * 0.25 + d16 * 0.25 + aS * 0.10 + hS * 0.20 + acS * 0.20;
// }
//
// /// ---------------------------------------------------------------
// /// RESULT
// /// ---------------------------------------------------------------
// class ImageSearchResult {
//   final Map<String, dynamic> item;
//   final double score; // 0..1
//   final bool exact;
//   ImageSearchResult(this.item, this.score, this.exact);
// }
//
// /// ================================================================
// /// SCREEN
// /// ================================================================
// class ImageSearchScreen extends StatefulWidget {
//   /// Page URL — Stock Gallery jevu j (branch merge hoy to e j branches)
//   final String Function(int page)? pageUrl;
//
//   /// Result par click → e item
//   final void Function(Map<String, dynamic> item)? onItemTap;
//
//   const ImageSearchScreen({super.key, this.pageUrl, this.onItemTap});
//
//   @override
//   State<ImageSearchScreen> createState() => _ImageSearchScreenState();
// }
//
// class _ImageSearchScreenState extends State<ImageSearchScreen> {
//   // 🎨 Light blue palette
//   static const Color _lbTop = Color(0xffDCE8FB);
//   static const Color _lbBottom = Color(0xffF0F5FE);
//   static const Color _lbBorder = Color(0xffC9DAF6);
//   static const Color _lbSoft = Color(0xffF5F8FE);
//   static const Color _lbText = Color(0xff2F4A78);
//   static const Color _ink = Color(0xff1C1E24);
//   static const Color _muted = Color(0xff8A8F98);
//   static const Color _green = Color(0xff16A34A);
//
//   /// v6 = background vagar, fakt item no fingerprint
//   static const String _cacheKey = "image_search_prints_v6";
//   static const int _parallel = 15; // ek sathe 10 image
//   static const int _pageParallel = 15; // ek sathe 10 stock page
//   static const int _maxSimilar = 30;
//   static const double _minScore = 0.55;
//
//   final ImagePicker _picker = ImagePicker();
//   final Dio _dio = Dio(BaseOptions(
//     responseType: ResponseType.bytes,
//     connectTimeout: const Duration(seconds: 15),
//     receiveTimeout: const Duration(seconds: 30),
//   ));
//
//   File? _query;
//   ImgPrint? _queryPrint;
//   /// Tamari photo na 4 roop (auto, 75%, 55% zoom, puri)
//   List<ImgPrint> _queryPrints = [];
//
//   List<Map<String, dynamic>> _items = []; // image vala item j
//   int _stockCount = 0;
//
//   /// 💾 static — screen bandh kari farithi kholo to pan memory ma rahe
//   static final Map<String, ImgPrint> _prints = {};
//   static Map<String, String> _cache = {};
//   static bool _cacheLoaded = false;
//
//   /// Stock list memory ma (login + page url pramane)
//   static final Map<String, List<Map<String, dynamic>>> _memItems = {};
//   static final Map<String, int> _memStock = {};
//
//   /// Login token — login badlay to stock list fari aave
//   String _token = "";
//
//   String get _scope {
//     final String Function(int)? f = widget.pageUrl;
//     final String url = f != null ? f(1) : "${ApiConstants.stock_gallery}?page=1";
//     return "$_token::$url";
//   }
//
//   /// App restart pachhi pan same rahe (String.hashCode par bharoso nahi)
//   String get _itemsKey {
//     int h = 0x811c9dc5;
//     for (final c in _scope.codeUnits) {
//       h ^= c;
//       h = (h * 0x01000193) & 0xffffffff;
//     }
//     return "image_search_items_v1_${h.toRadixString(16)}";
//   }
//
//   /// Background index (screen khulta j sharu)
//   Future<void>? _indexTask;
//   bool _indexing = false;
//   bool _indexed = false;
//
//   bool _busy = false; // photo vanchay chhe
//   String _status = "";
//   int _done = 0;
//   int _total = 0;
//   bool _cancelled = false;
//
//   List<ImageSearchResult> _exact = [];
//   List<ImageSearchResult> _similar = [];
//   bool _searched = false;
//
//   /// 🔍 Fine check (upar na 12)
//   static const int _fineTop = 12;
//   /// 💾 Dar stock image ni jhini olakh (ek vaar scan, phone ni file ma)
//   static final Map<String, Uint8List> _fineDb = {};
//   static bool _fineLoaded = false;
//   static const int _fineScreen = 60; // jhadpi sarkhamni pachhi aatla
//   List<Float64List> _queryFine = [];
//   Map<String, double> _fineScores = {};
//   bool _fining = false;
//
//   /// ✅ Pasand karela result (WhatsApp / PDF mate)
//   final Set<String> _sel = {};
//   bool _sharing = false;
//
//   /// Share / PDF hamesha (aa screen ma j bane)
//   bool get _canShare => true;
//
//   bool get _hasResults => _exact.isNotEmpty || _similar.isNotEmpty;
//
//   /// Kai select hoy to e j, nahi to badha result
//   List<ImageSearchResult> _pickResults(List<ImageSearchResult> list) =>
//       _sel.isEmpty ? list : list.where((r) => _sel.contains(_key(r.item))).toList();
//
//   List<ExportItem> _toExport(List<ImageSearchResult> list) => [
//     for (final r in list)
//       ExportItem(r.item, exact: r.exact, score: r.score),
//   ];
//
//   void _toggleSel(Map m) {
//     final k = _key(m);
//     setState(() => _sel.contains(k) ? _sel.remove(k) : _sel.add(k));
//   }
//
//   /// Section na badha select / unselect
//   void _toggleAll(List<ImageSearchResult> list) {
//     final keys = list.map((r) => _key(r.item)).toList();
//     final bool all = keys.every(_sel.contains);
//     setState(() => all ? _sel.removeAll(keys) : _sel.addAll(keys));
//   }
//
//   /// 📄 PDF / 📲 WhatsApp — aa screen ma j bane
//   ///   Upar: tame upload kareli photo
//   ///   Pachhi: Exact match → Similar (dar ek ni detail sathe)
//   Future<void> _share(bool pdf) async {
//     if (_sharing || _query == null) return;
//
//     final exact = _toExport(_pickResults(_exact));
//     final similar = _toExport(_pickResults(_similar));
//     if (exact.isEmpty && similar.isEmpty) {
//       AppMessage.error(context, "No items to share");
//       return;
//     }
//
//     setState(() => _sharing = true);
//     final ValueNotifier<String> progress = ValueNotifier("Preparing...");
//     final ValueNotifier<double?> frac = ValueNotifier(null);
//     _showShareLoader(pdf, progress, frac);
//
//     try {
//       if (pdf) {
//         final File f = await ImageSearchExport.buildPdf(
//           query: _query!,
//           exact: exact,
//           similar: similar,
//           scanned: _prints.length,
//           onProgress: (d, t) {
//             progress.value = "Adding photos $d of $t";
//             frac.value = t == 0 ? null : d / t;
//           },
//         );
//         _closeLoader();
//         if (!mounted) return;
//         await _pdfReady(f, exact: exact.length, similar: similar.length);
//       } else {
//         final files = await ImageSearchExport.buildShareImages(
//           query: _query!,
//           items: [...exact, ...similar],
//           exactCount: exact.length,
//           similarCount: similar.length,
//           onProgress: (d, t) {
//             progress.value = "Preparing images $d of $t";
//             frac.value = t == 0 ? null : d / t;
//           },
//         );
//         _closeLoader();
//         if (!mounted) return;
//         if (files.isEmpty) {
//           AppMessage.error(context, "Could not prepare images");
//           return;
//         }
//         await Share.shareXFiles(
//           files.map((f) => XFile(f.path, mimeType: "image/jpeg")).toList(),
//           text: "Image search: ${exact.length} exact, ${similar.length} similar",
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ IMAGE SEARCH SHARE ERROR => $e");
//       _closeLoader();
//       if (mounted) AppMessage.error(context, "Could not share");
//     } finally {
//       progress.dispose();
//       frac.dispose();
//       if (mounted) setState(() => _sharing = false);
//     }
//   }
//
//   bool _loaderOpen = false;
//
//   void _showShareLoader(
//       bool pdf, ValueNotifier<String> progress, ValueNotifier<double?> frac) {
//     _loaderOpen = true;
//     final Color c = pdf ? const Color(0xffDC2626) : const Color(0xff25D366);
//     final Color c2 = pdf ? const Color(0xffB91C1C) : const Color(0xff128C7E);
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       barrierColor: Colors.black.withOpacity(0.45),
//       builder: (_) => PopScope(
//         canPop: false,
//         child: Dialog(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           insetPadding: const EdgeInsets.symmetric(horizontal: 36),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 360),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(18),
//                 boxShadow: [
//                   BoxShadow(
//                     color: c.withOpacity(0.25),
//                     blurRadius: 30,
//                     offset: const Offset(0, 12),
//                   ),
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(18),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // ---- Rangin header
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [c, c2],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                       ),
//                       child: Column(
//                         children: [
//                           Container(
//                             width: 64,
//                             height: 64,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.18),
//                               shape: BoxShape.circle,
//                               border: Border.all(
//                                   color: Colors.white.withOpacity(0.4), width: 2),
//                             ),
//                             child: Icon(
//                               pdf
//                                   ? Icons.picture_as_pdf_rounded
//                                   : Icons.chat_rounded,
//                               color: Colors.white,
//                               size: 30,
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Text(
//                             pdf ? "Creating your PDF" : "Preparing for WhatsApp",
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                           const SizedBox(height: 3),
//                           Text(
//                             pdf
//                                 ? "Searched photo, exact & similar items"
//                                 : "Photos with details below each image",
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.85),
//                               fontSize: 11.5,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     // ---- Progress
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
//                       child: ValueListenableBuilder<double?>(
//                         valueListenable: frac,
//                         builder: (_, v, __) => Column(
//                           children: [
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ValueListenableBuilder<String>(
//                                     valueListenable: progress,
//                                     builder: (_, t, __) => Text(
//                                       t,
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                       style: const TextStyle(
//                                         fontSize: 12.5,
//                                         fontWeight: FontWeight.w600,
//                                         color: _ink,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 if (v != null)
//                                   Text(
//                                     "${(v * 100).round()}%",
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w800,
//                                       color: c,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                             const SizedBox(height: 10),
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(6),
//                               child: LinearProgressIndicator(
//                                 value: v,
//                                 minHeight: 7,
//                                 color: c,
//                                 backgroundColor: c.withOpacity(0.12),
//                               ),
//                             ),
//                             const SizedBox(height: 10),
//                             const Text(
//                               "Please keep the app open",
//                               style: TextStyle(fontSize: 10.5, color: _muted),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _closeLoader() {
//     if (!_loaderOpen || !mounted) return;
//     _loaderOpen = false;
//     Navigator.of(context, rootNavigator: true).pop();
//   }
//
//   /// ✨ PDF taiyar → premium sheet (Open / WhatsApp / Share)
//   Future<void> _pdfReady(File f, {int exact = 0, int similar = 0}) async {
//     const Color red = Color(0xffDC2626);
//
//     String size = "";
//     try {
//       final int b = f.lengthSync();
//       size = b > 1024 * 1024
//           ? "${(b / (1024 * 1024)).toStringAsFixed(1)} MB"
//           : "${(b / 1024).toStringAsFixed(0)} KB";
//     } catch (_) {}
//     final String name = f.path.split(Platform.pathSeparator).last;
//
//     void share() => Share.shareXFiles(
//       [XFile(f.path, mimeType: "application/pdf")],
//       text: "Image search report",
//     );
//
//     Widget stat(String label, String value, Color c) => Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 9),
//         decoration: BoxDecoration(
//           color: c.withOpacity(0.07),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: c.withOpacity(0.2)),
//         ),
//         child: Column(
//           children: [
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w800,
//                 color: c,
//               ),
//             ),
//             const SizedBox(height: 1),
//             Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
//           ],
//         ),
//       ),
//     );
//
//     Widget btn({
//       required IconData icon,
//       required String label,
//       required VoidCallback onTap,
//       Color? fill,
//       Color? fg,
//       Gradient? gradient,
//     }) {
//       return Expanded(
//         child: Material(
//           color: Colors.transparent,
//           child: InkWell(
//             onTap: onTap,
//             borderRadius: BorderRadius.circular(5),
//             child: Ink(
//               height: 46,
//               decoration: BoxDecoration(
//                 color: fill,
//                 gradient: gradient,
//                 borderRadius: BorderRadius.circular(5),
//                 border: fill == Colors.white
//                     ? Border.all(color: _lbBorder)
//                     : null,
//               ),
//               child: Center(
//                 child: FittedBox(
//                   fit: BoxFit.scaleDown,
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(icon, size: 18, color: fg ?? Colors.white),
//                       const SizedBox(width: 6),
//                       Text(
//                         label,
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w800,
//                           color: fg ?? Colors.white,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     }
//
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (sheet) => SafeArea(
//         child: Container(
//           margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.15),
//                 blurRadius: 24,
//                 offset: const Offset(0, 8),
//               ),
//             ],
//           ),
//           child: Center(
//             heightFactor: 1,
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 520),
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Center(
//                       child: Container(
//                         width: 40,
//                         height: 4,
//                         decoration: BoxDecoration(
//                           color: Colors.grey.shade300,
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     // ---- Success
//                     Row(
//                       children: [
//                         Container(
//                           width: 54,
//                           height: 54,
//                           decoration: BoxDecoration(
//                             gradient: const LinearGradient(
//                               colors: [Color(0xffEF4444), Color(0xffB91C1C)],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             borderRadius: BorderRadius.circular(14),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: red.withOpacity(0.3),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 5),
//                               ),
//                             ],
//                           ),
//                           child: const Icon(Icons.picture_as_pdf_rounded,
//                               color: Colors.white, size: 28),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   const Flexible(
//                                     child: Text(
//                                       "PDF is ready",
//                                       style: TextStyle(
//                                         fontSize: 16.5,
//                                         fontWeight: FontWeight.w800,
//                                         color: _ink,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 6),
//                                   Container(
//                                     padding: const EdgeInsets.all(2),
//                                     decoration: const BoxDecoration(
//                                       color: _green,
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: const Icon(Icons.check_rounded,
//                                         size: 12, color: Colors.white),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 3),
//                               Text(
//                                 name,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                     fontSize: 11, color: _muted),
//                               ),
//                               if (size.isNotEmpty)
//                                 Text(
//                                   "Image Search Report • $size",
//                                   style: const TextStyle(
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.w600,
//                                     color: _lbText,
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // ---- Andar shu chhe
//                     Row(
//                       children: [
//                         stat("Searched", "1", const Color(0xffC9A24A)),
//                         const SizedBox(width: 8),
//                         stat("Exact", "$exact", _green),
//                         const SizedBox(width: 8),
//                         stat("Similar", "$similar", _lbText),
//                       ],
//                     ),
//
//                     const SizedBox(height: 18),
//
//                     // ---- Actions
//                     Row(
//                       children: [
//                         btn(
//                           icon: Icons.visibility_rounded,
//                           label: "Open",
//                           fill: Colors.white,
//                           fg: _lbText,
//                           onTap: () {
//                             Navigator.pop(sheet);
//                             OpenFile.open(f.path);
//                           },
//                         ),
//                         const SizedBox(width: 10),
//                         btn(
//                           icon: Icons.chat_rounded,
//                           label: "WhatsApp",
//                           gradient: const LinearGradient(
//                               colors: [Color(0xff2BD46E), Color(0xff128C7E)]),
//                           onTap: () {
//                             Navigator.pop(sheet);
//                             share();
//                           },
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     Row(
//                       children: [
//                         btn(
//                           icon: Icons.ios_share_rounded,
//                           label: "Share to other apps",
//                           gradient: LinearGradient(
//                               colors: [AppColors.primaryDark, AppColors.secondaryDark]),
//                           onTap: () {
//                             Navigator.pop(sheet);
//                             share();
//                           },
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 6),
//                     TextButton(
//                       onPressed: () => Navigator.pop(sheet),
//                       child: const Text(
//                         "Close",
//                         style: TextStyle(
//                           fontSize: 12.5,
//                           fontWeight: FontWeight.w700,
//                           color: _muted,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   @override
//   void initState() {
//     super.initState();
//     // ⚡ Photo pasand kare e pahela j scan sharu
//     _ensureIndex();
//   }
//
//   @override
//   void dispose() {
//     _cancelled = true;
//     _saveCache(); // aadhu scan pan save
//     _saveFineDb();
//     _dio.close(force: true);
//     super.dispose();
//   }
//
//   // ============================================================
//   // CACHE
//   // ============================================================
//
//   Future<void> _loadCache() async {
//     if (_cacheLoaded) return; // 💾 ek vaar j vanchvu
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? raw = prefs.getString(_cacheKey);
//       if (raw != null) {
//         _cache = Map<String, String>.from(jsonDecode(raw) as Map);
//       }
//       // Juna format kadho (jagya na roke)
//       for (final k in [
//         "image_search_prints_v1",
//         "image_search_prints_v2",
//         "image_search_prints_v3",
//         "image_search_prints_v4",
//         "image_search_prints_v5",
//       ]) {
//         prefs.remove(k);
//       }
//       _cacheLoaded = true;
//     } catch (_) {
//       _cache = {};
//     }
//   }
//
//   /// Search mate jaruri field j save (nanu)
//   static const List<String> _keepFields = [
//     "id", "company_id", "company_name", "item_name", "label_code",
//     "qr_code", "huid", "gross_weight", "net_weight", "stock_status",
//     "is_sold", "has_image", "image_url", "image", "thumbnail_url",
//     "photo_url", "image_download_url",
//   ];
//
//   Future<void> _saveItemsCache() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final slim = [
//         for (final m in _items) {for (final k in _keepFields) k: m[k]},
//       ];
//       await prefs.setString(
//         _itemsKey,
//         jsonEncode({"stock": _stockCount, "items": slim}),
//       );
//     } catch (_) {}
//   }
//
//   /// Memory → nahi to phone ma save karelu → true = malyu (load nahi)
//   Future<bool> _loadItemsCache() async {
//     final mem = _memItems[_scope];
//     if (mem != null && mem.isNotEmpty) {
//       _items = mem;
//       _stockCount = _memStock[_scope] ?? mem.length;
//       return true;
//     }
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String? raw = prefs.getString(_itemsKey);
//       if (raw == null) return false;
//       final Map j = jsonDecode(raw) as Map;
//       final List list = j["items"] is List ? j["items"] : [];
//       if (list.isEmpty) return false;
//       _items = [
//         for (final e in list)
//           if (e is Map) Map<String, dynamic>.from(e),
//       ];
//       _stockCount = int.tryParse("${j["stock"] ?? ""}") ?? _items.length;
//       _memItems[_scope] = _items;
//       _memStock[_scope] = _stockCount;
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   static Future<File> _fineFile() async {
//     final dir = await getApplicationSupportDirectory();
//     return File("${dir.path}/image_search_fine_v1.json");
//   }
//
//   Future<void> _loadFineDb() async {
//     if (_fineLoaded) return;
//     try {
//       final f = await _fineFile();
//       if (await f.exists()) {
//         // 🧵 Moti file — alag thread ma vancho (screen atke nahi)
//         final m = await compute(_decodeFine, await f.readAsString());
//         _fineDb.addAll(m);
//       }
//       _fineLoaded = true;
//     } catch (_) {}
//   }
//
//   /// Ek save puru thay pachhi j biju (file bagde nahi)
//   static Future<void> _fineSaveChain = Future.value();
//   static Future<void> _cacheSaveChain = Future.value();
//
//   Future<void> _saveFineDb() => _fineSaveChain = _fineSaveChain.then((_) async {
//     try {
//       final f = await _fineFile();
//       // 🧵 JSON banavvanu alag thread ma
//       final String raw =
//       await compute(_encodeFine, Map<String, Uint8List>.of(_fineDb));
//       await f.writeAsString(raw, flush: true);
//     } catch (_) {}
//   });
//
//   Future<void> _saveCache() => _cacheSaveChain = _cacheSaveChain.then((_) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final String raw =
//       await compute(_jsonOf, Map<String, String>.of(_cache));
//       await prefs.setString(_cacheKey, raw);
//     } catch (_) {}
//   });
//
//   // ============================================================
//   // ITEM HELPERS
//   // ============================================================
//
//   String? _imageUrl(Map m) {
//     for (final k in ["image_url", "image", "thumbnail_url", "photo_url"]) {
//       final v = m[k];
//       if (v is String && v.trim().isNotEmpty && v != "null") return v.trim();
//     }
//     return null;
//   }
//
//   /// Image badlay to key badlay → navo fingerprint
//   String _key(Map m) => "${m["company_id"] ?? ""}|${m["id"]}|${_imageUrl(m)}";
//
//   String _s(dynamic v, [String f = "-"]) {
//     final t = v?.toString().trim() ?? "";
//     return t.isEmpty || t == "null" ? f : t;
//   }
//
//   void _set(VoidCallback fn) {
//     if (mounted && !_cancelled) setState(fn);
//   }
//
//   // ============================================================
//   // INDEX (background)
//   // ============================================================
//
//   Future<void> _ensureIndex() => _indexTask ??= _buildIndex();
//
//   Future<void> _buildIndex() async {
//     try {
//       await _loadCache();
//       await _loadFineDb();
//       await _attachToken();
//
//       // 💾 Pehla load thayelu hoy → sidhu vaparo (loading nahi)
//       final bool had = await _loadItemsCache();
//       if (!had) {
//         _set(() {
//           _indexing = true;
//           _status = "Loading stock...";
//         });
//         // ⚡ Page aave tem tem image scan pan sathe j chalu
//         //    (badha page ni raah na juo)
//         _feeding = true;
//         final Future<void> scan = _indexItems();
//         try {
//           await _loadAllItems();
//         } finally {
//           _feeding = false;
//         }
//         if (_cancelled) return;
//         if (_items.isNotEmpty) {
//           _memItems[_scope] = _items;
//           _memStock[_scope] = _stockCount;
//           _saveItemsCache(); // background ma
//         }
//         if (_next < _todo.length) {
//           _set(() => _status = "Scanning images...");
//         }
//         await scan;
//       } else {
//         if (_cancelled) return;
//         await _indexItems(); // fakt baki image j (save karela turant)
//       }
//       _indexed = true;
//     } catch (e) {
//       debugPrint("❌ IMAGE INDEX ERROR => $e");
//       _indexTask = null; // farithi try thai shake
//     } finally {
//       _set(() {
//         _indexing = false;
//         _status = "";
//       });
//       if (_queryPrint != null) {
//         _rank(); // chhello sacho result
//         _fineCheck(); // 🔍
//       }
//     }
//   }
//
//   /// Stock na badha page — pehlu page pachhi baki 6-6 ek sathe
//   Future<void> _loadAllItems() async {
//     final String Function(int) url =
//         widget.pageUrl ?? (p) => "${ApiConstants.stock_gallery}?page=$p";
//
//     final List<Map<String, dynamic>> all = [];
//     final Set<String> seen = {};
//     _stockCount = 0;
//     _items = all; // ⚡ aavta j search ma vapray
//
//     Future<({List rows, int last})?> fetch(int page) async {
//       try {
//         final res = await ApiHelper().getRequest(url(page), showLoading: false);
//         final body = res?.data;
//         if (res?.statusCode != 200 || body is! Map) return null;
//         final dynamic data = body["data"];
//         final List rows = data is List
//             ? data
//             : (data is Map && data["data"] is List ? data["data"] : []);
//         final dynamic pg =
//             body["pagination"] ?? (data is Map ? data : null) ?? body["meta"];
//         final int last =
//             int.tryParse("${pg is Map ? pg["last_page"] : ""}") ?? page;
//         return (rows: rows, last: last);
//       } catch (e) {
//         debugPrint("❌ IMAGE SEARCH PAGE $page => $e");
//         return null;
//       }
//     }
//
//     void take(List rows) {
//       _stockCount += rows.length;
//       for (final r in rows) {
//         if (r is! Map) continue;
//         final m = Map<String, dynamic>.from(r);
//         if (_imageUrl(m) == null) continue;
//         if (seen.add(_key(m))) {
//           all.add(m);
//           _enqueue(m); // ⚡ turant scan ni line ma
//         }
//       }
//     }
//
//     final first = await fetch(1);
//     if (first == null) {
//       _items = all;
//       return;
//     }
//     take(first.rows);
//     final int last = first.last.clamp(1, 500);
//
//     for (int p = 2; p <= last && !_cancelled; p += _pageParallel) {
//       _set(() => _status = "Loading stock... page $p / $last");
//       final pages = [
//         for (int q = p; q < p + _pageParallel && q <= last; q++) q,
//       ];
//       final results = await Future.wait(pages.map(fetch));
//       for (final r in results) {
//         if (r != null) take(r.rows);
//       }
//     }
//
//     _items = all;
//     debugPrint("🔎 IMAGE SEARCH: $_stockCount items, ${all.length} with image");
//   }
//
//   /// Login token (image private hoy to)
//   Future<void> _attachToken() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       for (final k in ["token", "access_token", "auth_token", "api_token"]) {
//         final t = prefs.getString(k);
//         if (t != null && t.isNotEmpty) {
//           _token = t;
//           _dio.options.headers["Authorization"] = "Bearer $t";
//           _dio.options.headers["Accept"] = "*/*";
//           return;
//         }
//       }
//     } catch (_) {}
//   }
//
//   /// image_url → na male to image_download_url
//   Future<Uint8List?> _download(Map m) async {
//     for (final url in [_imageUrl(m), m["image_download_url"]?.toString()]) {
//       if (url == null || url.isEmpty || url == "null") continue;
//       try {
//         final res = await _dio.get<List<int>>(url);
//         final d = res.data;
//         if (d != null && d.length > 64 && d.first != 0x7B) {
//           return d is Uint8List ? d : Uint8List.fromList(d);
//         }
//       } catch (_) {}
//     }
//     return null;
//   }
//
//   /// ⚡ Scan ni line (page aave tem vadhe)
//   final List<Map<String, dynamic>> _todo = [];
//   int _next = 0;
//   bool _feeding = false;
//
//   void _enqueue(Map<String, dynamic> m) {
//     final k = _key(m);
//     if (!_prints.containsKey(k)) {
//       final cached = _cache[k];
//       final p = cached == null ? null : ImgPrint.decode(cached);
//       if (p != null) _prints[k] = p;
//     }
//     if (!_prints.containsKey(k) || !_fineDb.containsKey(k)) {
//       _todo.add(m);
//       _total = _todo.length;
//     }
//   }
//
//   Future<void> _indexItems() async {
//     _todo.clear();
//     _next = 0;
//     _done = 0;
//     _total = 0;
//     for (final m in _items) {
//       _enqueue(m);
//     }
//     if (_todo.isEmpty && !_feeding) return;
//
//     _set(() {
//       _indexing = true;
//       if (!_feeding) _status = "Scanning images...";
//     });
//
//     final Stopwatch clock = Stopwatch()..start();
//     int lastSave = 0, lastRank = 0, lastUi = 0;
//
//     Future<void> worker() async {
//       while (!_cancelled) {
//         if (_next >= _todo.length) {
//           if (_feeding) {
//             // Navo page aave tyar sudhi thodi raah
//             await Future.delayed(const Duration(milliseconds: 120));
//             continue;
//           }
//           return;
//         }
//         final m = _todo[_next++];
//         final k = _key(m);
//         try {
//           final data = await _download(m);
//           if (data != null) {
//             final bool needP = !_prints.containsKey(k);
//             final bool needF = !_fineDb.containsKey(k);
//             // Decode (engine thread) — banne sathe
//             final dd = await Future.wait([
//               needP ? _decodeRgba(data) : Future.value(null),
//               needF ? _decodeRgba(data, 320) : Future.value(null),
//             ]);
//             final a = dd[0], b = dd[1];
//             if (a != null || b != null) {
//               // 🧵 Bhaare ganatri alag thread ma
//               final r = await compute(_heavyScan, (
//               a?.px, a?.w ?? 0, a?.h ?? 0,
//               b?.px, b?.w ?? 0, b?.h ?? 0,
//               ));
//               if (r.$1 != null) {
//                 _prints[k] = r.$1!;
//                 _cache[k] = r.$1!.encode();
//               }
//               if (r.$2 != null) _fineDb[k] = r.$2!;
//             }
//           }
//         } catch (e) {
//           debugPrint("⚠️ IMAGE SKIP ${m["id"]} => $e");
//         }
//         _done++;
//
//         final int now = clock.elapsedMilliseconds;
//         // Vachche vachche save (25 sec e) — screen bandh thay to pan kaam na jay
//         if (now - lastSave > 25000) {
//           lastSave = now;
//           _saveCache();
//           _saveFineDb();
//         }
//         // Live result (1.5 sec e) + progress (0.3 sec e)
//         final bool last = _done == _total && !_feeding;
//         if (_queryPrint != null && (now - lastRank > 1500 || last)) {
//           lastRank = now;
//           lastUi = now;
//           _rank();
//         } else if (now - lastUi > 300 || last) {
//           lastUi = now;
//           _set(() {});
//         }
//       }
//     }
//
//     await Future.wait(List.generate(_parallel, (_) => worker()));
//     await _saveCache();
//     await _saveFineDb();
//   }
//
//   // ============================================================
//   // SEARCH
//   // ============================================================
//
//   Future<void> _pick(ImageSource source) async {
//     try {
//       final XFile? x = await _picker.pickImage(
//         source: source,
//         maxWidth: 1200,
//         imageQuality: 90,
//       );
//       if (x == null) return;
//
//       setState(() {
//         _query = File(x.path);
//         _queryPrint = null;
//         _queryPrints = [];
//         _queryFine = [];
//         _fineScores = {};
//         _sel.clear();
//         _exact = [];
//         _similar = [];
//         _searched = false;
//       });
//
//       await _search();
//     } catch (e) {
//       debugPrint("❌ IMAGE PICK ERROR => $e");
//       if (mounted) AppMessage.error(context, "Could not open the image");
//     }
//   }
//
//   Future<void> _search() async {
//     if (_query == null || _busy) return;
//
//     _set(() => _busy = true);
//     try {
//       if (_queryPrint == null) {
//         _queryPrints = await _makeQueryPrints(await _query!.readAsBytes());
//         _queryPrint = _queryPrints.isEmpty ? null : _queryPrints.first;
//       }
//       if (_queryPrint == null) {
//         if (mounted) AppMessage.error(context, "This image could not be read");
//         return;
//       }
//     } finally {
//       _set(() => _busy = false);
//     }
//
//     // Atyar sudhi scan thayela sathe turant result
//     _rank();
//
//     // Scan baki hoy to chalu rahe — result live update thashe
//     if (!_indexed) {
//       await _ensureIndex();
//     } else if (!_indexing) {
//       await _fineCheck(); // 🔍 upar na 12 jhinvat thi
//     }
//   }
//
//   /// 🔍 Upar na 12 item ne jhinvat thi sarkhavo → Exact pakku
//   Future<void> _fineCheck() async {
//     final File? query = _query;
//     if (query == null || _fining || _queryPrints.isEmpty) return;
//     _set(() => _fining = true);
//     try {
//       if (_queryFine.isEmpty) {
//         final d0 = await _decodeRgba(await query.readAsBytes(), 320);
//         if (d0 == null) return;
//         final d = _trimDark(d0.px, d0.w, d0.h);
//         _queryFine = _queryFineViews(d.px, d.w, d.h);
//       }
//       if (_queryFine.isEmpty || _query != query) return;
//
//       // 1) Fingerprint pramane upar na 12
//       final qs = _queryPrints;
//       final scored = <(Map<String, dynamic>, double)>[];
//       for (final m in _items) {
//         final p = _prints[_key(m)];
//         if (p == null) continue;
//         double s = 0;
//         for (final q in qs) {
//           final double v = _similarity(q, p);
//           if (v > s) s = v;
//         }
//         scored.add((m, s));
//       }
//       scored.sort((a, b) => b.$2.compareTo(a.$2));
//       final Map<String, Map<String, dynamic>> pick = {
//         for (final e in scored.take(_fineTop)) _key(e.$1): e.$1,
//       };
//
//       // 2) 🔍 Badha 1785 × badhi baari — jhadpi sarkhamni (alag thread)
//       final keys = <String>[];
//       final itemOf = <String, Map<String, dynamic>>{};
//       for (final m in _items) {
//         final k = _key(m);
//         if (_fineDb.containsKey(k)) {
//           keys.add(k);
//           itemOf[k] = m;
//         }
//       }
//       for (final k in pick.keys) {
//         itemOf.putIfAbsent(k, () => pick[k]!);
//       }
//       const int L = _fN * _fN;
//       final int nv = _queryFine.length;
//       final Float32List qFlat = Float32List(nv * L);
//       for (int v = 0; v < nv; v++) {
//         qFlat.setRange(v * L, (v + 1) * L, _normFine(_queryFine[v]));
//       }
//       final Uint8List db = Uint8List(keys.length * L);
//       for (int i = 0; i < keys.length; i++) {
//         db.setRange(i * L, (i + 1) * L, _fineDb[keys[i]]!);
//       }
//       final Map<String, dynamic> sr = await compute(
//           _screenWork, {"q": qFlat, "v": nv, "db": db, "n": keys.length});
//       if (_query != query) return;
//       final Float32List sBest = sr["best"] as Float32List;
//
//       final order = List<int>.generate(keys.length, (i) => i)
//         ..sort((a, b) => sBest[b].compareTo(sBest[a]));
//       for (final i in order.take(_fineScreen)) {
//         pick[keys[i]] = itemOf[keys[i]]!;
//       }
//
//       // 3) Pasand karela ne puri jhinvat thi:
//       //    aakar (gray) + kinar (edge) + rang (sonu / meena / nang)
//       final List<Float64List> qGrad = [for (final q in _queryFine) _gradDesc(q)];
//       final Map<String, double> res = {};
//       for (final entry in pick.entries) {
//         final t = _fineDb[entry.key];
//         if (t == null) continue;
//         final Float64List tf = Float64List.fromList([for (final v in t) v.toDouble()]);
//         final Float64List tg = _gradDesc(tf);
//
//         // Sauthi sari baari (aakar + kinar)
//         int bv = 0;
//         double b0 = -2;
//         for (int v = 0; v < nv; v++) {
//           final double c = 0.5 * _nccFlat(_queryFine[v], tf) + 0.5 * _nccFlat(qGrad[v], tg);
//           if (c > b0) {
//             b0 = c;
//             bv = v;
//           }
//         }
//         // E baari ne thodu khasvi ne
//         final double shifted = 0.5 * _ncc(_queryFine[bv], tf) + 0.5 * _ncc(qGrad[bv], tg);
//         final double shape = math.max(b0, shifted);
//
//         // Rang
//         double col = 0;
//         final ImgPrint? tp = _prints[entry.key];
//         if (tp != null) {
//           for (final q in _queryPrints) {
//             final v = _colourSim(q, tp);
//             if (v > col) col = v;
//           }
//         }
//         res[entry.key] = shape * 0.75 + col * 0.25;
//       }
//       if (_query != query) return;
//       // 🐞 Logcat: upar na 5 (label → score)
//       final dbg = res.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
//       debugPrint("🔍 IMAGE FINE TOP: ${dbg.take(5).map((e) {
//         final m = itemOf[e.key] ?? pick[e.key];
//         return "${_s(m?["label_code"] ?? m?["qr_code"])}=${(e.value * 100).toStringAsFixed(1)}";
//       }).join("  ")}");
//       _fineScores = res;
//       _rank();
//     } catch (e) {
//       debugPrint("⚠️ IMAGE FINE ERR => $e");
//     } finally {
//       _set(() => _fining = false);
//     }
//   }
//
//   /// Exact: sauthi upar vado — score uncho ane bija thi chokhkho aagal
//   static const double _exactMin = 0.72;
//   static const double _exactSure = 0.85;
//
//   void _rank() {
//     final List<ImgPrint> qs =
//     _queryPrints.isNotEmpty ? _queryPrints : [if (_queryPrint != null) _queryPrint!];
//     if (qs.isEmpty) return;
//
//     final List<ImageSearchResult> all = [];
//     for (final m in _items) {
//       final p = _prints[_key(m)];
//       if (p == null) continue;
//       double s = 0;
//       for (final q in qs) {
//         final double v = _similarity(q, p);
//         if (v > s) s = v;
//       }
//       if (s >= _minScore || _fineScores.containsKey(_key(m))) {
//         all.add(ImageSearchResult(m, s, false));
//       }
//     }
//     all.sort((a, b) => b.score.compareTo(a.score));
//
//     final List<ImageSearchResult> exact = [];
//     final List<ImageSearchResult> similar = [];
//
//     // 🔍 Fine check thayu hoy → enu j pakku
//     if (_fineScores.isNotEmpty) {
//       double f(ImageSearchResult r) => _fineScores[_key(r.item)] ?? -2;
//       final checked = all.where((r) => _fineScores.containsKey(_key(r.item))).toList()
//         ..sort((a, b) => f(b).compareTo(f(a)));
//       if (checked.isNotEmpty) {
//         final double best = f(checked.first);
//
//         // 📸 E j photo bija item ma pan hoy (bija company / branch ma copy)
//         //    → e "bijo" nathi, e pan Exact. Gap sacha bija item thi j gano.
//         final Uint8List? bt = _fineDb[_key(checked.first.item)];
//         final Float64List? bf =
//         bt == null ? null : Float64List.fromList([for (final v in bt) v.toDouble()]);
//         bool isDup(ImageSearchResult r) {
//           if (bf == null) return false;
//           final t = _fineDb[_key(r.item)];
//           if (t == null) return false;
//           final tf = Float64List.fromList([for (final v in t) v.toDouble()]);
//           return _nccFlat(bf, tf) >= 0.97 && (best - f(r)) <= 0.06;
//         }
//
//         final dups = [for (final r in checked.skip(1)) if (isDup(r)) r];
//         final others = [for (final r in checked.skip(1)) if (!isDup(r)) r];
//         final double second = others.isNotEmpty ? f(others.first) : 0;
//         // Banne rit (fingerprint + jhini chakasni) e j item ne pehlo kahe?
//         final dupKeys = {for (final r in [checked.first, ...dups]) _key(r.item)};
//         final int coarseIdx = all
//             .where((r) => !dupKeys.contains(_key(r.item)) || _key(r.item) == _key(checked.first.item))
//             .toList()
//             .indexWhere((r) => dupKeys.contains(_key(r.item)));
//         final bool agree = coarseIdx == 0 ||
//             (coarseIdx >= 0 && coarseIdx < 3 && checked.first.score >= 0.80);
//
//         final bool sure = (best >= 0.80 && best - second >= 0.10) ||
//             (best >= 0.92 && best - second >= 0.04) ||
//             (best >= 0.65 && best - second >= 0.12) || // background / props vali photo
//             (best >= 0.68 && best - second >= 0.08) ||
//             (agree && best >= 0.62 && best - second >= 0.05) || // banne rit sahmat
//             // ✅ Database ma e j photo hoy j — jhini chakasni no pehlo = Exact
//             //    (bija thi aagal hoy, ane 60%+ sarkho hoy)
//             (best >= 0.60 && best > second);
//         if (sure) {
//           final rest = all.where((r) => !_fineScores.containsKey(_key(r.item)));
//           final r0 = checked.first;
//           exact.add(ImageSearchResult(r0.item, f(r0).clamp(0.0, 1.0), true));
//           for (final r in dups) {
//             exact.add(ImageSearchResult(r.item, f(r).clamp(0.0, 1.0), true));
//           }
//           final double low = f(checked.last).clamp(0.0, 1.0);
//           similar
//             ..addAll([
//               for (final r in others)
//                 ImageSearchResult(r.item, f(r).clamp(0.0, 1.0), false),
//             ])
//             ..addAll([
//               for (final r in rest)
//                 ImageSearchResult(r.item, math.min(r.score, low), false),
//             ]);
//           _set(() {
//             _exact = exact;
//             _similar = similar.take(_maxSimilar).toList();
//             _searched = true;
//           });
//           return;
//         }
//
//         // Pakku nathi → Exact nahi, pan jhinvat ma sara item upar
//         final good = [
//           for (final r in checked.where((r) => f(r) >= 0.45))
//             ImageSearchResult(r.item, f(r).clamp(0.0, 1.0), false),
//         ];
//         if (good.isNotEmpty) {
//           final gk = {for (final r in good) _key(r.item)};
//           final double low = good.last.score;
//           similar
//             ..addAll(good)
//             ..addAll([
//               for (final r in all.where((r) => !gk.contains(_key(r.item))))
//                 ImageSearchResult(r.item, math.min(r.score, low), false),
//             ]);
//           _set(() {
//             _exact = exact;
//             _similar = similar.take(_maxSimilar).toList();
//             _searched = true;
//           });
//           return;
//         }
//       }
//     }
//
//     if (all.isNotEmpty) {
//       final double top = all.first.score;
//       final double second = all.length > 1 ? all[1].score : 0;
//       final double gap = top - second;
//       final bool topExact = (top >= _exactSure && gap >= 0.03) ||
//           (top >= _exactMin && gap >= 0.08) ||
//           top >= 0.97;
//
//       for (int i = 0; i < all.length; i++) {
//         final r = all[i];
//         // Bijo pan ekdam e j photo (be item ma same photo) → e pan exact
//         final bool isExact = topExact &&
//             (i == 0 || (r.score >= 0.95 && r.score >= top - 0.01));
//         if (isExact) {
//           exact.add(ImageSearchResult(r.item, r.score, true));
//         } else {
//           similar.add(r);
//         }
//       }
//     }
//
//     _set(() {
//       _exact = exact;
//       _similar = similar.take(_maxSimilar).toList();
//       _searched = true;
//     });
//   }
//
//   Future<void> _clearCache() async {
//     if (_indexing) return;
//     _cache.clear();
//     _prints.clear();
//     _fineDb.clear();
//     await _saveFineDb();
//     _memItems.remove(_scope);
//     _memStock.remove(_scope);
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove(_itemsKey);
//     } catch (_) {}
//     _items = [];
//     _indexed = false;
//     _indexTask = null;
//     await _saveCache();
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Rescanning all images...")),
//       );
//     }
//     _rank();
//     await _ensureIndex();
//   }
//
//   // ============================================================
//   // UI
//   // ============================================================
//
//   bool get _isTablet => MediaQuery.of(context).size.width >= 600;
//   double get _hPad => _isTablet ? 20 : 14;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: Column(
//           children: [
//             /// 🔄 Upar badhu scroll thay
//             Expanded(
//               child: CustomScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 slivers: [
//                   SliverToBoxAdapter(child: _header()),
//                   SliverToBoxAdapter(child: _uploadCard()),
//                   if (_busy || _indexing || _fining)
//                     SliverToBoxAdapter(child: _progressCard()),
//                   if (_searched && !_busy) ..._resultSlivers(),
//                   const SliverToBoxAdapter(child: SizedBox(height: 16)),
//                 ],
//               ),
//             ),
//
//             /// 📌 Niche hamesha fix — WhatsApp + PDF
//             _shareBar(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _header() {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(_hPad, 12, _hPad, 6),
//       child: Row(
//         children: [
//           InkWell(
//             onTap: () => Navigator.pop(context),
//             borderRadius: BorderRadius.circular(10),
//             child: Container(
//               width: 38,
//               height: 38,
//               decoration: BoxDecoration(
//                 color: AppColors.primaryDark,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Icon(Icons.arrow_back_rounded,
//                   color: Colors.white, size: 20),
//             ),
//           ),
//           const SizedBox(width: 12),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "Search by Image",
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                       fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   "Find the same or similar item in stock",
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(fontSize: 11.5, color: _muted),
//                 ),
//               ],
//             ),
//           ),
//           PopupMenuButton<String>(
//             icon: const Icon(Icons.more_vert_rounded, color: _lbText),
//             onSelected: (v) {
//               if (v == "clear") _clearCache();
//             },
//             itemBuilder: (_) => const [
//               PopupMenuItem(
//                 value: "clear",
//                 child: Text("Rescan all images"),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _uploadCard() {
//     final double previewH = _isTablet ? 260 : 200;
//
//     return Center(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 1200),
//         child: Container(
//           margin: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 6),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: _lbBorder),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xff2563EB).withOpacity(0.06),
//                 blurRadius: 14,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(14),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 // Preview
//                 Container(
//                   height: previewH,
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [_lbTop, _lbBottom],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                   ),
//                   child: _query == null
//                       ? Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         width: 58,
//                         height: 58,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           shape: BoxShape.circle,
//                           border: Border.all(color: _lbBorder),
//                         ),
//                         child: const Icon(Icons.image_search_rounded,
//                             size: 28, color: _lbText),
//                       ),
//                       const SizedBox(height: 10),
//                       const Text(
//                         "Upload a photo of the jewellery",
//                         style: TextStyle(
//                           fontSize: 13.5,
//                           fontWeight: FontWeight.w700,
//                           color: _lbText,
//                         ),
//                       ),
//                       const SizedBox(height: 3),
//                       const Text(
//                         "Any background works · keep one item in the centre",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(fontSize: 11, color: _muted),
//                       ),
//                     ],
//                   )
//                       : Stack(
//                     fit: StackFit.expand,
//                     children: [
//                       Image.file(_query!, fit: BoxFit.contain),
//                       Positioned(
//                         top: 8,
//                         right: 8,
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 3),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(5),
//                             border: Border.all(color: _lbBorder),
//                           ),
//                           child: const Text(
//                             "Your photo",
//                             style: TextStyle(
//                               fontSize: 10.5,
//                               fontWeight: FontWeight.w700,
//                               color: _lbText,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Buttons
//                 Padding(
//                   padding: const EdgeInsets.all(10),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: _pickBtn(
//                           icon: Icons.photo_camera_rounded,
//                           label: "Camera",
//                           filled: true,
//                           onTap: _busy ? null : () => _pick(ImageSource.camera),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: _pickBtn(
//                           icon: Icons.photo_library_rounded,
//                           label: "Gallery",
//                           filled: false,
//                           onTap: _busy ? null : () => _pick(ImageSource.gallery),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _pickBtn({
//     required IconData icon,
//     required String label,
//     required bool filled,
//     required VoidCallback? onTap,
//   }) {
//     return Opacity(
//       opacity: onTap == null ? 0.5 : 1,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(5),
//         child: Container(
//           height: 42,
//           decoration: BoxDecoration(
//             gradient: filled
//                 ? LinearGradient(
//                 colors: [AppColors.primaryDark, AppColors.secondaryDark])
//                 : null,
//             color: filled ? null : _lbSoft,
//             borderRadius: BorderRadius.circular(5),
//             border: filled ? null : Border.all(color: _lbBorder),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 18, color: filled ? Colors.white : _lbText),
//               const SizedBox(width: 6),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w700,
//                   color: filled ? Colors.white : _lbText,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _progressCard() {
//     final bool scanning = _total > 0 && _status.startsWith("Scanning");
//     final double? v = scanning ? (_done / _total).clamp(0.0, 1.0) : null;
//     final String text = _busy
//         ? "Reading your photo..."
//         : _fining
//         ? "Checking best matches..."
//         : scanning
//         ? "Scanning images $_done / $_total"
//         : (_status.isEmpty
//         ? "Preparing..."
//         : (_status.startsWith("Loading") && _done > 0)
//         ? "$_status • $_done images scanned"
//         : _status);
//
//     return Container(
//       margin: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 0),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _lbBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const SizedBox(
//                 width: 16,
//                 height: 16,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   text,
//                   style: const TextStyle(
//                     fontSize: 12.5,
//                     fontWeight: FontWeight.w700,
//                     color: _lbText,
//                   ),
//                 ),
//               ),
//               if (scanning)
//                 Text(
//                   "${(v! * 100).round()}%",
//                   style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w800,
//                     color: _lbText,
//                   ),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(4),
//             child: LinearProgressIndicator(
//               value: v,
//               minHeight: 5,
//               backgroundColor: _lbSoft,
//               color: AppColors.primaryDark,
//             ),
//           ),
//           if (scanning) ...[
//             const SizedBox(height: 6),
//             Text(
//               _queryPrint == null
//                   ? "Scanning in background — pick your photo anytime."
//                   : "Showing results so far. They update as scanning continues.",
//               style: const TextStyle(fontSize: 10.5, color: _muted),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   List<Widget> _resultSlivers() {
//     if (_items.isEmpty && !_indexing) {
//       return [
//         SliverToBoxAdapter(
//           child: _emptyBox(
//             Icons.hide_image_outlined,
//             "None of the $_stockCount stock items have an image yet.\n"
//                 "Add photos to items in Stock Gallery, then search again.",
//           ),
//         ),
//       ];
//     }
//
//     if (_exact.isEmpty && _similar.isEmpty) {
//       if (_indexing) return [];
//       return [
//         SliverToBoxAdapter(
//           child: _emptyBox(Icons.search_off_rounded,
//               "No matching or similar item found.\nTry a clearer photo."),
//         ),
//       ];
//     }
//
//     return [
//       if (_exact.isNotEmpty) ...[
//         SliverToBoxAdapter(
//           child: _sectionTitle(Icons.verified_rounded, "Exact Match",
//               _exact.length, _green, _exact),
//         ),
//         _grid(_exact),
//       ],
//       if (_similar.isNotEmpty) ...[
//         SliverToBoxAdapter(
//           child: _sectionTitle(Icons.auto_awesome_rounded,
//               _exact.isEmpty ? "Similar Items" : "Also Similar",
//               _similar.length, _lbText, _similar),
//         ),
//         _grid(_similar),
//       ],
//     ];
//   }
//
//   Widget _sectionTitle(IconData icon, String title, int count, Color c,
//       List<ImageSearchResult> list) {
//     final bool allSel =
//         list.isNotEmpty && list.every((r) => _sel.contains(_key(r.item)));
//     return Padding(
//       padding: EdgeInsets.fromLTRB(_hPad, 16, _hPad, 8),
//       child: Row(
//         children: [
//           Icon(icon, size: 18, color: c),
//           const SizedBox(width: 6),
//           Text(
//             title,
//             style: TextStyle(
//                 fontSize: 14.5, fontWeight: FontWeight.w800, color: c),
//           ),
//           const SizedBox(width: 6),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
//             decoration: BoxDecoration(
//               color: c.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Text(
//               "$count",
//               style: TextStyle(
//                   fontSize: 11, fontWeight: FontWeight.w800, color: c),
//             ),
//           ),
//           const Spacer(),
//           if (_canShare)
//             InkWell(
//               onTap: () => _toggleAll(list),
//               borderRadius: BorderRadius.circular(5),
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       allSel
//                           ? Icons.check_box_rounded
//                           : Icons.check_box_outline_blank_rounded,
//                       size: 17,
//                       color: c,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       allSel ? "Unselect" : "Select all",
//                       style: TextStyle(
//                         fontSize: 11.5,
//                         fontWeight: FontWeight.w700,
//                         color: c,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   /// 📌 Niche fix bar — WhatsApp + PDF (badha / select karela)
//   Widget _shareBar() {
//     final int n = _sel.length;
//     final bool tablet = _isTablet;
//
//     Widget action({
//       required IconData icon,
//       required String label,
//       required Color color,
//       required VoidCallback? onTap,
//     }) {
//       return Expanded(
//         child: Opacity(
//           opacity: onTap == null ? 0.5 : 1,
//           child: InkWell(
//             onTap: onTap,
//             borderRadius: BorderRadius.circular(5),
//             child: Container(
//               height: tablet ? 44 : 42,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [color.withOpacity(0.85), color],
//                 ),
//                 borderRadius: BorderRadius.circular(5),
//                 boxShadow: [
//                   BoxShadow(
//                     color: color.withOpacity(0.25),
//                     blurRadius: 6,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Center(
//                 child: FittedBox(
//                   fit: BoxFit.scaleDown,
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(icon, color: Colors.white, size: 18),
//                       const SizedBox(width: 6),
//                       Text(
//                         label,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     }
//
//     final int total = _pickResults(_exact).length + _pickResults(_similar).length;
//     final bool ready = _hasResults && !_busy && !_sharing;
//
//     return Container(
//       padding: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: const Border(top: BorderSide(color: _lbBorder)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 10,
//             offset: const Offset(0, -3),
//           ),
//         ],
//       ),
//       child: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 900),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Ketla jashe — nani line
//               Row(
//                 children: [
//                   const Icon(Icons.ios_share_rounded, size: 14, color: _muted),
//                   const SizedBox(width: 5),
//                   Expanded(
//                     child: Text(
//                       !_hasResults
//                           ? "Search a photo to share results"
//                           : n == 0
//                           ? "All $total results will be shared"
//                           : "$n selected will be shared",
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                         color: _muted,
//                       ),
//                     ),
//                   ),
//                   if (n > 0)
//                     InkWell(
//                       onTap: () => setState(() => _sel.clear()),
//                       borderRadius: BorderRadius.circular(5),
//                       child: const Padding(
//                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                         child: Text(
//                           "Clear",
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: Color(0xffDC2626),
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 7),
//               Row(
//                 children: [
//                   action(
//                     icon: Icons.chat_rounded,
//                     label: n == 0 ? "WhatsApp" : "WhatsApp ($n)",
//                     color: const Color(0xff25D366),
//                     onTap: ready ? () => _share(false) : null,
//                   ),
//                   const SizedBox(width: 10),
//                   action(
//                     icon: Icons.picture_as_pdf_rounded,
//                     label: n == 0 ? "PDF" : "PDF ($n)",
//                     color: const Color(0xffDC2626),
//                     onTap: ready ? () => _share(true) : null,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _grid(List<ImageSearchResult> list) {
//     final double w = MediaQuery.of(context).size.width;
//     final int cols = w >= 1000 ? 5 : (w >= 700 ? 4 : (w >= 500 ? 3 : 2));
//
//     return SliverPadding(
//       padding: EdgeInsets.symmetric(horizontal: _hPad),
//       sliver: SliverGrid(
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: cols,
//           crossAxisSpacing: 10,
//           mainAxisSpacing: 10,
//           childAspectRatio: 0.68,
//         ),
//         delegate: SliverChildBuilderDelegate(
//               (_, i) => _resultCard(list[i]),
//           childCount: list.length,
//         ),
//       ),
//     );
//   }
//
//   Widget _resultCard(ImageSearchResult r) {
//     final m = r.item;
//     final int pct = (r.score * 100).round().clamp(0, 100);
//     final bool inStock = !(m["is_sold"]?.toString() == "1" ||
//         _s(m["stock_status"], "").toLowerCase().contains("out"));
//     final Color badge = r.exact ? _green : _lbText;
//     final bool sel = _sel.contains(_key(m));
//
//     return InkWell(
//       // Kai select hoy to tap = fakt SELECT (unselect nahi — e circle thi j)
//       onTap: _sel.isNotEmpty && _canShare
//           ? (sel ? null : () => _toggleSel(m))
//           : widget.onItemTap == null
//           ? (_canShare && !sel ? () => _toggleSel(m) : null)
//           : () {
//         Navigator.pop(context);
//         widget.onItemTap!(m);
//       },
//       // Long press = fakt select (unselect circle thi j)
//       onLongPress: _canShare && !sel ? () => _toggleSel(m) : null,
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: sel
//                 ? AppColors.primaryDark
//                 : (r.exact ? _green.withOpacity(0.5) : _lbBorder),
//             width: sel ? 2 : (r.exact ? 1.4 : 1),
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xff2563EB).withOpacity(0.05),
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Expanded(
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     Container(
//                       color: _lbSoft,
//                       child: Image.network(
//                         _imageUrl(m)!,
//                         fit: BoxFit.cover,
//                         // ⚡ Nani decode — jaldi dekhay, ochhi memory
//                         cacheWidth: 360,
//                         gaplessPlayback: true,
//                         errorBuilder: (_, __, ___) => const Icon(
//                             Icons.broken_image_outlined,
//                             color: _muted),
//                         loadingBuilder: (c, child, p) => p == null
//                             ? child
//                             : const Center(
//                             child: SizedBox(
//                                 width: 18,
//                                 height: 18,
//                                 child: CircularProgressIndicator(
//                                     strokeWidth: 2))),
//                       ),
//                     ),
//                     // ✅ Select circle
//                     if (_canShare)
//                       Positioned(
//                         top: 4,
//                         right: 4,
//                         child: GestureDetector(
//                           onTap: () => _toggleSel(m),
//                           child: Container(
//                             width: 26,
//                             height: 26,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               color: sel
//                                   ? AppColors.primaryDark
//                                   : Colors.white.withOpacity(0.9),
//                               shape: BoxShape.circle,
//                               border: Border.all(
//                                 color: sel ? Colors.white : _lbBorder,
//                                 width: 1.5,
//                               ),
//                             ),
//                             child: sel
//                                 ? const Icon(Icons.check_rounded,
//                                 size: 16, color: Colors.white)
//                                 : null,
//                           ),
//                         ),
//                       ),
//                     // Match %
//                     Positioned(
//                       top: 6,
//                       left: 6,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 7, vertical: 3),
//                         decoration: BoxDecoration(
//                           color: badge,
//                           borderRadius: BorderRadius.circular(5),
//                         ),
//                         child: Text(
//                           r.exact ? "Exact" : "$pct% match",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       _s(m["item_name"]),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 12.5,
//                         fontWeight: FontWeight.w800,
//                         color: _ink,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       "${_s(m["label_code"] ?? m["qr_code"])}  •  ${_s(m["gross_weight"])} g",
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(fontSize: 11, color: _muted),
//                     ),
//                     const SizedBox(height: 5),
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: (inStock ? _green : const Color(0xffDC2626))
//                                 .withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(5),
//                           ),
//                           child: Text(
//                             inStock ? "In Stock" : "Sold",
//                             style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: FontWeight.w700,
//                               color: inStock
//                                   ? _green
//                                   : const Color(0xffDC2626),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 5),
//                         Expanded(
//                           child: Text(
//                             _s(m["company_name"], ""),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             textAlign: TextAlign.right,
//                             style: const TextStyle(
//                                 fontSize: 10, color: _muted),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _emptyBox(IconData icon, String text) {
//     return Container(
//       margin: EdgeInsets.fromLTRB(_hPad, 16, _hPad, 0),
//       padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _lbBorder),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, size: 40, color: _muted.withOpacity(0.7)),
//           const SizedBox(height: 10),
//           Text(
//             text,
//             textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 13, color: _muted),
//           ),
//         ],
//       ),
//     );
//   }
// }




import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';
import 'ImageSearchExport.dart';

/// ================================================================
/// 🔎 IMAGE SEARCH — fakt Flutter app side (backend ma kai nahi)
///
/// ⚡ FAST VERSION (1900+ image mate)
///  • Native decoder — image sidhi 128px ma decode (full size nahi)
///  • 10 image ek sathe download
///  • Stock na page pan 10-10 ek sathe
///  🎯 Background game te hoy — fakt ITEM j jovay (tamari photo ane
///     database ni photo banne ma background kadhi nakhay)
///  ✅ Exact ma fakt 1 j — sauthi sacho ane bija thi chokhkho aagal
///  • Screen khulta j background ma scan sharu (photo pasand karo e
///    pahela j moṭa bhaag nu kaam thai gayu hoy)
///  • Scan chalu hoy tyare pan result dekhay (live)
///  • Fingerprint nano (~100 akshar) phone ma save — biji vaar
///    fakt navi image j scan thay, baki turant
/// ================================================================

/// ---------------------------------------------------------------
/// FINGERPRINT
/// ---------------------------------------------------------------
class ImgPrint {
  final int dHash; // 8×8 aakar
  final int aHash;
  final List<double> hist; // 64 bin rang (hue × ujas), sum = 1
  final Uint8List d16; // 16×16 jhinu aakar (256 bit)
  final List<double> accent; // 12 bin — sona sivay na rang (meena, nang)

  const ImgPrint(this.dHash, this.aHash, this.hist, this.d16, this.accent);

  String encode() {
    final Uint8List h = Uint8List(64);
    for (int i = 0; i < 64; i++) {
      h[i] = (hist[i] * 255).round().clamp(0, 255);
    }
    final Uint8List ac = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      ac[i] = (accent[i] * 1020).round().clamp(0, 255);
    }
    return "${dHash.toRadixString(16)}|${aHash.toRadixString(16)}|"
        "${base64Encode(h)}|${base64Encode(d16)}|${base64Encode(ac)}";
  }

  static ImgPrint? decode(String s) {
    try {
      final p = s.split("|");
      if (p.length != 5) return null; // juno format → farithi scan
      final Uint8List h = base64Decode(p[2]);
      final Uint8List d = base64Decode(p[3]);
      final Uint8List ac = base64Decode(p[4]);
      if (h.length != 64 || d.length != 32 || ac.length != 12) return null;
      return ImgPrint(
        int.parse(p[0], radix: 16),
        int.parse(p[1], radix: 16),
        [for (final v in h) v / 255],
        d,
        [for (final v in ac) v / 1020],
      );
    } catch (_) {
      return null;
    }
  }
}

/// ================================================================
/// 🎯 BACKGROUND GME TE HOY — fakt item ne j olkho
///
///  1) Photo nu aspect sachvi 128px ma decode
///  2) Kinara (border) na rang thi background olkho (4 baju — gradient
///     / be rang no background pan chale)
///  3) Background vala pixel → safed, item ni aaju-baju crop (square)
///  4) Rang (histogram) fakt item na pixel thi — background no rang
///     match ma gnay nahi
///  Background bahu bhid-bhad vado hoy to (olkhay nahi) → puri photo
///  Tamari photo mate 4 roop (auto, 75% zoom, 55% zoom, puri) — je
///  sauthi saru match thay e levay
/// ================================================================

const int _dec = 128;

Future<({Uint8List px, int w, int h})?> _decodeRgba(Uint8List bytes,
    [int maxSide = _dec]) async {
  ui.ImmutableBuffer? buf;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buf = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buf);
    final int iw = desc.width, ih = desc.height;
    if (iw <= 0 || ih <= 0) return null;
    final double sc = maxSide / (iw > ih ? iw : ih);
    final int tw = (iw * sc).round().clamp(8, maxSide);
    final int th = (ih * sc).round().clamp(8, maxSide);
    codec = await desc.instantiateCodec(targetWidth: tw, targetHeight: th);
    image = (await codec.getNextFrame()).image;
    final ByteData? data =
    await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return (px: data.buffer.asUint8List(), w: image.width, h: image.height);
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    buf?.dispose();
  }
}

/// Stock ni image — auto background kadhi ne
Future<ImgPrint?> _makePrint(Uint8List bytes) async {
  final d = await _decodeRgba(bytes);
  if (d == null) return null;
  try {
    return _printFromRgba(d.px, d.w, d.h);
  } catch (_) {
    return null;
  }
}

/// 📱 Screenshot hoy to kinara na kaala patta (status bar, app bar,
///    button bar) kapi nakho — fakt photo vado bhaag j rahe
({Uint8List px, int w, int h}) _trimDark(Uint8List px, int w, int h) {
  bool darkRow(int y, int x0, int x1) {
    int c = 0;
    for (int x = x0; x < x1; x++) {
      final int i = (y * w + x) * 4;
      if (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2] < 50) c++;
    }
    return c >= (x1 - x0) * 0.8;
  }

  bool darkCol(int x, int y0, int y1) {
    int c = 0;
    for (int y = y0; y < y1; y++) {
      final int i = (y * w + x) * 4;
      if (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2] < 50) c++;
    }
    return c >= (y1 - y0) * 0.8;
  }

  int y0 = 0, y1 = h, x0 = 0, x1 = w;
  while (y0 < (h * 0.45).floor() && darkRow(y0, x0, x1)) y0++;
  while (y1 > h - (h * 0.45).floor() && darkRow(y1 - 1, x0, x1)) y1--;
  while (x0 < (w * 0.45).floor() && darkCol(x0, y0, y1)) x0++;
  while (x1 > w - (w * 0.45).floor() && darkCol(x1 - 1, y0, y1)) x1--;
  if (y0 == 0 && y1 == h && x0 == 0 && x1 == w) return (px: px, w: w, h: h);

  final int nw = x1 - x0, nh = y1 - y0;
  final Uint8List out = Uint8List(nw * nh * 4);
  for (int y = 0; y < nh; y++) {
    out.setRange(y * nw * 4, (y + 1) * nw * 4, px, ((y + y0) * w + x0) * 4);
  }
  return (px: out, w: nw, h: nh);
}

/// ================================================================
/// 🔍 FINE CHECK — upar na 12 item ne vadhu jhinvat thi sarkhavo
///  (40×40 gray, thodu khasvu chalavi lye) → e j photo hoy to 0.85+,
///  biju sarkhu ghareṇu hoy to ochhu → Exact pakku
/// ================================================================
const int _fN = 40;

Float64List _fineDesc(Uint8List rgb, Uint8List fg, int w, int bx0, int by0,
    int bx1, int by1, int rx0, int ry0, int rx1, int ry1, double scale) {
  final double bw = (bx1 - bx0).toDouble(), bh = (by1 - by0).toDouble();
  final double sl = (bw > bh ? bw : bh) * 1.06 * scale;
  final double sx0 = (bx0 + bx1) / 2 - sl / 2;
  final double sy0 = (by0 + by1) / 2 - sl / 2;
  final double st = sl / _fN;
  final Float64List g = Float64List(_fN * _fN);
  for (int ty = 0; ty < _fN; ty++) {
    for (int tx = 0; tx < _fN; tx++) {
      double s = 0;
      for (int k = 0; k < 4; k++) {
        final int xi = (sx0 + (tx + ((k & 1) + 0.5) / 2) * st).floor();
        final int yi = (sy0 + (ty + ((k >> 1) + 0.5) / 2) * st).floor();
        if (xi < rx0 || yi < ry0 || xi >= rx1 || yi >= ry1 || fg[yi * w + xi] == 0) {
          s += 255;
        } else {
          final int i = yi * w + xi;
          s += 0.299 * rgb[i * 3] + 0.587 * rgb[i * 3 + 1] + 0.114 * rgb[i * 3 + 2];
        }
      }
      g[ty * _fN + tx] = s / 4;
    }
  }
  return g;
}

/// Ek photo → fine desc (zoom/segment roop, ane maap pramane)
List<Float64List> _fineFrom(Uint8List px, int w, int h,
    List<(double, bool)> views, List<double> scales) {
  final out = <Float64List>[];
  for (final v in views) {
    try {
      _printFromRgba(px, w, h, zoom: v.$1, segment: v.$2,
          onSeg: (rgb, fg, bx0, by0, bx1, by1, rx0, ry0, rx1, ry1) {
            for (final sc in scales) {
              out.add(_fineDesc(rgb, fg, w, bx0, by0, bx1, by1, rx0, ry0, rx1, ry1, sc));
            }
          });
    } catch (_) {}
  }
  return out;
}

/// Normalized correlation (±2 khasvu) — 1 = ekdam same
double _ncc(Float64List a, Float64List b) {
  double best = -1;
  for (int dy = -2; dy <= 2; dy++) {
    for (int dx = -2; dx <= 2; dx++) {
      final int ya = dy > 0 ? dy : 0, yb = dy < 0 ? -dy : 0;
      final int xa = dx > 0 ? dx : 0, xb = dx < 0 ? -dx : 0;
      final int hh = _fN - dy.abs(), ww = _fN - dx.abs();
      double sa = 0, sb = 0;
      for (int y = 0; y < hh; y++) {
        for (int x = 0; x < ww; x++) {
          sa += a[(y + ya) * _fN + x + xa];
          sb += b[(y + yb) * _fN + x + xb];
        }
      }
      final double ma = sa / (hh * ww), mb = sb / (hh * ww);
      double num = 0, da = 0, db = 0;
      for (int y = 0; y < hh; y++) {
        for (int x = 0; x < ww; x++) {
          final double p = a[(y + ya) * _fN + x + xa] - ma;
          final double q = b[(y + yb) * _fN + x + xb] - mb;
          num += p * q;
          da += p * p;
          db += q * q;
        }
      }
      if (da > 0 && db > 0) {
        final double v = num / math.sqrt(da * db);
        if (v > best) best = v;
      }
    }
  }
  return best;
}

/// Kinar (edge) — gol ghaṭṭ "blob" sathe khoṭi sarkhamni na thay
Float64List _gradDesc(Float64List d) {
  final Float64List g = Float64List(_fN * _fN);
  for (int y = 1; y < _fN - 1; y++) {
    for (int x = 1; x < _fN - 1; x++) {
      final double gx = d[y * _fN + x + 1] - d[y * _fN + x - 1];
      final double gy = d[(y + 1) * _fN + x] - d[(y - 1) * _fN + x];
      g[y * _fN + x] = math.sqrt(gx * gx + gy * gy);
    }
  }
  return g;
}

/// Sarkhamni (khasvu nahi)
double _nccFlat(Float64List a, Float64List b) {
  final int n = a.length;
  double sa = 0, sb = 0;
  for (int i = 0; i < n; i++) {
    sa += a[i];
    sb += b[i];
  }
  final double ma = sa / n, mb = sb / n;
  double num = 0, da = 0, db = 0;
  for (int i = 0; i < n; i++) {
    final double p = a[i] - ma, q = b[i] - mb;
    num += p * q;
    da += p * p;
    db += q * q;
  }
  return (da > 0 && db > 0) ? num / math.sqrt(da * db) : -1;
}

/// Fakt rang: sona no shade + meena / nang (jagya vagar)
double _colourSim(ImgPrint q, ImgPrint t) {
  double hS = 0;
  for (int i = 0; i < 64; i++) {
    hS += q.hist[i] < t.hist[i] ? q.hist[i] : t.hist[i];
  }
  double diff = 0, tot = 0;
  for (int i = 0; i < 12; i++) {
    diff += (q.accent[i] - t.accent[i]).abs();
    tot += q.accent[i] + t.accent[i];
  }
  final double acS = 1 - (diff / (tot > 0.03 ? tot : 0.03)).clamp(0.0, 1.0);
  return hS * 0.5 + acS * 0.5;
}

/// RGBA no tukdo
Uint8List _cropRgba(Uint8List px, int w, int x0, int y0, int cw, int ch) {
  final Uint8List out = Uint8List(cw * ch * 4);
  for (int y = 0; y < ch; y++) {
    out.setRange(y * cw * 4, (y + 1) * cw * 4, px, ((y + y0) * w + x0) * 4);
  }
  return out;
}

/// 🖼️ Tamari photo na ghana "baari" (window) — background / props / model
///    hoy to pan koi ek baari ma fakt item j aave → e j stock sathe male
List<Float64List> _queryFineViews(Uint8List px, int w, int h) {
  final out = <Float64List>[
    ..._fineFrom(px, w, h,
        const [(1.0, true), (0.75, true), (0.55, true), (1.0, false)], const [1.0]),
  ];
  for (final sc in const [0.9, 0.8, 0.7, 0.6]) {
    for (final ox in const [-0.1, 0.0, 0.1]) {
      for (final oy in const [-0.1, 0.0, 0.1]) {
        final int cw = (w * sc).round(), ch = (h * sc).round();
        if (cw < 24 || ch < 24) continue;
        final int x0 = ((w - cw) / 2 + ox * w).round().clamp(0, w - cw);
        final int y0 = ((h - ch) / 2 + oy * h).round().clamp(0, h - ch);
        final sub = _cropRgba(px, w, x0, y0, cw, ch);
        out.addAll(_fineFrom(sub, cw, ch, const [(1.0, true), (1.0, false)], const [1.0]));
      }
    }
  }
  return out;
}

/// Zero-mean, unit-length (sarkhamni = sidho gunakar)
Float32List _normFine(List<double> a) {
  final int n = a.length;
  double s = 0;
  for (final v in a) {
    s += v;
  }
  final double m = s / n;
  double q = 0;
  for (final v in a) {
    q += (v - m) * (v - m);
  }
  final double d = q > 0 ? math.sqrt(q) : 1;
  final Float32List out = Float32List(n);
  for (int i = 0; i < n; i++) {
    out[i] = (a[i] - m) / d;
  }
  return out;
}

/// compute() — badha stock × badha baari → dar stock no best (ane kai baari)
Map<String, dynamic> _screenWork(Map<String, dynamic> a) {
  final Float32List q = a["q"] as Float32List; // V × L (normalized)
  final int nv = a["v"] as int;
  final Uint8List db = a["db"] as Uint8List; // N × L
  final int n = a["n"] as int;
  const int L = _fN * _fN;
  final Float32List best = Float32List(n);
  final Int32List bestV = Int32List(n);
  final Float32List t = Float32List(L);
  for (int k = 0; k < n; k++) {
    final int off = k * L;
    double s = 0;
    for (int i = 0; i < L; i++) {
      s += db[off + i];
    }
    final double m = s / L;
    double qq = 0;
    for (int i = 0; i < L; i++) {
      final double v = db[off + i] - m;
      t[i] = v;
      qq += v * v;
    }
    final double d = qq > 0 ? math.sqrt(qq) : 1;
    double b = -2;
    int bv = 0;
    for (int v = 0; v < nv; v++) {
      final int qo = v * L;
      double dot = 0;
      for (int i = 0; i < L; i++) {
        dot += q[qo + i] * t[i];
      }
      dot /= d;
      if (dot > b) {
        b = dot;
        bv = v;
      }
    }
    best[k] = b;
    bestV[k] = bv;
  }
  return {"best": best, "view": bestV};
}

/// 🧵 ALAG THREAD — "Checking best matches" nu badhu bhaare kaam
///    (UI / loader atke nahi, ane 4 bhaag ma ek sathe)

/// Tamari photo → jhini baario
List<Float64List> _queryFineWork((Uint8List, int, int) a) {
  final d = _trimDark(a.$1, a.$2, a.$3);
  return _queryFineViews(d.px, d.w, d.h);
}

/// Fingerprint pramane upar na [top] (index)
List<int> _coarseWork((List<ImgPrint>, List<ImgPrint>, int) a) {
  final qs = a.$1, ps = a.$2;
  final Float64List sc = Float64List(ps.length);
  for (int i = 0; i < ps.length; i++) {
    double s = 0;
    for (final q in qs) {
      final double v = _similarity(q, ps[i]);
      if (v > s) s = v;
    }
    sc[i] = s;
  }
  final order = List<int>.generate(ps.length, (i) => i)
    ..sort((x, y) => sc[y].compareTo(sc[x]));
  return order.take(a.$3).toList();
}

/// Pasand karela ne puri jhinvat thi: aakar (gray) + kinar (edge) + rang
List<double> _refineWork(
    (List<Float64List>, List<Uint8List>, List<ImgPrint?>, List<ImgPrint>) a) {
  final qf = a.$1;
  final int nv = qf.length;
  final List<Float64List> qGrad = [for (final q in qf) _gradDesc(q)];
  final List<double> out = [];
  for (int j = 0; j < a.$2.length; j++) {
    final Float64List tf =
    Float64List.fromList([for (final v in a.$2[j]) v.toDouble()]);
    final Float64List tg = _gradDesc(tf);
    int bv = 0;
    double b0 = -2;
    for (int v = 0; v < nv; v++) {
      final double c = 0.5 * _nccFlat(qf[v], tf) + 0.5 * _nccFlat(qGrad[v], tg);
      if (c > b0) {
        b0 = c;
        bv = v;
      }
    }
    final double shifted = 0.5 * _ncc(qf[bv], tf) + 0.5 * _ncc(qGrad[bv], tg);
    final double shape = math.max(b0, shifted);
    double col = 0;
    final ImgPrint? tp = a.$3[j];
    if (tp != null) {
      for (final q in a.$4) {
        final v = _colourSim(q, tp);
        if (v > col) col = v;
      }
    }
    out.add(shape * 0.75 + col * 0.25);
  }
  return out;
}

/// Stock image → 40×40 jhini olakh (byte ma — save karva)
Uint8List? _fineBytes(Uint8List px, int w, int h) {
  final f = _fineFrom(px, w, h, const [(1.0, true)], const [1.0]);
  if (f.isEmpty) return null;
  final out = Uint8List(_fN * _fN);
  for (int i = 0; i < out.length; i++) {
    out[i] = f.first[i].round().clamp(0, 255);
  }
  return out;
}

/// 🧵 ALAG THREAD — fingerprint + jhini olakh (UI atke nahi, badha core vapray)
(ImgPrint?, Uint8List?) _heavyScan(
    (Uint8List?, int, int, Uint8List?, int, int) a) {
  ImgPrint? p;
  Uint8List? f;
  if (a.$1 != null) {
    try {
      p = _printFromRgba(a.$1!, a.$2, a.$3);
    } catch (_) {}
  }
  if (a.$4 != null) {
    try {
      f = _fineBytes(a.$4!, a.$5, a.$6);
    } catch (_) {}
  }
  return (p, f);
}

/// 🧵 Alag thread — save/load nu JSON kaam
String _jsonOf(Object? o) => jsonEncode(o);

Map _jsonMap(String raw) => jsonDecode(raw) as Map;

String _encodeFine(Map<String, Uint8List> m) =>
    jsonEncode({for (final e in m.entries) e.key: base64Encode(e.value)});

Map<String, Uint8List> _decodeFine(String raw) {
  final Map<String, Uint8List> out = {};
  try {
    final Map j = jsonDecode(raw) as Map;
    j.forEach((k, v) {
      try {
        final b = base64Decode(v as String);
        if (b.length == _fN * _fN) out[k as String] = b;
      } catch (_) {}
    });
  } catch (_) {}
  return out;
}

/// Tamari photo — 4 roop (je sauthi saru male e)
Future<List<ImgPrint>> _makeQueryPrints(Uint8List bytes) async {
  final d0 = await _decodeRgba(bytes);
  if (d0 == null) return [];
  final d = _trimDark(d0.px, d0.w, d0.h); // 📱 screenshot na kaala patta
  final out = <ImgPrint>[];
  for (final v in const [
    (1.0, true),   // auto
    (0.75, true),  // vachche no bhaag
    (0.55, true),  // vadhu zoom (item nanu hoy to)
    (1.0, false),  // puri photo
  ]) {
    try {
      out.add(_printFromRgba(d.px, d.w, d.h, zoom: v.$1, segment: v.$2));
    } catch (_) {}
  }
  return out;
}

/// Segment pachhi (rgb, fg, item box, region) — fine check mate
typedef _SegCb = void Function(Uint8List rgb, Uint8List fg, int bx0, int by0,
    int bx1, int by1, int rx0, int ry0, int rx1, int ry1);

ImgPrint _printFromRgba(Uint8List px, int w, int h,
    {double zoom = 1, bool segment = true, _SegCb? onSeg}) {
  final int total = w * h;

  // ---- 1) Safed par RGB (transparent PNG)
  final Uint8List rgb = Uint8List(total * 3);
  for (int i = 0; i < total; i++) {
    final int a = px[i * 4 + 3];
    rgb[i * 3] = (px[i * 4] + 255 - a).clamp(0, 255);
    rgb[i * 3 + 1] = (px[i * 4 + 1] + 255 - a).clamp(0, 255);
    rgb[i * 3 + 2] = (px[i * 4 + 2] + 255 - a).clamp(0, 255);
  }

  // ---- 2) Zoom → vachche no bhaag j
  int rx0 = 0, ry0 = 0, rw = w, rh = h;
  if (zoom < 1) {
    rw = (w * zoom).round().clamp(8, w);
    rh = (h * zoom).round().clamp(8, h);
    rx0 = (w - rw) ~/ 2;
    ry0 = (h - rh) ~/ 2;
  }
  final int rx1 = rx0 + rw, ry1 = ry0 + rh;

  // ---- 3) Background olkho (kinara na rang)
  final Uint8List fg = Uint8List(total); // 1 = item
  for (int y = ry0; y < ry1; y++) {
    for (int x = rx0; x < rx1; x++) {
      fg[y * w + x] = 1;
    }
  }
  int bx0 = rx0, by0 = ry0, bx1 = rx1, by1 = ry1;

  if (segment) {
    final int bt = ((rw < rh ? rw : rh) ~/ 24).clamp(2, 8);

    List<int> median(Iterable<int> idx) {
      final r = <int>[], g = <int>[], b = <int>[];
      for (final i in idx) {
        r.add(rgb[i * 3]);
        g.add(rgb[i * 3 + 1]);
        b.add(rgb[i * 3 + 2]);
      }
      r.sort();
      g.sort();
      b.sort();
      final m = r.length ~/ 2;
      return [r[m], g[m], b[m]];
    }

    Iterable<int> side(int xa, int xb, int ya, int yb) sync* {
      for (int y = ya; y < yb; y++) {
        for (int x = xa; x < xb; x++) {
          yield y * w + x;
        }
      }
    }

    final sides = [
      side(rx0, rx1, ry0, ry0 + bt), // upar
      side(rx0, rx1, ry1 - bt, ry1), // niche
      side(rx0, rx0 + bt, ry0, ry1), // dabe
      side(rx1 - bt, rx1, ry0, ry1), // jamne
    ];
    final List<List<int>> bg = [for (final sd in sides) median(sd)];

    int dist(int i) {
      int best = 1 << 30;
      for (final c in bg) {
        final int dr = rgb[i * 3] - c[0];
        final int dg = rgb[i * 3 + 1] - c[1];
        final int db = rgb[i * 3 + 2] - c[2];
        final int d = dr * dr + dg * dg + db * db;
        if (d < best) best = d;
      }
      return best;
    }

    // Border pote ketlo badlay chhe → threshold
    final List<int> bd = [for (final sd in sides) for (final i in sd) dist(i)]
      ..sort();
    final int p90 = bd[(bd.length * 0.9).floor().clamp(0, bd.length - 1)];
    final int thr = (p90 * 9 ~/ 4) > 28 * 28 ? p90 * 9 ~/ 4 : 28 * 28;

    // Kinara no rang "rang vagar no" (safed / grey / kalo / silk)?
    final List<int> bs = [
      for (final sd in sides)
        for (final i in sd) _sat(rgb, i),
    ]..sort();
    final int bMed = bs[bs.length ~/ 2];
    final int bP90 = bs[(bs.length * 0.9).floor().clamp(0, bs.length - 1)];
    final bool neutralBg = bMed < 25;
    final int satThr = bP90 * 2 > 35 ? bP90 * 2 : 35;
    final int strict = p90 * 4 > 60 * 60 ? p90 * 4 : 60 * 60;

    final Uint8List mask = Uint8List(total);
    final List<int> rowC = List.filled(h, 0);
    int cnt = 0;
    for (int y = ry0; y < ry1; y++) {
      for (int x = rx0; x < rx1; x++) {
        final int i = y * w + x;
        final int r = rgb[i * 3], g = rgb[i * 3 + 1], bl = rgb[i * 3 + 2];
        final int mn = r < g ? (r < bl ? r : bl) : (g < bl ? g : bl);
        final bool on;
        if (neutralBg) {
          // 🎯 Sadu background → sona / meena / rang vala pixel = item
          //    (silk ni chamak, padchhayo ganay nahi)
          on = mn < 235 && (_sat(rgb, i) > satThr || dist(i) > strict);
        } else {
          // Rangin background (lakdu, velvet, haath) → kinara thi alag
          // Ekdam safed (hira / chamak) → background ganay: safed background
          // vali stock photo ma pan e dekhatu nathi, etle banne sarkha rahe
          on = mn < 215 && dist(i) > thr;
        }
        if (on) {
          mask[i] = 1;
          rowC[y]++;
          cnt++;
        }
      }
    }

    final double frac = cnt / (rw * rh);
    if (frac >= 0.02 && frac <= 0.92) {
      // 📌 Sauthi moṭo bhaag j (niche/upar lakhan, naam, patti — chhoḍo)
      final int minR = (rw * 0.015).ceil().clamp(1, 1 << 20);
      final yb = _bestBand(rowC, ry0, ry1, minR,
          (rh * 0.03).round().clamp(2, 1 << 20));
      if (yb != null) {
        final List<int> colC = List.filled(w, 0);
        for (int y = yb.$1; y <= yb.$2; y++) {
          for (int x = rx0; x < rx1; x++) {
            if (mask[y * w + x] == 1) colC[x]++;
          }
        }
        final xb = _bestBand(
            colC,
            rx0,
            rx1,
            ((yb.$2 - yb.$1 + 1) * 0.015).ceil().clamp(1, 1 << 20),
            (rw * 0.03).round().clamp(2, 1 << 20));
        if (xb != null && xb.$2 - xb.$1 >= 4 && yb.$2 - yb.$1 >= 4) {
          bx0 = xb.$1;
          by0 = yb.$1;
          bx1 = xb.$2 + 1;
          by1 = yb.$2 + 1;
          // Box bahar nu (lakhan vagere) ganay nahi
          fg.fillRange(0, total, 0);
          for (int y = by0; y < by1; y++) {
            for (int x = bx0; x < bx1; x++) {
              fg[y * w + x] = mask[y * w + x];
            }
          }
        }
      }
    }
    // nahi to → puri photo (background olkhayo nahi)
  }

  onSeg?.call(rgb, fg, bx0, by0, bx1, by1, rx0, ry0, rx1, ry1);

  // ---- 4) Item ni aaju-baju square crop → 64×64
  const int n = 64;
  final double bw = (bx1 - bx0).toDouble(), bh = (by1 - by0).toDouble();
  final double sideLen = (bw > bh ? bw : bh) * 1.06;
  final double sx0 = (bx0 + bx1) / 2 - sideLen / 2;
  final double sy0 = (by0 + by1) / 2 - sideLen / 2;
  final double step = sideLen / n;

  final List<double> gray = List.filled(n * n, 0);
  final List<double> hist = List.filled(64, 0);
  final List<double> accent = List.filled(12, 0);
  int hc = 0;

  for (int ty = 0; ty < n; ty++) {
    for (int tx = 0; tx < n; tx++) {
      double gs = 0;
      for (int k = 0; k < 4; k++) {
        final int xi = (sx0 + (tx + ((k & 1) + 0.5) / 2) * step).floor();
        final int yi = (sy0 + (ty + ((k >> 1) + 0.5) / 2) * step).floor();
        if (xi < rx0 || yi < ry0 || xi >= rx1 || yi >= ry1) {
          gs += 255;
          continue;
        }
        final int i = yi * w + xi;
        if (fg[i] == 0) {
          gs += 255; // background → safed
          continue;
        }
        final int r = rgb[i * 3], g = rgb[i * 3 + 1], b = rgb[i * 3 + 2];
        gs += 0.299 * r + 0.587 * g + 0.114 * b;
        _colorBins(r, g, b, hist, accent);
        hc++;
      }
      gray[ty * n + tx] = gs / 4;
    }
  }
  if (hc == 0) {
    hist[63] = 1;
  } else {
    for (int i = 0; i < 64; i++) {
      hist[i] /= hc;
    }
    for (int i = 0; i < 12; i++) {
      accent[i] /= hc;
    }
  }

  // ---- d16: 17×16 block → 256 bit (jhini design)
  final List<double> e = List.filled(17 * 16, 0);
  for (int y = 0; y < n; y++) {
    final int by = (y * 16) ~/ n;
    for (int x = 0; x < n; x++) {
      e[by * 17 + (x * 17) ~/ n] += gray[y * n + x];
    }
  }
  final Uint8List d16 = Uint8List(32);
  int bit = 0;
  for (int y = 0; y < 16; y++) {
    for (int x = 0; x < 16; x++) {
      if (e[y * 17 + x] < e[y * 17 + x + 1]) {
        d16[bit >> 3] |= 1 << (7 - (bit & 7));
      }
      bit++;
    }
  }

  // ---- dHash: 9×8 block average, baju-baju sarkhamni
  final List<double> d = List.filled(9 * 8, 0);
  final List<int> dc = List.filled(9 * 8, 0);
  for (int y = 0; y < n; y++) {
    final int by = (y * 8) ~/ n;
    for (int x = 0; x < n; x++) {
      final int bx = (x * 9) ~/ n;
      d[by * 9 + bx] += gray[y * n + x];
      dc[by * 9 + bx]++;
    }
  }
  for (int i = 0; i < d.length; i++) {
    d[i] /= dc[i];
  }
  int dh = 0;
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      dh = (dh << 1) | (d[y * 9 + x] < d[y * 9 + x + 1] ? 1 : 0);
    }
  }

  // ---- aHash: 8×8 block average vs kul average
  final List<double> a = List.filled(64, 0);
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      a[(y >> 3) * 8 + (x >> 3)] += gray[y * n + x];
    }
  }
  double avg = 0;
  for (final v in a) {
    avg += v;
  }
  avg /= 64;
  int ah = 0;
  for (final v in a) {
    ah = (ah << 1) | (v >= avg ? 1 : 0);
  }

  return ImgPrint(dh, ah, hist, d16, accent);
}

int _sat(Uint8List rgb, int i) {
  final int r = rgb[i * 3], g = rgb[i * 3 + 1], b = rgb[i * 3 + 2];
  final int mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final int mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  return mx - mn;
}

/// Lagatar bhare line no sauthi moṭo patto (nana gap chalavi lye)
(int, int)? _bestBand(List<int> cnt, int lo, int hi, int minV, int tol) {
  (int, int)? best;
  int bestMass = 0;
  int start = -1, end = -1, mass = 0, gap = 0;
  void close() {
    if (start >= 0 && mass > bestMass) {
      bestMass = mass;
      best = (start, end);
    }
    start = -1;
    mass = 0;
    gap = 0;
  }

  for (int i = lo; i < hi; i++) {
    if (cnt[i] >= minV) {
      if (start < 0) start = i;
      end = i;
      mass += cnt[i];
      gap = 0;
    } else if (start >= 0) {
      gap++;
      if (gap > tol) close();
    }
  }
  close();
  return best;
}

int _hamming(int a, int b) {
  int x = a ^ b;
  int c = 0;
  while (x != 0) {
    x &= x - 1;
    c++;
  }
  return c;
}

/// Rang → bin (HSV). Sonu / meena / nang alag olkhay
void _colorBins(int r, int g, int b, List<double> hist, List<double> accent) {
  final int mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final int mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final double v = mx / 255;
  final double sat = mx == 0 ? 0 : (mx - mn) / mx;
  double h = 0; // 0..360
  if (mx != mn) {
    final double c = (mx - mn).toDouble();
    if (mx == r) {
      h = 60 * (((g - b) / c) % 6);
    } else if (mx == g) {
      h = 60 * (((b - r) / c) + 2);
    } else {
      h = 60 * (((r - g) / c) + 4);
    }
    if (h < 0) h += 360;
  }
  if (sat > 0.2 && v > 0.15) {
    final int hb = (h / 360 * 16).floor() % 16;
    final int vb = (v * 3).floor().clamp(0, 2);
    hist[hb * 3 + vb] += 1;
  } else {
    hist[48 + (v * 16).floor().clamp(0, 15)] += 1;
  }
  // Sona (pilo) sivay no ghaṭṭ rang = meena / nang
  if (sat > 0.35 && v > 0.25 && !(h >= 22 && h <= 58)) {
    accent[(h / 360 * 12).floor() % 12] += 1;
  }
}

/// 0..255 ma ketla 1 bit
final List<int> _pop8 = List<int>.generate(256, (i) {
  int c = 0, x = i;
  while (x != 0) {
    x &= x - 1;
    c++;
  }
  return c;
});

int _hamBytes(Uint8List a, Uint8List b) {
  int c = 0;
  for (int i = 0; i < a.length && i < b.length; i++) {
    c += _pop8[a[i] ^ b[i]];
  }
  return c;
}

/// 0..1 — 1 = ekdam sarkhu
///   aakar (8 + 16 grid) + ujas + rang + meena/nang no rang
double _similarity(ImgPrint q, ImgPrint t) {
  final double d8 = 1 - _hamming(q.dHash, t.dHash) / 64;
  final double d16 = 1 - _hamBytes(q.d16, t.d16) / 256;
  final double aS = 1 - _hamming(q.aHash, t.aHash) / 64;
  double hS = 0;
  for (int i = 0; i < 64; i++) {
    hS += q.hist[i] < t.hist[i] ? q.hist[i] : t.hist[i];
  }
  double diff = 0, tot = 0;
  for (int i = 0; i < 12; i++) {
    diff += (q.accent[i] - t.accent[i]).abs();
    tot += q.accent[i] + t.accent[i];
  }
  final double acS = 1 - (diff / (tot > 0.03 ? tot : 0.03)).clamp(0.0, 1.0);
  return d8 * 0.25 + d16 * 0.25 + aS * 0.10 + hS * 0.20 + acS * 0.20;
}

/// ---------------------------------------------------------------
/// RESULT
/// ---------------------------------------------------------------
class ImageSearchResult {
  final Map<String, dynamic> item;
  final double score; // 0..1
  final bool exact;
  ImageSearchResult(this.item, this.score, this.exact);
}

/// ================================================================
/// SCREEN
/// ================================================================
class ImageSearchScreen extends StatefulWidget {
  /// Page URL — Stock Gallery jevu j (branch merge hoy to e j branches)
  final String Function(int page)? pageUrl;

  /// Result par click → e item
  final void Function(Map<String, dynamic> item)? onItemTap;

  const ImageSearchScreen({super.key, this.pageUrl, this.onItemTap});

  /// 🚪 LOGOUT vakhte call karo → stock list bhuli jay (navo login = fresh)
  ///    Ex: logout function ma →  await ImageSearchScreen.clearOnLogout();
  static Future<void> clearOnLogout() =>
      _ImageSearchScreenState._clearOnLogout();

  @override
  State<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends State<ImageSearchScreen> {
  // 🎨 Light blue palette
  static const Color _lbTop = Color(0xffDCE8FB);
  static const Color _lbBottom = Color(0xffF0F5FE);
  static const Color _lbBorder = Color(0xffC9DAF6);
  static const Color _lbSoft = Color(0xffF5F8FE);
  static const Color _lbText = Color(0xff2F4A78);
  static const Color _ink = Color(0xff1C1E24);
  static const Color _muted = Color(0xff8A8F98);
  static const Color _green = Color(0xff16A34A);

  /// v6 = background vagar, fakt item no fingerprint
  static const String _cacheKey = "image_search_prints_v6";
  static const int _parallel = 15; // ek sathe 10 image
  static const int _pageParallel = 15; // ek sathe 10 stock page
  static const int _maxSimilar = 30;
  static const double _minScore = 0.55;

  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio(BaseOptions(
    responseType: ResponseType.bytes,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  File? _query;
  ImgPrint? _queryPrint;
  /// Tamari photo na 4 roop (auto, 75%, 55% zoom, puri)
  List<ImgPrint> _queryPrints = [];

  List<Map<String, dynamic>> _items = []; // image vala item j
  int _stockCount = 0;

  /// 💾 static — screen bandh kari farithi kholo to pan memory ma rahe
  static final Map<String, ImgPrint> _prints = {};
  static Map<String, String> _cache = {};
  static bool _cacheLoaded = false;

  /// Stock list memory ma (login + page url pramane)
  static final Map<String, List<Map<String, dynamic>>> _memItems = {};
  static final Map<String, int> _memStock = {};

  /// Login token — login badlay to stock list fari aave
  String _token = "";

  String get _scope {
    final String Function(int)? f = widget.pageUrl;
    final String url = f != null ? f(1) : "${ApiConstants.stock_gallery}?page=1";
    // Token nahi — token app start par badlay to pan data na jay.
    // User badlay / logout thay tyare j fresh.
    return "$_userKey::$url";
  }

  /// Login user ni olakh (user_id / email ...) — logout sudhi same
  static String _userKey = "";

  /// Aa app chalu chhe tyar sudhi navi item tapasi lidhi (scope pramane)
  static final Set<String> _refreshed = {};

  /// App restart pachhi pan same rahe (String.hashCode par bharoso nahi)
  String get _itemsKey {
    int h = 0x811c9dc5;
    for (final c in _scope.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return "image_search_items_v1_${h.toRadixString(16)}";
  }

  /// Background index (screen khulta j sharu)
  Future<void>? _indexTask;
  bool _indexing = false;
  bool _indexed = false;

  bool _busy = false; // photo vanchay chhe
  String _status = "";
  int _done = 0;
  int _total = 0;
  bool _cancelled = false;

  List<ImageSearchResult> _exact = [];
  List<ImageSearchResult> _similar = [];
  bool _searched = false;

  /// 🔍 Fine check (upar na 12)
  static const int _fineTop = 12;
  /// 💾 Dar stock image ni jhini olakh (ek vaar scan, phone ni file ma)
  static final Map<String, Uint8List> _fineDb = {};
  static bool _fineLoaded = false;
  static const int _fineScreen = 60; // jhadpi sarkhamni pachhi aatla
  List<Float64List> _queryFine = [];
  Map<String, double> _fineScores = {};
  bool _fining = false;

  /// Exact aavi gayu hoy to "Checking best matches" na batavo —
  /// tapas chupchap pachhad chale (jarur pade to result jate badlay)
  bool get _fineVisible => _fining && _exact.isEmpty;

  /// ✅ Pasand karela result (WhatsApp / PDF mate)
  final Set<String> _sel = {};
  bool _sharing = false;

  /// Share / PDF hamesha (aa screen ma j bane)
  bool get _canShare => true;

  bool get _hasResults => _exact.isNotEmpty || _similar.isNotEmpty;

  /// Kai select hoy to e j, nahi to badha result
  List<ImageSearchResult> _pickResults(List<ImageSearchResult> list) =>
      _sel.isEmpty ? list : list.where((r) => _sel.contains(_key(r.item))).toList();

  List<ExportItem> _toExport(List<ImageSearchResult> list) => [
    for (final r in list)
      ExportItem(r.item, exact: r.exact, score: r.score),
  ];

  void _toggleSel(Map m) {
    final k = _key(m);
    setState(() => _sel.contains(k) ? _sel.remove(k) : _sel.add(k));
  }

  /// Section na badha select / unselect
  void _toggleAll(List<ImageSearchResult> list) {
    final keys = list.map((r) => _key(r.item)).toList();
    final bool all = keys.every(_sel.contains);
    setState(() => all ? _sel.removeAll(keys) : _sel.addAll(keys));
  }

  /// 📄 PDF / 📲 WhatsApp — aa screen ma j bane
  ///   Upar: tame upload kareli photo
  ///   Pachhi: Exact match → Similar (dar ek ni detail sathe)
  Future<void> _share(bool pdf) async {
    if (_sharing || _query == null) return;

    final exact = _toExport(_pickResults(_exact));
    final similar = _toExport(_pickResults(_similar));
    if (exact.isEmpty && similar.isEmpty) {
      AppMessage.error(context, "No items to share");
      return;
    }

    setState(() => _sharing = true);
    final ValueNotifier<String> progress = ValueNotifier("Preparing...");
    final ValueNotifier<double?> frac = ValueNotifier(null);
    _showShareLoader(pdf, progress, frac);

    try {
      if (pdf) {
        final File f = await ImageSearchExport.buildPdf(
          query: _query!,
          exact: exact,
          similar: similar,
          scanned: _prints.length,
          onProgress: (d, t) {
            progress.value = "Adding photos $d of $t";
            frac.value = t == 0 ? null : d / t;
          },
        );
        _closeLoader();
        if (!mounted) return;
        await _pdfReady(f, exact: exact.length, similar: similar.length);
      } else {
        final files = await ImageSearchExport.buildShareImages(
          query: _query!,
          items: [...exact, ...similar],
          exactCount: exact.length,
          similarCount: similar.length,
          onProgress: (d, t) {
            progress.value = "Preparing images $d of $t";
            frac.value = t == 0 ? null : d / t;
          },
        );
        _closeLoader();
        if (!mounted) return;
        if (files.isEmpty) {
          AppMessage.error(context, "Could not prepare images");
          return;
        }
        await Share.shareXFiles(
          files.map((f) => XFile(f.path, mimeType: "image/jpeg")).toList(),
          text: "Image search: ${exact.length} exact, ${similar.length} similar",
        );
      }
    } catch (e) {
      debugPrint("❌ IMAGE SEARCH SHARE ERROR => $e");
      _closeLoader();
      if (mounted) AppMessage.error(context, "Could not share");
    } finally {
      progress.dispose();
      frac.dispose();
      if (mounted) setState(() => _sharing = false);
    }
  }

  bool _loaderOpen = false;

  void _showShareLoader(
      bool pdf, ValueNotifier<String> progress, ValueNotifier<double?> frac) {
    _loaderOpen = true;
    final Color c = pdf ? const Color(0xffDC2626) : const Color(0xff25D366);
    final Color c2 = pdf ? const Color(0xffB91C1C) : const Color(0xff128C7E);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: c.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---- Rangin header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c, c2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4), width: 2),
                            ),
                            child: Icon(
                              pdf
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.chat_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            pdf ? "Creating your PDF" : "Preparing for WhatsApp",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pdf
                                ? "Searched photo, exact & similar items"
                                : "Photos with details below each image",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---- Progress
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: ValueListenableBuilder<double?>(
                        valueListenable: frac,
                        builder: (_, v, __) => Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ValueListenableBuilder<String>(
                                    valueListenable: progress,
                                    builder: (_, t, __) => Text(
                                      t,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ),
                                if (v != null)
                                  Text(
                                    "${(v * 100).round()}%",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: c,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 7,
                                color: c,
                                backgroundColor: c.withOpacity(0.12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Please keep the app open",
                              style: TextStyle(fontSize: 10.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _closeLoader() {
    if (!_loaderOpen || !mounted) return;
    _loaderOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// ✨ PDF taiyar → premium sheet (Open / WhatsApp / Share)
  Future<void> _pdfReady(File f, {int exact = 0, int similar = 0}) async {
    const Color red = Color(0xffDC2626);

    String size = "";
    try {
      final int b = f.lengthSync();
      size = b > 1024 * 1024
          ? "${(b / (1024 * 1024)).toStringAsFixed(1)} MB"
          : "${(b / 1024).toStringAsFixed(0)} KB";
    } catch (_) {}
    final String name = f.path.split(Platform.pathSeparator).last;

    void share() => Share.shareXFiles(
      [XFile(f.path, mimeType: "application/pdf")],
      text: "Image search report",
    );

    Widget stat(String label, String value, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: c.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
            const SizedBox(height: 1),
            Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
          ],
        ),
      ),
    );

    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? fill,
      Color? fg,
      Gradient? gradient,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: Ink(
              height: 46,
              decoration: BoxDecoration(
                color: fill,
                gradient: gradient,
                borderRadius: BorderRadius.circular(5),
                border: fill == Colors.white
                    ? Border.all(color: _lbBorder)
                    : null,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: fg ?? Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: fg ?? Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---- Success
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xffEF4444), Color(0xffB91C1C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: red.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      "PDF is ready",
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: _green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: _muted),
                              ),
                              if (size.isNotEmpty)
                                Text(
                                  "Image Search Report • $size",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _lbText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ---- Andar shu chhe
                    Row(
                      children: [
                        stat("Searched", "1", const Color(0xffC9A24A)),
                        const SizedBox(width: 8),
                        stat("Exact", "$exact", _green),
                        const SizedBox(width: 8),
                        stat("Similar", "$similar", _lbText),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ---- Actions
                    Row(
                      children: [
                        btn(
                          icon: Icons.visibility_rounded,
                          label: "Open",
                          fill: Colors.white,
                          fg: _lbText,
                          onTap: () {
                            Navigator.pop(sheet);
                            OpenFile.open(f.path);
                          },
                        ),
                        const SizedBox(width: 10),
                        btn(
                          icon: Icons.chat_rounded,
                          label: "WhatsApp",
                          gradient: const LinearGradient(
                              colors: [Color(0xff2BD46E), Color(0xff128C7E)]),
                          onTap: () {
                            Navigator.pop(sheet);
                            share();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        btn(
                          icon: Icons.ios_share_rounded,
                          label: "Share to other apps",
                          gradient: LinearGradient(
                              colors: [AppColors.primaryDark, AppColors.secondaryDark]),
                          onTap: () {
                            Navigator.pop(sheet);
                            share();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(sheet),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    // ⚡ Photo pasand kare e pahela j scan sharu
    _ensureIndex();
  }

  @override
  void dispose() {
    _cancelled = true;
    _saveCache(); // aadhu scan pan save
    _saveFineDb();
    _dio.close(force: true);
    super.dispose();
  }

  // ============================================================
  // CACHE
  // ============================================================

  Future<void> _loadCache() async {
    if (_cacheLoaded) return; // 💾 ek vaar j vanchvu
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_cacheKey);
      if (raw != null) {
        _cache = Map<String, String>.from(jsonDecode(raw) as Map);
      }
      // Juna format kadho (jagya na roke)
      for (final k in [
        "image_search_prints_v1",
        "image_search_prints_v2",
        "image_search_prints_v3",
        "image_search_prints_v4",
        "image_search_prints_v5",
      ]) {
        prefs.remove(k);
      }
      _cacheLoaded = true;
    } catch (_) {
      _cache = {};
    }
  }

  /// Search mate jaruri field j save (nanu)
  static const List<String> _keepFields = [
    "id", "company_id", "company_name", "item_name", "label_code",
    "qr_code", "huid", "gross_weight", "net_weight", "stock_status",
    "is_sold", "has_image", "image_url", "image", "thumbnail_url",
    "photo_url", "image_download_url",
  ];

  /// 💾 Stock list phone ni FILE ma (moti list prefs ma na samaay)
  Future<File> _itemsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File("${dir.path}/$_itemsKey.json");
  }

  Future<void> _saveItemsCache() async {
    try {
      final slim = [
        for (final m in _items) {for (final k in _keepFields) k: m[k]},
      ];
      final String raw =
      await compute(_jsonOf, {"stock": _stockCount, "items": slim});
      final f = await _itemsFile();
      await f.writeAsString(raw, flush: true);
    } catch (e) {
      debugPrint("⚠️ IMAGE ITEMS SAVE ERR => $e");
    }
  }

  /// Memory → nahi to phone ma save karelu → true = malyu (load nahi)
  Future<bool> _loadItemsCache() async {
    final mem = _memItems[_scope];
    if (mem != null && mem.isNotEmpty) {
      _items = mem;
      _stockCount = _memStock[_scope] ?? mem.length;
      return true;
    }
    try {
      String? raw;
      final f = await _itemsFile();
      if (await f.exists()) raw = await f.readAsString();
      if (raw == null) {
        // Juni rit (prefs) → file ma lai jao
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_itemsKey);
        if (raw != null) {
          await f.writeAsString(raw, flush: true);
          await prefs.remove(_itemsKey);
        }
      }
      if (raw == null) return false;
      final Map j = await compute(_jsonMap, raw);
      final List list = j["items"] is List ? j["items"] : [];
      if (list.isEmpty) return false;
      _items = [
        for (final e in list)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
      _stockCount = int.tryParse("${j["stock"] ?? ""}") ?? _items.length;
      _memItems[_scope] = _items;
      _memStock[_scope] = _stockCount;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<File> _fineFile() async {
    final dir = await getApplicationSupportDirectory();
    return File("${dir.path}/image_search_fine_v1.json");
  }

  Future<void> _loadFineDb() async {
    if (_fineLoaded) return;
    try {
      final f = await _fineFile();
      if (await f.exists()) {
        // 🧵 Moti file — alag thread ma vancho (screen atke nahi)
        final m = await compute(_decodeFine, await f.readAsString());
        _fineDb.addAll(m);
      }
      _fineLoaded = true;
    } catch (_) {}
  }

  /// Ek save puru thay pachhi j biju (file bagde nahi)
  static Future<void> _fineSaveChain = Future.value();
  static Future<void> _cacheSaveChain = Future.value();

  Future<void> _saveFineDb() => _fineSaveChain = _fineSaveChain.then((_) async {
    try {
      final f = await _fineFile();
      // 🧵 JSON banavvanu alag thread ma
      final String raw =
      await compute(_encodeFine, Map<String, Uint8List>.of(_fineDb));
      await f.writeAsString(raw, flush: true);
    } catch (_) {}
  });

  Future<void> _saveCache() => _cacheSaveChain = _cacheSaveChain.then((_) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String raw =
      await compute(_jsonOf, Map<String, String>.of(_cache));
      await prefs.setString(_cacheKey, raw);
    } catch (_) {}
  });

  // ============================================================
  // ITEM HELPERS
  // ============================================================

  String? _imageUrl(Map m) {
    for (final k in ["image_url", "image", "thumbnail_url", "photo_url"]) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty && v != "null") return v.trim();
    }
    return null;
  }

  /// Image badlay to key badlay → navo fingerprint
  String _key(Map m) => "${m["company_id"] ?? ""}|${m["id"]}|${_imageUrl(m)}";

  String _s(dynamic v, [String f = "-"]) {
    final t = v?.toString().trim() ?? "";
    return t.isEmpty || t == "null" ? f : t;
  }

  void _set(VoidCallback fn) {
    if (mounted && !_cancelled) setState(fn);
  }

  // ============================================================
  // INDEX (background)
  // ============================================================

  Future<void> _ensureIndex() => _indexTask ??= _buildIndex();

  Future<void> _buildIndex() async {
    try {
      await _loadCache();
      await _loadFineDb();
      await _attachToken();

      // 💾 Pehla load thayelu hoy → sidhu vaparo (loading nahi)
      final bool had = await _loadItemsCache();
      if (!had) {
        _set(() {
          _indexing = true;
          _status = "Loading stock...";
        });
        // ⚡ Page aave tem tem image scan pan sathe j chalu
        //    (badha page ni raah na juo)
        _feeding = true;
        final Future<void> scan = _indexItems();
        try {
          await _loadAllItems();
        } finally {
          _feeding = false;
        }
        if (_cancelled) return;
        if (_items.isNotEmpty) {
          _memItems[_scope] = _items;
          _memStock[_scope] = _stockCount;
          _refreshed.add(_scope); // haman j aavyu — fari tapasvani jarur nathi
          _saveItemsCache(); // background ma
        }
        if (_next < _todo.length) {
          _set(() => _status = "Scanning images...");
        }
        await scan;
      } else {
        if (_cancelled) return;
        await _indexItems(); // fakt baki image j (save karela turant)
        _indexed = true;
        _set(() {
          _indexing = false;
          _status = "";
        });
        // 🔄 Search turant chale — pachhad navi item j lavo
        await _refreshNewItems();
      }
      _indexed = true;
    } catch (e) {
      debugPrint("❌ IMAGE INDEX ERROR => $e");
      _indexTask = null; // farithi try thai shake
    } finally {
      _set(() {
        _indexing = false;
        _status = "";
      });
      if (_queryPrint != null) {
        _rank(); // chhello sacho result
        _fineCheck(); // 🔍
      }
    }
  }

  /// Stock na badha page — pehlu page pachhi baki 6-6 ek sathe
  /// quiet = chupchap (navi item tapasva) — screen / juni list ne ade nahi
  Future<({List<Map<String, dynamic>> items, int stock, bool ok})?>
  _loadAllItems({bool quiet = false}) async {
    final String Function(int) url =
        widget.pageUrl ?? (p) => "${ApiConstants.stock_gallery}?page=$p";

    final List<Map<String, dynamic>> all = [];
    final Set<String> seen = {};
    int stock = 0;
    bool ok = true; // badha page aavya?
    if (!quiet) {
      _stockCount = 0;
      _items = all; // ⚡ aavta j search ma vapray
    }

    Future<({List rows, int last})?> fetch(int page) async {
      try {
        final res = await ApiHelper().getRequest(url(page), showLoading: false);
        final body = res?.data;
        if (res?.statusCode != 200 || body is! Map) return null;
        final dynamic data = body["data"];
        final List rows = data is List
            ? data
            : (data is Map && data["data"] is List ? data["data"] : []);
        final dynamic pg =
            body["pagination"] ?? (data is Map ? data : null) ?? body["meta"];
        final int last =
            int.tryParse("${pg is Map ? pg["last_page"] : ""}") ?? page;
        return (rows: rows, last: last);
      } catch (e) {
        debugPrint("❌ IMAGE SEARCH PAGE $page => $e");
        return null;
      }
    }

    void take(List rows) {
      stock += rows.length;
      if (!quiet) _stockCount = stock;
      for (final r in rows) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        if (_imageUrl(m) == null) continue;
        if (seen.add(_key(m))) {
          all.add(m);
          if (!quiet) _enqueue(m); // ⚡ turant scan ni line ma
        }
      }
    }

    final first = await fetch(1);
    if (first == null) {
      if (!quiet) _items = all;
      return null;
    }
    take(first.rows);
    final int last = first.last.clamp(1, 500);

    for (int p = 2; p <= last && !_cancelled; p += _pageParallel) {
      if (!quiet) _set(() => _status = "Loading stock... page $p / $last");
      final pages = [
        for (int q = p; q < p + _pageParallel && q <= last; q++) q,
      ];
      final results = await Future.wait(pages.map(fetch));
      for (final r in results) {
        if (r != null) {
          take(r.rows);
        } else {
          ok = false;
        }
      }
    }
    if (_cancelled) ok = false;

    if (!quiet) _items = all;
    debugPrint("🔎 IMAGE SEARCH${quiet ? " (refresh)" : ""}: "
        "$stock items, ${all.length} with image");
    return (items: all, stock: stock, ok: ok);
  }

  /// 🔄 Save karelu list vapray pachhi — chupchap navi item lavo,
  ///    fakt NAVI image j scan (juni fari load nahi). App chalu hoy tyar sudhi ek vaar.
  Future<void> _refreshNewItems() async {
    final String sc = _scope;
    if (_refreshed.contains(sc) || _cancelled) return;
    final r = await _loadAllItems(quiet: true);
    if (r == null || !r.ok || r.items.isEmpty || _cancelled) return;
    _refreshed.add(sc);

    final Set<String> old = {for (final m in _items) _key(m)};
    final int added = r.items.where((m) => !old.contains(_key(m))).length;
    final int removed =
        old.length - r.items.where((m) => old.contains(_key(m))).length;
    debugPrint("🔄 IMAGE SEARCH refresh: +$added new, -$removed gone");
    if (added == 0 && removed == 0) return; // kai badlyu nathi

    _items = r.items;
    _stockCount = r.stock;
    _memItems[sc] = _items;
    _memStock[sc] = _stockCount;
    await _saveItemsCache();
    if (added > 0) await _indexItems(); // ⚡ fakt navi image
  }

  /// Login token (image private hoy to)
  Future<void> _attachToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 👤 User olakh (logout sudhi same rahe)
      _userKey = "";
      for (final k in [
        "user_id", "userId", "id", "email", "user_email",
        "username", "mobile", "phone",
      ]) {
        final v = prefs.get(k);
        final String t = "${v ?? ""}".trim();
        if (t.isNotEmpty && t != "null") {
          _userKey = "$k=$t";
          break;
        }
      }
      for (final k in ["token", "access_token", "auth_token", "api_token"]) {
        final t = prefs.getString(k);
        if (t != null && t.isNotEmpty) {
          _token = t;
          _dio.options.headers["Authorization"] = "Bearer $t";
          _dio.options.headers["Accept"] = "*/*";
          return;
        }
      }
    } catch (_) {}
  }

  /// image_url → na male to image_download_url
  Future<Uint8List?> _download(Map m) async {
    for (final url in [_imageUrl(m), m["image_download_url"]?.toString()]) {
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

  /// ⚡ Scan ni line (page aave tem vadhe)
  final List<Map<String, dynamic>> _todo = [];
  int _next = 0;
  bool _feeding = false;

  void _enqueue(Map<String, dynamic> m) {
    final k = _key(m);
    if (!_prints.containsKey(k)) {
      final cached = _cache[k];
      final p = cached == null ? null : ImgPrint.decode(cached);
      if (p != null) _prints[k] = p;
    }
    if (!_prints.containsKey(k) || !_fineDb.containsKey(k)) {
      _todo.add(m);
      _total = _todo.length;
    }
  }

  Future<void> _indexItems() async {
    _todo.clear();
    _next = 0;
    _done = 0;
    _total = 0;
    for (final m in _items) {
      _enqueue(m);
    }
    if (_todo.isEmpty && !_feeding) return;

    _set(() {
      _indexing = true;
      if (!_feeding) _status = "Scanning images...";
    });

    final Stopwatch clock = Stopwatch()..start();
    int lastSave = 0, lastRank = 0, lastUi = 0;

    Future<void> worker() async {
      while (!_cancelled) {
        if (_next >= _todo.length) {
          if (_feeding) {
            // Navo page aave tyar sudhi thodi raah
            await Future.delayed(const Duration(milliseconds: 120));
            continue;
          }
          return;
        }
        final m = _todo[_next++];
        final k = _key(m);
        try {
          final data = await _download(m);
          if (data != null) {
            final bool needP = !_prints.containsKey(k);
            final bool needF = !_fineDb.containsKey(k);
            // Decode (engine thread) — banne sathe
            final dd = await Future.wait([
              needP ? _decodeRgba(data) : Future.value(null),
              needF ? _decodeRgba(data, 320) : Future.value(null),
            ]);
            final a = dd[0], b = dd[1];
            if (a != null || b != null) {
              // 🧵 Bhaare ganatri alag thread ma
              final r = await compute(_heavyScan, (
              a?.px, a?.w ?? 0, a?.h ?? 0,
              b?.px, b?.w ?? 0, b?.h ?? 0,
              ));
              if (r.$1 != null) {
                _prints[k] = r.$1!;
                _cache[k] = r.$1!.encode();
              }
              if (r.$2 != null) _fineDb[k] = r.$2!;
            }
          }
        } catch (e) {
          debugPrint("⚠️ IMAGE SKIP ${m["id"]} => $e");
        }
        _done++;

        final int now = clock.elapsedMilliseconds;
        // Vachche vachche save (25 sec e) — screen bandh thay to pan kaam na jay
        if (now - lastSave > 25000) {
          lastSave = now;
          _saveCache();
          _saveFineDb();
        }
        // Live result (1.5 sec e) + progress (0.3 sec e)
        final bool last = _done == _total && !_feeding;
        if (_queryPrint != null && (now - lastRank > 1500 || last)) {
          lastRank = now;
          lastUi = now;
          _rank();
        } else if (now - lastUi > 300 || last) {
          lastUi = now;
          _set(() {});
        }
      }
    }

    await Future.wait(List.generate(_parallel, (_) => worker()));
    await _saveCache();
    await _saveFineDb();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? x = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 90,
      );
      if (x == null) return;

      setState(() {
        _query = File(x.path);
        _queryPrint = null;
        _queryPrints = [];
        _queryFine = [];
        _fineScores = {};
        _sel.clear();
        _exact = [];
        _similar = [];
        _searched = false;
      });

      await _search();
    } catch (e) {
      debugPrint("❌ IMAGE PICK ERROR => $e");
      if (mounted) AppMessage.error(context, "Could not open the image");
    }
  }

  Future<void> _search() async {
    if (_query == null || _busy) return;

    _set(() => _busy = true);
    try {
      if (_queryPrint == null) {
        _queryPrints = await _makeQueryPrints(await _query!.readAsBytes());
        _queryPrint = _queryPrints.isEmpty ? null : _queryPrints.first;
      }
      if (_queryPrint == null) {
        if (mounted) AppMessage.error(context, "This image could not be read");
        return;
      }
    } finally {
      _set(() => _busy = false);
    }

    // Atyar sudhi scan thayela sathe turant result
    _rank();

    // Scan baki hoy to chalu rahe — result live update thashe
    if (!_indexed) {
      await _ensureIndex();
    } else if (!_indexing) {
      await _fineCheck(); // 🔍 upar na 12 jhinvat thi
    }
  }

  /// 🔍 Upar na 12 item ne jhinvat thi sarkhavo → Exact pakku
  /// Ek sathe ketla bhaag (phone na core)
  static const int _fineParts = 4;

  Future<void> _fineCheck() async {
    final File? query = _query;
    if (query == null || _fining || _queryPrints.isEmpty) return;
    _set(() => _fining = true);
    final Stopwatch clock = Stopwatch()..start();
    try {
      if (_queryFine.isEmpty) {
        final d0 = await _decodeRgba(await query.readAsBytes(), 320);
        if (d0 == null) return;
        // 🧵 alag thread
        _queryFine = await compute(_queryFineWork, (d0.px, d0.w, d0.h));
      }
      if (_queryFine.isEmpty || _query != query) return;
      final int nv = _queryFine.length;
      final List<Map<String, dynamic>> items = List.of(_items);

      // 1) Fingerprint pramane upar na 12 (alag thread)
      final List<Map<String, dynamic>> withPrint = [];
      final List<ImgPrint> prints = [];
      for (final m in items) {
        final p = _prints[_key(m)];
        if (p == null) continue;
        withPrint.add(m);
        prints.add(p);
      }
      final Map<String, Map<String, dynamic>> pick = {};
      if (prints.isNotEmpty) {
        final top = await compute(
            _coarseWork, (List<ImgPrint>.of(_queryPrints), prints, _fineTop));
        for (final i in top) {
          pick[_key(withPrint[i])] = withPrint[i];
        }
      }
      if (_query != query) return;

      // 2) 🔍 Badha item × badhi baari — jhadpi sarkhamni (4 thread ek sathe)
      final keys = <String>[];
      final itemOf = <String, Map<String, dynamic>>{};
      for (final m in items) {
        final k = _key(m);
        if (_fineDb.containsKey(k)) {
          keys.add(k);
          itemOf[k] = m;
        }
      }
      for (final k in pick.keys) {
        itemOf.putIfAbsent(k, () => pick[k]!);
      }
      const int L = _fN * _fN;
      final Float32List qFlat = Float32List(nv * L);
      for (int v = 0; v < nv; v++) {
        qFlat.setRange(v * L, (v + 1) * L, _normFine(_queryFine[v]));
      }
      final int n = keys.length;
      final int per = (n / _fineParts).ceil().clamp(1, n == 0 ? 1 : n);
      final List<Future<Map<String, dynamic>>> jobs = [];
      for (int st = 0; st < n; st += per) {
        final int en = math.min(n, st + per);
        final Uint8List db = Uint8List((en - st) * L);
        for (int i = st; i < en; i++) {
          db.setRange((i - st) * L, (i - st + 1) * L, _fineDb[keys[i]]!);
        }
        jobs.add(compute(
            _screenWork, {"q": qFlat, "v": nv, "db": db, "n": en - st}));
      }
      final parts = await Future.wait(jobs);
      if (_query != query) return;
      final Float32List sBest = Float32List(n);
      int o = 0;
      for (final pr in parts) {
        final Float32List b = pr["best"] as Float32List;
        sBest.setRange(o, o + b.length, b);
        o += b.length;
      }

      final order = List<int>.generate(n, (i) => i)
        ..sort((a, b) => sBest[b].compareTo(sBest[a]));
      for (final i in order.take(_fineScreen)) {
        pick[keys[i]] = itemOf[keys[i]]!;
      }

      // 3) Pasand karela ne puri jhinvat thi (4 thread ek sathe)
      final List<String> pk = [
        for (final k in pick.keys)
          if (_fineDb[k] != null) k,
      ];
      final int per3 = math.max(1, (pk.length / _fineParts).ceil());
      final List<Future<List<double>>> jobs3 = [];
      final List<List<String>> chunks = [];
      for (int st = 0; st < pk.length; st += per3) {
        final c = pk.sublist(st, math.min(pk.length, st + per3));
        chunks.add(c);
        jobs3.add(compute(_refineWork, (
        _queryFine,
        [for (final k in c) _fineDb[k]!],
        [for (final k in c) _prints[k]],
        List<ImgPrint>.of(_queryPrints),
        )));
      }
      final r3 = await Future.wait(jobs3);
      final Map<String, double> res = {};
      for (int c = 0; c < chunks.length; c++) {
        for (int j = 0; j < chunks[c].length; j++) {
          res[chunks[c][j]] = r3[c][j];
        }
      }
      if (_query != query) return;
      // 🐞 Logcat: upar na 5 (label → score) + samay
      final dbg = res.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      debugPrint("🔍 IMAGE FINE TOP (${clock.elapsedMilliseconds} ms, $n items): "
          "${dbg.take(5).map((e) {
        final m = itemOf[e.key] ?? pick[e.key];
        return "${_s(m?["label_code"] ?? m?["qr_code"])}=${(e.value * 100).toStringAsFixed(1)}";
      }).join("  ")}");
      _fineScores = res;
      _rank();
    } catch (e) {
      debugPrint("⚠️ IMAGE FINE ERR => $e");
    } finally {
      _set(() => _fining = false);
    }
  }

  /// Exact: sauthi upar vado — score uncho ane bija thi chokhkho aagal
  static const double _exactMin = 0.72;
  static const double _exactSure = 0.85;

  void _rank() {
    final List<ImgPrint> qs =
    _queryPrints.isNotEmpty ? _queryPrints : [if (_queryPrint != null) _queryPrint!];
    if (qs.isEmpty) return;

    final List<ImageSearchResult> all = [];
    for (final m in _items) {
      final p = _prints[_key(m)];
      if (p == null) continue;
      double s = 0;
      for (final q in qs) {
        final double v = _similarity(q, p);
        if (v > s) s = v;
      }
      if (s >= _minScore || _fineScores.containsKey(_key(m))) {
        all.add(ImageSearchResult(m, s, false));
      }
    }
    all.sort((a, b) => b.score.compareTo(a.score));

    final List<ImageSearchResult> exact = [];
    final List<ImageSearchResult> similar = [];

    // 🔍 Fine check thayu hoy → enu j pakku
    if (_fineScores.isNotEmpty) {
      double f(ImageSearchResult r) => _fineScores[_key(r.item)] ?? -2;
      final checked = all.where((r) => _fineScores.containsKey(_key(r.item))).toList()
        ..sort((a, b) => f(b).compareTo(f(a)));
      if (checked.isNotEmpty) {
        final double best = f(checked.first);

        // 📸 E j photo bija item ma pan hoy (bija company / branch ma copy)
        //    → e "bijo" nathi, e pan Exact. Gap sacha bija item thi j gano.
        final Uint8List? bt = _fineDb[_key(checked.first.item)];
        final Float64List? bf =
        bt == null ? null : Float64List.fromList([for (final v in bt) v.toDouble()]);
        bool isDup(ImageSearchResult r) {
          if (bf == null) return false;
          final t = _fineDb[_key(r.item)];
          if (t == null) return false;
          final tf = Float64List.fromList([for (final v in t) v.toDouble()]);
          return _nccFlat(bf, tf) >= 0.97 && (best - f(r)) <= 0.06;
        }

        final dups = [for (final r in checked.skip(1)) if (isDup(r)) r];
        final others = [for (final r in checked.skip(1)) if (!isDup(r)) r];
        final double second = others.isNotEmpty ? f(others.first) : 0;
        // Banne rit (fingerprint + jhini chakasni) e j item ne pehlo kahe?
        final dupKeys = {for (final r in [checked.first, ...dups]) _key(r.item)};
        final int coarseIdx = all
            .where((r) => !dupKeys.contains(_key(r.item)) || _key(r.item) == _key(checked.first.item))
            .toList()
            .indexWhere((r) => dupKeys.contains(_key(r.item)));
        final bool agree = coarseIdx == 0 ||
            (coarseIdx >= 0 && coarseIdx < 3 && checked.first.score >= 0.80);

        final bool sure = (best >= 0.80 && best - second >= 0.10) ||
            (best >= 0.92 && best - second >= 0.04) ||
            (best >= 0.65 && best - second >= 0.12) || // background / props vali photo
            (best >= 0.68 && best - second >= 0.08) ||
            (agree && best >= 0.62 && best - second >= 0.05) || // banne rit sahmat
            // ✅ Database ma e j photo hoy j — jhini chakasni no pehlo = Exact
            //    (bija thi aagal hoy, ane 60%+ sarkho hoy)
            (best >= 0.60 && best > second);
        if (sure) {
          final rest = all.where((r) => !_fineScores.containsKey(_key(r.item)));
          final r0 = checked.first;
          exact.add(ImageSearchResult(r0.item, f(r0).clamp(0.0, 1.0), true));
          for (final r in dups) {
            exact.add(ImageSearchResult(r.item, f(r).clamp(0.0, 1.0), true));
          }
          final double low = f(checked.last).clamp(0.0, 1.0);
          similar
            ..addAll([
              for (final r in others)
                ImageSearchResult(r.item, f(r).clamp(0.0, 1.0), false),
            ])
            ..addAll([
              for (final r in rest)
                ImageSearchResult(r.item, math.min(r.score, low), false),
            ]);
          _set(() {
            _exact = exact;
            _similar = similar.take(_maxSimilar).toList();
            _searched = true;
          });
          return;
        }

        // Pakku nathi → Exact nahi, pan jhinvat ma sara item upar
        final good = [
          for (final r in checked.where((r) => f(r) >= 0.45))
            ImageSearchResult(r.item, f(r).clamp(0.0, 1.0), false),
        ];
        if (good.isNotEmpty) {
          final gk = {for (final r in good) _key(r.item)};
          final double low = good.last.score;
          similar
            ..addAll(good)
            ..addAll([
              for (final r in all.where((r) => !gk.contains(_key(r.item))))
                ImageSearchResult(r.item, math.min(r.score, low), false),
            ]);
          _set(() {
            _exact = exact;
            _similar = similar.take(_maxSimilar).toList();
            _searched = true;
          });
          return;
        }
      }
    }

    if (all.isNotEmpty) {
      final double top = all.first.score;
      final double second = all.length > 1 ? all[1].score : 0;
      final double gap = top - second;
      final bool topExact = (top >= _exactSure && gap >= 0.03) ||
          (top >= _exactMin && gap >= 0.08) ||
          top >= 0.97;

      for (int i = 0; i < all.length; i++) {
        final r = all[i];
        // Bijo pan ekdam e j photo (be item ma same photo) → e pan exact
        final bool isExact = topExact &&
            (i == 0 || (r.score >= 0.95 && r.score >= top - 0.01));
        if (isExact) {
          exact.add(ImageSearchResult(r.item, r.score, true));
        } else {
          similar.add(r);
        }
      }
    }

    _set(() {
      _exact = exact;
      _similar = similar.take(_maxSimilar).toList();
      _searched = true;
    });
  }

  /// 🚪 Logout → stock list bhulo (image ni olakh rakho — e image pramane
  ///    j chhe, navo login thay to e j image fari scan na karvi pade)
  static Future<void> _clearOnLogout() async {
    _memItems.clear();
    _memStock.clear();
    _refreshed.clear();
    _userKey = "";
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith("image_search_items_v1_")) await prefs.remove(k);
      }
      final dir = await getApplicationSupportDirectory();
      await for (final e in dir.list()) {
        final String n = e.uri.pathSegments.isEmpty ? "" : e.uri.pathSegments.last;
        if (e is File && n.startsWith("image_search_items_v1_")) {
          await e.delete();
        }
      }
    } catch (e) {
      debugPrint("⚠️ IMAGE LOGOUT CLEAR ERR => $e");
    }
  }

  Future<void> _clearCache() async {
    if (_indexing) return;
    _cache.clear();
    _prints.clear();
    _fineDb.clear();
    await _saveFineDb();
    _memItems.remove(_scope);
    _memStock.remove(_scope);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_itemsKey);
      final f = await _itemsFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _refreshed.remove(_scope);
    _items = [];
    _indexed = false;
    _indexTask = null;
    await _saveCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rescanning all images...")),
      );
    }
    _rank();
    await _ensureIndex();
  }

  // ============================================================
  // UI
  // ============================================================

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  double get _hPad => _isTablet ? 20 : 14;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            /// 🔄 Upar badhu scroll thay
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _uploadCard()),
                  if (_busy || _indexing || _fineVisible)
                    SliverToBoxAdapter(child: _progressCard()),
                  if (_searched && !_busy) ..._resultSlivers(),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),

            /// 📌 Niche hamesha fix — WhatsApp + PDF
            _shareBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, 12, _hPad, 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Search by Image",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
                ),
                SizedBox(height: 2),
                Text(
                  "Find the same or similar item in stock",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _lbText),
            onSelected: (v) {
              if (v == "clear") _clearCache();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: "clear",
                child: Text("Rescan all images"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    final double previewH = _isTablet ? 260 : 200;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          margin: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _lbBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff2563EB).withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview
                Container(
                  height: previewH,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_lbTop, _lbBottom],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: _query == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _lbBorder),
                        ),
                        child: const Icon(Icons.image_search_rounded,
                            size: 28, color: _lbText),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Upload a photo of the jewellery",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _lbText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "Any background works · keep one item in the centre",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  )
                      : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_query!, fit: BoxFit.contain),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _lbBorder),
                          ),
                          child: const Text(
                            "Your photo",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _lbText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _pickBtn(
                          icon: Icons.photo_camera_rounded,
                          label: "Camera",
                          filled: true,
                          onTap: _busy ? null : () => _pick(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pickBtn(
                          icon: Icons.photo_library_rounded,
                          label: "Gallery",
                          filled: false,
                          onTap: _busy ? null : () => _pick(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickBtn({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                colors: [AppColors.primaryDark, AppColors.secondaryDark])
                : null,
            color: filled ? null : _lbSoft,
            borderRadius: BorderRadius.circular(5),
            border: filled ? null : Border.all(color: _lbBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : _lbText),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : _lbText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCard() {
    final bool scanning = _total > 0 && _status.startsWith("Scanning");
    final double? v = scanning ? (_done / _total).clamp(0.0, 1.0) : null;
    final String text = _busy
        ? "Reading your photo..."
        : _fineVisible
        ? "Checking best matches..."
        : scanning
        ? "Scanning images $_done / $_total"
        : (_status.isEmpty
        ? "Preparing..."
        : (_status.startsWith("Loading") && _done > 0)
        ? "$_status • $_done images scanned"
        : _status);

    return Container(
      margin: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lbBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _lbText,
                  ),
                ),
              ),
              if (scanning)
                Text(
                  "${(v! * 100).round()}%",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _lbText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor: _lbSoft,
              color: AppColors.primaryDark,
            ),
          ),
          if (scanning) ...[
            const SizedBox(height: 6),
            Text(
              _queryPrint == null
                  ? "Scanning in background — pick your photo anytime."
                  : "Showing results so far. They update as scanning continues.",
              style: const TextStyle(fontSize: 10.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _resultSlivers() {
    if (_items.isEmpty && !_indexing) {
      return [
        SliverToBoxAdapter(
          child: _emptyBox(
            Icons.hide_image_outlined,
            "None of the $_stockCount stock items have an image yet.\n"
                "Add photos to items in Stock Gallery, then search again.",
          ),
        ),
      ];
    }

    if (_exact.isEmpty && _similar.isEmpty) {
      if (_indexing) return [];
      return [
        SliverToBoxAdapter(
          child: _emptyBox(Icons.search_off_rounded,
              "No matching or similar item found.\nTry a clearer photo."),
        ),
      ];
    }

    return [
      if (_exact.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionTitle(Icons.verified_rounded, "Exact Match",
              _exact.length, _green, _exact),
        ),
        _grid(_exact),
      ],
      if (_similar.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionTitle(Icons.auto_awesome_rounded,
              _exact.isEmpty ? "Similar Items" : "Also Similar",
              _similar.length, _lbText, _similar),
        ),
        _grid(_similar),
      ],
    ];
  }

  Widget _sectionTitle(IconData icon, String title, int count, Color c,
      List<ImageSearchResult> list) {
    final bool allSel =
        list.isNotEmpty && list.every((r) => _sel.contains(_key(r.item)));
    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, 16, _hPad, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w800, color: c),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: c),
            ),
          ),
          const Spacer(),
          if (_canShare)
            InkWell(
              onTap: () => _toggleAll(list),
              borderRadius: BorderRadius.circular(5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allSel
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 17,
                      color: c,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      allSel ? "Unselect" : "Select all",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 📌 Niche fix bar — WhatsApp + PDF (badha / select karela)
  Widget _shareBar() {
    final int n = _sel.length;
    final bool tablet = _isTablet;

    Widget action({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap,
    }) {
      return Expanded(
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: tablet ? 44 : 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.85), color],
                ),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final int total = _pickResults(_exact).length + _pickResults(_similar).length;
    final bool ready = _hasResults && !_busy && !_sharing;

    return Container(
      padding: EdgeInsets.fromLTRB(_hPad, 8, _hPad, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _lbBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ketla jashe — nani line
              Row(
                children: [
                  const Icon(Icons.ios_share_rounded, size: 14, color: _muted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      !_hasResults
                          ? "Search a photo to share results"
                          : n == 0
                          ? "All $total results will be shared"
                          : "$n selected will be shared",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ),
                  if (n > 0)
                    InkWell(
                      onTap: () => setState(() => _sel.clear()),
                      borderRadius: BorderRadius.circular(5),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          "Clear",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffDC2626),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  action(
                    icon: Icons.chat_rounded,
                    label: n == 0 ? "WhatsApp" : "WhatsApp ($n)",
                    color: const Color(0xff25D366),
                    onTap: ready ? () => _share(false) : null,
                  ),
                  const SizedBox(width: 10),
                  action(
                    icon: Icons.picture_as_pdf_rounded,
                    label: n == 0 ? "PDF" : "PDF ($n)",
                    color: const Color(0xffDC2626),
                    onTap: ready ? () => _share(true) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<ImageSearchResult> list) {
    final double w = MediaQuery.of(context).size.width;
    final int cols = w >= 1000 ? 5 : (w >= 700 ? 4 : (w >= 500 ? 3 : 2));

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: _hPad),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
              (_, i) => _resultCard(list[i]),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _resultCard(ImageSearchResult r) {
    final m = r.item;
    final int pct = (r.score * 100).round().clamp(0, 100);
    final bool inStock = !(m["is_sold"]?.toString() == "1" ||
        _s(m["stock_status"], "").toLowerCase().contains("out"));
    final Color badge = r.exact ? _green : _lbText;
    final bool sel = _sel.contains(_key(m));

    return InkWell(
      // Kai select hoy to tap = fakt SELECT (unselect nahi — e circle thi j)
      onTap: _sel.isNotEmpty && _canShare
          ? (sel ? null : () => _toggleSel(m))
          : widget.onItemTap == null
          ? (_canShare && !sel ? () => _toggleSel(m) : null)
          : () {
        Navigator.pop(context);
        widget.onItemTap!(m);
      },
      // Long press = fakt select (unselect circle thi j)
      onLongPress: _canShare && !sel ? () => _toggleSel(m) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel
                ? AppColors.primaryDark
                : (r.exact ? _green.withOpacity(0.5) : _lbBorder),
            width: sel ? 2 : (r.exact ? 1.4 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff2563EB).withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: _lbSoft,
                      child: Image.network(
                        _imageUrl(m)!,
                        fit: BoxFit.cover,
                        // ⚡ Nani decode — jaldi dekhay, ochhi memory
                        cacheWidth: 360,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: _muted),
                        loadingBuilder: (c, child, p) => p == null
                            ? child
                            : const Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))),
                      ),
                    ),
                    // ✅ Select circle
                    if (_canShare)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _toggleSel(m),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primaryDark
                                  : Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel ? Colors.white : _lbBorder,
                                width: 1.5,
                              ),
                            ),
                            child: sel
                                ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    // Match %
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: badge,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          r.exact ? "Exact" : "$pct% match",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s(m["item_name"]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${_s(m["label_code"] ?? m["qr_code"])}  •  ${_s(m["gross_weight"])} g",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (inStock ? _green : const Color(0xffDC2626))
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            inStock ? "In Stock" : "Sold",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: inStock
                                  ? _green
                                  : const Color(0xffDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _s(m["company_name"], ""),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 10, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(IconData icon, String text) {
    return Container(
      margin: EdgeInsets.fromLTRB(_hPad, 16, _hPad, 0),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lbBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: _muted.withOpacity(0.7)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }
}
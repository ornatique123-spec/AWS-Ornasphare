//
// import 'dart:math' as math;
// import 'dart:typed_data';
//
// import 'package:flutter/foundation.dart' show compute;
// import 'package:flutter/material.dart';
// import 'package:image/image.dart' as img;
//
// /// ================================================================
// /// 💎 JEWELLERY BACKGROUND REMOVER — 100% APP SIDE (OFFLINE, FREE)
// ///
// /// Studio photo mate banavelu: saadu ek-rang nu background
// /// (aachho blue / kaalo board / safed kapad).
// ///
// /// Kevi rite kaam kare che:
// ///  1. Image ni chaare kinar parthi 1–3 background rang shodhe
// ///     (daa.ta. bahar grey table + vachche kaalo board — banne)
// ///  2. Kinar thi "flood fill" — background jevo rang hoy tya sudhi
// ///     felay (halki shadow / gradient pan sambhale)
// ///  3. Andar na band bhaag (necklace no U, chain na gaala) pan saaf
// ///  4. Nana dhaba / noise (background na speck) kadhi nakhe
// ///  5. Kinar soft kare + blue/black fringe (rang ni chhaya) kadhe
// ///  6. Jewellery ni aaspas 6% jagya rakhi auto-crop
// ///
// /// Badhu kaam compute() thi alag isolate ma → UI hang nathi thatu.
// ///
// /// ⚠️ Photo ma label sticker hoy to pehla CROP kari nakho,
// ///    nahi to e jewellery no bhaag gani ne rahi jase.
// /// ================================================================
//
// class JewelleryBgRemover {
//   JewelleryBgRemover._();
//
//   /// Background kadhi ne TRANSPARENT PNG bytes aape.
//   ///
//   /// [strength] 12–80: ochhu → jewellery surakshit (pan background
//   /// thodu rahi shake), vadhu → background vadhu saaf (pan halki
//   /// kinar kapai shake). Default 32 studio photo mate saaru.
//   static Future<Uint8List> removeBackground(
//       Uint8List imageBytes, {
//         double strength = 32,
//         int maxSide = 1600,
//         bool autoCrop = true,
//       }) {
//     return compute(_removeBgWorker, <String, dynamic>{
//       "bytes": imageBytes,
//       "tol": strength,
//       "maxSide": maxSide,
//       "crop": autoCrop,
//     });
//   }
//
//   /// Transparent PNG ne [color] background par muki JPG bytes aape.
//   /// [shadow] = jewellery niche halki soft shadow (premium look).
//   static Future<Uint8List> composeOnColor(
//       Uint8List transparentPng,
//       Color color, {
//         bool shadow = true,
//       }) {
//     return compute(_composeWorker, <String, dynamic>{
//       "png": transparentPng,
//       "color": color.value,
//       "shadow": shadow,
//     });
//   }
// }
//
// /// ================================================================
// /// TRANSPARENT PREVIEW MATE CHECKERBOARD
// /// ================================================================
//
// class CheckerboardPainter extends CustomPainter {
//   final double cell;
//
//   const CheckerboardPainter({this.cell = 10});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.drawRect(
//       Offset.zero & size,
//       Paint()..color = const Color(0xffFFFFFF),
//     );
//
//     final Paint dark = Paint()..color = const Color(0xffE7E7EA);
//
//     final int cols = (size.width / cell).ceil();
//     final int rows = (size.height / cell).ceil();
//
//     for (int y = 0; y < rows; y++) {
//       for (int x = 0; x < cols; x++) {
//         if ((x + y) % 2 == 0) {
//           canvas.drawRect(
//             Rect.fromLTWH(x * cell, y * cell, cell, cell),
//             dark,
//           );
//         }
//       }
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CheckerboardPainter oldDelegate) =>
//       oldDelegate.cell != cell;
// }
//
// /// ================================================================
// /// HELPERS (isolate ma chale)
// /// ================================================================
//
// img.Image _toRgba8(img.Image src) {
//   if (src.numChannels == 4 && src.format == img.Format.uint8) return src;
//   return src.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
// }
//
// int _c255(double v) {
//   if (v <= 0) return 0;
//   if (v >= 255) return 255;
//   return v.round();
// }
//
// /// Ek channel (alpha) par box blur — 3 vaar chalavo to gaussian jevu
// Uint8List _boxBlur(Uint8List src, int w, int h, int r) {
//   final Uint8List tmp = Uint8List(w * h);
//   final Uint8List dst = Uint8List(w * h);
//   final int win = r * 2 + 1;
//
//   // Horizontal
//   for (int y = 0; y < h; y++) {
//     final int row = y * w;
//     int sum = 0;
//
//     for (int k = -r; k <= r; k++) {
//       sum += src[row + math.min(w - 1, math.max(0, k))];
//     }
//
//     for (int x = 0; x < w; x++) {
//       tmp[row + x] = sum ~/ win;
//       final int addX = math.min(w - 1, x + r + 1);
//       final int subX = math.max(0, x - r);
//       sum += src[row + addX] - src[row + subX];
//     }
//   }
//
//   // Vertical
//   for (int x = 0; x < w; x++) {
//     int sum = 0;
//
//     for (int k = -r; k <= r; k++) {
//       sum += tmp[math.min(h - 1, math.max(0, k)) * w + x];
//     }
//
//     for (int y = 0; y < h; y++) {
//       dst[y * w + x] = sum ~/ win;
//       final int addY = math.min(h - 1, y + r + 1);
//       final int subY = math.max(0, y - r);
//       sum += tmp[addY * w + x] - tmp[subY * w + x];
//     }
//   }
//
//   return dst;
// }
//
// /// ================================================================
// /// 🔥 BACKGROUND REMOVE WORKER (MULTI-COLOR BACKGROUND)
// ///
// /// Kinar parthi 1–3 background rang shodhe che (k-means).
// /// Daakhla tarike: bahar grey table + vachche kaalo board →
// /// banne background gana ne saaf thay.
// /// ================================================================
//
// class _BgCluster {
//   double y = 0, u = 0, v = 0, r = 0, g = 0, b = 0;
//   double cw = 1.0; // chroma weight (kaala/ghera background mate vadhu)
//   double yStd = 4.0; // background ni texture (brightness ketli badlay)
//   int count = 0;
// }
//
// Uint8List _removeBgWorker(Map<String, dynamic> a) {
//   final Uint8List input = a["bytes"] as Uint8List;
//   final double tol = (a["tol"] as num).toDouble();
//   final int maxSide = a["maxSide"] as int;
//   final bool autoCrop = a["crop"] as bool;
//
//   img.Image? decoded = img.decodeImage(input);
//   if (decoded == null) throw Exception("Unable to decode image");
//
//   // Camera photo ni EXIF rotation sachvi
//   decoded = img.bakeOrientation(decoded);
//
//   // Moti image → nani (speed + memory)
//   if (math.max(decoded.width, decoded.height) > maxSide) {
//     decoded = decoded.width >= decoded.height
//         ? img.copyResize(decoded,
//         width: maxSide, interpolation: img.Interpolation.average)
//         : img.copyResize(decoded,
//         height: maxSide, interpolation: img.Interpolation.average);
//   }
//
//   final img.Image src = _toRgba8(decoded);
//
//   final int w = src.width;
//   final int h = src.height;
//   final int n = w * h;
//
//   final Uint8List px =
//   Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));
//
//   // ==============================================================
//   // 1) Brightness (Y) + rang (U, V)
//   // ==============================================================
//   final Float32List yA = Float32List(n);
//   final Float32List uA = Float32List(n);
//   final Float32List vA = Float32List(n);
//
//   for (int i = 0; i < n; i++) {
//     final int o = i * 4;
//     final double r = px[o].toDouble();
//     final double g = px[o + 1].toDouble();
//     final double b = px[o + 2].toDouble();
//     final double y = 0.299 * r + 0.587 * g + 0.114 * b;
//     yA[i] = y;
//     uA[i] = b - y;
//     vA[i] = r - y;
//   }
//
//   // ==============================================================
//   // 2) KINAR NA PIXELS → 1 thi 3 BACKGROUND RANG (k-means)
//   // ==============================================================
//   final List<int> border = [];
//   for (int x = 0; x < w; x++) {
//     border.add(x);
//     border.add((h - 1) * w + x);
//   }
//   for (int y = 1; y < h - 1; y++) {
//     border.add(y * w);
//     border.add(y * w + w - 1);
//   }
//
//   final int bn = border.length;
//
//   // Shuruat: ghero, vachalo, aachho (brightness pramane)
//   final List<int> byY = List<int>.from(border)
//     ..sort((p, q) => yA[p].compareTo(yA[q]));
//
//   final List<_BgCluster> cs = [];
//   for (final double f in [0.03, 0.5, 0.97]) {
//     final int idx = byY[math.min(bn - 1, math.max(0, (bn * f).floor()))];
//     cs.add(_BgCluster()
//       ..y = yA[idx]
//       ..u = uA[idx]
//       ..v = vA[idx]);
//   }
//
//   final Int8List assign = Int8List(bn);
//
//   for (int iter = 0; iter < 10; iter++) {
//     for (int k = 0; k < bn; k++) {
//       final int i = border[k];
//       double best = double.infinity;
//       int bi = 0;
//       for (int c = 0; c < cs.length; c++) {
//         final double dy = yA[i] - cs[c].y;
//         final double du = uA[i] - cs[c].u;
//         final double dv = vA[i] - cs[c].v;
//         final double d = dy * dy + du * du + dv * dv;
//         if (d < best) {
//           best = d;
//           bi = c;
//         }
//       }
//       assign[k] = bi;
//     }
//
//     for (final c in cs) {
//       c.y = c.u = c.v = c.r = c.g = c.b = 0;
//       c.count = 0;
//     }
//
//     for (int k = 0; k < bn; k++) {
//       final int i = border[k];
//       final _BgCluster c = cs[assign[k]];
//       c.y += yA[i];
//       c.u += uA[i];
//       c.v += vA[i];
//       c.r += px[i * 4];
//       c.g += px[i * 4 + 1];
//       c.b += px[i * 4 + 2];
//       c.count++;
//     }
//
//     for (final c in cs) {
//       if (c.count == 0) continue;
//       c.y /= c.count;
//       c.u /= c.count;
//       c.v /= c.count;
//       c.r /= c.count;
//       c.g /= c.count;
//       c.b /= c.count;
//     }
//   }
//
//   // Darek background ni texture (brightness no std)
//       {
//     final List<double> sq = List<double>.filled(cs.length, 0);
//     for (int k = 0; k < bn; k++) {
//       final double d = yA[border[k]] - cs[assign[k]].y;
//       sq[assign[k]] += d * d;
//     }
//     for (int c = 0; c < cs.length; c++) {
//       if (cs[c].count > 0) cs[c].yStd = math.sqrt(sq[c] / cs[c].count);
//     }
//   }
//
//   // Nana cluster (kinar par aavi gayeli jewellery / noise) kadho
//   final List<_BgCluster> bgs = cs
//   // 4% kinar pan puratu (display stand / board kinar ne thodu j adtu hoy)
//       .where((c) => c.count >= bn * 0.04)
//       .toList()
//     ..sort((p, q) => q.count.compareTo(p.count));
//
//   // Lagbhag sarkha rang → ek j gano
//   final List<_BgCluster> clusters = [];
//   for (final c in bgs) {
//     final bool dup = clusters.any((k) {
//       final double dy = k.y - c.y, du = k.u - c.u, dv = k.v - c.v;
//       return math.sqrt(dy * dy + du * du + dv * dv) < tol * 0.5;
//     });
//     if (!dup) clusters.add(c);
//   }
//
//   if (clusters.isEmpty) clusters.add(cs.reduce((p, q) => p.count >= q.count ? p : q));
//
//   // Ghera background (kaalo board) par rang no farak vadhu mahatva no
//   // → ghera green meenakari / maroon moti background na gana jay
//   for (final c in clusters) {
//     c.cw = c.y < 80 ? 2.2 : 1.0;
//   }
//
//   // ==============================================================
//   // 3) DAREK PIXEL NU NAJIK NA BACKGROUND THI ANTAR (ek j vaar)
//   // ==============================================================
//   final Float32List dBg = Float32List(n);
//   final Uint8List nearC = Uint8List(n);
//
//   for (int i = 0; i < n; i++) {
//     double best = double.infinity;
//     int bi = 0;
//     for (int c = 0; c < clusters.length; c++) {
//       final _BgCluster k = clusters[c];
//       final double dy = yA[i] - k.y;
//       final double wy = dy > 0 ? 1.0 : 0.35; // shadow ochhu, chamak puri
//       final double du = uA[i] - k.u;
//       final double dv = vA[i] - k.v;
//       final double d = wy * dy * dy + k.cw * (du * du + dv * dv);
//       if (d < best) {
//         best = d;
//         bi = c;
//       }
//     }
//     dBg[i] = best;
//     nearC[i] = bi;
//   }
//
//   double d2pair(int p, int q) {
//     final double dy = yA[p] - yA[q];
//     final double du = uA[p] - uA[q];
//     final double dv = vA[p] - vA[q];
//     return 0.5 * dy * dy + du * du + dv * dv;
//   }
//
//   final double t2 = tol * tol;
//   final double loose2 = (tol * 1.6) * (tol * 1.6);
//   final double step2 = (tol * 0.45) * (tol * 0.45);
//   final double strict2 = (tol * 0.75) * (tol * 0.75);
//
//   // ==============================================================
//   // 4) FLOOD FILL — kinar thi background felavo
//   // ==============================================================
//   final Uint8List isBg = Uint8List(n);
//   final Int32List queue = Int32List(n);
//   int head = 0;
//   int tail = 0;
//
//   for (final int i in border) {
//     if (isBg[i] == 0 && dBg[i] < loose2) {
//       isBg[i] = 1;
//       queue[tail++] = i;
//     }
//   }
//
//   void grow(int p, int q) {
//     if (isBg[q] != 0) return;
//     final double dq = dBg[q];
//     // Halka gradient fakt GHERA background (board) par j —
//     // aachha background par patli sonani wire na kapay
//     if (dq < t2 ||
//         (clusters[nearC[q]].y < 80 && dq < loose2 && d2pair(p, q) < step2)) {
//       isBg[q] = 1;
//       queue[tail++] = q;
//     }
//   }
//
//   while (head < tail) {
//     final int p = queue[head++];
//     final int x = p % w;
//     if (x > 0) grow(p, p - 1);
//     if (x < w - 1) grow(p, p + 1);
//     if (p >= w) grow(p, p - w);
//     if (p < n - w) grow(p, p + w);
//   }
//
//   // ==============================================================
//   // 5) ANDAR NA BAND BHAAG (necklace no U, label, board, jaali)
//   //    - Mota bhaag: hamesha background
//   //    - Nana bhaag: fakt jo background jevu SAADU (texture vagar)
//   //      hoy to j → kundan / moti / meenakari surakshit rahe
//   // ==============================================================
//   final int minHole = math.max(400, (n * 0.002).round());
//   final Uint8List seen = Uint8List(n);
//   final Int32List clusterHits = Int32List(clusters.length);
//
//   for (int s = 0; s < n; s++) {
//     if (isBg[s] != 0 || seen[s] != 0 || dBg[s] >= strict2) continue;
//
//     head = 0;
//     tail = 0;
//     seen[s] = 1;
//     queue[tail++] = s;
//
//     double sumD = 0, sumY = 0, sumY2 = 0;
//     clusterHits.fillRange(0, clusterHits.length, 0);
//
//     while (head < tail) {
//       final int p = queue[head++];
//       final int x = p % w;
//
//       sumD += math.sqrt(dBg[p]);
//       sumY += yA[p];
//       sumY2 += yA[p] * yA[p];
//       clusterHits[nearC[p]]++;
//
//       if (x > 0 && isBg[p - 1] == 0 && seen[p - 1] == 0 && dBg[p - 1] < strict2) {
//         seen[p - 1] = 1;
//         queue[tail++] = p - 1;
//       }
//       if (x < w - 1 && isBg[p + 1] == 0 && seen[p + 1] == 0 && dBg[p + 1] < strict2) {
//         seen[p + 1] = 1;
//         queue[tail++] = p + 1;
//       }
//       if (p >= w && isBg[p - w] == 0 && seen[p - w] == 0 && dBg[p - w] < strict2) {
//         seen[p - w] = 1;
//         queue[tail++] = p - w;
//       }
//       if (p < n - w && isBg[p + w] == 0 && seen[p + w] == 0 && dBg[p + w] < strict2) {
//         seen[p + w] = 1;
//         queue[tail++] = p + w;
//       }
//     }
//
//     bool remove = tail >= minHole;
//
//     if (!remove && tail >= 60) {
//       int ci = 0;
//       for (int c = 1; c < clusters.length; c++) {
//         if (clusterHits[c] > clusterHits[ci]) ci = c;
//       }
//       final double meanD = sumD / tail;
//       final double meanY = sumY / tail;
//       final double stdY = math.sqrt(math.max(0.0, sumY2 / tail - meanY * meanY));
//
//       remove = meanD < tol * 0.4 && stdY < clusters[ci].yStd * 1.8 + 4;
//     }
//
//     if (remove) {
//       for (int k = 0; k < tail; k++) {
//         isBg[queue[k]] = 1;
//       }
//     }
//   }
//
//   // ==============================================================
//   // 5b) PENDANT NICHE NI SHADOW (aachha background par)
//   //     Pendant upar uthelu hoy tyare niche grey chhaya pade.
//   //     Shadow = background karta ghero, rang lagbhag sarkho,
//   //     ane SAADO (texture vagar). Kundan/CZ ma chamak hoy →
//   //     texture vadhu → surakshit. Oxidised (khub ghero) → surakshit.
//   // ==============================================================
//   bool shadowCand(int i) {
//     if (isBg[i] != 0) return false;
//     final _BgCluster c = clusters[nearC[i]];
//     if (c.y < 80) return false; // fakt aachha background
//     final double y = yA[i];
//     if (y >= c.y - 12 || y <= c.y * 0.6) return false;
//     final double du = uA[i] - c.u;
//     final double dv = vA[i] - c.v;
//     return du * du + dv * dv < 26 * 26;
//   }
//
//   seen.fillRange(0, n, 0);
//
//   for (int s = 0; s < n; s++) {
//     if (seen[s] != 0 || !shadowCand(s)) continue;
//
//     head = 0;
//     tail = 0;
//     seen[s] = 1;
//     queue[tail++] = s;
//
//     double sumY = 0, sumY2 = 0;
//
//     while (head < tail) {
//       final int p = queue[head++];
//       final int x = p % w;
//
//       sumY += yA[p];
//       sumY2 += yA[p] * yA[p];
//
//       if (x > 0 && seen[p - 1] == 0 && shadowCand(p - 1)) {
//         seen[p - 1] = 1;
//         queue[tail++] = p - 1;
//       }
//       if (x < w - 1 && seen[p + 1] == 0 && shadowCand(p + 1)) {
//         seen[p + 1] = 1;
//         queue[tail++] = p + 1;
//       }
//       if (p >= w && seen[p - w] == 0 && shadowCand(p - w)) {
//         seen[p - w] = 1;
//         queue[tail++] = p - w;
//       }
//       if (p < n - w && seen[p + w] == 0 && shadowCand(p + w)) {
//         seen[p + w] = 1;
//         queue[tail++] = p + w;
//       }
//     }
//
//     if (tail < 250) continue;
//
//     final double meanY = sumY / tail;
//     final double stdY = math.sqrt(math.max(0.0, sumY2 / tail - meanY * meanY));
//
//     if (stdY < 12) {
//       for (int k = 0; k < tail; k++) {
//         isBg[queue[k]] = 1;
//       }
//     }
//   }
//
//   // ==============================================================
//   // 6) NANA DHABA / NOISE + LABEL NA QR / AKSHAR KADHO
//   //    QR / akshar = background jevo j "rang vagar no" (grey/kaalo)
//   //    sonu, moti, meenakari = rang vala → surakshit
//   // ==============================================================
//   final int minIsland = math.max(25, (n * 0.00015).round());
//   final int maxNeutral = (n * 0.003).round();
//   seen.fillRange(0, n, 0);
//
//   for (int s = 0; s < n; s++) {
//     if (isBg[s] != 0 || seen[s] != 0) continue;
//
//     head = 0;
//     tail = 0;
//     seen[s] = 1;
//     queue[tail++] = s;
//
//     double sumChroma = 0;
//
//     while (head < tail) {
//       final int p = queue[head++];
//       final int x = p % w;
//
//       final _BgCluster c = clusters[nearC[p]];
//       final double du = uA[p] - c.u;
//       final double dv = vA[p] - c.v;
//       sumChroma += math.sqrt(du * du + dv * dv);
//
//       if (x > 0 && isBg[p - 1] == 0 && seen[p - 1] == 0) {
//         seen[p - 1] = 1;
//         queue[tail++] = p - 1;
//       }
//       if (x < w - 1 && isBg[p + 1] == 0 && seen[p + 1] == 0) {
//         seen[p + 1] = 1;
//         queue[tail++] = p + 1;
//       }
//       if (p >= w && isBg[p - w] == 0 && seen[p - w] == 0) {
//         seen[p - w] = 1;
//         queue[tail++] = p - w;
//       }
//       if (p < n - w && isBg[p + w] == 0 && seen[p + w] == 0) {
//         seen[p + w] = 1;
//         queue[tail++] = p + w;
//       }
//     }
//
//     final bool tooSmall = tail < minIsland;
//     final bool labelPrint = tail < maxNeutral && sumChroma / tail < 14;
//
//     if (tooSmall || labelPrint) {
//       for (int k = 0; k < tail; k++) {
//         isBg[queue[k]] = 1;
//       }
//     }
//   }
//
//   // ==============================================================
//   // 6b) CHAMAKTI FLOOR PAR NU PRATIBIMB (REFLECTION) KADHO
//   //     Kaala glossy background par sonu niche jankhu dekhay che.
//   //     Pratibimb = mukhya jewellery thi ALAG tukdo + ghano jankho.
//   //     Earring jeva alag tukda mukhya jetla j chamkila → surakshit.
//   // ==============================================================
//       {
//     final Int32List comp = Int32List(n); // 0 = background
//     final List<int> compSize = [0];
//     final List<double> compSumY = [0];
//     final List<double> compSumChroma = [0];
//
//     for (int s = 0; s < n; s++) {
//       if (isBg[s] != 0 || comp[s] != 0) continue;
//
//       final int id = compSize.length;
//       head = 0;
//       tail = 0;
//       comp[s] = id;
//       queue[tail++] = s;
//       double sumY = 0;
//       double sumChroma = 0;
//
//       while (head < tail) {
//         final int p = queue[head++];
//         final int x = p % w;
//         sumY += yA[p];
//
//         final _BgCluster bc = clusters[nearC[p]];
//         final double du = uA[p] - bc.u;
//         final double dv = vA[p] - bc.v;
//         sumChroma += math.sqrt(du * du + dv * dv);
//
//         if (x > 0 && isBg[p - 1] == 0 && comp[p - 1] == 0) {
//           comp[p - 1] = id;
//           queue[tail++] = p - 1;
//         }
//         if (x < w - 1 && isBg[p + 1] == 0 && comp[p + 1] == 0) {
//           comp[p + 1] = id;
//           queue[tail++] = p + 1;
//         }
//         if (p >= w && isBg[p - w] == 0 && comp[p - w] == 0) {
//           comp[p - w] = id;
//           queue[tail++] = p - w;
//         }
//         if (p < n - w && isBg[p + w] == 0 && comp[p + w] == 0) {
//           comp[p + w] = id;
//           queue[tail++] = p + w;
//         }
//       }
//
//       compSize.add(tail);
//       compSumY.add(sumY);
//       compSumChroma.add(sumChroma);
//     }
//
//     if (compSize.length > 2) {
//       int mainId = 1;
//       for (int id = 2; id < compSize.length; id++) {
//         if (compSize[id] > compSize[mainId]) mainId = id;
//       }
//
//       final double mainY = compSumY[mainId] / compSize[mainId];
//       final Uint8List dim = Uint8List(compSize.length);
//
//       for (int id = 1; id < compSize.length; id++) {
//         if (id == mainId) continue;
//         final double meanY = compSumY[id] / compSize[id];
//         // Pratibimb: ghano jankho alag tukdo
//         if (meanY < mainY * 0.55 && compSize[id] < compSize[mainId] * 0.5) {
//           dim[id] = 1;
//           continue;
//         }
//
//         // Label na QR / akshar: nano, jankho, rang vagar no tukdo
//         // (CZ stud earring chamkila hoy → surakshit)
//         final double meanChroma = compSumChroma[id] / compSize[id];
//         if (compSize[id] < n * 0.003 && meanY < mainY * 0.8 && meanChroma < 20) {
//           dim[id] = 1;
//         }
//       }
//
//       for (int i = 0; i < n; i++) {
//         if (comp[i] != 0 && dim[comp[i]] == 1) isBg[i] = 1;
//       }
//     }
//   }
//
//   // ==============================================================
//   // 7) SOFT KINAR + RANG NI CHHAYA (fringe) KADHO
//   // ==============================================================
//   final Uint8List out = Uint8List(n * 4);
//   final double softFrom = tol * 0.5;
//   final double softRange = tol * 0.9;
//
//   int minX = w, minY = h, maxX = -1, maxY = -1;
//
//   for (int i = 0; i < n; i++) {
//     if (isBg[i] != 0) continue; // transparent
//
//     final int o = i * 4;
//     double r = px[o].toDouble();
//     double g = px[o + 1].toDouble();
//     double b = px[o + 2].toDouble();
//     int alpha = 255;
//
//     final int x = i % w;
//     final bool edge = (x > 0 && isBg[i - 1] != 0) ||
//         (x < w - 1 && isBg[i + 1] != 0) ||
//         (i >= w && isBg[i - w] != 0) ||
//         (i < n - w && isBg[i + w] != 0);
//
//     if (edge) {
//       final double d = math.sqrt(dBg[i]);
//       final double af = ((d - softFrom) / softRange).clamp(0.0, 1.0);
//
//       if (af <= 0.02) continue;
//
//       if (af < 1.0) {
//         final _BgCluster c = clusters[nearC[i]];
//         alpha = _c255(af * 255);
//         // C = a*F + (1-a)*B  →  F = (C - (1-a)*B) / a
//         r = (r - (1 - af) * c.r) / af;
//         g = (g - (1 - af) * c.g) / af;
//         b = (b - (1 - af) * c.b) / af;
//       }
//     }
//
//     out[o] = _c255(r);
//     out[o + 1] = _c255(g);
//     out[o + 2] = _c255(b);
//     out[o + 3] = alpha;
//
//     final int y = i ~/ w;
//     if (x < minX) minX = x;
//     if (x > maxX) maxX = x;
//     if (y < minY) minY = y;
//     if (y > maxY) maxY = y;
//   }
//
//   if (maxX < 0) {
//     throw Exception("No jewellery found. Try a lower strength.");
//   }
//
//   img.Image result = img.Image.fromBytes(
//     width: w,
//     height: h,
//     bytes: out.buffer,
//     numChannels: 4,
//     order: img.ChannelOrder.rgba,
//   );
//
//   // ==============================================================
//   // 8) AUTO CROP — jewellery vachche, 6% jagya saathe
//   // ==============================================================
//   if (autoCrop) {
//     final int bw = maxX - minX + 1;
//     final int bh = maxY - minY + 1;
//     final int pad = (math.max(bw, bh) * 0.06).round();
//
//     final int cx = math.max(0, minX - pad);
//     final int cy = math.max(0, minY - pad);
//     final int cw = math.min(w, maxX + pad + 1) - cx;
//     final int ch = math.min(h, maxY + pad + 1) - cy;
//
//     result = img.copyCrop(result, x: cx, y: cy, width: cw, height: ch);
//   }
//
//   return Uint8List.fromList(img.encodePng(result, level: 6));
// }
//
// /// ================================================================
// /// 🎨 COLOR BACKGROUND + SOFT SHADOW WORKER
// /// ================================================================
//
// Uint8List _composeWorker(Map<String, dynamic> a) {
//   final img.Image? decoded = img.decodePng(a["png"] as Uint8List);
//   if (decoded == null) throw Exception("Invalid PNG");
//
//   final img.Image src = _toRgba8(decoded);
//
//   final int w = src.width;
//   final int h = src.height;
//   final int n = w * h;
//
//   final Uint8List px =
//   Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));
//
//   final int argb = a["color"] as int;
//   final double cr = ((argb >> 16) & 0xff).toDouble();
//   final double cg = ((argb >> 8) & 0xff).toDouble();
//   final double cb = (argb & 0xff).toDouble();
//
//   final bool shadow = a["shadow"] as bool;
//
//   Uint8List? sh;
//   int dy = 0;
//
//   if (shadow) {
//     final Uint8List alpha = Uint8List(n);
//     for (int i = 0; i < n; i++) {
//       alpha[i] = px[i * 4 + 3];
//     }
//
//     final int r = math.max(3, (math.min(w, h) * 0.014).round());
//     sh = _boxBlur(_boxBlur(_boxBlur(alpha, w, h, r), w, h, r), w, h, r);
//     dy = math.max(2, (h * 0.012).round());
//   }
//
//   final Uint8List out = Uint8List(n * 3);
//
//   for (int i = 0; i < n; i++) {
//     double r0 = cr, g0 = cg, b0 = cb;
//
//     if (sh != null) {
//       final int y = i ~/ w;
//       final int sy = y - dy;
//       if (sy >= 0) {
//         final double s = sh[sy * w + (i - y * w)] / 255.0 * 0.32;
//         r0 *= 1 - s;
//         g0 *= 1 - s;
//         b0 *= 1 - s;
//       }
//     }
//
//     final int o = i * 4;
//     final double al = px[o + 3] / 255.0;
//
//     out[i * 3] = _c255(px[o] * al + r0 * (1 - al));
//     out[i * 3 + 1] = _c255(px[o + 1] * al + g0 * (1 - al));
//     out[i * 3 + 2] = _c255(px[o + 2] * al + b0 * (1 - al));
//   }
//
//   final img.Image result = img.Image.fromBytes(
//     width: w,
//     height: h,
//     bytes: out.buffer,
//     numChannels: 3,
//     order: img.ChannelOrder.rgb,
//   );
//
//   return Uint8List.fromList(img.encodeJpg(result, quality: 92));
// }


import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// ================================================================
/// 💎 JEWELLERY BACKGROUND REMOVER — 100% APP SIDE (OFFLINE, FREE)
///
/// Studio photo mate banavelu: saadu ek-rang nu background
/// (aachho blue / kaalo board / safed kapad).
///
/// Kevi rite kaam kare che:
///  1. Image ni chaare kinar parthi 1–3 background rang shodhe
///  2. Kinar thi "flood fill" — background jevo rang hoy tya sudhi felay
///  3. Andar na band bhaag (necklace no U, chain na gaala) pan saaf
///  4. 🔥 Jewellery na tukda 8-DISHA (diagonal pan) thi jode →
///     patli traansi chain tuti ne nana tukda nathi banti
///  5. 🔥 Jewellery ni aaspas "SURAKSHIT VISTAR" — mukhya jewellery
///     ni najik na badha tukda (chain, kaala mani, latkan) KYARE PAN
///     noise / label / pratibimb gani ne kadhata nathi
///  6. Door na nana dhaba, label QR, chamakti floor nu pratibimb kadhe
///  7. Kinar soft kare + blue/black fringe (rang ni chhaya) kadhe
///  8. Jewellery ni aaspas 6% jagya rakhi auto-crop (optional)
///
/// Badhu kaam compute() thi alag isolate ma → UI hang nathi thatu.
///
/// ⚠️ Photo ma label sticker jewellery ne adtu hoy to pehla CROP
///    kari nakho, nahi to e jewellery no bhaag gani ne rahi jase.
/// ================================================================

class JewelleryBgRemover {
  JewelleryBgRemover._();

  /// Background kadhi ne TRANSPARENT PNG bytes aape.
  ///
  /// [strength] 12–80: ochhu → jewellery surakshit (pan background
  /// thodu rahi shake), vadhu → background vadhu saaf (pan halki
  /// kinar kapai shake). Default 30 studio photo mate saaru.
  ///
  /// [autoCrop] = false → output image input jetli j size ni rahe
  /// (HD mask / brush editor mate jaruri).
  ///
  /// [cleanShadow] = true → jewellery ni aaspas / vachche ni grey
  /// chhaya (photo ni asli shadow) pan kadhe. Chandi (silver) ni
  /// item ma kinar kapati lage to false karo.
  static Future<Uint8List> removeBackground(
      Uint8List imageBytes, {
        double strength = 30,
        int maxSide = 1920,
        bool autoCrop = true,
        bool cleanShadow = true,
      }) {
    return compute(_removeBgWorker, <String, dynamic>{
      "bytes": imageBytes,
      "tol": strength,
      "maxSide": maxSide,
      "crop": autoCrop,
      "cleanShadow": cleanShadow,
    });
  }

  /// 💍 SET MATHI ALAG PIECE (try-on mate)
  ///
  /// Transparent PNG ma je mota alag tukda hoy (necklace, dabu
  /// earring, jamnu earring) e darek ne alag PNG ma aape.
  /// Moto thi nano kram ma: [0] = sauthi moto (mostly necklace).
  static Future<List<Uint8List>> extractPieces(Uint8List transparentPng) {
    return compute(_extractPiecesWorker, transparentPng);
  }

  /// Transparent PNG ne [color] background par muki JPG bytes aape.
  /// [shadow] = jewellery niche halki soft shadow (premium look).
  static Future<Uint8List> composeOnColor(
      Uint8List transparentPng,
      Color color, {
        bool shadow = true,
      }) {
    return compute(_composeWorker, <String, dynamic>{
      "png": transparentPng,
      "color": color.value,
      "shadow": shadow,
    });
  }
}

/// ================================================================
/// TRANSPARENT PREVIEW MATE CHECKERBOARD
/// ================================================================

class CheckerboardPainter extends CustomPainter {
  final double cell;

  const CheckerboardPainter({this.cell = 10});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xffFFFFFF),
    );

    final Paint dark = Paint()..color = const Color(0xffE7E7EA);

    final int cols = (size.width / cell).ceil();
    final int rows = (size.height / cell).ceil();

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if ((x + y) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) =>
      oldDelegate.cell != cell;
}

/// ================================================================
/// HELPERS (isolate ma chale)
/// ================================================================

img.Image _toRgba8(img.Image src) {
  if (src.numChannels == 4 && src.format == img.Format.uint8) return src;
  return src.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
}

int _c255(double v) {
  if (v <= 0) return 0;
  if (v >= 255) return 255;
  return v.round();
}

/// Ek channel (alpha) par box blur — 3 vaar chalavo to gaussian jevu
Uint8List _boxBlur(Uint8List src, int w, int h, int r) {
  final Uint8List tmp = Uint8List(w * h);
  final Uint8List dst = Uint8List(w * h);
  final int win = r * 2 + 1;

  // Horizontal
  for (int y = 0; y < h; y++) {
    final int row = y * w;
    int sum = 0;

    for (int k = -r; k <= r; k++) {
      sum += src[row + math.min(w - 1, math.max(0, k))];
    }

    for (int x = 0; x < w; x++) {
      tmp[row + x] = sum ~/ win;
      final int addX = math.min(w - 1, x + r + 1);
      final int subX = math.max(0, x - r);
      sum += src[row + addX] - src[row + subX];
    }
  }

  // Vertical
  for (int x = 0; x < w; x++) {
    int sum = 0;

    for (int k = -r; k <= r; k++) {
      sum += tmp[math.min(h - 1, math.max(0, k)) * w + x];
    }

    for (int y = 0; y < h; y++) {
      dst[y * w + x] = sum ~/ win;
      final int addY = math.min(h - 1, y + r + 1);
      final int subY = math.max(0, y - r);
      sum += tmp[addY * w + x] - tmp[subY * w + x];
    }
  }

  return dst;
}

/// ================================================================
/// 🔥 BINARY DILATE (square, radius r) — sliding window count
///
/// Mask (0/1) ne r pixel sudhi felave. Single pixel pan sachvay
/// (box blur ni jem nano thai ne gayab nathi thato).
/// ================================================================

Uint8List _dilate(Uint8List m, int w, int h, int r) {
  if (r <= 0) return Uint8List.fromList(m);

  final Uint8List tmp = Uint8List(w * h);
  final Uint8List dst = Uint8List(w * h);

  // Horizontal
  for (int y = 0; y < h; y++) {
    final int row = y * w;
    int cnt = 0;

    for (int k = 0; k <= r && k < w; k++) {
      if (m[row + k] != 0) cnt++;
    }

    for (int x = 0; x < w; x++) {
      if (cnt > 0) tmp[row + x] = 1;

      final int add = x + r + 1;
      if (add < w && m[row + add] != 0) cnt++;

      final int sub = x - r;
      if (sub >= 0 && m[row + sub] != 0) cnt--;
    }
  }

  // Vertical
  for (int x = 0; x < w; x++) {
    int cnt = 0;

    for (int k = 0; k <= r && k < h; k++) {
      if (tmp[k * w + x] != 0) cnt++;
    }

    for (int y = 0; y < h; y++) {
      if (cnt > 0) dst[y * w + x] = 1;

      final int add = y + r + 1;
      if (add < h && tmp[add * w + x] != 0) cnt++;

      final int sub = y - r;
      if (sub >= 0 && tmp[sub * w + x] != 0) cnt--;
    }
  }

  return dst;
}

/// ================================================================
/// 🔥 8-DISHA (diagonal saathe) CONNECTED TUKDA
///
/// comp[i] = 0 → khaali, nahi to tukda no id (1, 2, ...).
/// Return: darek id ni size (index 0 = khaali).
/// Patli chain ghani vaar fakt diagonal thi judayeli hoy →
/// 4-disha thi e nana tukda ma tuti jati hati.
/// ================================================================

List<int> _label8(
    Uint8List fg,
    int w,
    int h,
    Int32List comp,
    Int32List queue,
    ) {
  comp.fillRange(0, comp.length, 0);

  final int n = w * h;
  final List<int> sizes = [0];

  for (int s = 0; s < n; s++) {
    if (fg[s] == 0 || comp[s] != 0) continue;

    final int id = sizes.length;
    int head = 0;
    int tail = 0;

    comp[s] = id;
    queue[tail++] = s;

    while (head < tail) {
      final int p = queue[head++];
      final int x = p % w;
      final int y = p ~/ w;

      for (int dy = -1; dy <= 1; dy++) {
        final int yy = y + dy;
        if (yy < 0 || yy >= h) continue;

        final int rowQ = yy * w;

        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;

          final int xx = x + dx;
          if (xx < 0 || xx >= w) continue;

          final int q = rowQ + xx;

          if (fg[q] != 0 && comp[q] == 0) {
            comp[q] = id;
            queue[tail++] = q;
          }
        }
      }
    }

    sizes.add(tail);
  }

  return sizes;
}

/// ================================================================
/// 🔥 BACKGROUND REMOVE WORKER (MULTI-COLOR BACKGROUND)
/// ================================================================

class _BgCluster {
  double y = 0, u = 0, v = 0, r = 0, g = 0, b = 0;
  double cw = 1.0; // chroma weight (kaala/ghera background mate vadhu)
  double yStd = 4.0; // background ni texture (brightness ketli badlay)
  int count = 0;
}

Uint8List _removeBgWorker(Map<String, dynamic> a) {
  final Uint8List input = a["bytes"] as Uint8List;
  final double tol = (a["tol"] as num).toDouble();
  final int maxSide = a["maxSide"] as int;
  final bool autoCrop = a["crop"] as bool;
  final bool cleanShadow = a["cleanShadow"] as bool? ?? true;

  img.Image? decoded = img.decodeImage(input);
  if (decoded == null) throw Exception("Unable to decode image");

  // Camera photo ni EXIF rotation sachvi
  decoded = img.bakeOrientation(decoded);

  // Moti image → nani (speed + memory)
  if (math.max(decoded.width, decoded.height) > maxSide) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(decoded,
        width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(decoded,
        height: maxSide, interpolation: img.Interpolation.average);
  }

  final img.Image src = _toRgba8(decoded);

  final int w = src.width;
  final int h = src.height;
  final int n = w * h;

  final Uint8List px =
  Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));

  // ==============================================================
  // 1) Brightness (Y) + rang (U, V)
  // ==============================================================
  final Float32List yA = Float32List(n);
  final Float32List uA = Float32List(n);
  final Float32List vA = Float32List(n);

  for (int i = 0; i < n; i++) {
    final int o = i * 4;
    final double r = px[o].toDouble();
    final double g = px[o + 1].toDouble();
    final double b = px[o + 2].toDouble();
    final double y = 0.299 * r + 0.587 * g + 0.114 * b;
    yA[i] = y;
    uA[i] = b - y;
    vA[i] = r - y;
  }

  // ==============================================================
  // 2) KINAR NA PIXELS → 1 thi 3 BACKGROUND RANG (k-means)
  // ==============================================================
  final List<int> border = [];
  for (int x = 0; x < w; x++) {
    border.add(x);
    border.add((h - 1) * w + x);
  }
  for (int y = 1; y < h - 1; y++) {
    border.add(y * w);
    border.add(y * w + w - 1);
  }

  final int bn = border.length;

  // Shuruat: ghero, vachalo, aachho (brightness pramane)
  final List<int> byY = List<int>.from(border)
    ..sort((p, q) => yA[p].compareTo(yA[q]));

  final List<_BgCluster> cs = [];
  for (final double f in [0.03, 0.5, 0.97]) {
    final int idx = byY[math.min(bn - 1, math.max(0, (bn * f).floor()))];
    cs.add(_BgCluster()
      ..y = yA[idx]
      ..u = uA[idx]
      ..v = vA[idx]);
  }

  final Int8List assign = Int8List(bn);

  for (int iter = 0; iter < 10; iter++) {
    for (int k = 0; k < bn; k++) {
      final int i = border[k];
      double best = double.infinity;
      int bi = 0;
      for (int c = 0; c < cs.length; c++) {
        final double dy = yA[i] - cs[c].y;
        final double du = uA[i] - cs[c].u;
        final double dv = vA[i] - cs[c].v;
        final double d = dy * dy + du * du + dv * dv;
        if (d < best) {
          best = d;
          bi = c;
        }
      }
      assign[k] = bi;
    }

    for (final c in cs) {
      c.y = c.u = c.v = c.r = c.g = c.b = 0;
      c.count = 0;
    }

    for (int k = 0; k < bn; k++) {
      final int i = border[k];
      final _BgCluster c = cs[assign[k]];
      c.y += yA[i];
      c.u += uA[i];
      c.v += vA[i];
      c.r += px[i * 4];
      c.g += px[i * 4 + 1];
      c.b += px[i * 4 + 2];
      c.count++;
    }

    for (final c in cs) {
      if (c.count == 0) continue;
      c.y /= c.count;
      c.u /= c.count;
      c.v /= c.count;
      c.r /= c.count;
      c.g /= c.count;
      c.b /= c.count;
    }
  }

  // Darek background ni texture (brightness no std)
      {
    final List<double> sq = List<double>.filled(cs.length, 0);
    for (int k = 0; k < bn; k++) {
      final double d = yA[border[k]] - cs[assign[k]].y;
      sq[assign[k]] += d * d;
    }
    for (int c = 0; c < cs.length; c++) {
      if (cs[c].count > 0) cs[c].yStd = math.sqrt(sq[c] / cs[c].count);
    }
  }

  // Nana cluster (kinar par aavi gayeli jewellery / noise) kadho
  final List<_BgCluster> bgs = cs
      .where((c) => c.count >= bn * 0.04)
      .toList()
    ..sort((p, q) => q.count.compareTo(p.count));

  // Lagbhag sarkha rang → ek j gano
  final List<_BgCluster> clusters = [];
  for (final c in bgs) {
    final bool dup = clusters.any((k) {
      final double dy = k.y - c.y, du = k.u - c.u, dv = k.v - c.v;
      return math.sqrt(dy * dy + du * du + dv * dv) < tol * 0.5;
    });
    if (!dup) clusters.add(c);
  }

  if (clusters.isEmpty) {
    clusters.add(cs.reduce((p, q) => p.count >= q.count ? p : q));
  }

  // Ghera background (kaalo board) par rang no farak vadhu mahatva no
  for (final c in clusters) {
    c.cw = c.y < 80 ? 2.2 : 1.0;
  }

  // ==============================================================
  // 3) DAREK PIXEL NU NAJIK NA BACKGROUND THI ANTAR (ek j vaar)
  // ==============================================================
  final Float32List dBg = Float32List(n);
  final Uint8List nearC = Uint8List(n);

  for (int i = 0; i < n; i++) {
    double best = double.infinity;
    int bi = 0;
    for (int c = 0; c < clusters.length; c++) {
      final _BgCluster k = clusters[c];
      final double dy = yA[i] - k.y;
      final double wy = dy > 0 ? 1.0 : 0.35; // shadow ochhu, chamak puri
      final double du = uA[i] - k.u;
      final double dv = vA[i] - k.v;
      final double d = wy * dy * dy + k.cw * (du * du + dv * dv);
      if (d < best) {
        best = d;
        bi = c;
      }
    }
    dBg[i] = best;
    nearC[i] = bi;
  }

  double d2pair(int p, int q) {
    final double dy = yA[p] - yA[q];
    final double du = uA[p] - uA[q];
    final double dv = vA[p] - vA[q];
    return 0.5 * dy * dy + du * du + dv * dv;
  }

  final double t2 = tol * tol;
  final double loose2 = (tol * 1.6) * (tol * 1.6);
  final double step2 = (tol * 0.45) * (tol * 0.45);
  final double strict2 = (tol * 0.75) * (tol * 0.75);

  // ==============================================================
  // 4) FLOOD FILL — kinar thi background felavo (4-disha:
  //    background chain na diagonal gaap mathi andar na ghuse)
  // ==============================================================
  final Uint8List isBg = Uint8List(n);
  final Int32List queue = Int32List(n);
  int head = 0;
  int tail = 0;

  for (final int i in border) {
    if (isBg[i] == 0 && dBg[i] < loose2) {
      isBg[i] = 1;
      queue[tail++] = i;
    }
  }

  void grow(int p, int q) {
    if (isBg[q] != 0) return;
    final double dq = dBg[q];
    // Halka gradient fakt GHERA background (board) par j —
    // aachha background par patli sonani wire na kapay
    if (dq < t2 ||
        (clusters[nearC[q]].y < 80 && dq < loose2 && d2pair(p, q) < step2)) {
      isBg[q] = 1;
      queue[tail++] = q;
    }
  }

  while (head < tail) {
    final int p = queue[head++];
    final int x = p % w;
    if (x > 0) grow(p, p - 1);
    if (x < w - 1) grow(p, p + 1);
    if (p >= w) grow(p, p - w);
    if (p < n - w) grow(p, p + w);
  }

  // ==============================================================
  // 5) ANDAR NA BAND BHAAG (necklace no U, board, jaali)
  //    - Mota bhaag: hamesha background
  //    - Nana bhaag: fakt jo background jevu SAADU hoy to j
  // ==============================================================
  final int minHole = math.max(400, (n * 0.002).round());
  final Uint8List seen = Uint8List(n);
  final Int32List clusterHits = Int32List(clusters.length);

  for (int s = 0; s < n; s++) {
    if (isBg[s] != 0 || seen[s] != 0 || dBg[s] >= strict2) continue;

    head = 0;
    tail = 0;
    seen[s] = 1;
    queue[tail++] = s;

    double sumD = 0, sumY = 0, sumY2 = 0;
    clusterHits.fillRange(0, clusterHits.length, 0);

    while (head < tail) {
      final int p = queue[head++];
      final int x = p % w;

      sumD += math.sqrt(dBg[p]);
      sumY += yA[p];
      sumY2 += yA[p] * yA[p];
      clusterHits[nearC[p]]++;

      if (x > 0 &&
          isBg[p - 1] == 0 &&
          seen[p - 1] == 0 &&
          dBg[p - 1] < strict2) {
        seen[p - 1] = 1;
        queue[tail++] = p - 1;
      }
      if (x < w - 1 &&
          isBg[p + 1] == 0 &&
          seen[p + 1] == 0 &&
          dBg[p + 1] < strict2) {
        seen[p + 1] = 1;
        queue[tail++] = p + 1;
      }
      if (p >= w &&
          isBg[p - w] == 0 &&
          seen[p - w] == 0 &&
          dBg[p - w] < strict2) {
        seen[p - w] = 1;
        queue[tail++] = p - w;
      }
      if (p < n - w &&
          isBg[p + w] == 0 &&
          seen[p + w] == 0 &&
          dBg[p + w] < strict2) {
        seen[p + w] = 1;
        queue[tail++] = p + w;
      }
    }

    bool remove = tail >= minHole;

    if (!remove && tail >= 60) {
      int ci = 0;
      for (int c = 1; c < clusters.length; c++) {
        if (clusterHits[c] > clusterHits[ci]) ci = c;
      }
      final double meanD = sumD / tail;
      final double meanY = sumY / tail;
      final double stdY =
      math.sqrt(math.max(0.0, sumY2 / tail - meanY * meanY));

      remove = meanD < tol * 0.4 && stdY < clusters[ci].yStd * 1.8 + 4;
    }

    if (remove) {
      for (int k = 0; k < tail; k++) {
        isBg[queue[k]] = 1;
      }
    }
  }

  // ==============================================================
  // 5b) PENDANT NICHE NI SHADOW (aachha background par)
  // ==============================================================
  bool shadowCand(int i) {
    if (isBg[i] != 0) return false;
    final _BgCluster c = clusters[nearC[i]];
    if (c.y < 80) return false; // fakt aachha background
    final double y = yA[i];
    if (y >= c.y - 12 || y <= c.y * 0.6) return false;
    final double du = uA[i] - c.u;
    final double dv = vA[i] - c.v;
    return du * du + dv * dv < 26 * 26;
  }

  seen.fillRange(0, n, 0);

  for (int s = 0; s < n; s++) {
    if (seen[s] != 0 || !shadowCand(s)) continue;

    head = 0;
    tail = 0;
    seen[s] = 1;
    queue[tail++] = s;

    double sumY = 0, sumY2 = 0;

    while (head < tail) {
      final int p = queue[head++];
      final int x = p % w;

      sumY += yA[p];
      sumY2 += yA[p] * yA[p];

      if (x > 0 && seen[p - 1] == 0 && shadowCand(p - 1)) {
        seen[p - 1] = 1;
        queue[tail++] = p - 1;
      }
      if (x < w - 1 && seen[p + 1] == 0 && shadowCand(p + 1)) {
        seen[p + 1] = 1;
        queue[tail++] = p + 1;
      }
      if (p >= w && seen[p - w] == 0 && shadowCand(p - w)) {
        seen[p - w] = 1;
        queue[tail++] = p - w;
      }
      if (p < n - w && seen[p + w] == 0 && shadowCand(p + w)) {
        seen[p + w] = 1;
        queue[tail++] = p + w;
      }
    }

    if (tail < 250) continue;

    final double meanY = sumY / tail;
    final double stdY =
    math.sqrt(math.max(0.0, sumY2 / tail - meanY * meanY));

    if (stdY < 12) {
      for (int k = 0; k < tail; k++) {
        isBg[queue[k]] = 1;
      }
    }
  }

  // ==============================================================
  // 5c) STAND / BOARD NI KINAR NI PATLI LINE
  // ==============================================================
  if (clusters.length >= 2) {
    Uint8List dilate4(Uint8List m, int iters) {
      Uint8List cur = m;
      for (int it = 0; it < iters; it++) {
        final Uint8List next = Uint8List.fromList(cur);
        for (int i = 0; i < n; i++) {
          if (cur[i] == 0) continue;
          final int x = i % w;
          if (x > 0) next[i - 1] = 1;
          if (x < w - 1) next[i + 1] = 1;
          if (i >= w) next[i - w] = 1;
          if (i < n - w) next[i + w] = 1;
        }
        cur = next;
      }
      return cur;
    }

    final List<Uint8List> nearBg = [];
    for (int c = 0; c < clusters.length; c++) {
      final Uint8List m = Uint8List(n);
      for (int i = 0; i < n; i++) {
        if (isBg[i] != 0 && nearC[i] == c) m[i] = 1;
      }
      nearBg.add(dilate4(m, 3));
    }

    final List<int> toClear = [];

    for (int i = 0; i < n; i++) {
      if (isBg[i] != 0) continue;

      for (int ca = 0; ca < clusters.length; ca++) {
        for (int cb = ca + 1; cb < clusters.length; cb++) {
          if (nearBg[ca][i] == 0 || nearBg[cb][i] == 0) continue;

          final _BgCluster A = clusters[ca];
          final _BgCluster B = clusters[cb];
          final double abY = B.y - A.y, abU = B.u - A.u, abV = B.v - A.v;
          final double l2 = abY * abY + abU * abU + abV * abV;
          if (l2 < (tol * 2) * (tol * 2)) continue;

          final double pY = yA[i] - A.y, pU = uA[i] - A.u, pV = vA[i] - A.v;
          final double t = (pY * abY + pU * abU + pV * abV) / l2;
          if (t <= 0.05 || t >= 0.95) continue;

          final double dY = pY - t * abY, dU = pU - t * abU, dV = pV - t * abV;
          if (dY * dY + dU * dU + dV * dV < (tol * 0.6) * (tol * 0.6)) {
            toClear.add(i);
          }
        }
      }
    }

    for (final int i in toClear) {
      isBg[i] = 1;
    }
  }

  // ==============================================================
  // 5c-2) 💎 MOTI / KUNDAN SURAKSHIT VISTAR
  //
  //   Safed background par moti ane kundan pan background jeva j
  //   safed / grey dekhay → khaana saaf karta e pan kapai jata.
  //   Moti ni olakh: rang vagar no ane
  //     - background jetlo ujaas (88%+), athva
  //     - aaspas karta CHAMAKTO bindu (gol moti par prakash) —
  //       chhaya kyare pan chamakti nathi, e saadi hoy.
  //   Aa pixel ane eni aaspas thodi jagya: kyare pan bhusvi nahi.
  // ==============================================================
  final int pearlR = math.max(2, (math.max(w, h) * 0.0025).round());
  Uint8List pearlNear = Uint8List(n);

  // Background no sauthi ujaas shade (ghana shade hoy tyare)
  double maxBgY = 0;
  for (final c in clusters) {
    if (c.y > maxBgY) maxBgY = c.y;
  }
  {
    final Uint8List y8 = Uint8List(n);
    for (int i = 0; i < n; i++) {
      y8[i] = _c255(yA[i]);
    }
    final Uint8List yMean = _boxBlur(y8, w, h, pearlR);

    final Uint8List pearl = Uint8List(n);
    for (int i = 0; i < n; i++) {
      if (isBg[i] != 0) continue;
      final _BgCluster c = clusters[nearC[i]];
      if (c.y < 150) continue;
      final double ratio = yA[i] / c.y;
      final double r1 = math.min(ratio, 1.0);
      final double du = uA[i] - c.u * r1;
      final double dv = vA[i] - c.v * r1;
      final double bgDev2 = du * du + dv * dv;
      final double abs2 = uA[i] * uA[i] + vA[i] * vA[i];
      // Rang vagar no j (safed moti) — background jevo ke saav safed
      if (math.min(bgDev2, abs2) >= 24 * 24) continue;

      final bool isPearl;
      if (c.y >= 235) {
        // SAFED background: moti background jetla j safed → ujaas
        // athva chamakta bindu thi olkho
        isPearl =
            ratio >= 0.84 || (ratio >= 0.66 && yA[i] - yMean[i] > 8);
      } else {
        // 🔥 Grey / blue background: moti HAMESHA
        //   - saav rang vagar no safed (background jevo blue-grey nahi)
        //   - background na SAUTHI UJAAS shade karta pan vadhu safed
        // (Pehla najik na ghera shade sathe sarkhavata → choker na
        // ujaas khaana pan "moti" ganata ane bachi jata.)
        isPearl = abs2 < 12 * 12 && yA[i] >= maxBgY * 1.04;
      }
      if (isPearl) pearl[i] = 1;
    }
    pearlNear = _dilate(pearl, w, h, pearlR);
  }

  // ==============================================================
  // 5d) 🔥 JEWELLERY NA VACHCHE NA KHAANA (chhaya + kapad ni texture)
  //
  //   Necklace ni jaali / ghungharu vachche nana khaana ma kapad
  //   dekhay che. Tya CHHAYA pade (background karta ghero) ane kapad
  //   ni texture hoy → upar na niyam ma "background" na ganay ane
  //   grey dhaba rahi jay.
  //
  //   Have aa khaana pan saaf thay jo:
  //   - rang vagar nu (neutral) hoy → sonu / meenakari surakshit
  //   - background jetlu ke ethi ghero (chhaya) hoy, khub kaalo nahi
  //     → kaala mani / oxidised surakshit
  //   - saadu hoy (vadhu texture nahi) → nakshi vaalu silver surakshit
  //   - CHAMAK vaala safed bhaag ne adtu na hoy → moti / kundan
  //     surakshit (ema hamesha chamak hoy che)
  // ==============================================================
      {
    bool holeCand(int i) {
      if (isBg[i] != 0) return false;
      if (pearlNear[i] != 0) return false; // moti / kundan
      final _BgCluster c = clusters[nearC[i]];
      if (c.y < 80) return false; // fakt aachha background
      final double y = yA[i];
      if (y > c.y + 14 || y < c.y * 0.45) return false;
      // 🔥 Rang vagar no grey (sona nu prakash padelo garam grey pan)
      // → background ni chhaya. Sonu khub rangin hoy etle surakshit.
      if (uA[i] * uA[i] + vA[i] * vA[i] < 16 * 16) return true;
      // Chhaya ma rang pan ghero thay → background no ghero version
      final double ratio = (y / c.y).clamp(0.45, 1.0);
      final double du = uA[i] - c.u * ratio;
      final double dv = vA[i] - c.v * ratio;
      final double lim = tol * 0.75;
      return du * du + dv * dv < lim * lim;
    }

    final int maxHole = (n * 0.02).round();
    seen.fillRange(0, n, 0);

    for (int s = 0; s < n; s++) {
      if (seen[s] != 0 || !holeCand(s)) continue;

      head = 0;
      tail = 0;
      seen[s] = 1;
      queue[tail++] = s;

      double sumY = 0, sumY2 = 0, sumChroma = 0;

      // 🔥 Kinar na pixel ganvo: ketla moti/kundan (safed chamak) che?
      // Pehla EK pan moti adtu to aakhu khaanu chhodi detu → ghungroo
      // vachche na ghana khaana grey rahi jata. Have fakt jo kinar no
      // MOTO bhag chamak hoy (kundan ni aaspas moti ni ring) to j bache.
      int edgeCount = 0;
      int shineCount = 0;

      void visit(int q) {
        if (seen[q] != 0) return;
        if (holeCand(q)) {
          seen[q] = 1;
          queue[tail++] = q;
        } else if (isBg[q] == 0) {
          edgeCount++;
          if (pearlNear[q] != 0) shineCount++;
        }
      }

      while (head < tail) {
        final int p = queue[head++];
        final int x = p % w;

        final double y = yA[p];
        sumY += y;
        sumY2 += y * y;

        final _BgCluster c = clusters[nearC[p]];
        final double ratio = (y / c.y).clamp(0.45, 1.0);
        final double du = uA[p] - c.u * ratio;
        final double dv = vA[p] - c.v * ratio;
        // Background jevo rang ke saav rang vagar no — je ochhu hoy
        sumChroma += math.min(
          math.sqrt(du * du + dv * dv),
          math.sqrt(uA[p] * uA[p] + vA[p] * vA[p]),
        );

        if (x > 0) visit(p - 1);
        if (x < w - 1) visit(p + 1);
        if (p >= w) visit(p - w);
        if (p < n - w) visit(p + w);
      }

      if (tail < 6 || tail > maxHole) continue;

      // Kundan / moti ni ring vachche → jewellery no bhag, rehva do
      if (edgeCount > 0 && shineCount > edgeCount * 0.35) continue;

      final _BgCluster c = clusters[nearC[s]];
      final double meanY = sumY / tail;
      final double stdY =
      math.sqrt(math.max(0.0, sumY2 / tail - meanY * meanY));
      final double meanChroma = sumChroma / tail;

      // Safed background par ujaas (88%+) nanu khaanu = moti / kundan
      if (c.y >= 235 && meanY > c.y * 0.88) continue;

      final bool smooth = stdY < math.max(18.0, c.yStd * 3);
      final bool neutral = meanChroma < tol * 0.55;

      if (smooth && neutral) {
        for (int k = 0; k < tail; k++) {
          isBg[queue[k]] = 1;
        }
      }
    }
  }

  // ==============================================================
  // 5e) 🔥 JEWELLERY NI CHHAYA (CAST SHADOW) — GREY DHABA KADHO
  //
  //   Safed / aachha background par jewellery ni aaspas ane
  //   ghungroo vachche grey chhaya pade. E background no j
  //   "ghero" rang che: rang (U,V) background jevo j, fakt
  //   brightness ochhi. Pehla na niyam ma e rahi jati kem ke:
  //     - jewellery ni najik chhaya ma halko garam (sonera) rang
  //     - chhaya ma dhime dhime brightness badlay (gradient)
  //
  //   Have:
  //   A) Background thi chhaya ma DHIME DHIME felavo — fakt jya
  //      pixel-pixel brightness halke thi badlay (chhaya soft hoy).
  //      Moti/kundan/chandi ni kinar tikhi hoy → tya atki jay.
  //   B) Jewellery thi gherayela band khaana ni chhaya pan saaf —
  //      jo ema safed chamakto bhaag (moti / kundan) na adto hoy.
  //
  //   Sonu (pilo rang) kyare pan chhaya nathi ganatu.
  // ==============================================================
  if (cleanShadow && clusters.any((c) => c.y >= 150)) {
    // Background no "ghero" version che?
    double shadowDev(int i) {
      final _BgCluster c = clusters[nearC[i]];
      if (c.y < 150) return 1e9; // fakt aachha background
      final double ratio = yA[i] / c.y;
      if (ratio < 0.30 || ratio > 0.985) return 1e9;
      // 🔥 Rang vagar no grey (garam grey pan) → chhaya
      if (uA[i] * uA[i] + vA[i] * vA[i] < 16 * 16) return 0;
      final double du = uA[i] - c.u * ratio;
      final double dv = vA[i] - c.v * ratio;
      // Ghera chhaya ma thodo sonero prakash (reflection) chale
      final double lim = 12 + 18 * (1 - ratio);
      final double d = math.sqrt(du * du + dv * dv);
      return d < lim ? d : 1e9;
    }

    bool shadowLike(int i) =>
        isBg[i] == 0 && pearlNear[i] == 0 && shadowDev(i) < 1e8;

    // Soft chhaya: pixel-pixel brightness no farak nano
    const double maxStep = 7.0;

    // ---------- A) Background thi felavo ----------
    head = 0;
    tail = 0;

    void tryAdd(int p, int q) {
      if (isBg[q] != 0) return;
      if ((yA[p] - yA[q]).abs() >= maxStep) return;
      if (!shadowLike(q)) return;
      isBg[q] = 1;
      queue[tail++] = q;
    }

    for (int p = 0; p < n; p++) {
      if (isBg[p] == 0) continue;
      final int x = p % w;
      if (x > 0) tryAdd(p, p - 1);
      if (x < w - 1) tryAdd(p, p + 1);
      if (p >= w) tryAdd(p, p - w);
      if (p < n - w) tryAdd(p, p + w);
    }

    while (head < tail) {
      final int p = queue[head++];
      final int x = p % w;
      if (x > 0) tryAdd(p, p - 1);
      if (x < w - 1) tryAdd(p, p + 1);
      if (p >= w) tryAdd(p, p - w);
      if (p < n - w) tryAdd(p, p + w);
    }

    // ---------- B) Band khaana ni chhaya ----------
    final int maxPocket = (n * 0.02).round();
    seen.fillRange(0, n, 0);

    for (int s = 0; s < n; s++) {
      if (seen[s] != 0 || !shadowLike(s)) continue;

      head = 0;
      tail = 0;
      seen[s] = 1;
      queue[tail++] = s;

      double sumY = 0, sumY2 = 0;
      int edgeCount = 0;
      int whiteCount = 0;

      void visit(int p, int q) {
        if (seen[q] != 0 || isBg[q] != 0) return;
        if (shadowLike(q) && (yA[p] - yA[q]).abs() < maxStep) {
          seen[q] = 1;
          queue[tail++] = q;
        } else {
          edgeCount++;
          if (pearlNear[q] != 0) {
            whiteCount++;
            return;
          }
          // Moti / kundan: rang vagar no, chhaya karta spasht safed
          final _BgCluster c = clusters[nearC[q]];
          final double du = uA[q] - c.u;
          final double dv = vA[q] - c.v;
          if (yA[q] > yA[p] + 28 && du * du + dv * dv < 28 * 28) {
            whiteCount++;
          }
        }
      }

      while (head < tail) {
        final int p = queue[head++];
        final int x = p % w;
        sumY += yA[p];
        sumY2 += yA[p] * yA[p];
        if (x > 0) visit(p, p - 1);
        if (x < w - 1) visit(p, p + 1);
        if (p >= w) visit(p, p - w);
        if (p < n - w) visit(p, p + w);
      }

      if (tail < 6 || tail > maxPocket) continue;

      // Kinar no moto bhag safed (kundan ni moti ring) → rehva do
      if (edgeCount > 0 && whiteCount > edgeCount * 0.35) continue;

      final double meanY = sumY / tail;
      final double stdY =
      math.sqrt(math.max(0.0, sumY2 / tail - meanY * meanY));

      // Safed background par ujaas (88%+) nanu khaanu = moti / kundan
      final _BgCluster cs0 = clusters[nearC[s]];
      if (cs0.y >= 235 && meanY > cs0.y * 0.88) continue;

      // Chhaya saadi hoy (vadhu texture nahi)
      if (stdY < 20) {
        for (int k = 0; k < tail; k++) {
          isBg[queue[k]] = 1;
        }
      }
    }
  }

  // ==============================================================
  // 6) 🔥 TUKDA OLKHO (8-DISHA) + SURAKSHIT VISTAR
  //
  //   Pehla: 4-disha thi tukda gana ta → patli chain diagonal
  //   pixel thi tuti ne nana tukda banti, ane e "noise" /
  //   "label" / "pratibimb" gani ne kadhai jati (mangalsutra na
  //   kaala mani khaas kari ne — rang vagar na hoy che).
  //
  //   Have:
  //   - Tukda 8-disha thi (diagonal pan) jodaay
  //   - Mota tukda (mukhya jewellery, earrings) ni aaspas
  //     thodo vistar "surakshit" → ema na badha tukda RAHE
  //   - Fakt DOOR na nana dhaba / label / pratibimb j kadhay
  // ==============================================================
      {
    final Uint8List fg = Uint8List(n);
    for (int i = 0; i < n; i++) {
      if (isBg[i] == 0) fg[i] = 1;
    }

    final Int32List comp = Int32List(n);
    final List<int> compSize = _label8(fg, w, h, comp, queue);
    final int cc = compSize.length;

    if (cc > 1) {
      final Float64List sumY = Float64List(cc);
      final Float64List sumY2 = Float64List(cc);
      final Float64List sumChroma = Float64List(cc);
      final Float64List sumPy = Float64List(cc);
      final Int32List firstPx = Int32List(cc)..fillRange(0, cc, -1);
      final Int32List minPy = Int32List(cc)..fillRange(0, cc, h);
      final Int32List maxPy = Int32List(cc)..fillRange(0, cc, -1);

      for (int i = 0; i < n; i++) {
        final int id = comp[i];
        if (id == 0) continue;

        if (firstPx[id] < 0) firstPx[id] = i;

        final double y = yA[i];
        sumY[id] += y;
        sumY2[id] += y * y;

        final _BgCluster bc = clusters[nearC[i]];
        final double du = uA[i] - bc.u;
        final double dv = vA[i] - bc.v;
        sumChroma[id] += math.sqrt(du * du + dv * dv);

        final int py = i ~/ w;
        sumPy[id] += py;
        if (py < minPy[id]) minPy[id] = py;
        if (py > maxPy[id]) maxPy[id] = py;
      }

      int mainId = 1;
      for (int id = 2; id < cc; id++) {
        if (compSize[id] > compSize[mainId]) mainId = id;
      }

      final int mainSize = compSize[mainId];
      final double mainY = sumY[mainId] / mainSize;
      final double mainCy = sumPy[mainId] / mainSize;
      final int mainH = maxPy[mainId] - minPy[mainId] + 1;

      // ---- SURAKSHIT VISTAR ----
      // Mota tukda (mukhya na 25%+) ni aaspas ~1.2% image jetlo vistar
      final int nearR = math.max(3, (math.max(w, h) * 0.012).round());
      final Uint8List zone = _dilate(fg, w, h, nearR);
      final Int32List zoneComp = Int32List(n);
      _label8(zone, w, h, zoneComp, queue);

      final Set<int> safeZones = {};
      for (int id = 1; id < cc; id++) {
        if (compSize[id] >= mainSize * 0.25 && firstPx[id] >= 0) {
          safeZones.add(zoneComp[firstPx[id]]);
        }
      }

      final int minIsland = math.max(25, (n * 0.00015).round());
      final int maxNeutral = (n * 0.003).round();

      final Uint8List drop = Uint8List(cc);

      for (int id = 1; id < cc; id++) {
        if (id == mainId) continue;

        final int size = compSize[id];
        final double meanY = sumY[id] / size;
        final double meanChroma = sumChroma[id] / size;
        final double stdY =
        math.sqrt(math.max(0.0, sumY2[id] / size - meanY * meanY));
        final double cy = sumPy[id] / size;

        final bool isSafe =
            firstPx[id] >= 0 && safeZones.contains(zoneComp[firstPx[id]]);

        final bool darkBg =
            firstPx[id] >= 0 && clusters[nearC[firstPx[id]]].y < 80;

        // 🪞 Chamakti KAALI floor par pratibimb: ghano jankho, mukhya
        // jewellery ni NICHE. Safed background par pratibimb hotu j
        // nathi → tya kaala mani (mangalsutra) KYARE PAN nahi kapay.
        final bool reflection = darkBg &&
            meanY < mainY * 0.55 &&
            size < mainSize * 0.5 &&
            cy > mainCy &&
            (!isSafe || cy > maxPy[mainId] - mainH * 0.1);

        if (reflection) {
          drop[id] = 1;
          continue;
        }

        // Surakshit vistar ma → jewellery no j bhaag
        if (isSafe) continue;

        // Door no nano dhabo / noise
        if (size < minIsland) {
          drop[id] = 1;
          continue;
        }

        // Door no label QR / akshar: nano, rang vagar no, ane
        // jankho athva khub contrast (kaalo + safed)
        if (size < maxNeutral &&
            meanChroma < 20 &&
            (meanY < mainY * 0.8 || stdY > 45)) {
          drop[id] = 1;
        }
      }

      for (int i = 0; i < n; i++) {
        final int id = comp[i];
        if (id != 0 && drop[id] == 1) isBg[i] = 1;
      }
    }
  }

  // ==============================================================
  // 7) SOFT KINAR + RANG NI CHHAYA (fringe) KADHO
  // ==============================================================
  final Uint8List out = Uint8List(n * 4);
  final double softFrom = tol * 0.5;
  final double softRange = tol * 0.9;

  int minX = w, minY = h, maxX = -1, maxY = -1;

  // 🔥 Kinar no rang AASPAAS na saaf thayela background thi sarkhavo
  // (pehla hamesha mukhya background — safed — thi sarkhavata. Etle
  // grey khaana saaf thaya pachhi eni kinar par grey-brown line
  // rahi jati.) Najik na 2–4 px ma je background che eno rang lo.
  final int er = math.max(2, (math.max(w, h) * 0.0022).round());
  final Uint8List nearBgZone = _dilate(isBg, w, h, er);

  for (int i = 0; i < n; i++) {
    if (isBg[i] != 0) continue; // transparent

    final int o = i * 4;
    double r = px[o].toDouble();
    double g = px[o + 1].toDouble();
    double b = px[o + 2].toDouble();
    int alpha = 255;

    final int x = i % w;

    if (nearBgZone[i] != 0) {
      // Aaspaas na background no sarerash rang
      final int y0 = i ~/ w;
      double br = 0, bgc = 0, bb = 0;
      int cnt = 0;

      for (int dy = -er; dy <= er; dy++) {
        final int yy = y0 + dy;
        if (yy < 0 || yy >= h) continue;
        final int row = yy * w;
        for (int dx = -er; dx <= er; dx++) {
          final int xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          final int j = row + xx;
          if (isBg[j] == 0) continue;
          br += px[j * 4];
          bgc += px[j * 4 + 1];
          bb += px[j * 4 + 2];
          cnt++;
        }
      }

      if (cnt > 0) {
        br /= cnt;
        bgc /= cnt;
        bb /= cnt;

        final double by = 0.299 * br + 0.587 * bgc + 0.114 * bb;
        final double dyy = yA[i] - by;

        // Moti / kundan (background karta ujaas) → kyare pan pardarshak nahi
        final bool protect = pearlNear[i] != 0 && dyy >= 0;

        if (!protect) {
          final double du = uA[i] - (bb - by);
          final double dv = vA[i] - (br - by);
          final double wy = dyy > 0 ? 1.0 : 0.35;
          final double d = math.sqrt(wy * dyy * dyy + du * du + dv * dv);
          final double af = ((d - softFrom) / softRange).clamp(0.0, 1.0);

          if (af <= 0.02) continue;

          if (af < 1.0) {
            alpha = _c255(af * 255);
            // C = a*F + (1-a)*B  →  F = (C - (1-a)*B) / a
            r = (r - (1 - af) * br) / af;
            g = (g - (1 - af) * bgc) / af;
            b = (b - (1 - af) * bb) / af;
          }
        }
      }
    }

    out[o] = _c255(r);
    out[o + 1] = _c255(g);
    out[o + 2] = _c255(b);
    out[o + 3] = alpha;

    final int y = i ~/ w;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  if (maxX < 0) {
    throw Exception("No jewellery found. Try a lower strength.");
  }

  img.Image result = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: out.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  // ==============================================================
  // 8) AUTO CROP — jewellery vachche, 6% jagya saathe
  // ==============================================================
  if (autoCrop) {
    final int bw = maxX - minX + 1;
    final int bh = maxY - minY + 1;
    final int pad = (math.max(bw, bh) * 0.06).round();

    final int cx = math.max(0, minX - pad);
    final int cy = math.max(0, minY - pad);
    final int cw = math.min(w, maxX + pad + 1) - cx;
    final int ch = math.min(h, maxY + pad + 1) - cy;

    result = img.copyCrop(result, x: cx, y: cy, width: cw, height: ch);
  }

  return Uint8List.fromList(img.encodePng(result, level: 6));
}

/// ================================================================
/// 💍 PIECES WORKER — alag tukda olkhi ne crop (8-disha)
/// ================================================================

List<Uint8List> _extractPiecesWorker(Uint8List png) {
  final img.Image? decoded = img.decodePng(png);
  if (decoded == null) return [png];

  final img.Image src = _toRgba8(decoded);
  final int w = src.width;
  final int h = src.height;
  final int n = w * h;

  final Uint8List px =
  Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));

  final Uint8List fg = Uint8List(n);
  for (int i = 0; i < n; i++) {
    if (px[i * 4 + 3] > 32) fg[i] = 1;
  }

  final Int32List comp = Int32List(n);
  final Int32List queue = Int32List(n);
  final List<int> size = _label8(fg, w, h, comp, queue);

  if (size.length <= 1) return [png];

  final int cc = size.length;
  final Int32List minX = Int32List(cc)..fillRange(0, cc, w);
  final Int32List minY = Int32List(cc)..fillRange(0, cc, h);
  final Int32List maxX = Int32List(cc)..fillRange(0, cc, -1);
  final Int32List maxY = Int32List(cc)..fillRange(0, cc, -1);

  for (int i = 0; i < n; i++) {
    final int id = comp[i];
    if (id == 0) continue;
    final int x = i % w;
    final int y = i ~/ w;
    if (x < minX[id]) minX[id] = x;
    if (x > maxX[id]) maxX[id] = x;
    if (y < minY[id]) minY[id] = y;
    if (y > maxY[id]) maxY[id] = y;
  }

  int largest = 1;
  for (int id = 2; id < cc; id++) {
    if (size[id] > size[largest]) largest = id;
  }

  // "Mota" tukda = sauthi mota na 5% thi vadhu (necklace, earrings)
  final List<int> big = [];
  for (int id = 1; id < cc; id++) {
    if (size[id] >= size[largest] * 0.05) big.add(id);
  }
  big.sort((a, b) => size[b].compareTo(size[a]));

  final Set<int> bigSet = big.toSet();
  final List<Uint8List> out = [];

  for (final int id in big.take(4)) {
    final int pad =
    (math.max(maxX[id] - minX[id], maxY[id] - minY[id]) * 0.02).round();

    final int cx0 = math.max(0, minX[id] - pad);
    final int cy0 = math.max(0, minY[id] - pad);
    final int cx1 = math.min(w - 1, maxX[id] + pad);
    final int cy1 = math.min(h - 1, maxY[id] + pad);

    final int cw = cx1 - cx0 + 1;
    final int ch = cy1 - cy0 + 1;
    final Uint8List bytes = Uint8List(cw * ch * 4);

    for (int y = 0; y < ch; y++) {
      for (int x = 0; x < cw; x++) {
        final int si = (cy0 + y) * w + (cx0 + x);
        final int c = comp[si];

        // Bija MOTA tukda (daa.ta. earring necklace ni andar) → kadho
        if (c != 0 && c != id && bigSet.contains(c)) continue;

        final int so = si * 4;
        final int o = (y * cw + x) * 4;
        bytes[o] = px[so];
        bytes[o + 1] = px[so + 1];
        bytes[o + 2] = px[so + 2];
        bytes[o + 3] = px[so + 3];
      }
    }

    final img.Image piece = img.Image.fromBytes(
      width: cw,
      height: ch,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    out.add(Uint8List.fromList(img.encodePng(piece, level: 6)));
  }

  return out.isEmpty ? [png] : out;
}

/// ================================================================
/// 🎨 COLOR BACKGROUND + SOFT SHADOW WORKER
/// ================================================================

Uint8List _composeWorker(Map<String, dynamic> a) {
  final img.Image? decoded = img.decodePng(a["png"] as Uint8List);
  if (decoded == null) throw Exception("Invalid PNG");

  final img.Image src = _toRgba8(decoded);

  final int w = src.width;
  final int h = src.height;
  final int n = w * h;

  final Uint8List px =
  Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));

  final int argb = a["color"] as int;
  final double cr = ((argb >> 16) & 0xff).toDouble();
  final double cg = ((argb >> 8) & 0xff).toDouble();
  final double cb = (argb & 0xff).toDouble();

  final bool shadow = a["shadow"] as bool;

  Uint8List? sh;
  int dy = 0;

  if (shadow) {
    final Uint8List alpha = Uint8List(n);
    for (int i = 0; i < n; i++) {
      alpha[i] = px[i * 4 + 3];
    }

    // 🔥 Halki ane najik ni (contact) shadow — pehla moti ane 32%
    // gheri hati, safed background par grey dhaba jevi lagti
    final int r = math.max(2, (math.min(w, h) * 0.006).round());
    sh = _boxBlur(_boxBlur(_boxBlur(alpha, w, h, r), w, h, r), w, h, r);
    dy = math.max(1, (h * 0.004).round());
  }

  final Uint8List out = Uint8List(n * 3);

  for (int i = 0; i < n; i++) {
    double r0 = cr, g0 = cg, b0 = cb;

    if (sh != null) {
      final int y = i ~/ w;
      final int sy = y - dy;
      if (sy >= 0) {
        final double s = sh[sy * w + (i - y * w)] / 255.0 * 0.14;
        r0 *= 1 - s;
        g0 *= 1 - s;
        b0 *= 1 - s;
      }
    }

    final int o = i * 4;
    final double al = px[o + 3] / 255.0;

    out[i * 3] = _c255(px[o] * al + r0 * (1 - al));
    out[i * 3 + 1] = _c255(px[o + 1] * al + g0 * (1 - al));
    out[i * 3 + 2] = _c255(px[o + 2] * al + b0 * (1 - al));
  }

  final img.Image result = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: out.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );

  return Uint8List.fromList(img.encodeJpg(result, quality: 95));
}
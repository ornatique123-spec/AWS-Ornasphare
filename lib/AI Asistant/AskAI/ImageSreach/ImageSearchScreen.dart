import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Api_Constant/ApiConstants.dart';
import '../stock_ai_models.dart';
import '../stock_ai_repository.dart';

/// =======================================================================
///  🔍 IMAGE SEARCH — upload / click a photo → EXACT + SIMILAR stock items
///
///  How it works (on the phone, no paid AI, no image is sent anywhere):
///   1) Every Stock Gallery photo gets a tiny "fingerprint" ONE time
///      (shape hash + colour mix + 8×8 pattern) → saved on the phone.
///      Next time only NEW photos are added → search is instant.
///   2) Your photo gets the same fingerprint (full + centre crop).
///   3) Score = shape 40% + colour 35% + pattern 25%.
///        ≥ 93% and almost same shape → EXACT
///        ≥ 55%                        → SIMILAR (best first)
///  Buttons: 📄 PDF (with photos) · WhatsApp (shares the PDF + summary)
///
///  Open:  ImageSearchScreen.open(context);
/// =======================================================================
class ImageSearchScreen extends StatefulWidget {
  const ImageSearchScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImageSearchScreen()));

  @override
  State<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends State<ImageSearchScreen> {
  // ✨ premium light blue
  static const Color _blue = Color(0xff2563EB);
  static const Color _blueDeep = Color(0xff1D4ED8);
  static const Color _ink = Color(0xff1B2433);
  static const Color _soft = Color(0xff6B7487);
  static const Color _line = Color(0xffDCE7F7);
  static const Color _bgSoft = Color(0xffF4F8FF);
  static const Color _green = Color(0xff16A34A);
  static const Color _wa = Color(0xff25D366);

  final ImagePicker _picker = ImagePicker();

  Uint8List? _query;
  bool _searching = false;
  bool _inStockOnly = true;
  List<_Hit> _exact = [];
  List<_Hit> _similar = [];
  bool _searched = false;
  bool _pdfBusy = false;

  // index state
  int _indexed = 0;
  int _total = 0;
  bool _indexing = false;
  String? _indexError;

  @override
  void initState() {
    super.initState();
    _buildIndex(); // ⚡ start right away (new photos only)
  }

  // ---------------------------------------------------------------------
  //  INDEX (once per photo, saved on the phone)
  // ---------------------------------------------------------------------
  Future<void> _buildIndex() async {
    if (_indexing) return;
    setState(() {
      _indexing = true;
      _indexError = null;
    });
    try {
      await _ImageIndex.instance.build(onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _indexed = done;
          _total = total;
        });
      });
      // a search was waiting for the index → run it again with everything
      if (_query != null && mounted) await _search(_query!, silent: true);
    } catch (e) {
      _indexError = 'Could not load stock photos. Pull down to retry.';
      debugPrint('🔍 INDEX ERROR => $e');
    }
    if (mounted) setState(() => _indexing = false);
  }

  // ---------------------------------------------------------------------
  //  PICK + SEARCH
  // ---------------------------------------------------------------------
  Future<void> _pick(ImageSource src) async {
    try {
      final x = await _picker.pickImage(source: src, maxWidth: 900, maxHeight: 900, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() => _query = bytes);
      await _search(bytes);
    } catch (e) {
      _snack('Could not open the photo');
    }
  }

  Future<void> _search(Uint8List bytes, {bool silent = false}) async {
    if (!silent) setState(() => _searching = true);
    try {
      final q = await _Fp.many(bytes); // full + centre crop
      if (q.isEmpty) {
        _snack('Could not read this photo, please try another one');
      } else {
        final r = _ImageIndex.instance.search(q, inStockOnly: _inStockOnly);
        _exact = r.exact;
        _similar = r.similar;
        _searched = true;
      }
    } catch (e) {
      debugPrint('🔍 SEARCH ERROR => $e');
    }
    if (mounted) setState(() => _searching = false);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  // ---------------------------------------------------------------------
  //  PDF + WHATSAPP
  // ---------------------------------------------------------------------
  Future<File?> _makePdf() async {
    if (_exact.isEmpty && _similar.isEmpty) {
      _snack('Search a photo first');
      return null;
    }
    setState(() => _pdfBusy = true);
    try {
      final f = await _SearchPdf.build(query: _query, exact: _exact, similar: _similar);
      return f;
    } catch (e) {
      debugPrint('🔍 PDF ERROR => $e');
      _snack('Could not make the PDF');
      return null;
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _openPdf() async {
    final f = await _makePdf();
    if (f != null) OpenFile.open(f.path);
  }

  String get _shareText {
    final b = StringBuffer('🔍 Image search result\n');
    if (_exact.isNotEmpty) {
      b.writeln('✅ Exact match:');
      for (final h in _exact.take(5)) {
        b.writeln('• ${h.item.labelCode} · ${h.item.itemName} · ${h.item.netWeight.toStringAsFixed(3)} g');
      }
    }
    if (_similar.isNotEmpty) {
      b.writeln('✨ Similar (${_similar.length}):');
      for (final h in _similar.take(8)) {
        b.writeln('• ${h.item.labelCode} · ${h.item.itemName} · ${h.item.netWeight.toStringAsFixed(3)} g · ${h.pct}%');
      }
    }
    return b.toString().trim();
  }

  /// WhatsApp: shares the PDF (with photos) + a short text — pick WhatsApp in the share sheet
  Future<void> _whatsApp() async {
    final f = await _makePdf();
    if (f == null) return;
    await Share.shareXFiles([XFile(f.path)], text: _shareText);
  }

  // ---------------------------------------------------------------------
  //  UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 900 ? 5 : (w >= 600 ? 4 : 2);
    final hasResults = _exact.isNotEmpty || _similar.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: _ink,
        titleSpacing: 0,
        title: const Row(children: [
          _GradIcon(Icons.image_search_rounded),
          SizedBox(width: 10),
          Text('Image Search', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _ink)),
        ]),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      bottomNavigationBar: hasResults ? _bottomBar() : null,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: () async {
          _ImageIndex.instance.resetStock();
          await _buildIndex();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _pickCard(),
                  const SizedBox(height: 10),
                  _indexBar(),
                  const SizedBox(height: 8),
                  _filterRow(),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator(color: _blue)),
                    ),
                  if (!_searching && _searched && !hasResults) _empty(),
                  if (!_searching && _exact.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('Exact match', '${_exact.length}', _green, Icons.verified_rounded),
                  ],
                ]),
              ),
            ),
            if (!_searching && _exact.isNotEmpty) _grid(_exact, cols, exact: true),
            if (!_searching && _similar.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                sliver: SliverToBoxAdapter(
                  child: _sectionTitle('Similar items', '${_similar.length}', _blue, Icons.auto_awesome_rounded),
                ),
              ),
            if (!_searching && _similar.isNotEmpty) _grid(_similar, cols),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _pickCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xffEFF6FF), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: _query == null ? () => _pick(ImageSource.gallery) : () => _preview(_query!),
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          clipBehavior: Clip.antiAlias,
          child: _query == null
              ? const Icon(Icons.add_photo_alternate_rounded, size: 34, color: _blue)
              : Image.memory(_query!, fit: BoxFit.cover),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_query == null ? 'Find a piece by photo' : 'Your photo',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 2),
          const Text('Exact match + similar items from your stock gallery',
              style: TextStyle(fontSize: 11.5, color: _soft)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _pill(Icons.photo_camera_rounded, 'Camera', () => _pick(ImageSource.camera))),
            const SizedBox(width: 8),
            Expanded(child: _pill(Icons.photo_library_rounded, 'Gallery', () => _pick(ImageSource.gallery))),
          ]),
        ]),
      ),
    ]),
  );

  Widget _pill(IconData i, String t, VoidCallback onTap) => InkWell(
    onTap: _searching ? null : onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xff60A5FA), _blueDeep]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ]),
    ),
  );

  Widget _indexBar() {
    if (_indexError != null) {
      return Text(_indexError!, style: const TextStyle(fontSize: 11.5, color: Colors.red));
    }
    final done = !_indexing && _total > 0;
    final v = _total == 0 ? null : (_indexed / _total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.bolt_rounded, size: 15, color: done ? _green : _blue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _total == 0
                  ? 'Loading stock photos…'
                  : done
                  ? '$_total photos ready · search is instant'
                  : 'Preparing photos $_indexed / $_total (one time only)',
              style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        if (!done) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: v, minHeight: 4, color: _blue, backgroundColor: _line),
          ),
        ],
      ]),
    );
  }

  Widget _filterRow() => Row(children: [
    const Text('In stock only', style: TextStyle(fontSize: 12.5, color: _ink, fontWeight: FontWeight.w700)),
    const Spacer(),
    Switch(
      value: _inStockOnly,
      activeColor: _blue,
      onChanged: (v) {
        setState(() => _inStockOnly = v);
        if (_query != null) _search(_query!);
      },
    ),
  ]);

  Widget _sectionTitle(String t, String n, Color c, IconData i) => Row(children: [
    Icon(i, size: 17, color: c),
    const SizedBox(width: 6),
    Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
    const SizedBox(width: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(n, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w800)),
    ),
  ]);

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(children: [
      const Icon(Icons.image_not_supported_outlined, size: 40, color: _soft),
      const SizedBox(height: 8),
      Text(
        _indexing ? 'Still preparing photos — results will appear automatically.' : 'No matching item found.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, color: _soft),
      ),
      if (_inStockOnly && !_indexing)
        TextButton(
          onPressed: () {
            setState(() => _inStockOnly = false);
            _search(_query!);
          },
          child: const Text('Search sold items too', style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
        ),
    ]),
  );

  Widget _grid(List<_Hit> list, int cols, {bool exact = false}) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    sliver: SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate((_, i) => _card(list[i], exact), childCount: list.length),
    ),
  );

  Widget _card(_Hit h, bool exact) {
    final s = h.item;
    final c = exact ? _green : _blue;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _details(h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: exact ? _green.withOpacity(0.5) : _line, width: exact ? 1.4 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Image.network(
                h.url,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: _bgSoft,
                  child: Icon(Icons.image_not_supported_outlined, color: _soft),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
                  child: Text(exact ? 'EXACT' : '${h.pct}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
              if (s.isSold)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(10)),
                    child: const Text('SOLD',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.labelCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink)),
              Text(s.itemName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _soft)),
              const SizedBox(height: 3),
              Text('Net ${s.netWeight.toStringAsFixed(3)} g',
                  style: const TextStyle(fontSize: 11.5, color: _blueDeep, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bottomBar() => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(children: [
        Expanded(
          child: _bigBtn(
            icon: Icons.picture_as_pdf_rounded,
            text: 'PDF',
            colors: const [Color(0xff60A5FA), _blueDeep],
            onTap: _pdfBusy ? null : _openPdf,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _bigBtn(
            icon: Icons.chat_rounded,
            text: 'WhatsApp',
            colors: const [Color(0xff34E07A), Color(0xff128C7E)],
            onTap: _pdfBusy ? null : _whatsApp,
          ),
        ),
      ]),
    ),
  );

  Widget _bigBtn({required IconData icon, required String text, required List<Color> colors, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: colors.last.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_pdfBusy)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      );

  void _preview(Uint8List b) => showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Image.memory(b, fit: BoxFit.contain),
    ),
  );

  void _details(_Hit h) {
    final s = h.item;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 1.3,
                child: Image.network(h.url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: _soft)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(s.labelCode, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (h.exact ? _green : _blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(h.exact ? 'Exact match' : '${h.pct}% similar',
                    style: TextStyle(color: h.exact ? _green : _blue, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            _kv('Item', s.itemName),
            _kv('Gross', '${s.grossWeight.toStringAsFixed(3)} g'),
            if (s.otherWeight > 0) _kv('Other', '${s.otherWeight.toStringAsFixed(3)} g'),
            _kv('Net', '${s.netWeight.toStringAsFixed(3)} g'),
            if (s.huid.trim().isNotEmpty && s.huid != '-') _kv('HUID', s.huid),
            _kv('Status', s.isSold ? 'Sold' : 'In stock'),
          ]),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 70, child: Text(k, style: const TextStyle(fontSize: 12.5, color: _soft))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _GradIcon extends StatelessWidget {
  final IconData icon;
  const _GradIcon(this.icon);

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xff60A5FA), Color(0xff1D4ED8)]),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 18, color: Colors.white),
  );
}

// =======================================================================
//  🧬 FINGERPRINT  (shape hash 64 bit + colour mix 28 + pattern 8×8)
// =======================================================================
class _Fp {
  final int h1, h2; // dHash 64 bit as 2 × 32 bit
  final List<double> col; // colour histogram (sum = 1)
  final List<double> pat; // 8×8 grey, zero mean, unit length
  _Fp(this.h1, this.h2, this.col, this.pat);

  Map<String, dynamic> toJson() => {
    'a': h1,
    'b': h2,
    'c': col.map((e) => double.parse(e.toStringAsFixed(4))).toList(),
    'p': pat.map((e) => double.parse(e.toStringAsFixed(4))).toList(),
  };

  static _Fp? fromJson(dynamic j) {
    if (j is! Map) return null;
    try {
      return _Fp(
        (j['a'] as num).toInt(),
        (j['b'] as num).toInt(),
        (j['c'] as List).map((e) => (e as num).toDouble()).toList(),
        (j['p'] as List).map((e) => (e as num).toDouble()).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static const int _n = 48; // decode size

  static Future<Uint8List?> _rgba(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: _n, targetHeight: _n);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// stock photo → one fingerprint (full photo)
  static Future<_Fp?> of(Uint8List bytes) async {
    final px = await _rgba(bytes);
    return px == null ? null : _from(px, 0, _n);
  }

  /// your photo → full + centre crop (phone photos usually have extra border)
  static Future<List<_Fp>> many(Uint8List bytes) async {
    final px = await _rgba(bytes);
    if (px == null) return const [];
    return [_from(px, 0, _n), _from(px, 6, _n - 12), _from(px, 10, _n - 20)];
  }

  static _Fp _from(Uint8List px, int off, int size) {
    // grey + colour inside the region
    double grey(int x, int y) {
      final i = ((off + y) * _n + (off + x)) * 4;
      return 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
    }

    // block average helper on region
    List<double> grid(int gw, int gh) {
      final out = List<double>.filled(gw * gh, 0);
      for (var gy = 0; gy < gh; gy++) {
        final y0 = (gy * size / gh).floor(), y1 = math.max(y0 + 1, ((gy + 1) * size / gh).floor());
        for (var gx = 0; gx < gw; gx++) {
          final x0 = (gx * size / gw).floor(), x1 = math.max(x0 + 1, ((gx + 1) * size / gw).floor());
          var s = 0.0;
          var c = 0;
          for (var y = y0; y < y1; y++) {
            for (var x = x0; x < x1; x++) {
              s += grey(x, y);
              c++;
            }
          }
          out[gy * gw + gx] = s / c;
        }
      }
      return out;
    }

    // 1) dHash 9×8
    final g9 = grid(9, 8);
    var h1 = 0, h2 = 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final bit = g9[r * 9 + c] > g9[r * 9 + c + 1] ? 1 : 0;
        final k = r * 8 + c;
        if (k < 32) {
          h1 |= bit << k;
        } else {
          h2 |= bit << (k - 32);
        }
      }
    }

    // 2) pattern 8×8 (normalised)
    final g8 = grid(8, 8);
    final mean = g8.reduce((a, b) => a + b) / 64;
    var pat = g8.map((v) => v - mean).toList();
    final len = math.sqrt(pat.fold<double>(0, (a, v) => a + v * v));
    pat = len < 1e-6 ? List<double>.filled(64, 0) : pat.map((v) => v / len).toList();

    // 3) colour mix: 12 hues × 2 saturation + 4 grey levels
    final col = List<double>.filled(28, 0);
    var cnt = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final i = ((off + y) * _n + (off + x)) * 4;
        final r = px[i] / 255.0, g = px[i + 1] / 255.0, b = px[i + 2] / 255.0;
        final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
        final v = mx, s = mx == 0 ? 0.0 : (mx - mn) / mx;
        if (s < 0.18 || v < 0.15) {
          col[24 + math.min(3, (v * 4).floor())] += 1;
        } else {
          final d = mx - mn;
          double h;
          if (mx == r) {
            h = ((g - b) / d) % 6;
          } else if (mx == g) {
            h = (b - r) / d + 2;
          } else {
            h = (r - g) / d + 4;
          }
          final hb = ((h / 6) * 12).floor() % 12;
          col[hb * 2 + (s < 0.5 ? 0 : 1)] += 1;
        }
        cnt++;
      }
    }
    for (var k = 0; k < col.length; k++) {
      col[k] /= cnt;
    }
    return _Fp(h1, h2, col, pat);
  }

  static int _bits(int v) {
    var c = 0;
    var x = v & 0xFFFFFFFF;
    while (x != 0) {
      x &= x - 1;
      c++;
    }
    return c;
  }

  int ham(_Fp o) => _bits(h1 ^ o.h1) + _bits(h2 ^ o.h2);

  /// 0 … 1
  double score(_Fp o) {
    final shape = 1 - ham(o) / 64.0;
    var inter = 0.0;
    for (var i = 0; i < col.length && i < o.col.length; i++) {
      inter += math.min(col[i], o.col[i]);
    }
    var dot = 0.0;
    for (var i = 0; i < pat.length && i < o.pat.length; i++) {
      dot += pat[i] * o.pat[i];
    }
    return 0.40 * shape + 0.35 * inter + 0.25 * ((dot + 1) / 2);
  }
}

class _Hit {
  final StockItem item;
  final String url;
  final double score;
  final bool exact;
  _Hit(this.item, this.url, this.score, this.exact);
  int get pct => (score * 100).round().clamp(0, 100);
}

// =======================================================================
//  🗂️ INDEX — fingerprints of every stock photo, saved on the phone
// =======================================================================
class _ImageIndex {
  _ImageIndex._();
  static final _ImageIndex instance = _ImageIndex._();

  static const String _file = 'ai_image_index_v1.json';
  final Map<String, _Fp> _fp = {}; // "id|url" → fingerprint
  List<StockItem> _stock = [];
  bool _loadedFromDisk = false;
  Future<void>? _running;

  static String get _site => ApiConstants.baseUrl.replaceFirst(RegExp(r'api/?$'), '');

  static String? urlOf(StockItem s) {
    // small gallery photo first (faster), download url as backup
    for (final raw in [s.imageUrl, s.imageDownloadUrl]) {
      final v = (raw ?? '').trim();
      if (v.isEmpty || v == 'null') continue;
      if (RegExp(r'(no[-_ ]?image|noimage|placeholder|dummy)', caseSensitive: false).hasMatch(v)) continue;
      return v.startsWith('http') ? v : '$_site${v.replaceFirst(RegExp(r'^/'), '')}';
    }
    return null;
  }

  static String _key(StockItem s, String url) => '${s.id}|$url';

  void resetStock() {
    StockAiRepository.clearCache();
    _stock = [];
  }

  Future<File> _path() async => File('${(await getApplicationDocumentsDirectory()).path}/$_file');

  Future<void> _loadDisk() async {
    if (_loadedFromDisk) return;
    _loadedFromDisk = true;
    try {
      final f = await _path();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      if (j is Map) {
        j.forEach((k, v) {
          final fp = _Fp.fromJson(v);
          if (fp != null) _fp[k.toString()] = fp;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDisk() async {
    try {
      final f = await _path();
      await f.writeAsString(jsonEncode({for (final e in _fp.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }

  Future<void> build({void Function(int done, int total)? onProgress}) {
    _running ??= _build(onProgress).whenComplete(() => _running = null);
    return _running!;
  }

  Future<void> _build(void Function(int done, int total)? onProgress) async {
    await _loadDisk();
    _stock = await StockAiRepository.loadAll();
    final withPhoto = <(StockItem, String)>[];
    for (final s in _stock) {
      final u = urlOf(s);
      if (u != null) withPhoto.add((s, u));
    }
    final todo = withPhoto.where((e) => !_fp.containsKey(_key(e.$1, e.$2))).toList();
    var done = withPhoto.length - todo.length;
    onProgress?.call(done, withPhoto.length);
    if (todo.isEmpty) return;

    final dio = Dio(BaseOptions(
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 25),
    ));
    String? token;
    try {
      token = (await SharedPreferences.getInstance()).getString('token');
    } catch (_) {}

    Future<void> one((StockItem, String) e) async {
      try {
        final res = await dio.get<List<int>>(e.$2,
            options: Options(headers: {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'}));
        final b = res.data;
        if (b != null && b.length > 200) {
          final fp = await _Fp.of(Uint8List.fromList(b));
          if (fp != null) _fp[_key(e.$1, e.$2)] = fp;
        }
      } catch (_) {}
      done++;
      if (done % 4 == 0 || done == withPhoto.length) onProgress?.call(done, withPhoto.length);
    }

    // ⚡ 10 photos at a time · save every 60 so nothing is lost if you go back
    const par = 10;
    for (var i = 0; i < todo.length; i += par) {
      await Future.wait([for (var j = i; j < i + par && j < todo.length; j++) one(todo[j])]);
      if ((i ~/ par) % 6 == 5) await _saveDisk();
    }
    await _saveDisk();
    onProgress?.call(withPhoto.length, withPhoto.length);
  }

  ({List<_Hit> exact, List<_Hit> similar}) search(List<_Fp> q, {required bool inStockOnly}) {
    final hits = <_Hit>[];
    for (final s in _stock) {
      if (inStockOnly && s.isSold) continue;
      final u = urlOf(s);
      if (u == null) continue;
      final fp = _fp[_key(s, u)];
      if (fp == null) continue;
      var best = 0.0;
      var bestHam = 64;
      for (final x in q) {
        final sc = x.score(fp);
        if (sc > best) best = sc;
        final hm = x.ham(fp);
        if (hm < bestHam) bestHam = hm;
      }
      final exact = best >= 0.93 && bestHam <= 6;
      if (exact || best >= 0.55) hits.add(_Hit(s, u, best, exact));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    final exact = hits.where((h) => h.exact).take(12).toList();
    final similar = hits.where((h) => !h.exact).take(30).toList();
    return (exact: exact, similar: similar);
  }
}

// =======================================================================
//  📄 PDF — your photo + exact + similar (with photos)
// =======================================================================
class _SearchPdf {
  static const _navy = PdfColor.fromInt(0xff1D4ED8);
  static const _soft = PdfColor.fromInt(0xffEFF6FF);
  static const _line = PdfColor.fromInt(0xffDCE7F7);
  static const _grey = PdfColor.fromInt(0xff6B7487);
  static const _green = PdfColor.fromInt(0xff16A34A);

  static Future<Uint8List?> _png(Uint8List bytes, int w) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: w);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<File> build({Uint8List? query, required List<_Hit> exact, required List<_Hit> similar}) async {
    final all = [...exact, ...similar];
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 20)));
    final imgs = <String, pw.MemoryImage>{};
    // ⚡ photos 8 at a time (pdf can't draw webp → convert to small png)
    for (var i = 0; i < all.length; i += 8) {
      await Future.wait([
        for (var j = i; j < i + 8 && j < all.length; j++)
              () async {
            try {
              final r = await dio.get<List<int>>(all[j].url);
              if (r.data == null) return;
              final p = await _png(Uint8List.fromList(r.data!), 220);
              if (p != null) imgs[all[j].url] = pw.MemoryImage(p);
            } catch (_) {}
          }(),
      ]);
    }
    pw.MemoryImage? q;
    if (query != null) {
      final p = await _png(query, 320);
      if (p != null) q = pw.MemoryImage(p);
    }
    String company = 'Ornasphere';
    try {
      final c = (await SharedPreferences.getInstance()).getString('companyName');
      if (c != null && c.trim().isNotEmpty && c != 'null') company = c.trim();
    } catch (_) {}

    pw.Widget card(_Hit h) {
      final s = h.item;
      final img = imgs[h.url];
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: h.exact ? _green : _line, width: h.exact ? 1.2 : 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        padding: const pw.EdgeInsets.all(5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            height: 92,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
            child: img == null
                ? pw.Text('No photo', style: const pw.TextStyle(fontSize: 7, color: _grey))
                : pw.Image(img, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Text(s.labelCode, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(h.exact ? 'EXACT' : '${h.pct}%',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: h.exact ? _green : _navy)),
          ]),
          pw.Text(s.itemName, maxLines: 1, style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          pw.Text('Gross ${s.grossWeight.toStringAsFixed(3)} · Net ${s.netWeight.toStringAsFixed(3)} g',
              style: const pw.TextStyle(fontSize: 7.2)),
          pw.Text(s.isSold ? 'Sold' : 'In stock',
              style: pw.TextStyle(fontSize: 7, color: s.isSold ? PdfColors.red : _green, fontWeight: pw.FontWeight.bold)),
        ]),
      );
    }

    pw.Widget grid(List<_Hit> list) => pw.GridView(
      crossAxisCount: 5,
      childAspectRatio: 0.68,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      children: list.map(card).toList(),
    );

    pw.Widget title(String t, PdfColor c) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(color: _soft, border: pw.Border(left: pw.BorderSide(color: c, width: 4))),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: c)),
    );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 200,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(company, style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('IMAGE SEARCH', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (q != null)
            pw.Container(
              width: 110,
              height: 110,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              padding: const pw.EdgeInsets.all(4),
              child: pw.Image(q, fit: pw.BoxFit.contain),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Searched photo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Exact match: ${exact.length}', style: const pw.TextStyle(fontSize: 10, color: _green)),
              pw.Text('Similar items: ${similar.length}', style: const pw.TextStyle(fontSize: 10, color: _navy)),
            ]),
          ),
        ]),
        if (exact.isNotEmpty) ...[title('EXACT MATCH', _green), grid(exact)],
        if (similar.isNotEmpty) ...[title('SIMILAR ITEMS', _navy), grid(similar)],
      ],
    ));

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/Image_Search_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }
}
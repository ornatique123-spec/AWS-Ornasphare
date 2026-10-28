import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ai_core.dart';

/// =======================================================================
///  📊 AI GRAPH VIEW — any "Day wise / Month wise / Year wise / Top …" list
///  in an Ask AI answer can be seen as a chart.
///
///   • 5 chart types: Bar · Line · Ranking (horizontal) · Donut (share %) · Growth (running total)
///   • Metric chips taken from the rows: Amount (₹), Bill, Pcs, Weight (g) …
///   • Total / Average / Highest / Lowest summary
///   • Tap a bar / point → its details + "Open" (same as tapping the row)
///   • Many rows → chart scrolls sideways
///
///  No package needed (pure Flutter CustomPainter).
///
///  Use:  AiGraph.open(context, section, onAsk: (q) => _ask(q));
///  File: Ask AI/core/AiGraph.dart
/// =======================================================================
class AiGraph {
  AiGraph._();

  /// Can this section be drawn? (2+ rows with a number)
  static bool canShow(AiSection s) => _metrics(s.rows).isNotEmpty && s.rows.length >= 2;

  static Future<void> open(BuildContext context, AiSection s, {void Function(String q)? onAsk}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (_) => _GraphSheet(section: s, onAsk: onAsk),
    );
  }

  // ---------------------------------------------------------------------
  //  Numbers inside the row texts
  //  value "₹15554.60"            → Amount
  //  sub   "1 bill · 166.85 g"    → Bill, Weight
  // ---------------------------------------------------------------------
  static final RegExp _num = RegExp(r'(-?[\d,]+(?:\.\d+)?)\s*([A-Za-z%]+)?');

  static double? _parse(String s) {
    final m = RegExp(r'-?[\d,]*\d(?:\.\d+)?').firstMatch(s);
    if (m == null) return null;
    final v = double.tryParse(m[0]!.replaceAll(',', ''));
    if (v == null) return null;
    // 1.2L / 3.4Cr / 5k style values
    final low = s.toLowerCase();
    if (RegExp(r'\d\s*cr\b').hasMatch(low)) return v * 1e7;
    if (RegExp(r'\d\s*(l|lac|lakh)\b').hasMatch(low)) return v * 1e5;
    if (RegExp(r'\d\s*k\b').hasMatch(low)) return v * 1e3;
    return v;
  }

  static String _metricName(String part, String unit) {
    final p = part.toLowerCase();
    final u = unit.toLowerCase();
    if (p.contains('₹') || p.contains('rs')) return 'Amount';
    if (u.startsWith('bill') || p.contains('bill') || p.contains('voucher')) return 'Bill';
    if (u.startsWith('pc') || u == 'nang' || u == 'piece' || u == 'pieces') return 'Pcs';
    if (u == 'g' || u == 'gm' || u == 'gms' || u == 'gram' || u == 'grams') {
      if (p.contains('fine')) return 'Fine';
      if (p.contains('gross')) return 'Gross';
      return 'Weight';
    }
    if (u == 'kg') return 'Weight (kg)';
    if (u == '%') return 'Percent';
    if (u.isEmpty) return 'Value';
    return '${unit[0].toUpperCase()}${unit.substring(1)}';
  }

  /// metric name → value per row (null = row has no such number)
  static Map<String, List<double?>> _metrics(List<AiRow> rows) {
    final out = <String, List<double?>>{};
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final parts = <String>[r.value, ...?r.sub?.split(RegExp(r'\s*[·|]\s*'))];
      final seen = <String>{};
      for (var j = 0; j < parts.length; j++) {
        final part = parts[j].trim();
        if (part.isEmpty) continue;
        final v = _parse(part);
        if (v == null) continue;
        final m = _num.firstMatch(part.replaceAll('₹', ''));
        final name = j == 0 && part.contains('₹') ? 'Amount' : _metricName(part, m?[2] ?? '');
        if (seen.contains(name)) continue;
        seen.add(name);
        out.putIfAbsent(name, () => List<double?>.filled(rows.length, null));
        out[name]![i] = v;
      }
    }
    // keep metrics that most rows have
    out.removeWhere((k, v) => v.where((e) => e != null).length < math.max(2, rows.length ~/ 2));
    return out;
  }

  static String fmt(double v, String metric) {
    String compact(double x) {
      final a = x.abs();
      if (a >= 1e7) return '${(x / 1e7).toStringAsFixed(2)} Cr';
      if (a >= 1e5) return '${(x / 1e5).toStringAsFixed(2)} L';
      if (a >= 1e3) return '${(x / 1e3).toStringAsFixed(1)} K';
      return x.toStringAsFixed(x == x.roundToDouble() ? 0 : 2);
    }

    switch (metric) {
      case 'Amount':
        return '₹${compact(v)}';
      case 'Weight':
      case 'Fine':
      case 'Gross':
        return '${v.toStringAsFixed(v >= 1000 ? 0 : 2)} g';
      case 'Bill':
      case 'Pcs':
        return v.toStringAsFixed(0);
      case 'Percent':
        return '${v.toStringAsFixed(1)}%';
      default:
        return compact(v);
    }
  }

  /// "01-10-2026" → "01 Oct", "October 2026" → "Oct 26", long names cut
  static String shortLabel(String t) {
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})').firstMatch(t.trim());
    if (d != null) {
      final m = int.tryParse(d[2]!) ?? 1;
      return '${d[1]!.padLeft(2, '0')} ${mon[(m - 1).clamp(0, 11)]}';
    }
    final my = RegExp(r'^([A-Za-z]{3})[a-z]*\s+(\d{4})').firstMatch(t.trim());
    if (my != null) return '${my[1]} ${my[2]!.substring(2)}';
    final s = t.trim();
    return s.length <= 9 ? s : '${s.substring(0, 8)}…';
  }
}

// =======================================================================
//  SHEET — 5 chart types
// =======================================================================
enum _Kind { bar, line, ranking, donut, growth }

extension on _Kind {
  String get label => const {
    _Kind.bar: 'Bar',
    _Kind.line: 'Line',
    _Kind.ranking: 'Ranking',
    _Kind.donut: 'Donut',
    _Kind.growth: 'Growth',
  }[this]!;

  IconData get icon => const {
    _Kind.bar: Icons.bar_chart_rounded,
    _Kind.line: Icons.show_chart_rounded,
    _Kind.ranking: Icons.align_horizontal_left_rounded,
    _Kind.donut: Icons.donut_large_rounded,
    _Kind.growth: Icons.trending_up_rounded,
  }[this]!;

  String get hint => const {
    _Kind.bar: 'Compare each row',
    _Kind.line: 'See the trend',
    _Kind.ranking: 'Highest to lowest',
    _Kind.donut: 'Share of total (%)',
    _Kind.growth: 'Running total',
  }[this]!;
}

/// Slice colours (donut / ranking) — blue family + a few accents
const List<Color> _palette = [
  Color(0xff2563EB),
  Color(0xff0EA5E9),
  Color(0xff14B8A6),
  Color(0xff8B5CF6),
  Color(0xffF59E0B),
  Color(0xffEC4899),
  Color(0xff22C55E),
  Color(0xff64748B),
  Color(0xffEF4444),
];

class _GraphSheet extends StatefulWidget {
  const _GraphSheet({required this.section, this.onAsk});

  final AiSection section;
  final void Function(String q)? onAsk;

  @override
  State<_GraphSheet> createState() => _GraphSheetState();
}

class _GraphSheetState extends State<_GraphSheet> {
  static const Color _blue = Color(0xff2563EB);
  static const Color _ink = Color(0xff1B2433);
  static const Color _soft = Color(0xff6B7487);
  static const Color _line = Color(0xffDCE7F7);
  static const Color _bgSoft = Color(0xffF4F8FF);

  late final Map<String, List<double?>> _metrics = AiGraph._metrics(widget.section.rows);
  late String _metric = _metrics.containsKey('Amount') ? 'Amount' : _metrics.keys.first;
  _Kind _kind = _Kind.bar;
  int? _sel;

  List<AiRow> get _rows => widget.section.rows;
  List<double> get _vals => _metrics[_metric]!.map((e) => e ?? 0).toList();

  List<double> _running(List<double> v) {
    var s = 0.0;
    return [for (final x in v) s += x];
  }

  @override
  Widget build(BuildContext context) {
    final vals = _vals;
    final total = vals.fold<double>(0, (a, b) => a + b);
    final avg = vals.isEmpty ? 0.0 : total / vals.length;
    int hi = 0, lo = 0;
    for (var i = 1; i < vals.length; i++) {
      if (vals[i] > vals[hi]) hi = i;
      if (vals[i] < vals[lo]) lo = i;
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                    width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 12),

              // ---- title ----
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xff60A5FA), _blue]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink)),
                    Text('${_kind.label} chart · ${_kind.hint}', style: const TextStyle(fontSize: 11, color: _soft)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _soft),
                ),
              ]),
              const SizedBox(height: 12),

              // ---- 5 chart types ----
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _Kind.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _kindTile(_Kind.values[i]),
                ),
              ),
              const SizedBox(height: 12),

              // ---- metric chips ----
              if (_metrics.length > 1) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _metrics.keys
                      .map((m) => ChoiceChip(
                    label: Text(m),
                    selected: m == _metric,
                    selectedColor: _blue,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: m == _metric ? _blue : _line),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: m == _metric ? Colors.white : _ink,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _metric = m;
                      _sel = null;
                    }),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // ---- summary ----
              Wrap(spacing: 6, runSpacing: 6, children: [
                _stat('Total', AiGraph.fmt(total, _metric)),
                _stat('Average', AiGraph.fmt(avg, _metric)),
                _stat('Highest', '${AiGraph.fmt(vals[hi], _metric)} · ${AiGraph.shortLabel(_rows[hi].title)}'),
                _stat('Lowest', '${AiGraph.fmt(vals[lo], _metric)} · ${AiGraph.shortLabel(_rows[lo].title)}'),
              ]),
              const SizedBox(height: 14),

              // ---- chart ----
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey('$_kind$_metric'), child: _chart(vals, avg, total)),
              ),
              const SizedBox(height: 6),
              Text(_footHint(vals.length), style: const TextStyle(fontSize: 11, color: _soft)),

              // ---- selected row ----
              if (_sel != null && _sel! < _rows.length) ...[
                const SizedBox(height: 12),
                _selectedCard(vals, total),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _footHint(int n) {
    switch (_kind) {
      case _Kind.bar:
        return n * 56 + 40 > MediaQuery.of(context).size.width - 32
            ? 'Swipe sideways · tap a bar for details · dashed line = average'
            : 'Tap a bar for details · dashed line = average';
      case _Kind.line:
        return 'Tap a point for details · dashed line = average';
      case _Kind.ranking:
        return 'Sorted from highest to lowest · tap a row for details';
      case _Kind.donut:
        return 'Each slice = share of the total · tap a slice or a name';
      case _Kind.growth:
        return 'Running total — how the total built up row by row';
    }
  }

  // ---------------------------------------------------------------------
  //  CHART AREA
  // ---------------------------------------------------------------------
  Widget _chart(List<double> vals, double avg, double total) {
    switch (_kind) {
      case _Kind.ranking:
        return _ranking(vals);
      case _Kind.donut:
        return _donut(vals, total);
      case _Kind.bar:
      case _Kind.line:
      case _Kind.growth:
        final growth = _kind == _Kind.growth;
        final shown = growth ? _running(vals) : vals;
        final perItem = 56.0;
        final screenW = MediaQuery.of(context).size.width - 32;
        final chartW = math.max(screenW, shown.length * perItem + 40);
        return _frame(
          height: 280,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartW,
              height: 264,
              child: LayoutBuilder(
                builder: (_, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final i = _ChartPainter.indexAt(d.localPosition.dx, box.maxWidth, shown.length);
                    if (i != null) setState(() => _sel = _sel == i ? null : i);
                  },
                  child: CustomPaint(
                    size: Size(box.maxWidth, box.maxHeight),
                    painter: _ChartPainter(
                      values: shown,
                      labels: _rows.map((r) => AiGraph.shortLabel(r.title)).toList(),
                      bars: _kind == _Kind.bar,
                      growth: growth,
                      selected: _sel,
                      average: growth ? null : avg,
                      format: (v) => AiGraph.fmt(v, _metric),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _frame({required Widget child, double? height}) => Container(
    height: height,
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    decoration: BoxDecoration(
      color: _bgSoft,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: child,
  );

  // ---- 3) RANKING: horizontal bars, highest first ----
  Widget _ranking(List<double> vals) {
    final order = List<int>.generate(vals.length, (i) => i)..sort((a, b) => vals[b].compareTo(vals[a]));
    final maxAbs = vals.fold<double>(0, (a, b) => math.max(a, b.abs()));
    return _frame(
      height: math.min(360.0, 22.0 + order.length * 42),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemCount: order.length,
        itemBuilder: (_, k) {
          final i = order[k];
          final v = vals[i];
          final sel = _sel == i;
          final frac = maxAbs == 0 ? 0.0 : (v.abs() / maxAbs).clamp(0.0, 1.0);
          final c = k < 3 ? _palette[k] : _blue.withOpacity(0.55);
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _sel = sel ? null : i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _blue.withOpacity(0.35) : Colors.transparent),
              ),
              child: Row(children: [
                SizedBox(
                  width: 22,
                  child: Text('${k + 1}',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800, color: k < 3 ? c : _soft)),
                ),
                SizedBox(
                  width: 92,
                  child: Text(AiGraph.shortLabel(_rows[i].title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, box) => Stack(alignment: Alignment.centerLeft, children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(color: const Color(0xffE7EEFB), borderRadius: BorderRadius.circular(10)),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 14,
                        width: math.max(4.0, box.maxWidth * frac),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [c.withOpacity(0.75), c]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: Text(AiGraph.fmt(v, _metric),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _ink)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ---- 4) DONUT: share of total ----
  Widget _donut(List<double> vals, double total) {
    final pos = [for (final v in vals) math.max(0.0, v)];
    final sum = pos.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) {
      return _frame(
        height: 160,
        child: const Center(
          child: Text('Donut needs positive values — try Bar or Ranking.',
              style: TextStyle(fontSize: 12.5, color: _soft)),
        ),
      );
    }
    // top 8 + "Others"
    final order = List<int>.generate(pos.length, (i) => i)..sort((a, b) => pos[b].compareTo(pos[a]));
    final top = order.take(8).toList();
    final rest = order.skip(8).fold<double>(0, (a, i) => a + pos[i]);
    final slices = <({String label, double value, int? index, Color color})>[
      for (var k = 0; k < top.length; k++)
        (label: _rows[top[k]].title, value: pos[top[k]], index: top[k], color: _palette[k % _palette.length]),
      if (rest > 0) (label: 'Others (${order.length - 8})', value: rest, index: null, color: const Color(0xffCBD5E1)),
    ];
    final selSlice = slices.indexWhere((e) => e.index != null && e.index == _sel);

    return _frame(
      child: Column(children: [
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (_, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final k = _DonutPainter.sliceAt(d.localPosition, Size(box.maxWidth, 220), slices.map((e) => e.value).toList());
                if (k != null && slices[k].index != null) {
                  final i = slices[k].index!;
                  setState(() => _sel = _sel == i ? null : i);
                }
              },
              child: CustomPaint(
                size: Size(box.maxWidth, 220),
                painter: _DonutPainter(
                  values: slices.map((e) => e.value).toList(),
                  colors: slices.map((e) => e.color).toList(),
                  selected: selSlice < 0 ? null : selSlice,
                  centerTop: selSlice < 0 ? 'Total' : AiGraph.shortLabel(slices[selSlice].label),
                  centerValue: selSlice < 0
                      ? AiGraph.fmt(total, _metric)
                      : '${(slices[selSlice].value / sum * 100).toStringAsFixed(1)}%',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // legend
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            children: [
              for (var k = 0; k < slices.length; k++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: slices[k].index == null
                      ? null
                      : () => setState(() => _sel = _sel == slices[k].index ? null : slices[k].index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: slices[k].color, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(slices[k].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: _ink,
                                fontWeight: k == selSlice ? FontWeight.w800 : FontWeight.w500)),
                      ),
                      Text(AiGraph.fmt(slices[k].value, _metric),
                          style: const TextStyle(fontSize: 11.5, color: _soft, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 46,
                        child: Text('${(slices[k].value / sum * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: slices[k].color)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------------
  Widget _kindTile(_Kind k) {
    final on = _kind == k;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _kind = k;
        _sel = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: on ? const LinearGradient(colors: [Color(0xff3B82F6), Color(0xff1D4ED8)]) : null,
          color: on ? null : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? const Color(0xff1D4ED8) : _line),
          boxShadow: on ? [BoxShadow(color: _blue.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(k.icon, size: 20, color: on ? Colors.white : _blue),
          const SizedBox(height: 4),
          Text(k.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: on ? Colors.white : _ink)),
        ]),
      ),
    );
  }

  Widget _selectedCard(List<double> vals, double total) {
    final r = _rows[_sel!];
    final v = vals[_sel!];
    final share = total == 0 ? 0.0 : v / total * 100;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blue.withOpacity(0.25)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 2),
            Text(
              '${AiGraph.fmt(v, _metric)} · ${share.toStringAsFixed(1)}% of total',
              style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              [r.value, if (r.sub != null) r.sub!].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: _soft),
            ),
          ]),
        ),
        if (r.askOnTap != null && widget.onAsk != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final q = r.askOnTap!;
              Navigator.pop(context);
              widget.onAsk!(q);
            },
            child: const Text('Open'),
          ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 8.5, color: _soft, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _blue)),
    ]),
  );
}

// =======================================================================
//  CHART PAINTER (bar · line · growth)
// =======================================================================
class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.labels,
    required this.bars,
    required this.growth,
    required this.selected,
    required this.average,
    required this.format,
  });

  final List<double> values;
  final List<String> labels;
  final bool bars;
  final bool growth;
  final int? selected;
  final double? average;
  final String Function(double) format;

  static const double _left = 8, _right = 8, _top = 22, _bottom = 30;
  static const Color _blue = Color(0xff2563EB);
  static const Color _blueLight = Color(0xff93C5FD);
  static const Color _teal = Color(0xff0D9488);

  static int? indexAt(double dx, double width, int n) {
    if (n == 0) return null;
    final slot = (width - _left - _right) / n;
    final i = ((dx - _left) / slot).floor();
    return i >= 0 && i < n ? i : null;
  }

  TextPainter _text(String s, double size, Color c, {FontWeight w = FontWeight.w600}) => TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: c, fontWeight: w)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final maxV = values.fold<double>(0, (a, b) => math.max(a, b));
    final minV = values.fold<double>(0, (a, b) => math.min(a, b));
    final top = maxV <= 0 ? 1.0 : maxV * 1.12;
    final bottom = math.min(0.0, minV);
    final chartH = size.height - _top - _bottom;
    final slot = (size.width - _left - _right) / n;
    double y(double v) => _top + chartH * (1 - (v - bottom) / (top - bottom));
    double x(int i) => _left + slot * i + slot / 2;
    final main = growth ? _teal : _blue;

    // grid
    final grid = Paint()
      ..color = const Color(0xffDCE7F7)
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final gy = _top + chartH * k / 4;
      canvas.drawLine(Offset(_left, gy), Offset(size.width - _right, gy), grid);
    }

    // average (dashed)
    if (average != null) {
      final ay = y(average!);
      final dash = Paint()
        ..color = const Color(0xffF59E0B)
        ..strokeWidth = 1.4;
      for (double dx = _left; dx < size.width - _right; dx += 9) {
        canvas.drawLine(Offset(dx, ay), Offset(math.min(dx + 5, size.width - _right), ay), dash);
      }
    }

    if (bars) {
      final bw = math.min(34.0, slot * 0.62);
      for (var i = 0; i < n; i++) {
        final sel = selected == i;
        final r = RRect.fromRectAndCorners(
          Rect.fromLTRB(x(i) - bw / 2, y(values[i]), x(i) + bw / 2, y(0)),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        );
        canvas.drawRRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: sel
                  ? const [Color(0xffF59E0B), Color(0xffD97706)]
                  : (selected == null
                  ? const [_blue, _blueLight]
                  : [_blue.withOpacity(0.45), _blueLight.withOpacity(0.45)]),
            ).createShader(r.outerRect),
        );
      }
    } else {
      final path = Path();
      final area = Path();
      for (var i = 0; i < n; i++) {
        final p = Offset(x(i), y(values[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
          area.moveTo(p.dx, y(0));
          area.lineTo(p.dx, p.dy);
        } else if (growth) {
          // step-like growth line (straight segments read better for totals)
          path.lineTo(p.dx, p.dy);
          area.lineTo(p.dx, p.dy);
        } else {
          final prev = Offset(x(i - 1), y(values[i - 1]));
          final cx = (prev.dx + p.dx) / 2;
          path.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
          area.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
        }
      }
      area
        ..lineTo(x(n - 1), y(0))
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [main.withOpacity(growth ? 0.30 : 0.25), main.withOpacity(0.0)],
          ).createShader(Rect.fromLTWH(0, _top, size.width, chartH)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = main
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      for (var i = 0; i < n; i++) {
        final sel = selected == i;
        canvas.drawCircle(Offset(x(i), y(values[i])), sel ? 6 : 4, Paint()..color = Colors.white);
        canvas.drawCircle(
            Offset(x(i), y(values[i])), sel ? 4.5 : 3, Paint()..color = sel ? const Color(0xffD97706) : main);
      }
    }

    // values: selected one, or all when few (growth → last one always)
    for (var i = 0; i < n; i++) {
      final show = selected == i || (selected == null && (n <= 8 || (growth && i == n - 1)));
      if (!show) continue;
      final tp = _text(format(values[i]), 10, selected == i ? const Color(0xffB45309) : const Color(0xff1B2433),
          w: FontWeight.w800);
      final lx = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, math.max(2, y(values[i]) - tp.height - 4)));
    }

    // x labels
    for (var i = 0; i < n; i++) {
      final tp = _text(labels[i], 9.5, selected == i ? _blue : const Color(0xff6B7487));
      final lx = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, size.height - _bottom + 8));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values ||
          old.bars != bars ||
          old.growth != growth ||
          old.selected != selected ||
          old.average != average;
}

// =======================================================================
//  DONUT PAINTER
// =======================================================================
class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.selected,
    required this.centerTop,
    required this.centerValue,
  });

  final List<double> values;
  final List<Color> colors;
  final int? selected;
  final String centerTop;
  final String centerValue;

  static const double _stroke = 34;

  static int? sliceAt(Offset p, Size size, List<double> values) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 8;
    final d = (p - c).distance;
    if (d < r - _stroke - 8 || d > r + 8) return null;
    final sum = values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return null;
    // angle from top, clockwise
    var a = math.atan2(p.dy - c.dy, p.dx - c.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      acc += values[i] / sum * 2 * math.pi;
      if (a <= acc) return i;
    }
    return values.length - 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sum = values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 8 - _stroke / 2;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / sum * 2 * math.pi;
      final sel = selected == i;
      final dim = selected != null && !sel;
      final paint = Paint()
        ..color = dim ? colors[i].withOpacity(0.35) : colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? _stroke + 8 : _stroke;
      // tiny gap between slices
      final gap = values.length > 1 ? 0.012 : 0.0;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start + gap, math.max(0.001, sweep - gap * 2), false, paint);
      start += sweep;
    }

    final t1 = TextPainter(
      text: TextSpan(text: centerTop, style: const TextStyle(fontSize: 11, color: Color(0xff6B7487), fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: r * 1.4);
    final t2 = TextPainter(
      text: TextSpan(text: centerValue, style: const TextStyle(fontSize: 16, color: Color(0xff1B2433), fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: r * 1.5);
    t1.paint(canvas, Offset(c.dx - t1.width / 2, c.dy - t1.height - 1));
    t2.paint(canvas, Offset(c.dx - t2.width / 2, c.dy + 1));
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.selected != selected || old.centerValue != centerValue || old.centerTop != centerTop;
}
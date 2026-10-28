import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';

/// =====================================================================
/// ONE ROW MODEL
/// =====================================================================
class PurchaseItemRow {
  Map<String, dynamic>? item;

  final TextEditingController labelCtrl = TextEditingController();
  final FocusNode labelFocus = FocusNode();
  final TextEditingController grossCtrl = TextEditingController();
  final TextEditingController otherCtrl = TextEditingController();
  final TextEditingController purityCtrl = TextEditingController();
  final TextEditingController wasteCtrl = TextEditingController();
  final TextEditingController rateCtrl = TextEditingController();
  bool apply = true;

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get gross => _d(grossCtrl);
  double get other => _d(otherCtrl);
  double get net => (gross - other) < 0 ? 0 : gross - other;
  double get purity => _d(purityCtrl);
  double get waste => _d(wasteCtrl);
  double get netPurity => purity + waste;
  double get fine => net * netPurity / 100;
  double get rate => _d(rateCtrl);
  double get metalAmount => apply ? fine * rate : 0;

  /// Row empty hoy to save ma na mokalvi
  bool get isEmpty => item == null && labelCtrl.text.trim().isEmpty && gross == 0;

  Map<String, dynamic> toJson() => {
    "item_id": item?["id"],
    "label": labelCtrl.text.trim(),
    "gross_weight": gross,
    "other_weight": other,
    "net_weight": double.parse(net.toStringAsFixed(3)),
    "purity": purity,
    "waste_percent": waste,
    "net_purity": netPurity,
    "fine_weight": double.parse(fine.toStringAsFixed(3)),
    "metal_rate": rate,
    "apply": apply ? 1 : 0,
    "metal_amount": double.parse(metalAmount.toStringAsFixed(2)),
  };

  void dispose() {
    labelCtrl.dispose();
    labelFocus.dispose();
    grossCtrl.dispose();
    otherCtrl.dispose();
    purityCtrl.dispose();
    wasteCtrl.dispose();
    rateCtrl.dispose();
  }
}

/// =====================================================================
/// TABLE WIDGET
/// =====================================================================
class PurchaseItemTable extends StatefulWidget {
  /// Parent screen aa list own kare chhe (save vakhte vaparva mate)
  final List<PurchaseItemRow> rows;
  final VoidCallback? onChanged;
  final EdgeInsetsGeometry margin;

  const PurchaseItemTable({
    super.key,
    required this.rows,
    this.onChanged,
    this.margin = const EdgeInsets.fromLTRB(10, 10, 10, 0),
  });

  @override
  State<PurchaseItemTable> createState() => _PurchaseItemTableState();
}

class _PurchaseItemTableState extends State<PurchaseItemTable> {
  // Column widths
  static const double wLabel = 230;
  static const double wNum = 90;
  static const double wSmall = 75;
  static const double wApply = 60;
  static const double wAmt = 115;
  static const double wAction = 46;

  @override
  void initState() {
    super.initState();
    if (widget.rows.isEmpty) widget.rows.add(PurchaseItemRow());
  }

  void _refresh() {
    setState(() {});
    widget.onChanged?.call();
  }

  // -------------------------------------------------------------------
  // API SEARCH (tamaro existing suggest API)
  // -------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _searchItems(String q) async {
    if (q.trim().isEmpty) return [];
    try {
      final res = await ApiHelper().getRequest(
        "${ApiConstants.Barcode_report}/suggest?q=${Uri.encodeQueryComponent(q.trim())}",
      );
      if (res != null && res.statusCode == 200) {
        final list = res.data["data"] ?? [];
        return List<Map<String, dynamic>>.from(
          (list as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (e) {
      debugPrint("Item search error => $e");
    }
    return [];
  }

  /// API ma field nu naam alag hoy to aa keys ma umero
  String _v(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty && v.toString() != "null") {
        return v.toString();
      }
    }
    return "";
  }

  String _itemTitle(Map m) =>
      _v(m, ["label", "barcode", "label_no", "code"]).isNotEmpty
          ? _v(m, ["label", "barcode", "label_no", "code"])
          : _v(m, ["item_name", "name"]);

  String _itemSub(Map m) => _v(m, ["item_name", "name", "product_name"]);

  void _onItemSelected(int index, Map<String, dynamic> item) {
    final row = widget.rows[index];
    row.item = item;
    row.labelCtrl.text = _itemTitle(item);
    row.grossCtrl.text = _v(item, ["gross_weight", "gross_wt", "gross"]);
    row.otherCtrl.text = _v(item, ["other_weight", "less_weight", "other_wt"]);
    row.purityCtrl.text = _v(item, ["purity", "touch", "tunch"]);
    row.wasteCtrl.text = _v(item, ["wastage", "waste", "waste_percent"]);
    row.rateCtrl.text = _v(item, ["metal_rate", "rate"]);

    // 🔥 Sale jevu: chhelli row ma item select thay etle navi row add
    if (index == widget.rows.length - 1) {
      widget.rows.add(PurchaseItemRow());
    }
    _refresh();

    // Navi row na label par focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.rows.last.labelFocus.requestFocus();
    });
  }

  void _removeRow(int index) {
    if (widget.rows.length == 1) {
      widget.rows[0].dispose();
      widget.rows[0] = PurchaseItemRow();
    } else {
      widget.rows.removeAt(index).dispose();
    }
    _refresh();
  }

  // -------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final filled = rows.where((r) => !r.isEmpty);

    double tGross = 0, tOther = 0, tNet = 0, tFine = 0, tAmt = 0;
    for (final r in filled) {
      tGross += r.gross;
      tOther += r.other;
      tNet += r.net;
      tFine += r.fine;
      tAmt += r.metalAmount;
    }

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(),
            ...List.generate(rows.length, (i) => _dataRow(i)),
            _totalsRow(tGross, tOther, tNet, tFine, tAmt),
          ],
        ),
      ),
    );
  }

  Widget _headerRow() {
    Widget h(String t, double w, {TextAlign align = TextAlign.left}) => _cell(
      w,
      Text(t,
          textAlign: align,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
    return Container(
      color: AppColors.primaryDark,
      height: 42,
      child: Row(children: [
        h("Label", wLabel),
        h("Gross Wt", wNum),
        h("Other Wt", wNum),
        h("Net Wt", wNum),
        h("Purity", wSmall),
        h("Waste %", wSmall),
        h("Net Purity", wNum),
        h("Fine Wt", wNum),
        h("Metal Rate", wNum),
        h("Apply", wApply),
        h("Metal Amt", wAmt),
        h("", wAction),
      ]),
    );
  }

  Widget _dataRow(int i) {
    final r = widget.rows[i];
    return Container(
      decoration: BoxDecoration(
        color: i.isEven ? Colors.white : const Color(0xffFAFAFA),
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.6))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _cell(wLabel, _labelSearch(i)),
        _cell(wNum, _numInput(r.grossCtrl)),
        _cell(wNum, _numInput(r.otherCtrl)),
        _cell(wNum, _readOnly(r.net.toStringAsFixed(3))),
        _cell(wSmall, _numInput(r.purityCtrl)),
        _cell(wSmall, _numInput(r.wasteCtrl)),
        _cell(wNum, _readOnly(r.netPurity.toStringAsFixed(2))),
        _cell(wNum, _readOnly(r.fine.toStringAsFixed(3), bold: true)),
        _cell(wNum, _numInput(r.rateCtrl)),
        _cell(
          wApply,
          Checkbox(
            value: r.apply,
            activeColor: AppColors.primaryDark,
            onChanged: (v) {
              r.apply = v ?? false;
              _refresh();
            },
          ),
        ),
        _cell(wAmt, _readOnly(r.metalAmount.toStringAsFixed(2), bold: true)),
        _cell(
          wAction,
          r.isEmpty && widget.rows.length > 1 && i == widget.rows.length - 1
              ? const SizedBox()
              : IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            onPressed: () => _removeRow(i),
          ),
        ),
      ]),
    );
  }

  Widget _totalsRow(double g, double o, double n, double f, double a) {
    Widget t(String v, double w) => _cell(
      w,
      Text(v,
          style: const TextStyle(
              color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
    );
    return Container(
      height: 44,
      color: AppColors.primaryDark.withOpacity(0.10),
      child: Row(children: [
        _cell(
          wLabel,
          const Align(
            alignment: Alignment.centerRight,
            child: Text("Totals",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
        t(g.toStringAsFixed(3), wNum),
        t(o.toStringAsFixed(3), wNum),
        t(n.toStringAsFixed(3), wNum),
        _cell(wSmall, const SizedBox()),
        _cell(wSmall, const SizedBox()),
        _cell(wNum, const SizedBox()),
        t(f.toStringAsFixed(3), wNum),
        _cell(wNum, const SizedBox()),
        _cell(wApply, const SizedBox()),
        t(a.toStringAsFixed(2), wAmt),
        _cell(wAction, const SizedBox()),
      ]),
    );
  }

  // -------------------------------------------------------------------
  // LABEL / ITEM SEARCHABLE DROPDOWN
  // -------------------------------------------------------------------
  Widget _labelSearch(int i) {
    final r = widget.rows[i];

    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: r.labelCtrl,
      focusNode: r.labelFocus,
      displayStringForOption: (m) => _itemTitle(m),
      optionsBuilder: (value) async {
        if (value.text.trim().isEmpty) return const [];
        return _searchItems(value.text);
      },
      onSelected: (m) => _onItemSelected(i, m),
      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
        return TextField(
          controller: ctrl,
          focusNode: focus,
          style: const TextStyle(fontSize: 12, color: Colors.black),
          decoration: _dec("Search Label / Item").copyWith(
            prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.primaryDark),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            suffixIcon: r.item != null
                ? InkWell(
              onTap: () {
                r.item = null;
                ctrl.clear();
                _refresh();
              },
              child: const Icon(Icons.close, size: 15, color: Colors.black45),
            )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 260),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final m = options.elementAt(idx);
                  final sub = _itemSub(m);
                  return ListTile(
                    dense: true,
                    title: Text(_itemTitle(m),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: sub.isEmpty || sub == _itemTitle(m)
                        ? null
                        : Text(sub, style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      _v(m, ["gross_weight", "gross_wt", "gross"]),
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    onTap: () => onSelected(m),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // SMALL HELPERS
  // -------------------------------------------------------------------
  Widget _cell(double w, Widget child) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );

  Widget _numInput(TextEditingController c) => SizedBox(
    height: 36,
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      style: const TextStyle(fontSize: 12, color: Colors.black),
      onChanged: (_) => _refresh(),
      decoration: _dec("0"),
    ),
  );

  Widget _readOnly(String v, {bool bold = false}) => Container(
    height: 36,
    width: double.infinity,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.primaryDark.withOpacity(0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(v,
        style: TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 11, color: Colors.black38),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.2),
    ),
  );
}
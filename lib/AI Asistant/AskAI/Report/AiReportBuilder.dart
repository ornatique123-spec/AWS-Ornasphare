import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Api_Constant/ApiConstants.dart';
import '../../../Api_Constant/api_helper.dart';
import '../../../Extra/PremiumSearchableDropdown.dart';
import '../stock_ai_repository.dart';
import '../stock_ai_models.dart';
// 🏢 Branch (same as Approval Outstanding report screen)
import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart' show BranchApi, Company;
import '../../../Reports/BranchAccess.dart';

/// 🌐 site root from the ONE base url (ApiConstants.baseUrl = https://…/api/ → https://…/)
///    used for photo / logo paths like "storage/…"
String get _site => ApiConstants.baseUrl.replaceFirst(RegExp(r'api/?$'), '');

/// =======================================================================
///  📑 AI REPORT BUILDER — fill one form, get the PDF
///
///   Customer : Lado Creation            (search, or All customers)
///   Range    : September 2026           (month / this month / FY / custom)
///   Action   : ☑ Approval issue  ☑ Approval return  ☑ Sold from approval
///
///  PDF → APPROVAL ISSUE · APPROVAL RETURN · SOLD FROM APPROVAL · BOTH TOTAL
///   • Section summary: vouchers, items, qty, gross, less, net,
///     avg labour rate, labour amt, metal amt, other amt, amount
///   • Item rows: voucher/date · item · qty · gross · less · net ·
///     labour rate · metal rate · amount · other amt · status
///     (Pending / Returned / Sold / Partial)
///
///  APIs (same as the Approval screens):
///   approvals            → list   (id, approval_no, customer_name, approval_date)
///   approvals/{id}       → details (items[])
///   returns/list         → list   (id, return_voucher_no, customer_name, return_date)
///   returns/{id}         → details (items[])
///
///  Use:  AiReportBuilder.open(context);
///  File: Ask AI/Report/AiReportBuilder.dart
/// =======================================================================
class AiReportBuilder {
  AiReportBuilder._();

  /// [query] = the typed / spoken sentence → customer + month are pre-filled
  static Future<void> open(BuildContext context, {String? customer, String? query}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (_) => _ReportSheet(initialCustomer: customer, query: query),
    );
  }
}

// =======================================================================
//  DATA
// =======================================================================
class _Line {
  String voucher = '';
  String date = '';
  String item = '';
  String barcode = '';
  double qty = 1;
  double gross = 0, less = 0, net = 0;
  double labourRate = 0, labourAmt = 0;
  double metalRate = 0, metalAmt = 0;
  double other = 0, amount = 0;
  String status = '';

  /// same piece in approval and in return (barcode, else name + net weight)
  String get key => barcode.trim().isNotEmpty
      ? 'B:${barcode.trim().toUpperCase()}'
      : 'N:${item.trim().toLowerCase()}|${net.toStringAsFixed(3)}';
}

class _Section {
  final String title;
  final List<_Line> lines = [];
  int vouchers = 0;
  _Section(this.title);

  double sum(double Function(_Line) f) => lines.fold(0, (a, l) => a + f(l));
  double get avgLabour {
    final w = lines.where((l) => l.labourRate > 0).toList();
    return w.isEmpty ? 0 : w.fold<double>(0, (a, l) => a + l.labourRate) / w.length;
  }
}

class _Data {
  /// Pick the first non-empty value among [keys] (also inside nested maps)
  static dynamic pick(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is Map || v is List) continue; // nested object → searched below (never print "{id: …}")
      if (v != null && v.toString().trim().isNotEmpty && v.toString() != 'null') return v;
    }
    // 🏢 branch details: lines[] → { source: { gross_weight…, item_set: { item: {…} } } }
    for (final n in const ['source', 'item', 'item_set', 'approval_item', 'sale_item', 'itemset', 'label', 'product']) {
      final sub = m[n];
      if (sub is Map) {
        final v = pick(sub, keys);
        if (v != null) return v;
      }
    }
    return null;
  }

  static double number(Map m, List<String> keys) {
    final v = pick(m, keys);
    if (v == null) return 0;
    return double.tryParse(v.toString().replaceAll(',', '').replaceAll('₹', '').trim()) ?? 0;
  }

  static String text(Map m, List<String> keys) => (pick(m, keys) ?? '').toString().trim();

  static String customerOf(Map m) {
    final c = m['customer'];
    if (c is Map && (c['name'] ?? '').toString().trim().isNotEmpty) return c['name'].toString().trim();
    if (c is String && c.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(c.trim())) return c.trim();
    return text(m, const ['customer_name', 'party_name', 'account_name']);
  }

  static DateTime? date(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    if (iso != null) return iso;
    final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
    if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return null;
  }

  static String status(dynamic raw, {required bool isReturn}) {
    if (isReturn) return 'Returned';
    final s = (raw ?? '').toString().toLowerCase();
    if (s.contains('partial')) return 'Partial';
    if (s.contains('return')) return 'Returned';
    if (s.contains('sold') || s.contains('sale')) return 'Sold';
    if (s.contains('complete')) return 'Completed';
    return 'Pending';
  }

  static List<Map> listOf(dynamic body) {
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    if (body is List) return body.whereType<Map>().toList();
    if (body is Map) {
      final d = body['data'];
      if (d is List) return d.whereType<Map>().toList();
      if (d is Map && d['data'] is List) return (d['data'] as List).whereType<Map>().toList();
    }
    return const [];
  }

  static Map? detailOf(dynamic body) {
    if (body is List<int>) body = utf8.decode(body);
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    if (body is! Map) return null;
    final d = body['data'];
    if (d is List && d.isNotEmpty && d.first is Map) return d.first as Map;
    if (d is Map) return d;
    return body;
  }

  static List<Map> itemsOf(Map d) {
    for (final k in const ['items', 'lines', 'sale_items', 'sales_items', 'details', 'item_details', 'voucher_items', 'bill_items',
      'line_items', 'return_items', 'approval_items', 'products', 'rows']) {
      final v = d[k];
      if (v is List) return v.whereType<Map>().toList();
    }
    return const [];
  }

  static _Line line(Map it, {required String voucher, required String date, required bool isReturn}) {
    final l = _Line()
      ..voucher = voucher
      ..date = date
      ..item = text(it, const ['item_name', 'name', 'product_name', 'item'])
      ..barcode = text(it, const ['qr_code', 'label_code', 'barcode', 'label', 'tag_no'])
      ..qty = number(it, const ['qty', 'qty_pcs', 'pcs', 'quantity', 'nos', 'total_qty', 'pending_pcs'])
      ..gross = number(it, const ['gross_weight', 'gross_wt', 'gross', 'gr_wt', 'total_gross_weight'])
      ..less = number(it, const ['less_weight', 'less_wt', 'less', 'stone_weight', 'stone_wt', 'other_weight', 'total_other_weight'])
      ..net = number(it, const ['net_weight', 'net_wt', 'net', 'total_net_weight'])
      ..labourRate = number(it, const ['labour_rate', 'sale_labour_rate', 'labor_rate', 'making_rate', 'lab_rate'])
      ..labourAmt = number(it, const ['labour_amount', 'sale_labour_amount', 'labor_amount', 'making_amount', 'total_labour_amount'])
      ..metalRate = number(it, const ['metal_rate', 'gold_rate', 'rate', 'sale_rate'])
      ..metalAmt = number(it, const ['metal_amount', 'metal', 'gold_amount', 'total_metal_amount'])
      ..other = number(it, const ['other_amount', 'sale_other', 'other', 'other_charges', 'total_other_amount'])
      ..amount = number(it, const ['amount', 'net_total', 'total_amount', 'item_total', 'total', 'return_total', 'amount_all'])
      ..status = status(pick(it, const ['status', 'item_status', 'return_status']), isReturn: isReturn);
    if (l.item.isEmpty) l.item = l.barcode.isEmpty ? '-' : l.barcode;
    if (l.qty <= 0) l.qty = 1;
    if (l.less == 0 && l.gross > 0 && l.net > 0 && l.gross > l.net) l.less = l.gross - l.net;
    if (l.net == 0 && l.gross > 0) l.net = l.gross - l.less;
    if (l.amount == 0) l.amount = l.metalAmt + l.labourAmt + l.other;
    return l;
  }
}

// =======================================================================
//  SHEET (the form)
// =======================================================================
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({this.initialCustomer, this.query});
  final String? initialCustomer;
  final String? query;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

/// Report type
/// stock = 🖼️ Stock Gallery (pieces) · position = 📦 Stock (stock-position, branch wise)
enum _Kind { party, approval, sale, loss, job, position, stock, label, history }

class _ReportSheetState extends State<_ReportSheet> {
  // ✨ light-blue premium palette
  static const Color _blue = Color(0xff2563EB);
  static const Color _blueDeep = Color(0xff1D4ED8);
  static const Color _ink = Color(0xff1B2433);
  static const Color _soft = Color(0xff6B7487);
  static const Color _line = Color(0xffDCE7F7);
  static const Color _bgSoft = Color(0xffF4F8FF);
  static final DateFormat _dmy = DateFormat('dd-MM-yyyy');
  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');

  _Kind _kind = _Kind.approval;

  // lists (loaded once)
  List<Map> _approvals = [];
  List<Map> _returns = [];
  List<String> _customers = []; // approval customers
  List<String> _saleCustomers = [];
  bool _saleLoaded = false;
  final Map<String, int?> _workers = {}; // worker name → id
  bool _workersLoaded = false;
  bool _loading = true;
  bool _listBusy = false;
  String? _loadError;

  // form
  final TextEditingController _custCtrl = TextEditingController();
  int _fieldKey = 0; // rebuild the autocomplete when the type changes
  String? _customer; // null = all (customer or worker)
  String _rangeKey = 'last_month';
  DateTimeRange? _range;
  bool _doApproval = true;
  bool _doReturn = true;
  bool _doSold = true;
  bool _doSale = true; // party wise: sales bills
  String _ledgerFormat = 'daily'; // worker loss: daily | detailed
  String _stockStatus = 'in'; // stock: in | out | all
  String _photo = 'without'; // In stock only: with (only pieces with photo + photos in PDF) | without (all in-stock pieces, no photos) · Out / All: 'any'
  List<String> _stockItems = [];
  // 🏢 BRANCH — main company admin only (same API as Approval Outstanding screen)
  List<Company> _branches = []; // main + branches
  final Set<int> _branchIds = {}; // empty = only this company (normal report)
  bool _canBranch = false;
  bool _branchLoading = false;
  int? _mainId;

  /// only the main company (default) → normal full report · any other branch → branch merge
  bool get _branchMode => _branchIds.isNotEmpty && !(_branchIds.length == 1 && _branchIds.first == _mainId);
  List<Company> get _selBranches => _branches.where((c) => _branchIds.contains(c.id)).toList();

  /// reports that have a backend branch report (company/branch-reports/<name>)
  bool get _branchSupported => true; // every report: branch merge (report_branches) or normal
  bool _doJobIssue = true; // job work: issue vouchers
  bool _doJobReceive = true; // job work: receive vouchers (both → loss / profit)
  List<Map> _jobIssues = [];
  List<Map> _jobRecvs = [];
  List<String> _jobWorkers = [];
  bool _jobLoaded = false;
  final Map<String, int> _histVouchers = {}; // "VV-001 | 12-10-2026 · Ramesh" → voucher id
  bool _histLoaded = false;
  static const String _histUrl = '${ApiConstants.baseUrl}voucher-history';
  String _labelStatus = 'all'; // item labels: all | printed | pending
  List<Map> _labelRows = []; // itemsets/qr-list (all dates, loaded once)
  List<String> _labelItems = [];
  bool _labelLoaded = false;
  bool _stockLoaded = false;

  // 📦 STOCK POSITION (reports/stock-position · branch wise)
  static const String _posUrl = '${ApiConstants.baseUrl}reports/stock-position';
  List<_PosRow> _posRows = [];
  List<String> _posItems = [];
  bool _posLoaded = false;
  String _posSource = '';
  String? _posType; // null = all stock types · else stock_type key (finished_item, raw_material…)

  // result
  bool _busy = false;
  String _progress = '';
  File? _pdf;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _setRange('last_month');
    if (widget.initialCustomer != null) {
      _customer = widget.initialCustomer;
      _custCtrl.text = widget.initialCustomer!;
    }
    _loadLists();
    _loadBranches();
  }

  // ---------------------------------------------------------------------
  //  🏢 BRANCHES
  // ---------------------------------------------------------------------
  Future<void> _loadBranches() async {
    setState(() => _branchLoading = true);
    try {
      final isAdmin = await BranchAccess.isMainCompanyAdmin();
      if (!isAdmin) return;
      final o = await BranchApi.fetchOverview();
      final list = <Company>[if (o.mainCompany != null) o.mainCompany!, ...o.branches];
      if (!mounted) return;
      setState(() {
        _branches = list;
        _canBranch = list.length > 1;
        // ✅ default: main company selected (same as Branch Reports screen)
        _mainId = o.mainCompany?.id;
        _branchIds
          ..clear()
          ..addAll([if (_mainId != null) _mainId!]);
      });
    } catch (e) {
      debugPrint('🏢 Branch list load failed: $e'); // branch user / staff → no branch card
    } finally {
      if (mounted) setState(() => _branchLoading = false);
    }
  }

  String _companyLabel(Company c) => c.isMain ? '${c.name} (Main)' : c.name;

  /// which branch a row belongs to (company_id → branch name)
  String _branchOf(Map r) {
    final id = int.tryParse('${r['company_id'] ?? ''}');
    if (id != null) {
      for (final c in _branches) {
        if (c.id == id) return c.name;
      }
    }
    final b = r['branch'] ?? r['branch_name'] ?? r['company'];
    if (b is Map && b['name'] != null) return b['name'].toString();
    final t = (b ?? r['company_name'] ?? '').toString().trim();
    return t.isEmpty || t == 'null' ? 'Main' : t;
  }

  /// "a,b" slugs of the selected branches (comma kept as comma)
  String get _slugs => _selBranches.map((c) => Uri.encodeQueryComponent(c.slug ?? c.id.toString())).join(',');

  /// 🏢 branch merge → add &report_branches=a,b to a normal API url (same as branch Excel / details)
  String _br(String url) => _branchMode ? '$url${url.contains('?') ? '&' : '?'}report_branches=$_slugs' : url;

  /// branch name of a row — '' when the row has no branch info (no company_id / branch)
  String _branchTag(Map r) {
    if (!_branchMode) return '';
    final hasInfo = r['company_id'] != null || r['branch'] != null || r['branch_name'] != null || r['company'] != null;
    return hasInfo ? _branchOf(r) : '';
  }

  /// "Main 10 · Dishank 5" — for the summary under the PDF
  void _noteBranches(String what, Iterable<Map> rows) {
    if (!_branchMode) return;
    final c = <String, int>{};
    var noInfo = 0;
    for (final r in rows) {
      final t = _branchTag(r);
      if (t.isEmpty) {
        noInfo++;
      } else {
        c[t] = (c[t] ?? 0) + 1;
      }
    }
    _branchDebug += '$what: ${rows.length} rows${c.isEmpty ? '' : ' · ${c.entries.map((e) => '${e.key} ${e.value}').join(' · ')}'}\n';
    if (rows.isNotEmpty && c.isEmpty) {
      _branchDebug += '⚠️ $what API sent no branch info (company_id) — backend may not merge branches for this report yet.\n';
    }
    if (noInfo > 0 && c.isNotEmpty) _branchDebug += '$what: $noInfo rows without branch\n';
  }

  /// branch changed → lists (workers / items / vouchers) must reload for those branches
  void _branchChanged() {
    _jobLoaded = false;
    _labelLoaded = false;
    _histLoaded = false;
    _workersLoaded = false;
    _stockLoaded = false;
    _posLoaded = false;
    _posType = null;
    _workers.clear();
    _customer = null;
    _custCtrl.clear();
    _fieldKey++;
    if (_kind == _Kind.loss) _loadWorkers();
    if (_kind == _Kind.stock) _loadStockItems();
    if (_kind == _Kind.position) _loadPosition();
    if (_kind == _Kind.label) _loadLabels();
    if (_kind == _Kind.job) _loadJob();
    if (_kind == _Kind.history) _loadHistVouchers();
  }

  /// 📦 stock gallery of the selected branches (all pages, no popup)
  Future<List<({StockItem s, String tag})>> _branchStock() async {
    final out = <({StockItem s, String tag})>[];
    final raw = <Map>[];
    var last = 1;
    for (var p = 1; p <= last && p <= 200; p++) {
      if (mounted) setState(() => _progress = 'Loading branch stock… page $p${last > 1 ? ' / $last' : ''}');
      final res = await ApiHelper().getRequest(_br('${ApiConstants.stock_gallery}?page=$p&per_page=200'),
          showLoading: false, receiveTimeout: const Duration(seconds: 60));
      final body = res?.data;
      if (body is! Map) break;
      final rows = (body['data'] is List ? body['data'] as List : const []).whereType<Map>().toList();
      raw.addAll(rows);
      for (final r in rows) {
        try {
          out.add((s: StockItem.fromJson(Map<String, dynamic>.from(r)), tag: _branchTag(r)));
        } catch (_) {}
      }
      final pg = body['pagination'] is Map ? body['pagination'] as Map : (body['meta'] is Map ? body['meta'] as Map : null);
      last = int.tryParse('${pg?['last_page'] ?? ''}') ?? 1;
      if (rows.isEmpty) break;
    }
    _noteBranches('Stock', raw);
    return out;
  }

  /// company/branch-reports/<name>?report_branches=a,b&per_page=100 — all pages
  Future<List<Map>> _branchRows(String reportPath, Map<String, String> params) async {
    final path = reportPath.split('?').first;
    final i = path.indexOf('reports/');
    final name = i >= 0 ? path.substring(i + 'reports/'.length) : path;
    // comma must stay a comma (not %2C) → build by hand
    final slugs = _selBranches.map((c) => Uri.encodeQueryComponent(c.slug ?? c.id.toString())).join(',');
    final extra = params.entries.map((e) => '&${e.key}=${Uri.encodeQueryComponent(e.value)}').join();
    const per = 50;
    final out = <Map>[];
    for (var page = 1; page <= 60; page++) {
      var url = '${ApiConstants.baseUrl}company/branch-reports/$name?report_branches=$slugs&per_page=$per$extra';
      if (page > 1) url += '&page=$page&start=${(page - 1) * per}';
      if (mounted) setState(() => _progress = 'Loading branch data… page $page');
      final res = await ApiHelper().getRequest(url, showLoading: false, receiveTimeout: const Duration(seconds: 60));
      final body = res?.data;
      if (body is! Map) break;
      if (body['success'] == false) throw Exception(body['message'] ?? 'Branch report failed');
      var rows = _Data.listOf(body);
      if (rows.isEmpty) {
        final d0 = body['data'];
        final alt = d0 is Map ? (d0['rows'] ?? d0['items']) : body['rows'];
        if (alt is List) rows = alt.whereType<Map>().toList();
      }
      out.addAll(rows);
      // more pages?
      final total = int.tryParse('${body['recordsFiltered'] ?? body['recordsTotal'] ?? ''}');
      Map? meta = body['meta'] is Map ? body['meta'] : (body['pagination'] is Map ? body['pagination'] : null);
      final d = body['data'];
      if (meta == null && d is Map && d['current_page'] != null) meta = d;
      final cur = int.tryParse('${meta?['current_page'] ?? ''}') ?? 0;
      final last = int.tryParse('${meta?['last_page'] ?? ''}') ?? 0;
      final more = total != null
          ? out.length < total && rows.isNotEmpty
          : (last > 0 ? cur < last : rows.length >= per);
      if (!more) break;
    }
    // same voucher twice (page overlap) → once
    final seen = <String>{};
    return out
        .where((r) => seen.add('${r['company_id']}|${r['id']}|${r['voucher_no'] ?? r['approval_no']}|'
        '${r['buch_no']}|${r['stage']}|${r['worker_id']}|${r['process_datetime']}'))
        .toList();
  }

  /// rows → one section per branch (Main first)
  Future<List<_Section>> _branchSections(
      String title,
      List<Map> rows, {
        required List<String> Function(Map v, String id) urls,
        required List<String> voucherKeys,
        required List<String> dateKeys,
        String Function(Map v)? partyOf,
      }) async {
    final by = <String, List<Map>>{};
    for (final r in rows) {
      by.putIfAbsent(_branchOf(r), () => []).add(r);
    }
    final order = [
      for (final c in _selBranches)
        if (by.containsKey(c.name)) c.name,
      ...by.keys.where((k) => !_selBranches.any((c) => c.name == k)),
    ];
    final out = <_Section>[];
    for (final b in order) {
      out.add(await _collect('$title · $b', by[b]!,
          isReturn: false,
          url: (id) => urls(const {}, id).first,
          urlsOf: urls,
          rowFallback: true,
          voucherKeys: voucherKeys,
          dateKeys: dateKeys,
          partyOf: partyOf));
    }
    if (out.isEmpty) out.add(_Section('$title · ${_selBranches.map((c) => c.name).join(', ')}'));
    return out;
  }

  String _slugOf(Map r) {
    final id = int.tryParse('${r['company_id'] ?? ''}');
    for (final c in _branches) {
      if (c.id == id) return c.slug ?? c.id.toString();
    }
    return 'all';
  }

  /// 🏢 last run numbers (shown under the PDF so we can see where data stops)
  String _branchDebug = '';

  /// rows from branch report: with date range first, if 0 → without dates (filter here)
  Future<List<Map>> _branchRowsDated(String reportPath, Map<String, String> params) async {
    // ✅ same URL as the working Branch Reports screen:
    //    company/branch-reports/<name>?report_branches=a,b&per_page=..  (no columns / dates)
    final rows = await _branchRows(reportPath, const {});
    debugPrint('🏢 BRANCH ROWS $reportPath → ${rows.length}');
    if (rows.isNotEmpty) debugPrint('🏢 FIRST ROW → ${rows.first}');
    return rows;
  }

  bool _inRangeOrNoDate(Map m, List<String> keys) {
    final d = _Data.date(_Data.pick(m, keys));
    return d == null || _inRange(d);
  }

  /// 🧾 sales of the selected branches (customer + date filtered here)
  Future<List<_Section>> _branchSaleSections() async {
    const cols = 'voucher_no,date,customer,qty_pcs,gross_weight,other_weight,net_weight,fine_weight,'
        'metal_amount,labour_amount,other_amount,net_total';
    const itemCols = 'label,huid,item_name,qty_pcs,gross_weight,other_weight,net_weight,purity,waste_percent,fine_weight,'
        'metal_rate,metal_amount,labour_rate,labour_amount,other_amount,net_total';
    final rows = await _branchRowsDated(ApiConstants.Sale_Summary_report, {'columns': cols});
    final byCust = rows.where(_isCustomer).toList();
    final bills = byCust.where((m) => _inRangeOrNoDate(m, const ['date', 'sale_date', 'created_at'])).toList();
    _branchDebug += 'Sales: API ${rows.length} · customer ${byCust.length} · in range ${bills.length}\n';
    return _branchSections('Sales', bills,
        urls: (v, id) => [
          '${ApiConstants.Sale_Summary_report}/$id/details?columns=$itemCols&report_branches=all',
          '${ApiConstants.Sale_Summary_report}/$id/details?columns=$itemCols&report_branches=${_slugOf(v)}',
          '${ApiConstants.baseUrl}company/branch-report-details/sale/$id?report_branches=${_slugOf(v)}',
          '${ApiConstants.baseUrl}company/branch-report-details/sales/$id?report_branches=${_slugOf(v)}',
          '${ApiConstants.baseUrl}company/branch-report-details/sales-summary/$id?report_branches=${_slugOf(v)}',
          '${ApiConstants.Sale_Summary_report}/$id/details?report_branches=all',
        ],
        voucherKeys: const ['voucher_no', 'bill_no', 'invoice_no'],
        dateKeys: const ['date', 'sale_date', 'created_at'],
        partyOf: _Data.customerOf);
  }

  /// 📋 approval OUTSTANDING (pending) of the selected branches
  Future<List<_Section>> _branchApprovalSections() async {
    const cols = 'approval_no,date,customer,status,pending_pcs,gross_weight,other_weight,net_weight,purity,'
        'waste_percent,fine_weight,metal_rate,metal_amount,labour_rate,labour_amount,other_amount,pending_amount,net_total';
    final rows = await _branchRowsDated(ApiConstants.Approval_Outstanding_report, {'columns': cols});
    final byCust = rows.where(_isCustomer).toList();
    final list = byCust.where((m) => _inRangeOrNoDate(m, const ['date', 'approval_date', 'created_at'])).toList();
    _branchDebug += 'Approval: API ${rows.length} · customer ${byCust.length} · in range ${list.length}\n';
    return _branchSections('Approval Outstanding', list,
        urls: (v, id) => [
          '${ApiConstants.baseUrl}reports/approval-outstanding/$id/details'
              '?columns=${Uri.encodeQueryComponent(cols)}&report_branches=all',
          '${ApiConstants.baseUrl}company/branch-report-details/approval/$id?report_branches=${_slugOf(v)}',
        ],
        voucherKeys: const ['approval_no', 'voucher_no'],
        dateKeys: const ['date', 'approval_date', 'created_at'],
        partyOf: _Data.customerOf);
  }

  Future<void> _pickBranches() async {
    final temp = {..._branchIds};
    final res = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final all = temp.length == _branches.length;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(children: [
                  const Icon(Icons.account_tree_rounded, size: 18, color: _blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Select branches', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
                  ),
                  TextButton(
                    onPressed: () => set(() => all ? temp.clear() : temp.addAll(_branches.map((c) => c.id))),
                    child: Text(all ? 'Clear all' : 'Select all',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _blue)),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _line),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in _branches)
                    CheckboxListTile(
                      dense: true,
                      value: temp.contains(c.id),
                      activeColor: _blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      title: Text(_companyLabel(c),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink)),
                      secondary: Icon(c.isMain ? Icons.verified_rounded : Icons.store_mall_directory_rounded,
                          size: 18, color: _blue),
                      onChanged: (v) => set(() => v == true ? temp.add(c.id) : temp.remove(c.id)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: Text(temp.isEmpty ? 'Use main company' : 'Use ${temp.length} branch${temp.length == 1 ? '' : 'es'}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
    if (res == null || !mounted) return;
    setState(() {
      _branchIds
        ..clear()
        ..addAll(res.isEmpty ? [if (_mainId != null) _mainId!] : res);
      _pdf = null;
      _summary = null;
    });
    _branchChanged();
  }

  /// 🏢 premium branch card (top of the sheet)
  Widget _branchCard() {
    if (_branchLoading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: _blue)),
          SizedBox(width: 8),
          Text('Loading branches…', style: TextStyle(fontSize: 11.5, color: _soft)),
        ]),
      );
    }
    if (!_canBranch) return const SizedBox.shrink();
    final sel = _selBranches;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _branchMode ? _blue : _line, width: _branchMode ? 1.3 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: _pickBranches,
          borderRadius: BorderRadius.circular(10),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xff60A5FA), _blueDeep]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_tree_rounded, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Branch', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink)),
                Text(
                  !_branchMode
                      ? 'Main company · tap to add branches'
                      : '${sel.length} of ${_branches.length} selected · branch merge',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: sel.isEmpty ? _soft : _blue, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            if (_branchMode)
              TextButton(
                onPressed: () => setState(() {
                  _branchIds
                    ..clear()
                    ..addAll([if (_mainId != null) _mainId!]);
                  _pdf = null;
                  _summary = null;
                  _branchChanged();
                }),
                child: const Text('Reset', style: TextStyle(fontSize: 12, color: Color(0xffD32F2F), fontWeight: FontWeight.w700)),
              ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _blue),
          ]),
        ),
        if (sel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in sel)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                child: Text(_companyLabel(c),
                    style: const TextStyle(fontSize: 11, color: _blueDeep, fontWeight: FontWeight.w700)),
              ),
          ]),
          if (!_branchMode) ...[
          ] else if (_kind == _Kind.approval || _kind == _Kind.party) ...[
            const SizedBox(height: 6),
            const Text(
              'ⓘ Branch approval = outstanding (pending) approvals of each branch.',
              style: TextStyle(fontSize: 10.5, color: _soft),
            ),
          ],
        ],
      ]),
    );
  }

  @override
  void dispose() {
    _custCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final r = await Future.wait([
        ApiHelper().getRequest(ApiConstants.Approval_list, showLoading: false),
        ApiHelper().getRequest(ApiConstants.return_list, showLoading: false),
      ]);
      _approvals = _Data.listOf(r[0]?.data);
      _returns = _Data.listOf(r[1]?.data);
      final names = <String>{
        ..._approvals.map(_Data.customerOf),
        ..._returns.map(_Data.customerOf),
      }..removeWhere((e) => e.isEmpty);
      _customers = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (widget.query != null) _prefill(widget.query!);
    } catch (e) {
      _loadError = 'Could not load approvals. Please try again.';
    }
    if (mounted) setState(() => _loading = false);
    if (_kind == _Kind.sale || _kind == _Kind.party) _loadSaleCustomers();
    if (_kind == _Kind.loss) _loadWorkers();
    if (_kind == _Kind.stock) _loadStockItems();
    if (_kind == _Kind.position) _loadPosition();
    if (_kind == _Kind.label) _loadLabels();
    if (_kind == _Kind.job) _loadJob();
    if (_kind == _Kind.history) _loadHistVouchers();
  }

  /// 🧾 Voucher list for voucher history (voucher-history → data.vouchers[])
  Future<void> _loadHistVouchers() async {
    if (_histLoaded) return;
    if (mounted) setState(() => _listBusy = true);
    try {
      final res =
      await ApiHelper().getRequest(_br(_histUrl), showLoading: false, receiveTimeout: const Duration(seconds: 60));
      final body = res?.data;
      final d = body is Map ? body['data'] : null;
      final list = (d is Map && d['vouchers'] is List) ? (d['vouchers'] as List).whereType<Map>() : const <Map>[];
      _histVouchers.clear();
      for (final v in list) {
        final id = int.tryParse('${v['id']}');
        if (id == null) continue;
        final no = _Job.s(v['voucher_no']);
        final dt = _Job.s(v['voucher_date_view'] ?? v['voucher_date']);
        final wk = _Job.s(v['worker_name']);
        var label = [no.isEmpty ? '#$id' : no, if (dt.isNotEmpty) dt].join(' | ');
        if (wk.isNotEmpty) label += ' · $wk';
        final tg = _branchTag(v);
        if (tg.isNotEmpty) label += ' [$tg]';
        while (_histVouchers.containsKey(label)) {
          label += ' ';
        }
        _histVouchers[label] = id;
      }
      _histLoaded = true;
      _noteBranches('Vouchers', list);
    } catch (e) {
      debugPrint('🧾 VOUCHER HISTORY LIST ERROR => $e');
    }
    if (mounted) setState(() => _listBusy = false);
  }

  /// 🛠️ Job work issue + receive lists (all dates, once) — no loader popup
  ///   🏢 branch merge: tries 3 ways, first one that gives rows wins
  ///     1) company/branch-reports/jobwork-issues?report_branches=a,b   (same as sales-summary)
  ///     2) jobwork-issues?report_branches=a,b
  ///     3) own company (so the report is never blank) + ⚠️ note under the PDF
  String _jobSource = '';

  Future<List<Map>> _jobFetch(String path, {Map<String, String> params = const {}}) async {
    final q = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final plain = q.isEmpty ? path : '$path?$q';
    Future<List<Map>> normal(String url) async {
      final res = await ApiHelper().getRequest(url, showLoading: false, receiveTimeout: const Duration(seconds: 90));
      debugPrint('🛠️ JOB $url → ${res?.statusCode}');
      return _Data.listOf(res?.data);
    }

    if (!_branchMode) return normal(plain);
    // 1) branch report endpoint
    try {
      final rows = await _branchRows(path, params);
      debugPrint('🛠️ JOB branch-reports/$path → ${rows.length}');
      if (rows.isNotEmpty) {
        _jobSource += '$path: branch report ✓ ';
        return rows;
      }
    } catch (e) {
      debugPrint('🛠️ JOB branch-reports/$path failed → $e');
    }
    // 2) normal api + report_branches
    try {
      final rows = await normal(_br(plain));
      if (rows.isNotEmpty && rows.any((r) => _branchTag(r).isNotEmpty)) {
        _jobSource += '$path: report_branches ✓ ';
        return rows;
      }
      if (rows.isNotEmpty) {
        _jobSource += '$path: ⚠️ only this company (backend did not merge branches) ';
        return rows;
      }
    } catch (e) {
      debugPrint('🛠️ JOB $path + report_branches failed → $e');
    }
    // 3) own company
    _jobSource += '$path: ⚠️ branch data not available — showing this company ';
    return normal(plain);
  }

  /// 🏢 branch merge → job work from the WORKER LOSS report (it has a branch version)
  ///   company/branch-reports/worker-loss?report_branches=a,b  → data[] entries:
  ///   stage · worker_name · voucher_no · source_wt (issued) · receive_wt · bhuko · loss · process_datetime · company_id
  ///   → one issue row + one receive row per entry (loss = issued − received)
  Future<bool> _jobFromWorkerLoss() async {
    try {
      final rows = await _branchRows(ApiConstants.worker_loss_report, const {});
      debugPrint('🛠️ JOB via worker-loss (branch) → ${rows.length} rows');
      if (rows.isEmpty) return false;
      String st(Map r) => (r['stage'] ?? '').toString().toLowerCase();
      var job = rows.where((r) => st(r).contains('job')).toList();
      final onlyJob = job.isNotEmpty;
      if (!onlyJob) job = rows; // stage names without "job" → use all entries
      double n(dynamic v) => double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
      final iss = <Map>[], rec = <Map>[];
      for (final r in job) {
        final src = n(r['source_wt'] ?? r['issue_wt'] ?? r['issue_net_wt']);
        final got = n(r['receive_wt'] ?? r['receive_net_wt']) + n(r['bhuko']);
        final worker = (r['worker_name'] ?? r['jobworker_name'] ?? '').toString();
        final date = r['process_datetime'] ?? r['process_datetime_fmt'] ?? r['date'] ?? r['created_at'];
        final vno = '${r['voucher_no'] ?? '-'}${(r['buch_no'] ?? '').toString().trim().isNotEmpty && r['buch_no'] != '-' ? ' · ${r['buch_no']}' : ''}';
        final step = (r['stage'] ?? '').toString();
        iss.add({
          'voucher_no': vno,
          'job_worker': {'name': worker},
          'production_step_name': step,
          'voucher_date': date,
          'gross_wt_sum': src,
          'net_wt_sum': src,
          'company_id': r['company_id'],
        });
        rec.add({
          'voucher_no': vno,
          'jobworker_name': worker,
          'production_step_name': step,
          'voucher_date': date,
          'issue_net_wt': src,
          'receive_net_wt': got,
          'pending_net_wt': got > 0.0005 ? 0 : src,
          'status': got > 0.0005 ? 'completed' : 'pending',
          'company_id': r['company_id'],
        });
      }
      _jobIssues = iss;
      _jobRecvs = rec;
      _jobSource = 'Job work from worker-loss branch report ✓${onlyJob ? '' : ' (all stages)'} · ${job.length} entries';
      return true;
    } catch (e) {
      debugPrint('🛠️ JOB via worker-loss failed → $e');
      return false;
    }
  }

  Future<void> _loadJob({bool force = false}) async {
    if (_jobLoaded && !force) return;
    if (mounted) setState(() => _listBusy = true);
    _jobSource = '';
    try {
      if (_branchMode && await _jobFromWorkerLoss()) {
        _jobWorkers = <String>{
          ..._jobIssues.map(_Job.workerOf),
        }.where((e) => e.isNotEmpty && e != '-').toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _jobLoaded = true;
        if (mounted) setState(() => _listBusy = false);
        return;
      }
      final r = await Future.wait([
        _jobFetch(ApiConstants.jobwork_issues),
        _jobFetch(ApiConstants.jobwork_receive,
            params: {'from': '2000-01-01', 'to': _ymd.format(DateTime.now())}),
      ]);
      _jobIssues = r[0];
      _jobRecvs = r[1];
      _jobWorkers = <String>{
        ..._jobIssues.map(_Job.workerOf),
        ..._jobRecvs.map(_Job.workerOf),
      }.where((e) => e.isNotEmpty && e != '-').toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _jobLoaded = true;
    } catch (e) {
      debugPrint('🛠️ JOB WORK LIST ERROR => $e');
    }
    if (mounted) setState(() => _listBusy = false);
  }

  /// 🏷️ Item labels (Label print list · itemsets/qr-list) — all dates, once
  Future<void> _loadLabels({bool force = false}) async {
    if (_labelLoaded && !force) return;
    if (mounted) setState(() => _listBusy = true);
    try {
      final res = await ApiHelper().getRequest(
        _br('${ApiConstants.label_print}?from_date=2000-01-01&to_date=${_ymd.format(DateTime.now())}'),
        showLoading: false, // 🔕 no loader popup
        receiveTimeout: const Duration(minutes: 3),
      );
      _labelRows = _Data.listOf(res?.data);
      _labelItems = _labelRows
          .map((m) => _Data.text(m, const ['item_name', 'name']))
          .where((e) => e.isNotEmpty && e != '-')
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _labelLoaded = true;
    } catch (e) {
      debugPrint('🏷️ LABEL LIST ERROR => $e');
    }
    if (mounted) setState(() => _listBusy = false);
  }

  /// Sale customers (last 12 months bills) — only when "Sale" is picked
  Future<void> _loadSaleCustomers() async {
    if (_saleLoaded) return;
    setState(() => _listBusy = true);
    try {
      final now = DateTime.now();
      final res = await ApiHelper().getRequest(
        '${ApiConstants.Sale_Summary_report}?columns=voucher_no,date,customer'
            '&from_date=${_ymd.format(DateTime(now.year - 1, now.month, now.day))}&to_date=${_ymd.format(now)}',
        showLoading: false,
        receiveTimeout: const Duration(seconds: 40),
      );
      final names = _Data.listOf(res?.data).map(_Data.customerOf).where((e) => e.isNotEmpty).toSet();
      _saleCustomers = {...names, ..._customers}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _saleLoaded = true;
    } catch (_) {
      _saleCustomers = List.of(_customers);
    }
    if (mounted) setState(() => _listBusy = false);
  }

  /// Workers (from the metal ledger) — only when "Worker loss" is picked
  Future<void> _loadWorkers() async {
    if (_workersLoaded) return;
    setState(() => _listBusy = true);
    try {
      final res = await ApiHelper().getRequest(
        _br('${ApiConstants.worker_loss_report}?mode=ledger&format=daily'
            '&from_date=2020-01-01&to_date=${_ymd.format(DateTime.now())}'),
        showLoading: false,
        receiveTimeout: const Duration(seconds: 60),
      );
      for (final g in _LedgerData.groups(res?.data, tag: _branchTag)) {
        _workers.putIfAbsent(g.worker, () => g.workerId);
      }
      _workersLoaded = true;
    } catch (_) {}
    if (mounted) setState(() => _listBusy = false);
  }

  /// Stock item names (from the Stock Gallery data) — only when "Stock" is picked
  Future<void> _loadStockItems() async {
    if (_stockLoaded) return;
    setState(() => _listBusy = true);
    try {
      final all = _branchMode ? (await _branchStock()).map((e) => e.s).toList() : await StockAiRepository.loadAll();
      _stockItems = all.map((s) => s.itemName).where((e) => e.isNotEmpty && e != '-').toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _stockLoaded = true;
    } catch (_) {}
    if (mounted) setState(() => _listBusy = false);
  }

  /// 📦 STOCK POSITION rows
  ///   normal → reports/stock-position
  ///   🏢 branch → ONE call per selected branch (so every row surely gets its branch):
  ///       1) company/branch-reports/stock-position?report_branches=<slug>
  ///       2) reports/stock-position?report_branches=<slug>
  ///   [dated] → from_date / to_date of the selected range are sent too
  Future<void> _loadPosition({bool force = false, bool dated = false}) async {
    if (_posLoaded && !force) return;
    if (mounted) setState(() => _listBusy = true);
    _posSource = '';
    try {
      Future<List<_PosRow>> get(String url) async {
        final res = await ApiHelper().getRequest(url, showLoading: false, receiveTimeout: const Duration(seconds: 90));
        debugPrint('📦 STOCK POSITION $url → ${res?.statusCode}');
        final body = res?.data;
        if (body is Map && body['success'] == false) throw Exception(body['message'] ?? 'Stock position failed');
        return _PosRow.listFrom(body, branchOf: _branchOf);
      }

      String url(String base, {String? slug}) {
        final p = <String>[
          if (slug != null) 'report_branches=${Uri.encodeQueryComponent(slug)}',
          if (dated && _rangeKey != 'all' && _range != null) ...[
            'from_date=${_ymd.format(_range!.start)}',
            'to_date=${_ymd.format(_range!.end)}',
          ],
        ];
        return p.isEmpty ? base : '$base?${p.join('&')}';
      }

      var rows = <_PosRow>[];
      if (_branchMode) {
        final branchUrl = '${ApiConstants.baseUrl}company/branch-reports/stock-position';

        Future<({Company c, List<_PosRow> rows, String how})> one(Company c) async {
          final slug = c.slug ?? c.id.toString();
          var rs = <_PosRow>[];
          var how = '';
          try {
            rs = await get(url(branchUrl, slug: slug));
            how = 'branch report';
          } catch (e) {
            debugPrint('📦 ${c.name}: branch-reports/stock-position failed → $e');
          }
          if (rs.isEmpty) {
            try {
              rs = await get(url(_posUrl, slug: slug));
              how = 'report_branches';
            } catch (e) {
              debugPrint('📦 ${c.name}: stock-position failed → $e');
            }
          }
          // backend sent several branches together → keep only this branch
          if (rs.any((r) => r.branch == c.name)) {
            rs = rs.where((r) => r.branch.isEmpty || r.branch == c.name).toList();
          }
          for (final r in rs) {
            r.branch = c.name;
          }
          return (c: c, rows: rs, how: how);
        }

        if (mounted) setState(() => _progress = 'Loading stock position · ${_selBranches.length} branches…');
        final res = await Future.wait(_selBranches.map(one));

        // same rows for 2 branches → backend ignored report_branches
        String fp(List<_PosRow> l) => l.map((r) => '${r.item}|${r.typeKey}|${r.customer}|${r.qty}|${r.net}').join(';');
        final seen = <String, String>{};
        final notes = <String>[];
        for (final r in res) {
          final f = fp(r.rows);
          final same = f.isNotEmpty ? seen[f] : null;
          notes.add('${r.c.name}: ${r.rows.length} rows${r.how.isEmpty ? '' : ' (${r.how})'}'
              '${same != null ? ' ⚠️ same data as $same — backend may not filter this branch' : ''}');
          if (f.isNotEmpty) seen.putIfAbsent(f, () => r.c.name);
          rows.addAll(r.rows);
        }
        _posSource = notes.join('\n');
      } else {
        rows = await get(url(_posUrl));
      }
      _posRows = rows;
      _posItems = rows.map((r) => r.item).where((e) => e.isNotEmpty && e != '-').toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _posLoaded = !dated; // dated load = only for this PDF → item list reloads normally
    } catch (e) {
      debugPrint('📦 STOCK POSITION ERROR => $e');
    }
    if (mounted) setState(() => _listBusy = false);
  }

  /// stock types found in the data → chips (Finished Item, Raw Material, …)
  List<({String key, String name})> get _posTypes {
    final seen = <String, String>{};
    for (final r in _posRows) {
      seen.putIfAbsent(r.typeKey, () => r.typeName);
    }
    return seen.entries.map((e) => (key: e.key, name: e.value)).toList();
  }

  List<String> get _options => switch (_kind) {
    _Kind.approval => _customers,
    _Kind.sale => _saleCustomers.isEmpty ? _customers : _saleCustomers,
    _Kind.loss => (_workers.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
    _Kind.stock => _stockItems,
    _Kind.position => _posItems,
    _Kind.party => _saleCustomers.isEmpty ? _customers : _saleCustomers,
    _Kind.label => _labelItems,
    _Kind.job => _jobWorkers,
    _Kind.history => _histVouchers.keys.toList(),
  };

  /// 🧾 party / voucher history → must pick one (no "All" item)
  bool get _pickOne => _kind == _Kind.party || _kind == _Kind.history;

  bool get _isWorkerKind => _kind == _Kind.loss || _kind == _Kind.job;

  String get _allLabel => _isWorkerKind
      ? 'All workers'
      : (_isItemKind ? 'All items' : 'All customers');

  /// item dropdown (not customer)
  bool get _isItemKind => _kind == _Kind.stock || _kind == _Kind.position || _kind == _Kind.label;

  void _pickKind(_Kind k) {
    if (_kind == k) return;
    setState(() {
      _kind = k;
      _customer = null;
      _custCtrl.clear();
      _fieldKey++;
      _pdf = null;
      _summary = null;
    });
    if (k == _Kind.sale || k == _Kind.party) _loadSaleCustomers();
    if (k == _Kind.loss) _loadWorkers();
    if (k == _Kind.job) _loadJob();
    if (k == _Kind.history) _loadHistVouchers();
    if (k == _Kind.position) {
      _loadPosition();
      _setRange('all'); // default all dates · month / range same as Stock Gallery
    } else if (k == _Kind.stock || k == _Kind.label) {
      if (k == _Kind.stock) _loadStockItems();
      if (k == _Kind.label) _loadLabels();
      _setRange('all');
    } else if (_rangeKey == 'all') {
      _setRange('last_month');
    }
  }

  /// "Lado creation september approval and return report" → fill the form
  void _prefill(String q) {
    final t = ' ${q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ')} ';
    // report type
    if (RegExp(r' (label|labels|lable|lables|tag|tags|qr) ').hasMatch(t)) {
      _kind = _Kind.label;
      _setRange('all');
      if (RegExp(r' (pending|baki|remaining|not printed|unprinted) ').hasMatch(t)) {
        _labelStatus = 'pending';
      } else if (RegExp(r' (printed|print thayel|nikdi) ').hasMatch(t)) {
        _labelStatus = 'printed';
      }
    } else if (RegExp(r' (stock position|position|stock summary|branch stock|stock report) ').hasMatch(t) ||
        (t.contains(' stock ') &&
            !RegExp(r' (gallery|photo|photos|image|images|in stock|out of stock|sold) ').hasMatch(t) &&
            !t.contains(' ledger '))) {
      _kind = _Kind.position;
      _setRange('all');
    } else if (RegExp(r' (stock|gallery|in stock|out of stock) ').hasMatch(t) && !t.contains(' ledger ')) {
      _kind = _Kind.stock;
      _setRange('all');
      if (t.contains(' out of stock ') || t.contains(' sold ')) _stockStatus = 'out';
      if (_stockStatus != 'in') {
        _photo = 'any';
      } else if (RegExp(r' (without|vagar|vina|no) (image|photo|photos|images|foto) ').hasMatch(t)) {
        _photo = 'without';
      } else if (RegExp(r' (image|photo|photos|images|foto) ').hasMatch(t)) {
        _photo = 'with';
      }
    } else if (RegExp(r' (voucher history|vouchar history|voucher ni history|vouchar ni history|casting history) ').hasMatch(t)) {
      _kind = _Kind.history;
    } else if (RegExp(r' (job work|jobwork|job worker|jobworker|job issue|job receive) ').hasMatch(t)) {
      _kind = _Kind.job;
      final iss = RegExp(r' (issue|issued) ').hasMatch(t);
      final rec = RegExp(r' (receive|received|recive) ').hasMatch(t);
      if (iss != rec) {
        _doJobIssue = iss;
        _doJobReceive = rec;
      }
    } else if (RegExp(r' (ledger|worker|karigar|loss|ghat|metal) ').hasMatch(t)) {
      _kind = _Kind.loss;
      if (RegExp(r' (detail|detailed|item wise|itemwise|vigat) ').hasMatch(t)) _ledgerFormat = 'detailed';
    } else if (RegExp(r' (party|party wise|partywise|customer wise|full report|all details|badhi details|complete) ').hasMatch(t)) {
      _kind = _Kind.party;
    } else if (RegExp(r' (sale|sales|vechan|bill|bills|invoice) ').hasMatch(t) && !t.contains(' approval ')) {
      _kind = _Kind.sale;
    }
    // customer: longest name found in the sentence
    String? best;
    for (final c in _customers) {
      final n = ' ${c.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
      if (n.trim().isNotEmpty && t.contains(n) && (best == null || c.length > best.length)) best = c;
    }
    if (best != null && !_isWorkerKind) {
      _customer = best;
      _custCtrl.text = best;
    }
    // range
    const months = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september',
      'october', 'november', 'december'];
    const short = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final now = DateTime.now();
    int? m;
    for (var i = 0; i < 12; i++) {
      if (t.contains(' ${months[i]} ') || t.contains(' ${short[i]} ') || (i == 8 && t.contains(' sept '))) m = i + 1;
    }
    if (m != null) {
      final yMatch = RegExp(r' (20\d\d) ').firstMatch(t);
      var y = yMatch != null ? int.parse(yMatch[1]!) : now.year;
      if (yMatch == null && m > now.month) y -= 1;
      _setRange('m_${y}_$m');
    } else if (t.contains(' last month ') || t.contains(' gaya mahine ') || t.contains(' pichhla mahina ')) {
      _setRange('last_month');
    } else if (t.contains(' this month ') || t.contains(' aa mahine ') || t.contains(' is mahine ')) {
      _setRange('this_month');
    } else if (t.contains(' this year ') || t.contains(' fy ') || t.contains(' financial year ')) {
      _setRange('fy');
    }
    _doApproval = !(t.contains(' only return') || t.contains(' return only'));
    _doReturn = !(t.contains(' only approval') || t.contains(' approval only'));
  }

  void _setRange(String key, {DateTimeRange? custom}) {
    final now = DateTime.now();
    DateTimeRange r;
    switch (key) {
      case 'this_month':
        r = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case 'last_month':
        r = DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0));
        break;
      case 'fy':
        final fyStart = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
        r = DateTimeRange(start: fyStart, end: now);
        break;
      case 'all':
        r = DateTimeRange(start: DateTime(2000, 1, 1), end: now);
        break;
      case 'last_3':
        r = DateTimeRange(start: DateTime(now.year, now.month - 2, 1), end: now);
        break;
      default:
        if (key.startsWith('m_')) {
          final p = key.split('_');
          final y = int.parse(p[1]), m = int.parse(p[2]);
          r = DateTimeRange(start: DateTime(y, m, 1), end: DateTime(y, m + 1, 0));
        } else {
          r = custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        }
    }
    setState(() {
      _rangeKey = key;
      _range = r;
      _pdf = null;
      _summary = null;
    });
  }

  String get _rangeText => _range == null
      ? '-'
      : (_rangeKey == 'all' ? 'All dates' : '${_dmy.format(_range!.start)} to ${_dmy.format(_range!.end)}');

  bool _inRange(DateTime? d) {
    if (d == null || _range == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(_range!.start) && !day.isAfter(DateTime(_range!.end.year, _range!.end.month, _range!.end.day));
  }

  bool _isCustomer(Map m) {
    if (_customer == null) return true;
    return _Data.customerOf(m).toLowerCase() == _customer!.toLowerCase();
  }

  // ---------------------------------------------------------------------
  //  BUILD REPORT
  // ---------------------------------------------------------------------
  Future<void> _generate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (_kind) {
      case _Kind.approval:
        return _generateApproval();
      case _Kind.sale:
        return _generateSale();
      case _Kind.loss:
        return _generateLedger();
      case _Kind.stock:
        return _generateStock();
      case _Kind.position:
        return _generatePosition();
      case _Kind.party:
        return _generateParty();
      case _Kind.label:
        return _generateLabels();
      case _Kind.job:
        return _generateJob();
      case _Kind.history:
        return _generateHistory();
    }
  }

  void _start(String msg) => setState(() {
    _branchDebug = '';
    _busy = true;
    _pdf = null;
    _summary = null;
    _progress = msg;
  });

  void _done(File file, String summary) {
    if (!mounted) return;
    setState(() {
      _pdf = file;
      _summary = _branchMode && _branchDebug.isNotEmpty ? '$summary\n\n🏢 ${_branchDebug.trim()}' : summary;
      _busy = false;
    });
    OpenFile.open(file.path);
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() => _busy = false);
    _snack('Could not make the report. Please try again.');
    debugPrint('📑 REPORT ERROR => $e');
  }

  // ---------------- 📋 APPROVAL ----------------
  /// 📋 Approval issue · return · sold-from-approval sections (used by Approval + Party wise)
  Future<List<_Section>> _approvalSections() async {
    final sections = <_Section>[];
    if (_doApproval) {
      final list = _approvals
          .where((a) => _isCustomer(a) && _inRange(_Data.date(_Data.pick(a, const ['approval_date', 'date', 'created_at']))))
          .toList();
      sections.add(await _collect(
        'Approval Issue',
        list,
        isReturn: false,
        url: (id) => '${ApiConstants.Approval_dailog_list}/$id',
        voucherKeys: const ['approval_no', 'voucher_no'],
        dateKeys: const ['approval_date', 'date', 'created_at'],
      ));
    }
    if (_doReturn) {
      final list = _returns.where((r) {
        final src = _Data.text(r, const ['source_type', 'type', 'return_type']).toLowerCase();
        final approvalOnly = src.isEmpty || src.contains('approval');
        return approvalOnly && _isCustomer(r) && _inRange(_Data.date(_Data.pick(r, const ['return_date', 'date', 'created_at'])));
      }).toList();
      sections.add(await _collect(
        'Approval Return',
        list,
        isReturn: true,
        url: (id) => '${ApiConstants.returns_vouchar}/$id',
        voucherKeys: const ['return_voucher_no', 'voucher_no', 'return_no'],
        dateKeys: const ['return_date', 'date', 'created_at'],
      ));
    }
    if (_doSold) {
      setState(() => _progress = 'Finding items sold from approval…');
      sections.add(await _soldFromApproval(sections));
    }
    return sections;
  }

  Future<void> _generateApproval() async {
    if (!_doApproval && !_doReturn && !_doSold) {
      _snack('Select at least one action');
      return;
    }
    _start('Finding vouchers…');
    try {
      // 🏢 branch mode → outstanding approvals, one section per branch
      final sections = _branchMode ? await _branchApprovalSections() : await _approvalSections();

      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.build(
        kind: 'approval',
        customer: _customer ?? 'All customers',
        range: _rangeText,
        sections: sections,
        branch: _branchMode ? _selBranches.map((c) => c.name).join(', ') : null,
      );

      final parts = sections
          .map((s) => '${s.title}: ${s.vouchers} vouchers · ${s.lines.length} items · '
          'net ${s.sum((l) => l.net).toStringAsFixed(3)} g · ₹${s.sum((l) => l.amount).toStringAsFixed(2)}')
          .join('\n');
      final g = sections.where((s) => s.title == 'Approval Issue');
      final r = sections.where((s) => s.title == 'Approval Return');
      final sd = sections.where((s) => s.title == 'Sold From Approval');
      String pendingLine = '';
      if (g.isNotEmpty) {
        final pNet = g.first.lines.where((l) => l.status != 'Sold').fold<double>(0, (a, l) => a + l.net);
        final rNet = r.isEmpty ? 0.0 : r.first.sum((l) => l.net);
        final sNet = sd.isEmpty ? 0.0 : sd.first.sum((l) => l.net);
        pendingLine = '\n⚖️ Total ${(pNet + rNet + sNet).toStringAsFixed(3)} g − Return ${rNet.toStringAsFixed(3)} g'
            '${sNet > 0 ? ' − Sold ${sNet.toStringAsFixed(3)} g' : ''} = Pending ${pNet.toStringAsFixed(3)} g';
      }
      _done(file, parts + pendingLine);
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 🧾 SALE ----------------
  Future<void> _generateSale() async {
    if (_range == null) return;
    _start('Finding sale bills…');
    try {
      if (_branchMode) {
        // 🏢 one section per branch + branch overview
        final secs = await _branchSaleSections();
        setState(() => _progress = 'Making PDF…');
        final file = await _ReportPdf.build(
          kind: 'sale',
          customer: _customer ?? 'All customers',
          range: _rangeText,
          sections: secs,
          branch: _selBranches.map((c) => c.name).join(', '),
        );
        _done(
            file,
            secs
                .map((s) => '${s.title}: ${s.vouchers} bills · net ${s.sum((l) => l.net).toStringAsFixed(3)} g · '
                '₹${_ReportPdf.a(s.sum((l) => l.amount))}')
                .join('\n'));
        return;
      }
      final sec = await _saleSection();
      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.build(
        kind: 'sale',
        customer: _customer ?? 'All customers',
        range: _rangeText,
        sections: [sec],
      );
      _done(
        file,
        'Sales: ${sec.vouchers} bills · ${sec.lines.length} items · qty ${_ReportPdf.q(sec.sum((l) => l.qty))}\n'
            'Net ${sec.sum((l) => l.net).toStringAsFixed(3)} g · Amount ₹${_ReportPdf.a(sec.sum((l) => l.amount))}',
      );
    } catch (e) {
      _fail(e);
    }
  }

  /// 🧾 Sale bills section (used by Sale + Party wise)
  Future<_Section> _saleSection() async {
    {
      final res = await ApiHelper().getRequest(
        '${ApiConstants.Sale_Summary_report}?columns=voucher_no,date,customer,net_total'
            '&from_date=${_ymd.format(_range!.start)}&to_date=${_ymd.format(_range!.end)}',
        showLoading: false,
        receiveTimeout: const Duration(seconds: 40),
      );
      final bills = _Data.listOf(res?.data).where(_isCustomer).toList();
      final sec = await _collect(
        'Sales',
        bills,
        isReturn: false,
        url: (id) => '${ApiConstants.Sale_Summary_report}/$id/details?columns='
            'label,huid,item_name,qty_pcs,gross_weight,other_weight,net_weight,purity,waste_percent,fine_weight,'
            'metal_rate,metal_amount,labour_rate,labour_amount,other_amount,net_total',
        voucherKeys: const ['voucher_no', 'bill_no', 'invoice_no'],
        dateKeys: const ['date', 'sale_date', 'created_at'],
        partyOf: _Data.customerOf,
      );
      return sec;
    }
  }

  // ---------------- 🧾 VOUCHER HISTORY → one voucher, every stage ----------------
  Future<void> _generateHistory() async {
    final id = _customer == null ? null : _histVouchers[_customer];
    if (id == null) {
      _snack('Select a voucher first');
      return;
    }
    _start('Loading voucher history…');
    try {
      final res = await ApiHelper().getRequest(_br('$_histUrl?voucher_id=$id'),
          showLoading: false, receiveTimeout: const Duration(seconds: 60));
      final body = res?.data;
      if (body is! Map || body['success'] == false || body['data'] is! Map) {
        throw Exception(body is Map ? (body['message'] ?? 'No data') : 'No data');
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final voucher = data['voucher'] is Map ? Map<String, dynamic>.from(data['voucher']) : <String, dynamic>{};
      final history = data['history'] is Map ? Map<String, dynamic>.from(data['history']) : <String, dynamic>{};
      final stages = _HistStage.all(history);
      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.buildHistory(voucher: voucher, history: history, stages: stages);
      final vno = _Job.s(voucher['voucher_no']);
      final loss = stages.fold<double>(0, (a, s) => a + s.loss);
      _done(
        file,
        '🧾 ${vno.isEmpty ? _customer : vno} · ${_Job.s(voucher['process_name']).isEmpty ? '' : '${_Job.s(voucher['process_name'])} · '}'
            '${stages.where((s) => s.rows.isNotEmpty).length} of ${stages.length} stages done\n'
            '${stages.map((s) => '${s.title}: ${s.rows.length}').join(' · ')}'
            '${loss > 0.0005 ? '\n🔻 Total loss ${loss.toStringAsFixed(3)} g' : ''}',
      );
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 🛠️ JOB WORK → issue · receive · loss / profit ----------------
  Future<void> _generateJob() async {
    if (_range == null) return;
    if (!_doJobIssue && !_doJobReceive) {
      _snack('Select issue, receive or both');
      return;
    }
    _start('Loading job work…');
    try {
      await _loadJob(force: true); // always fresh
      bool mine(Map m) => _customer == null || _Job.workerOf(m).toLowerCase() == _customer!.toLowerCase();
      final issues = _doJobIssue
          ? (_jobIssues.where((m) => mine(m) && _inRange(_Job.issueDate(m))).map((m) => _JobIssue.from(m, branch: _branchTag(m))).toList()
        ..sort((a, b) => (a.date ?? DateTime(1900)).compareTo(b.date ?? DateTime(1900))))
          : <_JobIssue>[];
      final recvs = _doJobReceive
          ? (_jobRecvs.where((m) => mine(m) && _inRange(_Job.recvDate(m))).map((m) => _JobRecv.from(m, branch: _branchTag(m))).toList()
        ..sort((a, b) => (a.date ?? DateTime(1900)).compareTo(b.date ?? DateTime(1900))))
          : <_JobRecv>[];
      final both = _doJobIssue && _doJobReceive;
      _noteBranches('Job issue', _jobIssues);
      _noteBranches('Job receive', _jobRecvs);
      if (_branchMode && _jobSource.isNotEmpty) _branchDebug += '${_jobSource.trim()}\n';

      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.buildJob(
        worker: _customer ?? 'All workers',
        range: _rangeText,
        issues: issues,
        recvs: recvs,
        showIssue: _doJobIssue,
        showReceive: _doJobReceive,
      );

      String g(double v) => v.toStringAsFixed(3);
      final lines = <String>[];
      if (_doJobIssue) {
        lines.add('📤 Issue: ${issues.length} vouchers · net ${g(issues.fold<double>(0, (a, e) => a + e.net))} g');
      }
      if (_doJobReceive) {
        lines.add('📥 Receive: ${recvs.length} vouchers · issued ${g(recvs.fold<double>(0, (a, e) => a + e.issued))} g'
            ' → received ${g(recvs.fold<double>(0, (a, e) => a + e.received))} g'
            ' · pending ${g(recvs.fold<double>(0, (a, e) => a + e.pending))} g');
      }
      if (both) {
        final lp = recvs.fold<double>(0, (a, e) => a + e.lossGain);
        lines.add(lp > 0.0005
            ? '🔻 Loss: ${g(lp)} g'
            : lp < -0.0005
            ? '🔺 Profit (gain): ${g(-lp)} g'
            : '⚖️ No loss / profit');
      }
      _done(file, lines.join('\n'));
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 🏷️ ITEM LABELS → created · printed · pending ----------------
  static bool _isPrinted(Map m) {
    final v = (m['is_printed'] ?? '').toString().trim().toLowerCase();
    if (v == '1' || v == 'true' || v == 'yes') return true;
    if (v == '0' || v == 'false' || v == 'no') return false;
    final p = (m['printed_at'] ?? '').toString().trim();
    return p.isNotEmpty && p != 'null' && p != '-';
  }

  /// 📍 location order (PDF + summary)
  static const List<String> _places = ['In stock', 'On approval', 'Sold', 'Sold from approval', 'Returned', 'Unknown'];

  /// barcode history cache (code → place) · 10 min
  static final Map<String, ({String place, String voucher, String date})> _placeCache = {};
  static DateTime? _placeCachedAt;

  Future<void> _findPlaces(List<_LabelLine> lines) async {
    if (_placeCachedAt == null || DateTime.now().difference(_placeCachedAt!) > const Duration(minutes: 10)) {
      _placeCache.clear();
      _placeCachedAt = DateTime.now();
    }
    final todo = lines.where((l) => l.label.isNotEmpty && !_placeCache.containsKey(l.label.toUpperCase())).toList();
    var done = 0;
    Future<void> one(_LabelLine l) async {
      final code = l.label.toUpperCase();
      try {
        final res = await ApiHelper().getRequest(
          _br('${ApiConstants.Barcode_report}?code=${Uri.encodeQueryComponent(l.label)}'),
          showLoading: false, // 🔕 no popup
          receiveTimeout: const Duration(seconds: 40),
        );
        final list = _Data.listOf(res?.data);
        if (list.isNotEmpty) {
          final exact = list.where((e) => (e['label_code'] ?? e['barcode'] ?? '').toString().toUpperCase() == code);
          _placeCache[code] = _placeOf(exact.isNotEmpty ? exact.first : list.first);
        }
      } catch (_) {}
      done++;
      if (mounted && (done % 5 == 0 || done == todo.length)) {
        setState(() => _progress = 'Finding where labels are now… $done / ${todo.length}');
      }
    }

    for (var i = 0; i < todo.length; i += 8) {
      await Future.wait([for (var j = i; j < i + 8 && j < todo.length; j++) one(todo[j])]);
    }
    for (final l in lines) {
      final p = _placeCache[l.label.toUpperCase()];
      l.place = p?.place ?? 'Unknown';
      l.placeVoucher = p?.voucher ?? '';
      l.placeDate = p?.date ?? '';
    }
  }

  /// barcode-history row → where it is now
  static ({String place, String voucher, String date}) _placeOf(Map d) {
    final status = (d['current_status'] ?? '').toString().toLowerCase().trim();
    List<Map> h(String k) => (d[k] is List ? (d[k] as List) : const []).whereType<Map>().toList();
    final sales = h('sale_history'), apps = h('approval_history'), rets = h('return_history');
    // "APP1789194519 (12-09-2026) [sold]"
    String vno(Map m) => (m['label'] ?? '').toString().split(' (').first.trim();
    String dt(Map m) => RegExp(r'\((\d{1,2}-\d{1,2}-\d{4})\)').firstMatch((m['label'] ?? '').toString())?[1] ?? '';
    String st(Map m) =>
        (m['status'] ?? RegExp(r'\[(\w+)\]').firstMatch((m['label'] ?? '').toString())?[1] ?? '').toString().toLowerCase();

    if (status.contains('sold') || status.contains('sale')) {
      // sold out of an approval voucher → "Sold from approval"
      if (apps.isNotEmpty && st(apps.last).contains('sold')) {
        return (place: 'Sold from approval', voucher: vno(apps.last), date: dt(apps.last));
      }
      if (sales.isNotEmpty) return (place: 'Sold', voucher: vno(sales.last), date: dt(sales.last));
      return (place: 'Sold', voucher: '', date: '');
    }
    if (status.contains('approval') || status == 'pending') {
      return apps.isNotEmpty
          ? (place: 'On approval', voucher: vno(apps.last), date: dt(apps.last))
          : (place: 'On approval', voucher: '', date: '');
    }
    if (status.contains('return')) {
      return rets.isNotEmpty
          ? (place: 'Returned', voucher: vno(rets.last), date: dt(rets.last))
          : (place: 'Returned', voucher: '', date: '');
    }
    return (place: 'In stock', voucher: '', date: '');
  }

  Future<void> _generateLabels() async {
    if (_range == null) return;
    _start('Loading labels…');
    try {
      await _loadLabels(force: true); // always fresh print status
      final status = _labelStatus;
      final lines = <_LabelLine>[];
      for (final m in _labelRows) {
        final item = _Data.text(m, const ['item_name', 'name']);
        if (_customer != null && item.toLowerCase() != _customer!.toLowerCase()) continue;
        final created = _Data.date(m['created_at']);
        if (_rangeKey != 'all' && !_inRange(created)) continue;
        final printed = _isPrinted(m);
        if (status == 'printed' && !printed) continue;
        if (status == 'pending' && printed) continue;
        final pAt = (m['printed_at'] ?? '').toString().trim();
        final tg = _branchTag(m);
        lines.add(_LabelLine(
          label: _Data.text(m, const ['qr_code', 'label_code', 'barcode']),
          item: (item.isEmpty ? '-' : item) + (tg.isEmpty ? '' : ' · $tg'),
          huid: _Data.text(m, const ['HUID', 'huid']),
          gross: _Data.number(m, const ['gross_weight']),
          other: _Data.number(m, const ['other_weight']),
          net: _Data.number(m, const ['net_weight']),
          printed: printed,
          created: created,
          printedAt: (pAt.isEmpty || pAt == 'null') ? '' : pAt,
        ));
      }
      // 📍 where is each label now? (barcode history · 8 at a time)
      await _findPlaces(lines);
      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.buildLabels(
        item: _customer ?? 'All items',
        range: _rangeText,
        status: status,
        lines: lines,
      );
      final printed = lines.where((l) => l.printed).length;
      final head = status == 'printed'
          ? '🖨️ Printed labels: ${lines.length}'
          : status == 'pending'
          ? '⏳ Pending labels (not printed): ${lines.length}'
          : '🏷️ Labels created: ${lines.length} · printed $printed · pending ${lines.length - printed}';
      final items = lines.map((l) => l.item).toSet().length;
      final pc = <String, int>{};
      for (final l in lines) {
        pc[l.place] = (pc[l.place] ?? 0) + 1;
      }
      final where = _places.where((k) => (pc[k] ?? 0) > 0).map((k) => '$k ${pc[k]}').join(' · ');
      _done(file,
          '$head\n$items items · net ${lines.fold<double>(0, (a, l) => a + l.net).toStringAsFixed(3)} g'
              '${where.isEmpty ? '' : '\n📍 Now: $where'}');
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 👤 PARTY WISE → everything of one customer ----------------
  Future<void> _generateParty() async {
    if (_range == null) return;
    if (_customer == null) {
      _snack('Select a party (customer) first');
      return;
    }
    if (!_doApproval && !_doReturn && !_doSold && !_doSale) {
      _snack('Select at least one section');
      return;
    }
    _start('Collecting $_customer details…');
    try {
      final sections = _branchMode
          ? (_doApproval ? await _branchApprovalSections() : <_Section>[])
          : await _approvalSections();
      if (_doSale) {
        setState(() => _progress = 'Finding sale bills…');
        if (_branchMode) {
          sections.addAll(await _branchSaleSections());
        } else {
          sections.add(await _saleSection());
        }
      }
      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.build(
        kind: 'party',
        customer: _customer!,
        range: _rangeText,
        sections: sections,
        branch: _branchMode ? _selBranches.map((c) => c.name).join(', ') : null,
      );
      final parts = sections
          .map((s) => '${s.title}: ${s.vouchers} vouchers · ${s.lines.length} items · '
          'net ${s.sum((l) => l.net).toStringAsFixed(3)} g · ₹${_ReportPdf.a(s.sum((l) => l.amount))}')
          .join('\n');
      _done(file, '👤 $_customer\n$parts');
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 📒 WORKER LOSS → DAY-WISE METAL LEDGER ----------------
  Future<void> _generateLedger() async {
    if (_range == null) return;
    _start('Loading metal ledger…');
    try {
      final wid = _customer == null ? null : _workers[_customer];
      final res = await ApiHelper().getRequest(
        _br('${ApiConstants.worker_loss_report}?mode=ledger&format=$_ledgerFormat'
            '&from_date=${_ymd.format(_range!.start)}&to_date=${_ymd.format(_range!.end)}'
            '${wid != null && !_branchMode ? '&worker_id=$wid' : ''}'),
        showLoading: false,
        receiveTimeout: const Duration(seconds: 60),
      );
      var groups = _LedgerData.groups(res?.data, tag: _branchTag);
      if (_branchMode) {
        final b = res?.data;
        final d = b is Map ? b['data'] : null;
        final gl = d is Map ? d['groups'] : (b is Map ? b['groups'] : null);
        _noteBranches('Worker ledger', gl is List ? gl.whereType<Map>() : const <Map>[]);
      }
      if (_customer != null) {
        groups = groups.where((g) => g.worker.toLowerCase() == _customer!.toLowerCase()).toList();
      }
      // keep only workers with something to show
      groups = groups
          .where((g) => g.rows.isNotEmpty || g.opening.abs() > 0.0005 || g.closing.abs() > 0.0005)
          .toList()
        ..sort((a, b) => b.closing.compareTo(a.closing));
      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.buildLedger(
        worker: _customer ?? 'All workers',
        range: _rangeText,
        groups: groups,
        detailed: _ledgerFormat == 'detailed',
      );
      final pending = groups.where((g) => g.closing > 0).fold<double>(0, (a, g) => a + g.closing);
      final dr = groups.fold<double>(0, (a, g) => a + g.debit);
      final cr = groups.fold<double>(0, (a, g) => a + g.credit);
      _done(
        file,
        'Metal ledger (${_ledgerFormat == 'detailed' ? 'detailed · item wise' : 'day wise'}): ${groups.length} workers\n'
            'Issued (Dr) ${dr.toStringAsFixed(3)} g · Received (Cr) ${cr.toStringAsFixed(3)} g\n'
            '⚖️ Metal pending with workers: ${pending.toStringAsFixed(3)} g',
      );
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 📦 STOCK ----------------
  Future<void> _generateStock() async {
    _start('Loading stock…');
    try {
      // 🏢 branch merge → stock gallery of the selected branches (tagged with branch name)
      final tagged = _branchMode ? await _branchStock() : null;
      final tagOf = <StockItem, String>{if (tagged != null) for (final e in tagged) e.s: e.tag};
      final all = tagged != null ? tagged.map((e) => e.s).toList() : await StockAiRepository.loadAll();
      final status = _stockStatus;
      // 🖼️ photo filter works only for In stock
      final photo = status == 'in' ? _photo : 'any';
      final images = photo == 'with';
      final list = all.where((s) {
        if (status == 'in' && s.isSold) return false;
        if (status == 'out' && !s.isSold) return false;
        if (_customer != null && s.itemName.toLowerCase() != _customer!.toLowerCase()) return false;
        if (_rangeKey != 'all') {
          final d = status == 'out' ? (s.soldOn ?? s.addedOn) : s.addedOn;
          if (!_inRange(d)) return false;
        }
        // 🖼️ "With image" → only pieces that have a photo
        final has = _hasPhoto(s.imageUrl) || _hasPhoto(s.imageDownloadUrl);
        if (photo == 'with' && !has) return false;
        // "Without image" → ALL in-stock pieces, PDF without photo column
        return true;
      }).toList();

      final List<_StockLine> lines = list
          .map((s) => _StockLine(
        label: s.labelCode,
        item: (tagOf[s] ?? '').isEmpty ? s.itemName : '${s.itemName} · ${tagOf[s]}',
        huid: s.huid == '-' ? '' : s.huid,
        gross: s.grossWeight,
        other: s.otherWeight,
        net: s.netWeight,
        sold: s.isSold,
        date: status == 'out' ? (s.soldOn ?? s.addedOn) : s.addedOn,
        soldOn: s.soldOn,
        imageUrl: (s.imageDownloadUrl ?? '').trim().isNotEmpty ? s.imageDownloadUrl : s.imageUrl,
        imageUrl2: s.imageUrl,
      ))
          .toList();

      // 🖼️ photos: 6 at a time
      if (images) {
        final withUrl = lines.where((l) => (l.imageUrl ?? '').isNotEmpty || (l.imageUrl2 ?? '').isNotEmpty).toList();
        var done = 0;
        final dio = Dio(BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ));
        Future<void> one(_StockLine l) async {
          for (final raw in {l.imageUrl, l.imageUrl2}.whereType<String>().where((e) => e.trim().isNotEmpty)) {
            try {
              final u = raw.startsWith('http') ? raw : '$_site${raw.replaceFirst(RegExp(r'^/'), '')}';
              final res = await dio.get<List<int>>(u);
              final b = res.data;
              if (b == null || b.length < 200) continue;
              final png = await _thumbPng(Uint8List.fromList(b));
              if (png != null) {
                l.image = pw.MemoryImage(png);
                break;
              }
            } catch (_) {}
          }
          done++;
          if (mounted) setState(() => _progress = 'Photos: $done / ${withUrl.length}');
        }

        for (var i = 0; i < withUrl.length; i += 6) {
          await Future.wait([for (var j = i; j < i + 6 && j < withUrl.length; j++) one(withUrl[j])]);
        }
        // ✅ With image = ONLY pieces whose photo really loaded
        lines.removeWhere((l) => l.image == null);
      }

      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.buildStock(
        item: _customer ?? 'All items',
        range: _rangeText,
        status: status,
        withImages: images,
        photoMode: photo,
        lines: lines,
      );
      final net = lines.fold<double>(0, (a, l) => a + l.net);
      final gross = lines.fold<double>(0, (a, l) => a + l.gross);
      _done(
        file,
        '${status == 'in' ? 'In stock' : status == 'out' ? 'Out of stock' : 'All stock'}: ${lines.length} pcs\n'
            'Gross ${gross.toStringAsFixed(3)} g · Net ${net.toStringAsFixed(3)} g'
            '${images ? '\n🖼️ Only pieces with photo (${lines.length})' : photo == 'without' ? '\n📄 All in-stock pieces · without photos' : ''}',
      );
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------- 📦 STOCK POSITION (branch wise) ----------------
  Future<void> _generatePosition() async {
    _start('Loading stock position…');
    try {
      await _loadPosition(force: true, dated: true);
      final rows = _posRows.where((r) {
        if (_customer != null && r.item.toLowerCase() != _customer!.toLowerCase()) return false;
        if (_posType != null && r.typeKey != _posType) return false;
        // 📅 month / range (same as Stock Gallery) → by added date
        if (_rangeKey != 'all' && !_inRange(r.date)) return false;
        // empty rows (0 pcs · 0 wt) → skip
        return r.qty != 0 || r.gross != 0 || r.net != 0 || r.fine != 0;
      }).toList();

      // 🏢 group by branch (selected order, Main first)
      final mains = _branches.where((c) => c.isMain).toList();
      final mainName = mains.isNotEmpty ? mains.first.name : 'This company';
      final by = <String, List<_PosRow>>{};
      for (final r in rows) {
        final b = r.branch.isNotEmpty ? r.branch : (_branchMode ? 'Selected branches' : mainName);
        by.putIfAbsent(b, () => []).add(r);
      }
      final order = [
        for (final c in _selBranches)
          if (by.containsKey(c.name)) c.name,
        ...by.keys.where((k) => !_selBranches.any((c) => c.name == k)),
      ];
      final groups = {for (final k in order) k: by[k]!};

      final typeName = _posType == null
          ? 'All types'
          : _posTypes.firstWhere((t) => t.key == _posType, orElse: () => (key: '', name: _posType!)).name;

      setState(() => _progress = 'Making PDF…');
      final file = await _ReportPdf.buildStockPosition(
        item: _customer ?? 'All items',
        type: typeName,
        range: _rangeText,
        branch: _branchMode ? _selBranches.map((c) => c.name).join(', ') : mainName,
        groups: groups,
      );

      double sum(double Function(_PosRow) f) => rows.fold(0, (a, r) => a + f(r));
      if (_branchMode) {
        _branchDebug += 'Stock position: ${rows.length} rows'
            '${groups.isEmpty ? '' : ' · ${groups.entries.map((e) => '${e.key} ${e.value.length}').join(' · ')}'}'
            '${_posSource.isEmpty ? '' : '\n$_posSource'}\n';
      }
      _done(
        file,
        'Stock position: ${rows.length} rows · ${_ReportPdf.q(sum((r) => r.qty))} pcs\n'
            'Gross ${sum((r) => r.gross).toStringAsFixed(3)} g · Net ${sum((r) => r.net).toStringAsFixed(3)} g · '
            'Fine ${sum((r) => r.fine).toStringAsFixed(3)} g'
            '${groups.length > 1 ? '\n🏢 ${groups.length} branches' : ''}',
      );
    } catch (e) {
      _fail(e);
    }
  }

  /// real photo url? (empty / "null" / default no-image placeholder = no photo)
  static bool _hasPhoto(String? u) {
    final v = (u ?? '').trim().toLowerCase();
    if (v.isEmpty || v == 'null' || v == '-') return false;
    if (RegExp(r'(no[-_ ]?image|noimage|no[-_]?photo|placeholder|default[-_]?(img|image)|dummy|not[-_]?found)').hasMatch(v)) {
      return false;
    }
    // folder only (no file name)
    if (v.endsWith('/')) return false;
    return true;
  }

  /// Any photo (JPG / PNG / WebP / HEIC the phone can read) → small PNG (220 px)
  /// so the PDF can always show it and stays light.
  static Future<Uint8List?> _thumbPng(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 220);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<_Section> _soldFromApproval(List<_Section> sections) async {
    final sold = _Section('Sold From Approval');
    final seen = <String>{};

    List<_Line> issued;
    final iss = sections.where((s) => s.title == 'Approval Issue');
    if (iss.isNotEmpty) {
      issued = iss.first.lines;
    } else {
      final list = _approvals
          .where((a) => _isCustomer(a) && _inRange(_Data.date(_Data.pick(a, const ['approval_date', 'date', 'created_at']))))
          .toList();
      issued = (await _collect(
        'Approval Issue',
        list,
        isReturn: false,
        url: (id) => '${ApiConstants.Approval_dailog_list}/$id',
        voucherKeys: const ['approval_no', 'voucher_no'],
        dateKeys: const ['approval_date', 'date', 'created_at'],
      ))
          .lines;
    }

    for (final l in issued.where((l) => l.status == 'Sold')) {
      if (seen.add(l.key)) sold.lines.add(_copy(l)..status = 'Sold');
    }

    final approvalKeys = {for (final l in issued) l.key: l};
    final barcodes = issued.where((l) => l.barcode.isNotEmpty).map((l) => l.key).toSet();
    if (barcodes.isNotEmpty && _range != null) {
      try {
        final res = await ApiHelper().getRequest(
          '${ApiConstants.Sale_Summary_report}?columns=voucher_no,date,customer'
              '&from_date=${_ymd.format(_range!.start)}&to_date=${_ymd.format(DateTime.now())}',
          showLoading: false,
          receiveTimeout: const Duration(seconds: 25),
        );
        final bills = _Data.listOf(res?.data).where(_isCustomer).toList();
        final saleSec = await _collect(
          'Sold From Approval',
          bills,
          isReturn: false,
          url: (id) => '${ApiConstants.Sale_Summary_report}/$id/details?columns='
              'label,huid,item_name,qty_pcs,gross_weight,net_weight,purity,waste_percent,fine_weight,'
              'metal_rate,metal_amount,labour_rate,labour_amount,other_amount,net_total',
          voucherKeys: const ['voucher_no', 'bill_no', 'invoice_no'],
          dateKeys: const ['date', 'sale_date', 'created_at'],
        );
        for (final l in saleSec.lines) {
          if (barcodes.contains(l.key) && seen.add(l.key)) {
            l.status = 'Sold';
            final from = approvalKeys[l.key];
            if (from != null) l.voucher = '${l.voucher}\n(from ${from.voucher})';
            sold.lines.add(l);
          }
        }
      } catch (_) {}
    }

    for (final l in issued) {
      if (seen.contains(l.key)) l.status = 'Sold';
    }
    sold.vouchers = sold.lines.map((l) => l.voucher).toSet().length;
    return sold;
  }

  _Line _copy(_Line s) => _Line()
    ..voucher = s.voucher
    ..date = s.date
    ..item = s.item
    ..barcode = s.barcode
    ..qty = s.qty
    ..gross = s.gross
    ..less = s.less
    ..net = s.net
    ..labourRate = s.labourRate
    ..labourAmt = s.labourAmt
    ..metalRate = s.metalRate
    ..metalAmt = s.metalAmt
    ..other = s.other
    ..amount = s.amount
    ..status = s.status;

  Future<_Section> _collect(
      String title,
      List<Map> vouchers, {
        required bool isReturn,
        required String Function(String id) url,
        required List<String> voucherKeys,
        required List<String> dateKeys,
        String Function(Map v)? partyOf, // sale: put customer in the last column
        List<String> Function(Map v, String id)? urlsOf, // 🏢 try these detail urls in order
        bool rowFallback = false, // 🏢 no item details → use the voucher row itself
      }) async {
    final sec = _Section(title)..vouchers = vouchers.length;
    int done = 0;
    final results = List<List<_Line>>.filled(vouchers.length, const []);

    Future<void> one(int i) async {
      final v = vouchers[i];
      final id = v['id']?.toString() ?? '';
      final vno = _Data.text(v, voucherKeys);
      final d = _Data.date(_Data.pick(v, dateKeys));
      final dText = d == null ? '' : _dmy.format(d);
      List<Map> items = _Data.itemsOf(v);
      final tries = urlsOf != null ? urlsOf(v, id) : [url(id)];
      for (final u in tries) {
        if (items.isNotEmpty || id.isEmpty) break;
        try {
          final res = await ApiHelper().getRequest(u, showLoading: false, receiveTimeout: const Duration(seconds: 25));
          final det = _Data.detailOf(res?.data);
          if (det != null) items = _Data.itemsOf(det);
          if (items.isEmpty) {
            final rows = _Data.listOf(res?.data);
            const itemKeys = ['item_name', 'label', 'gross_weight', 'gross_wt', 'net_weight', 'net_wt', 'item', 'huid', 'qr_code'];
            if (rows.isNotEmpty && itemKeys.any(rows.first.containsKey)) items = rows;
          }
          // 🏢 items came but every line is empty (no name, no weight) → not useful, try next url
          if (items.isNotEmpty && urlsOf != null) {
            final ok = items.any((it) {
              final l = _Data.line(it, voucher: vno, date: dText, isReturn: isReturn);
              return l.gross > 0 || l.net > 0 || (l.item.isNotEmpty && l.item != '-');
            });
            if (!ok) items = const [];
          }
          if (urlsOf != null) {
            debugPrint('🏢 DETAILS $u → ${items.length} items');
            if (items.isNotEmpty) debugPrint('🏢 FIRST ITEM → ${items.first}');
          }
        } catch (e) {
          debugPrint('🏢 DETAILS FAILED $u → $e');
        }
      }
      // 🏢 still nothing → one line from the voucher row (weights / amount of the bill)
      final fromRow = items.isEmpty && rowFallback;
      if (fromRow) items = [v];
      final party = partyOf?.call(v);
      results[i] = items.map((it) {
        final l = _Data.line(it, voucher: vno, date: dText, isReturn: isReturn);
        if (fromRow && (l.item == '-' || l.item == vno)) l.item = 'Voucher total';
        if (party != null) l.status = party.isEmpty ? '-' : party;
        return l;
      }).toList();
      done++;
      if (mounted) setState(() => _progress = '$title: $done / ${vouchers.length}');
    }

    for (var s = 0; s < vouchers.length; s += 4) {
      await Future.wait([for (var i = s; i < s + 4 && i < vouchers.length; i++) one(i)]);
    }
    for (final r in results) {
      sec.lines.addAll(r);
    }
    return sec;
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  // ---------------------------------------------------------------------
  //  UI — ✨ premium light blue
  // ---------------------------------------------------------------------
  ({String title, String sub, IconData icon, Color color}) _meta(_Kind k) => switch (k) {
    _Kind.approval => (
    title: 'Approval',
    sub: 'Issue · Return · Sold',
    icon: Icons.assignment_turned_in_rounded,
    color: const Color(0xffD97706)
    ),
    _Kind.sale => (title: 'Sale', sub: 'Bills · item-wise', icon: Icons.receipt_long_rounded, color: const Color(0xff059669)),
    _Kind.loss => (
    title: 'Worker loss',
    sub: 'Metal ledger',
    icon: Icons.handyman_rounded,
    color: const Color(0xff7C3AED)
    ),
    _Kind.party => (
    title: 'Party wise',
    sub: 'All details of a party',
    icon: Icons.person_search_rounded,
    color: const Color(0xff2563EB)
    ),
    _Kind.job => (
    title: 'Job work',
    sub: 'Issue · receive · loss',
    icon: Icons.construction_rounded,
    color: const Color(0xffEA580C)
    ),
    _Kind.history => (
    title: 'Voucher history',
    sub: 'One voucher · all stages',
    icon: Icons.timeline_rounded,
    color: const Color(0xff0D9488)
    ),
    _Kind.label => (
    title: 'Item labels',
    sub: 'Printed · pending',
    icon: Icons.qr_code_2_rounded,
    color: const Color(0xffDB2777)
    ),
    _Kind.position => (
    title: 'Stock',
    sub: 'Position · branch wise',
    icon: Icons.warehouse_rounded,
    color: const Color(0xff4F46E5)
    ),
    _Kind.stock => (
    title: 'Stock Gallery',
    sub: 'In / out · photos',
    icon: Icons.inventory_2_rounded,
    color: const Color(0xff0891B2)
    ),
  };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final meta = _meta(_kind);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
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
                // ---- header ----
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffEEF5FF), Color(0xffDCEAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _line),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xff60A5FA), _blue]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: _blue.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.summarize_rounded, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Report builder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        SizedBox(height: 2),
                        Text('Pick a report · who · range → premium PDF',
                            style: TextStyle(fontSize: 11.5, color: _soft)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _soft),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator(color: _blue)),
                  )
                else if (_loadError != null && _kind == _Kind.approval)
                  Text(_loadError!, style: const TextStyle(color: Colors.red))
                else ...[
                    // ---------------- 🏢 BRANCH ----------------
                    _branchCard(),

                    // ---------------- REPORT TYPE ----------------
                    _label('1', 'Report'),
                    // ↔️ horizontal scroll, compact cards
                    LayoutBuilder(builder: (_, box) {
                      const gap = 8.0;
                      final n = _Kind.values.length;
                      // 📱 wide screen (tablet) → all cards in one row, no scroll
                      if (box.maxWidth >= n * 120 + (n - 1) * gap) {
                        return IntrinsicHeight(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              for (var i = 0; i < n; i++) ...[
                                Expanded(child: _kindTile(_Kind.values[i])),
                                if (i < n - 1) const SizedBox(width: gap),
                              ],
                            ]));
                      }
                      // 📱 phone → horizontal scroll, ~2.6 cards visible (so you see there is more)
                      final w = ((box.maxWidth - 2 * gap) / 2.6).clamp(104.0, 150.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (var i = 0; i < n; i++) ...[
                              SizedBox(width: w, child: _kindTile(_Kind.values[i])),
                              if (i < n - 1) const SizedBox(width: gap),
                            ],
                          ]),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // ---------------- CUSTOMER / WORKER ----------------
                    _label('2', _kind == _Kind.history ? 'Voucher' : _isWorkerKind ? 'Worker' : (_isItemKind ? 'Item' : (_kind == _Kind.party ? 'Party' : 'Customer'))),
                    PremiumSearchableDropdown<String>(
                      key: ValueKey('dd_${_fieldKey}_${_options.length}'),
                      label: '',
                      hint: _kind == _Kind.history ? 'Select voucher' : _isWorkerKind ? 'Select worker' : (_isItemKind ? 'Select item' : (_kind == _Kind.party ? 'Select party' : 'Select customer')),
                      items: _pickOne ? _options : [_allLabel, ..._options],
                      value: _pickOne ? _customer : (_customer ?? _allLabel),
                      itemLabel: (n) => n,
                      searchText: (n) => n,
                      prefixIcon: _kind == _Kind.history
                          ? Icons.receipt_long_rounded
                          : _isWorkerKind
                          ? Icons.engineering_rounded
                          : ((_kind == _Kind.stock || _kind == _Kind.position)
                          ? Icons.diamond_outlined
                          : (_kind == _Kind.label ? Icons.qr_code_2_rounded : Icons.person_outline_rounded)),
                      dropdownMaxHeight: 350,
                      onChanged: (n) => setState(() {
                        _customer = (n == null || n == _allLabel) ? null : n;
                        _pdf = null;
                        _summary = null;
                      }),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (_listBusy) ...[
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: _blue)),
                        const SizedBox(width: 6),
                        const Text('Loading names…', style: TextStyle(fontSize: 11.5, color: _soft)),
                      ] else
                        Text(
                          _customer == null
                              ? (_kind == _Kind.party
                              ? 'Select a party to see all its details'
                              : (_kind == _Kind.history ? 'Select a voucher to see its full history' : _allLabel))
                              : 'Selected: $_customer',
                          style: TextStyle(fontSize: 11.5, color: _customer == null ? _soft : _blue, fontWeight: FontWeight.w700),
                        ),
                    ]),
                    const SizedBox(height: 16),

                    // ---------------- RANGE (not for voucher history) ----------------
                    if (_kind != _Kind.history) ...[
                      _label('3', 'Range'),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (_isItemKind) _rangeChip('all', 'All dates'),
                        _rangeChip('this_month', 'This month'),
                        _rangeChip('last_month', 'Last month'),
                        _rangeChip('last_3', 'Last 3 months'),
                        _rangeChip('fy', 'This FY'),
                        _monthPicker(),
                        _customChip(),
                      ]),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.event_rounded, size: 14, color: _blue),
                          const SizedBox(width: 6),
                          Text(_rangeText, style: const TextStyle(fontSize: 11.5, color: _blue, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ---------------- ACTION ----------------
                    _label(_kind == _Kind.history ? '3' : '4', 'Action'),
                    if (_kind == _Kind.party) ...[
                      _infoCard(meta.color, meta.icon,
                          'One PDF with everything of this party\nSummary · approval issue · return · sold · sale bills · pending'),
                      const SizedBox(height: 8),
                      _check('Approval issue — item-wise', _doApproval, (v) => setState(() => _doApproval = v)),
                      _check('Approval return — item-wise', _doReturn, (v) => setState(() => _doReturn = v)),
                      _check('Sold from approval — item-wise', _doSold, (v) => setState(() => _doSold = v)),
                      _check('Sale bills — item-wise', _doSale, (v) => setState(() => _doSale = v)),
                    ] else if (_kind == _Kind.approval) ...[
                      _check('Approval issue — item-wise', _doApproval, (v) => setState(() => _doApproval = v)),
                      _check('Approval return — item-wise', _doReturn, (v) => setState(() => _doReturn = v)),
                      _check('Sold from approval — item-wise', _doSold, (v) => setState(() => _doSold = v)),
                    ] else if (_kind == _Kind.loss) ...[
                      Row(children: [
                        Expanded(
                          child: _formatTile('daily', Icons.calendar_view_day_rounded, 'Day wise ledger',
                              'One line per day · Dr · Cr · balance'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _formatTile('detailed', Icons.list_alt_rounded, 'Detailed ledger',
                              'Item-wise · voucher · issue / receive'),
                        ),
                      ]),
                    ] else if (_kind == _Kind.history) ...[
                      _infoCard(meta.color, meta.icon,
                          'Full timeline of the selected voucher\nHeating · metal issue · casting receive · tree cutting office · '
                              'tree cutting issue / receive · sorting · totals · loss'),
                    ] else if (_kind == _Kind.job) ...[
                      _check('Job work issue — voucher-wise', _doJobIssue, (v) => setState(() {
                        _doJobIssue = v;
                        _pdf = null;
                      })),
                      _check('Job work receive — voucher-wise', _doJobReceive, (v) => setState(() {
                        _doJobReceive = v;
                        _pdf = null;
                      })),
                      const SizedBox(height: 6),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _doJobIssue && _doJobReceive
                            ? _infoCard(meta.color, Icons.balance_rounded,
                            'Both selected → PDF also shows LOSS / PROFIT\nIssued − received − pending · voucher-wise + worker-wise')
                            : const SizedBox(width: double.infinity),
                      ),
                    ] else if (_kind == _Kind.label) ...[
                      IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: _labelTile('all', Icons.all_inclusive_rounded, 'All', 'Created')),
                          const SizedBox(width: 8),
                          Expanded(child: _labelTile('printed', Icons.print_rounded, 'Printed', 'Label printed')),
                          const SizedBox(width: 8),
                          Expanded(child: _labelTile('pending', Icons.pending_actions_rounded, 'Pending', 'Not printed')),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'PDF: where now (in stock · approval · sold · sold from approval · returned) · item-wise count · '
                            'date wise list · label · item · HUID · weights · print status · voucher',
                        style: TextStyle(fontSize: 10.5, color: _soft),
                      ),
                    ] else if (_kind == _Kind.position) ...[
                      _infoCard(meta.color, meta.icon,
                          'Current stock — item-wise · stock type wise\n'
                              '${_branchMode ? 'One section per branch + branch wise overview' : 'Pcs · gross · less · net · fine · labour · other'}'),
                      const SizedBox(height: 10),
                      const Text('Stock type',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _soft)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _posChip(null, 'All types'),
                        for (final t in _posTypes) _posChip(t.key, t.name),
                      ]),
                      const SizedBox(height: 6),
                      const Text(
                        'PDF: branch wise · stock type wise · item · customer · pcs · image / no image · '
                            'gross · less · net · fine · labour · other',
                        style: TextStyle(fontSize: 10.5, color: _soft),
                      ),
                    ] else if (_kind == _Kind.stock) ...[
                      IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: _stockTile('all', Icons.all_inclusive_rounded, 'All', 'In + sold')),
                          const SizedBox(width: 8),
                          Expanded(child: _stockTile('in', Icons.inventory_rounded, 'In stock', 'Available')),
                          const SizedBox(width: 8),
                          Expanded(child: _stockTile('out', Icons.sell_rounded, 'Out of stock', 'Sold')),
                        ]),
                      ),
                      // In stock → 2 more options: With image / Without image
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _stockStatus == 'in'
                            ? Padding(padding: const EdgeInsets.only(top: 8), child: _photoChoice())
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stockStatus == 'out'
                            ? 'PDF: date wise by sold date · label · item · HUID · gross · other · net'
                            : 'PDF: date wise by added date · label · item · HUID · gross · other · net'
                            '${_stockStatus == 'in' && _photo == 'with' ? ' · photo' : ''}',
                        style: const TextStyle(fontSize: 10.5, color: _soft),
                      ),
                    ] else
                      _infoCard(meta.color, meta.icon,
                          'Sale bills — item-wise\nVoucher · item · qty · gross · less · net · labour · metal · amount · customer'),
                    const SizedBox(height: 16),

                    // ---------------- MAKE ----------------
                    _makeButton(meta),

                    if (_pdf != null) ...[
                      const SizedBox(height: 14),
                      _resultCard(),
                    ],
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kindTile(_Kind k) {
    final m = _meta(k);
    final on = _kind == k;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pickKind(k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        decoration: BoxDecoration(
          color: on ? m.color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? m.color : _line, width: on ? 1.5 : 1),
          boxShadow: on ? [BoxShadow(color: m.color.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: on ? m.color : m.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(m.icon, size: 14, color: on ? Colors.white : m.color),
            ),
            const Spacer(),
            if (on) Icon(Icons.check_circle_rounded, size: 14, color: m.color),
          ]),
          const SizedBox(height: 6),
          Text(m.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _ink)),
          Text(m.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: _soft)),
        ]),
      ),
    );
  }

  /// 📦 stock type chip (null = all types)
  Widget _posChip(String? key, String label) {
    const c = Color(0xff4F46E5);
    final on = _posType == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _posType = key;
        _pdf = null;
        _summary = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: on ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? c : _line),
          boxShadow: on ? [BoxShadow(color: c.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : _ink)),
      ),
    );
  }

  Widget _stockTile(String st, IconData icon, String title, String sub) {
    const c = Color(0xff0891B2);
    final on = _stockStatus == st;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _stockStatus = st;
        // In stock → With / Without image (default Without) · Out / All → no photo filter
        _photo = st == 'in' ? (_photo == 'any' ? 'without' : _photo) : 'any';
        _pdf = null;
        _summary = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: on ? c.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? c : _line, width: on ? 1.5 : 1),
          boxShadow: on ? [BoxShadow(color: c.withOpacity(0.16), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: on ? c : c.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: on ? Colors.white : c),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title,
                maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink)),
          ),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: _soft)),
        ]),
      ),
    );
  }

  /// 🏷️ All · Printed · Pending
  Widget _labelTile(String st, IconData icon, String title, String sub) {
    const c = Color(0xffDB2777);
    final on = _labelStatus == st;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _labelStatus = st;
        _pdf = null;
        _summary = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: on ? c.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? c : _line, width: on ? 1.5 : 1),
          boxShadow: on ? [BoxShadow(color: c.withOpacity(0.16), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: on ? c : c.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: on ? Colors.white : c),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title,
                maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink)),
          ),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: _soft)),
        ]),
      ),
    );
  }

  /// 🖼️ Photo: All · With image · Without image
  Widget _photoChoice() {
    const c = Color(0xff0891B2);
    Widget chip(String v, IconData icon, String title, String sub) {
      final on = _photo == v;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _photo = v;
            _pdf = null;
            _summary = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: on ? c.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? c : _line, width: on ? 1.4 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: on ? c : _soft),
              const SizedBox(width: 6),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(title,
                        maxLines: 1,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? c : _ink)),
                  ),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.5, color: _soft)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('In stock · Photo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _soft)),
      const SizedBox(height: 6),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          chip('with', Icons.photo_library_rounded, 'With image', 'Photo in PDF'),
          const SizedBox(width: 8),
          chip('without', Icons.hide_image_outlined, 'Without image', 'All pieces, no photo'),
        ]),
      ),
    ]);
  }

  Widget _formatTile(String f, IconData icon, String title, String sub) {
    const c = Color(0xff7C3AED);
    final on = _ledgerFormat == f;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _ledgerFormat = f;
        _pdf = null;
        _summary = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: on ? c.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? c : _line, width: on ? 1.5 : 1),
          boxShadow: on ? [BoxShadow(color: c.withOpacity(0.16), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: on ? c : c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: on ? Colors.white : c),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink)),
                ),
                if (on) const Icon(Icons.check_circle_rounded, size: 15, color: c),
              ]),
              const SizedBox(height: 2),
              Text(sub, maxLines: 2, style: const TextStyle(fontSize: 10, color: _soft, height: 1.3)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard(Color c, IconData icon, String text) {
    final lines = text.split('\n');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lines.first, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
            if (lines.length > 1) ...[
              const SizedBox(height: 3),
              Text(lines[1], style: const TextStyle(fontSize: 11, color: _soft, height: 1.35)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _makeButton(({String title, String sub, IconData icon, Color color}) meta) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _busy ? null : _generate,
      child: Ink(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xffF43F5E), Color(0xffE11D48), Color(0xffBE123C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: const Color(0xffE11D48).withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: _busy
                ? const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xffE11D48)),
            )
                : const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xffE11D48)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_busy ? 'Preparing…' : 'Make ${meta.title} PDF',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(_busy ? _progress : '${_customer ?? _allLabel} · $_rangeText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5)),
            ]),
          ),
          if (!_busy) const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
        ]),
      ),
    ),
  );

  Widget _resultCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xffECFDF5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xffA7F3D0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.check_circle_rounded, size: 18, color: Color(0xff059669)),
        SizedBox(width: 6),
        Text('Report ready', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xff047857))),
      ]),
      const SizedBox(height: 6),
      Text(_summary ?? '', style: const TextStyle(fontSize: 12, color: _ink, height: 1.45)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => OpenFile.open(_pdf!.path),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('Open'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Share.shareXFiles([XFile(_pdf!.path)], text: '${_meta(_kind).title} report'),
            icon: const Icon(Icons.share_rounded, size: 17),
            label: const Text('Share'),
          ),
        ),
      ]),
    ]),
  );

  Widget _label(String n, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xff60A5FA), _blueDeep]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
    ]),
  );

  InputDecoration _box(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12.5, color: _soft),
    prefixIcon: Icon(icon, size: 20, color: _blue),
    filled: true,
    fillColor: _bgSoft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _line)),
    focusedBorder:
    OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _blue, width: 1.3)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  );

  Widget _rangeChip(String key, String label) {
    final on = _rangeKey == key;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      showCheckmark: false,
      selectedColor: _blue,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: on ? _blue : _line),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : _ink),
      onSelected: (_) => _setRange(key),
    );
  }

  Widget _customChip() {
    final on = _rangeKey == 'custom';
    return ActionChip(
      avatar: Icon(Icons.date_range_rounded, size: 16, color: on ? Colors.white : _blue),
      label: Text('Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : _ink)),
      backgroundColor: on ? _blue : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: on ? _blue : _line),
      onPressed: () async {
        final r = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: _range,
        );
        if (r != null) _setRange('custom', custom: r);
      },
    );
  }

  /// Month dropdown: last 18 months ("September 2026")
  Widget _monthPicker() {
    final now = DateTime.now();
    final months = List.generate(18, (i) => DateTime(now.year, now.month - i, 1));
    final on = _rangeKey.startsWith('m_');
    return PopupMenuButton<String>(
      onSelected: (k) => _setRange(k),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: _line)),
      itemBuilder: (_) => months
          .map((m) => PopupMenuItem(
        value: 'm_${m.year}_${m.month}',
        height: 40,
        child: Text(DateFormat('MMMM yyyy').format(m), style: const TextStyle(fontSize: 13, color: _ink)),
      ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? _blue : _line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_rounded, size: 15, color: on ? Colors.white : _blue),
          const SizedBox(width: 5),
          Text(
            on && _range != null ? DateFormat('MMMM yyyy').format(_range!.start) : 'Pick month',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : _ink),
          ),
          Icon(Icons.arrow_drop_down_rounded, size: 18, color: on ? Colors.white : _ink),
        ]),
      ),
    );
  }

  Widget _check(String t, bool v, ValueChanged<bool> on) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => on(!v),
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: v ? _bgSoft : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: v ? _blue.withOpacity(0.35) : _line),
      ),
      child: Row(children: [
        Checkbox(
          value: v,
          activeColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          onChanged: (x) => on(x ?? false),
        ),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w600))),
      ]),
    ),
  );
}

// =======================================================================
//  📦 STOCK LINE
// =======================================================================
/// 🧾 VOUCHER HISTORY stage (same stages + columns as Voucher History screen)
class _HistStage {
  final String title, status;
  final List<String> columns, keys;
  final List<Map> rows;
  final Map<String, String>? total; // column → total
  final double loss;
  _HistStage(this.title, this.status, this.columns, this.keys, this.rows, this.total, this.loss);

  static String v(dynamic x, [String d = '0.000']) {
    final s = (x ?? '').toString().trim();
    return (s.isEmpty || s == 'null') ? d : s;
  }

  static List<_HistStage> all(Map<String, dynamic> h) {
    final out = <_HistStage>[];
    List<Map> rows(Map m) => (m['rows'] is List) ? (m['rows'] as List).whereType<Map>().toList() : const <Map>[];
    double n(dynamic x) => double.tryParse('${x ?? ''}'.replaceAll(',', '')) ?? 0;
    void add(String key, String title, String Function(Map) status, List<String> cols, List<String> keys,
        Map<String, String> Function(Map)? total,
        {String? lossKey}) {
      final m = h[key];
      if (m is! Map) return;
      out.add(_HistStage(title, status(m), cols, keys, rows(m), total?.call(m), lossKey == null ? 0 : n(m[lossKey])));
    }

    add('casting_heating', 'Casting Heating', (m) => '${v(m['in_bhati_count'], '0')} in bhati / ${v(m['total_count'], '0')} pcs',
        ['Sr', 'Buch No', 'In Bhati', 'Checked At'], ['sr', 'buch_no', 'in_bhati_view', 'checked_at_view'], null);
    add('casting_metal_issue', 'Casting Metal Issue', (m) => '${v(m['issued_count'], '0')} issued',
        ['Sr', 'Buch No', 'Silver Wt', 'Issue Silver Wt', 'Issued At'],
        ['sr', 'buch_no', 'silver_wt', 'issue_silver_wt', 'issued_at_view'],
            (m) => {'Silver Wt': v(m['silver_wt_total']), 'Issue Silver Wt': v(m['issue_silver_wt_total'])});
    add('casting_receive', 'Casting Receive', (m) => '${v(m['received_count'], '0')} received',
        ['Sr', 'Buch No', 'Release Tree Wt', 'Release Tree Bhuko', 'Release Tree Total Wt', 'Loss', 'Released At'],
        ['sr', 'buch_no', 'release_tree_wt', 'release_tree_bhuko', 'release_tree_total_wt', 'loss', 'released_at_view'],
            (m) => {
          'Release Tree Wt': v(m['release_tree_wt_total']),
          'Release Tree Bhuko': v(m['release_tree_bhuko_total']),
          'Release Tree Total Wt': v(m['release_tree_total_wt_total']),
          'Loss': v(m['loss_total']),
        },
        lossKey: 'loss_total');
    add('tree_cutting_office', 'Tree Cutting Office', (m) => '${v(m['office_count'], '0')} office',
        ['Sr', 'Buch No', 'Tree Wt', 'Tree Bhuko', 'Remaining Tree Wt', 'Office At'],
        ['sr', 'buch_no', 'tree_wt', 'tree_bhuko', 'remaining_tree_wt', 'office_at_view'],
            (m) => {
          'Tree Wt': v(m['tree_wt_total']),
          'Tree Bhuko': v(m['tree_bhuko_total']),
          'Remaining Tree Wt': v(m['remaining_tree_wt_total']),
        });
    add('tree_cutting_issue', 'Tree Cutting Issue', (m) => '${v(m['issued_count'], '0')} issued',
        ['Sr', 'Buch No', 'Worker', 'Receive Tree Wt', 'Issued At'],
        ['sr', 'buch_no', 'worker_name', 'receive_tree_wt', 'issued_at_view'],
            (m) => {'Receive Tree Wt': v(m['receive_tree_wt_total'])});
    add('tree_cutting_receive', 'Tree Cutting Receive', (m) => '${v(m['received_count'], '0')} received',
        ['Sr', 'Buch No', 'Worker', 'Receive Pc Wt', 'Receive Tree Bhuko', 'Loss', 'Received At'],
        ['sr', 'buch_no', 'worker_name', 'receive_pc_wt', 'receive_tree_bhuko', 'loss', 'received_at_view'],
            (m) => {
          'Receive Pc Wt': v(m['receive_pc_wt_total']),
          'Receive Tree Bhuko': v(m['receive_tree_bhuko_total']),
          'Loss': v(m['loss_total']),
        },
        lossKey: 'loss_total');
    add('casting_sorting', 'Casting Sorting',
            (m) => '${v(m['sorting_count'], '0')} sorted / ${v(m['quantity_total'], '0')} qty',
        ['Sr', 'Item', 'Weight', 'Quantity', 'Sorted At'], ['sr', 'item', 'weight', 'quantity', 'sorted_at_view'],
            (m) => {'Weight': v(m['sorting_wt_total']), 'Quantity': v(m['quantity_total'], '0')});
    return out;
  }
}

/// 🛠️ job work helpers (jobwork-issues · jobwork-receive)
class _Job {
  static String s(dynamic v) {
    final x = (v ?? '').toString().trim();
    return (x.isEmpty || x == 'null') ? '' : x;
  }

  static double n(dynamic v) => double.tryParse((v ?? '').toString().replaceAll(',', '').trim()) ?? 0;

  static String workerOf(Map m) {
    final jw = m['job_worker'];
    final w = s(jw is Map ? jw['name'] : (m['jobworker_name'] ?? m['job_worker_name'] ?? m['worker_name']));
    return w.isEmpty ? '-' : w;
  }

  static String stepOf(Map m) {
    final ps = m['production_step'];
    return s(ps is Map ? ps['name'] : m['production_step_name']);
  }

  static String itemsOf(Map m) {
    final its = m['items'] is List ? (m['items'] as List).whereType<Map>() : const <Map>[];
    return its
        .map((i) {
      final it = i['item'];
      return s(it is Map ? (it['item_name'] ?? it['name']) : (i['item_name'] ?? i['name']));
    })
        .where((e) => e.isNotEmpty)
        .toSet()
        .join(', ');
  }

  static DateTime? issueDate(Map m) => _Data.date(m['voucher_date'] ?? m['issue_date'] ?? m['created_at']);
  static DateTime? recvDate(Map m) => _Data.date(m['receive_date'] ?? m['voucher_date'] ?? m['created_at']);
}

class _JobIssue {
  final String voucher, worker, step, items;
  final DateTime? date;
  final double pcs, gross, net;
  String branch = ''; // 🏢 branch merge
  _JobIssue(this.voucher, this.worker, this.step, this.items, this.date, this.pcs, this.gross, this.net);

  static _JobIssue from(Map m, {String branch = ''}) {
    final its = m['items'] is List ? (m['items'] as List).whereType<Map>().toList() : const <Map>[];
    var gross = _Job.n(m['gross_wt_sum']);
    var net = _Job.n(m['net_wt_sum']);
    if (gross == 0) gross = its.fold(0.0, (a, i) => a + _Job.n(i['gross_wt'] ?? i['gross_weight']));
    if (net == 0) net = its.fold(0.0, (a, i) => a + _Job.n(i['net_wt'] ?? i['net_weight']));
    final v = _Job.s(m['voucher_no']);
    return _JobIssue(v.isEmpty ? '-' : v, _Job.workerOf(m), _Job.stepOf(m), _Job.itemsOf(m), _Job.issueDate(m),
        its.fold(0.0, (a, i) => a + _Job.n(i['qty_pcs'])), gross, net)
      ..branch = branch;
  }
}

class _JobRecv {
  final String voucher, worker, step, items, status;
  final DateTime? date;
  final double issued, received, pending;
  String branch = ''; // 🏢 branch merge
  _JobRecv(this.voucher, this.worker, this.step, this.items, this.status, this.date, this.issued, this.received,
      this.pending);

  bool get completed => status == 'completed' || status == 'complete';

  /// + = LOSS (metal less came back) · − = PROFIT / gain (more came back)
  double get lossGain => issued - received - pending;

  static _JobRecv from(Map m, {String branch = ''}) {
    final issued = _Job.n(m['issue_net_wt']);
    final received = _Job.n(m['receive_net_wt']);
    var pending = _Job.n(m['pending_net_wt']);
    final status = _Job.s(m['status']).toLowerCase();
    if (status == 'completed' || status == 'complete') pending = 0; // done → whatever is short is loss
    final v = _Job.s(m['voucher_no']);
    return _JobRecv(v.isEmpty ? '-' : v, _Job.workerOf(m), _Job.stepOf(m), _Job.itemsOf(m), status, _Job.recvDate(m),
        issued, received, pending)
      ..branch = branch;
  }
}

class _LabelLine {
  final String label, item, huid, printedAt;
  final double gross, other, net;
  final bool printed;
  final DateTime? created;
  // 📍 where the piece is NOW (from barcode history)
  String place = ''; // In stock | On approval | Sold | Sold from approval | Returned
  String placeVoucher = '';
  String placeDate = '';
  _LabelLine({
    required this.label,
    required this.item,
    required this.huid,
    required this.gross,
    required this.other,
    required this.net,
    required this.printed,
    required this.created,
    required this.printedAt,
  });
}

/// 📦 one row of reports/stock-position (item × stock type × customer)
class _PosRow {
  String branch = '';
  String item = '';
  String typeKey = '';
  String typeName = '';
  String customer = '';
  DateTime? date; // created_at (added on)
  double qty = 0, withImage = 0, withoutImage = 0;
  double gross = 0, less = 0, net = 0, fine = 0;
  double labour = 0, other = 0;

  static double _n(dynamic v) => double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;

  static _PosRow from(Map m, String branch) {
    final r = _PosRow()
      ..branch = branch
      ..item = (m['item_name'] ?? m['name'] ?? '-').toString().trim()
      ..typeKey = (m['stock_type'] ?? 'other').toString()
      ..customer = (m['customer_name'] ?? '').toString().trim()
      ..qty = _n(m['qty_pcs'] ?? m['qty'])
      ..withImage = _n(m['with_image'])
      ..withoutImage = _n(m['without_image'])
      ..gross = _n(m['gross_weight'])
      ..less = _n(m['less_weight'] ?? m['other_weight'])
      ..net = _n(m['net_weight'])
      ..fine = _n(m['fine_weight'])
      ..labour = _n(m['labour_amount'])
      ..other = _n(m['other_amount'])
      ..date = _Data.date(m['created_at'] ?? m['date']);
    final tn = (m['stock_type_name'] ?? '').toString().trim();
    r.typeName = tn.isNotEmpty
        ? tn
        : r.typeKey.split('_').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    if (r.customer == '-' || r.customer == 'null') r.customer = '';
    return r;
  }

  /// data[] → rows. Handles both:
  ///   flat  : data: [{item_name…, company_id}]
  ///   nested: data / branches: [{company_name, data|rows|items: [{item_name…}]}]
  static List<_PosRow> listFrom(dynamic body, {required String Function(Map) branchOf}) {
    if (body is List<int>) body = utf8.decode(body);
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    List list = const [];
    if (body is List) {
      list = body;
    } else if (body is Map) {
      final d = body['data'];
      if (d is List) {
        list = d;
      } else if (d is Map && d['data'] is List) {
        list = d['data'];
      } else if (d is Map && d['branches'] is List) {
        list = d['branches'];
      } else if (body['branches'] is List) {
        list = body['branches'];
      }
    }
    final out = <_PosRow>[];
    bool hasBranch(Map m) =>
        m['company_id'] != null || m['branch'] != null || m['branch_name'] != null || m['company'] != null ||
            m['company_name'] != null;
    for (final m in list.whereType<Map>()) {
      final inner = m['data'] ?? m['rows'] ?? m['items'] ?? m['stock'];
      if (m['item_name'] == null && inner is List) {
        // 🏢 nested branch group
        final b = (m['company_name'] ?? m['branch_name'] ?? m['name'] ?? '').toString().trim();
        final tag = b.isNotEmpty ? b : (hasBranch(m) ? branchOf(m) : '');
        for (final r in inner.whereType<Map>()) {
          out.add(from(r, hasBranch(r) ? branchOf(r) : tag));
        }
      } else {
        out.add(from(m, hasBranch(m) ? branchOf(m) : ''));
      }
    }
    return out;
  }
}

class _StockLine {
  final String label, item, huid;
  final double gross, other, net;
  final bool sold;
  final DateTime? date; // added (in / all) or sold (out) — used for grouping
  final DateTime? soldOn;
  final String? imageUrl; // download url (preferred)
  final String? imageUrl2; // gallery url (fallback)
  pw.MemoryImage? image;
  _StockLine({
    required this.label,
    required this.item,
    required this.huid,
    required this.gross,
    required this.other,
    required this.net,
    required this.sold,
    required this.date,
    required this.soldOn,
    required this.imageUrl,
    this.imageUrl2,
  });
}

// =======================================================================
//  📒 METAL LEDGER DATA  (reports/worker-loss?mode=ledger&format=daily)
//  data.groups[] → { worker_id, worker_name, metal, opening, debit, credit, closing, rows[] }
//  balance: + = Dr (metal pending with worker), − = Cr (worker got extra)
// =======================================================================
class _LRow {
  final DateTime date;
  final String text; // voucher · item (daily)
  final String voucher, type, item; // detailed ledger columns
  final double debit, credit, balance;
  _LRow(this.date, this.text, this.debit, this.credit, this.balance,
      {this.voucher = '', this.type = '', this.item = ''});
}

class _LGroup {
  final int? workerId;
  final String worker, metal;
  final double opening, debit, credit, closing;
  final List<_LRow> rows;
  _LGroup(this.workerId, this.worker, this.metal, this.opening, this.debit, this.credit, this.closing, this.rows);
}

class _LedgerData {
  static double _d(dynamic v) => double.tryParse(v?.toString().replaceAll(',', '') ?? '') ?? 0;
  static String _s(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return (t.isEmpty || t == 'null' || t == '-') ? '' : t;
  }

  static List<_LGroup> groups(dynamic body, {String Function(Map g)? tag}) {
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    if (body is! Map) return [];
    final data = body['data'];
    final list = data is Map ? data['groups'] : body['groups'];
    if (list is! List) return [];
    return list.whereType<Map>().map((g) {
      final rows = (g['rows'] is List ? g['rows'] as List : const [])
          .whereType<Map>()
          .map((r) => _LRow(
        _Data.date(r['date']) ?? DateTime(2000),
        [_s(r['voucher_no'] ?? r['reference']), _s(r['item_name'] ?? r['particulars'] ?? r['item'])]
            .where((e) => e.isNotEmpty)
            .join(' · '),
        _d(r['debit']),
        _d(r['credit']),
        _d(r['balance']),
        voucher: _s(r['voucher_no'] ?? r['reference']),
        type: _s(r['type'] ?? r['entry_type']),
        item: _s(r['item_name'] ?? r['item'] ?? r['particulars']),
      ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final t = tag?.call(g) ?? '';
      final name = _s(g['worker_name']) + (t.isEmpty || _s(g['worker_name']).isEmpty ? '' : ' · $t');
      final metal = _s(g['metal']);
      final opening = _d(g['opening']);
      final debit = g['debit'] != null ? _d(g['debit']) : rows.fold<double>(0, (a, r) => a + r.debit);
      final credit = g['credit'] != null ? _d(g['credit']) : rows.fold<double>(0, (a, r) => a + r.credit);
      final closing = g['closing'] != null ? _d(g['closing']) : (rows.isEmpty ? opening : rows.last.balance);
      return _LGroup(int.tryParse(g['worker_id']?.toString() ?? ''), name.isEmpty ? 'No Worker' : name,
          metal.isEmpty ? 'Metal' : metal, opening, debit, credit, closing, rows);
    }).toList();
  }
}

// =======================================================================
//  PDF (premium navy + gold, landscape)
// =======================================================================
class _ReportPdf {
  static const _navy = PdfColor.fromInt(0xff0F2A4A);
  static const _gold = PdfColor.fromInt(0xffC9A24A);
  static const _goldSoft = PdfColor.fromInt(0xffF6EEDB);
  static const _cream = PdfColor.fromInt(0xffFBF9F4);
  static const _line = PdfColor.fromInt(0xffE6E0D2);
  static const _ink = PdfColor.fromInt(0xff1B2433);
  static const _grey = PdfColor.fromInt(0xff6B7487);
  static const _green = PdfColor.fromInt(0xff1E7B3A);
  static const _orange = PdfColor.fromInt(0xffB86A0C);
  static const _red = PdfColor.fromInt(0xffB3261E);

  static final NumberFormat _amt = NumberFormat('#,##,##0.00', 'en_IN');
  static String w(double v) => v.toStringAsFixed(3);
  static String a(double v) => _amt.format(v);
  static String q(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static Future<({String name, String place, pw.MemoryImage? logo})> _brand() async {
    String name = 'Ornasphere', place = '', logoUrl = '';
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
    if (logoUrl.isNotEmpty) {
      try {
        final u = logoUrl.startsWith('http') ? logoUrl : '$_site${logoUrl.replaceFirst(RegExp(r'^/'), '')}';
        final res = await Dio(BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        )).get<List<int>>(u);
        if (res.data != null && res.data!.length > 100) logo = pw.MemoryImage(Uint8List.fromList(res.data!));
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

  static Future<File> build({
    String kind = 'approval', // approval | sale | party
    required String customer,
    required String range,
    required List<_Section> sections,
    String? branch, // 🏢 branch mode → names of selected branches
  }) async {
    final sale = kind == 'sale';
    final party = kind == 'party';
    final reportName = party ? 'Party wise report' : (sale ? 'Sales report' : 'Approval report');
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    pw.Widget header(pw.Context ctx) => _header(
        brand,
        party ? 'PARTY WISE REPORT' : (sale ? 'SALES REPORT' : 'APPROVAL REPORT'),
        party ? 'All details · item-wise' : 'Item-wise');

    pw.Widget info() => pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Row(children: [
        _kv(party ? 'Party' : 'Customer', customer),
        _kv('Range', range),
        if (branch != null) _kv('Branch', branch),
        _kv('Sections', branch != null ? '${sections.length} (branch wise)' : sections.map((s) => s.title).join(' + ')),
        _kv('Generated', made),
      ]),
    );

    final given = sections.where((s) => s.title == 'Approval Issue').toList();
    final ret = sections.where((s) => s.title == 'Approval Return').toList();
    final sold = sections.where((s) => s.title == 'Sold From Approval').toList();
    final soldSec = sold.isNotEmpty ? sold.first : null;
    final both = given.isNotEmpty; // balance comes from the approval items themselves

    final content = <pw.Widget>[info()];
    // 👤 party wise → one overview table of everything first
    // 👤 party / 🏢 branch wise → one overview table first
    if (party || (branch != null && sections.length > 1)) {
      content.add(_partyOverview(sections, heading: party ? 'PARTY OVERVIEW' : 'BRANCH WISE OVERVIEW'));
    }
    // quick idea at the top: how much is still pending on approval
    if (both) content.add(_pendingBanner(given.first, ret.isNotEmpty ? ret.first : null, soldSec));
    for (final s in sections) {
      content.add(_sectionTitle(s));
      content.add(_summary(s));
      content.add(pw.SizedBox(height: 6));
      if (s.lines.isEmpty) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Text('No ${s.title.toLowerCase()} found for this customer and range.',
              style: const pw.TextStyle(color: _grey, fontSize: 9)),
        ));
      } else {
        content.add(_table(s,
            lastCol: (sale || (party && s.title.startsWith('Sales')) || s.title.startsWith('Approval Outstanding'))
                ? 'Customer'
                : 'Status'));
      }
      content.add(pw.SizedBox(height: 16));
    }
    // ⚖️ BOTH TOTAL: Approval issue − Approval return = still pending
    if (both) content.add(_balance(given.first, ret.isNotEmpty ? ret.first : null, soldSec));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000, // 🔥 big lists (All items) — default 20 pages gave an error
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: header,
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · $reportName · $customer', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = customer.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/${party ? 'Party' : (sale ? 'Sales' : 'Approval')}_Report_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  // -------------------------------------------------------------------
  //  shared header (navy + gold)
  // -------------------------------------------------------------------
  static pw.Widget _header(({String name, String place, pw.MemoryImage? logo}) brand, String title, String sub) =>
      pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Row(children: [
            if (brand.logo != null)
              pw.Container(
                width: 38,
                height: 38,
                margin: const pw.EdgeInsets.only(right: 10),
                padding: const pw.EdgeInsets.all(3),
                decoration:
                const pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Image(brand.logo!, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(brand.name, style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                if (brand.place.isNotEmpty)
                  pw.Text(brand.place, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8.5)),
              ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(title, style: pw.TextStyle(color: _gold, fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(sub, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
            ]),
          ]),
        ),
        pw.Container(height: 2, color: _gold, margin: const pw.EdgeInsets.only(top: 3, bottom: 8)),
      ]);

  static String bal(double v) {
    if (v.abs() < 0.0005) return '0.000';
    return '${w(v.abs())} ${v > 0 ? 'Dr' : 'Cr'}';
  }

  // -------------------------------------------------------------------
  //  📦 STOCK PDF — date wise, optional photos
  // -------------------------------------------------------------------
  static Future<File> buildStock({
    required String item,
    required String range,
    required String status, // in | out | all
    required bool withImages,
    String photoMode = 'any', // any | with | without
    required List<_StockLine> lines,
  }) async {
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final statusText = status == 'in' ? 'In stock' : (status == 'out' ? 'Out of stock (sold)' : 'All stock');

    // ---- group by date (newest first) ----
    final groups = <String, List<_StockLine>>{};
    final sorted = [...lines]..sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    for (final l in sorted) {
      groups.putIfAbsent(l.date == null ? 'No date' : DateFormat('dd-MM-yyyy').format(l.date!), () => []).add(l);
    }

    double sum(Iterable<_StockLine> ls, double Function(_StockLine) f) => ls.fold(0, (a, l) => a + f(l));
    final inCount = lines.where((l) => !l.sold).length;
    final outCount = lines.length - inCount;
    final photoCount = lines.where((l) => l.image != null).length;

    pw.Widget cell(String t, {bool head = false, bool left = false, PdfColor? color, bool bold = false, double size = 8.3}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
          child: pw.Text(
            t,
            textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: head ? 7.8 : size,
              color: head ? PdfColors.white : (color ?? _ink),
              fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    pw.Widget statusCell(_StockLine l) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: pw.BoxDecoration(
          color: l.sold ? const PdfColor.fromInt(0xffFDECEC) : const PdfColor.fromInt(0xffE8F6EE),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Text(l.sold ? 'Sold' : 'In stock',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: l.sold ? _red : _green)),
      ),
    );

    final content = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(children: [
          _kv('Item', item),
          _kv('Status', statusText),
          _kv('Range', range),
          _kv('Photos', photoMode == 'with' ? 'Only with image' : photoMode == 'without' ? 'Without image' : 'All pieces'),
          _kv('Generated', made),
        ]),
      ),
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          _bannerKv('TOTAL PIECES', '${lines.length}', _gold, big: true),
          _bannerKv('Gross wt', '${w(sum(lines, (l) => l.gross))} g', PdfColors.white),
          _bannerKv('Other wt', '${w(sum(lines, (l) => l.other))} g', PdfColors.white),
          _bannerKv('NET WT', '${w(sum(lines, (l) => l.net))} g', _gold, big: true),
          if (status == 'all') _bannerKv('In stock / Sold', '$inCount / $outCount', PdfColors.white),
          if (withImages) _bannerKv('With photo', '$photoCount', PdfColors.white),
          _bannerKv('Days', '${groups.length}', PdfColors.white),
        ]),
      ),
    ];

    if (lines.isEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        child: pw.Text('No stock found for this item and range.', style: const pw.TextStyle(color: _grey, fontSize: 10)),
      ));
    }

    var serial = 0;
    for (final e in groups.entries) {
      final ls = e.value;
      content.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 6, top: 4),
        decoration: const pw.BoxDecoration(
          color: _goldSoft,
          border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(
                '${status == 'out' ? 'SOLD ON' : 'ADDED ON'}  ${e.key}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
          ),
          pw.Text('${ls.length} pcs  ·  gross ${w(sum(ls, (l) => l.gross))} g  ·  net ${w(sum(ls, (l) => l.net))} g',
              style: pw.TextStyle(fontSize: 8.5, color: _navy, fontWeight: pw.FontWeight.bold)),
        ]),
      ));

      final rows = <pw.TableRow>[
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _navy),
          children: [
            cell('#', head: true, left: true),
            if (withImages) cell('Photo', head: true, left: true),
            cell('Label', head: true, left: true),
            cell('Item', head: true, left: true),
            cell('HUID', head: true, left: true),
            cell('Gross (g)', head: true),
            cell('Other (g)', head: true),
            cell('Net (g)', head: true),
            if (status != 'in') cell('Sold on', head: true, left: true),
            cell('Status', head: true, left: true),
          ],
        ),
      ];
      for (var i = 0; i < ls.length; i++) {
        final l = ls[i];
        serial++;
        rows.add(pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream),
          children: [
            cell('$serial', left: true, color: _grey),
            if (withImages)
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: l.image != null
                    ? pw.Container(
                  width: 54,
                  height: 54,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _line),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(l.image!, fit: pw.BoxFit.cover),
                  ),
                )
                    : pw.Container(
                  width: 54,
                  height: 54,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: _cream,
                    border: pw.Border.all(color: _line),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text('No photo', style: const pw.TextStyle(fontSize: 6.5, color: _grey)),
                ),
              ),
            cell(l.label, left: true, bold: true),
            cell(l.item, left: true),
            cell(l.huid.isEmpty ? '-' : l.huid, left: true, color: _grey),
            cell(w(l.gross)),
            cell(l.other == 0 ? '-' : w(l.other)),
            cell(w(l.net), bold: true),
            if (status != 'in') cell(l.soldOn == null ? '-' : DateFormat('dd-MM-yyyy').format(l.soldOn!), left: true),
            statusCell(l),
          ],
        ));
      }
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: _goldSoft),
        children: [
          cell(''),
          if (withImages) cell(''),
          cell('TOTAL', left: true, bold: true),
          cell('${ls.length} pcs', left: true, bold: true),
          cell(''),
          cell(w(sum(ls, (l) => l.gross)), bold: true),
          cell(w(sum(ls, (l) => l.other)), bold: true),
          cell(w(sum(ls, (l) => l.net)), bold: true, color: _navy),
          if (status != 'in') cell(''),
          cell(''),
        ],
      ));

      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(26),
          if (withImages) 1: const pw.FixedColumnWidth(62),
          (withImages ? 2 : 1): const pw.FlexColumnWidth(1.1),
          (withImages ? 3 : 2): const pw.FlexColumnWidth(2.4),
          (withImages ? 4 : 3): const pw.FlexColumnWidth(1.2),
          (withImages ? 5 : 4): const pw.FlexColumnWidth(1.0),
          (withImages ? 6 : 5): const pw.FlexColumnWidth(0.9),
          (withImages ? 7 : 6): const pw.FlexColumnWidth(1.0),
          if (status != 'in') (withImages ? 8 : 7): const pw.FlexColumnWidth(1.0),
          (withImages ? (status != 'in' ? 9 : 8) : (status != 'in' ? 8 : 7)): const pw.FlexColumnWidth(0.9),
        },
        children: rows,
      ));
      content.add(pw.SizedBox(height: 12));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000, // 🔥 big lists (All items) — default 20 pages gave an error
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand, 'STOCK REPORT', '$statusText · date wise${photoMode == 'with' ? ' · with image' : photoMode == 'without' ? ' · without image' : ''}'),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · Stock report · $item', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = item.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/Stock_${status}_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  // -------------------------------------------------------------------
  //  📦 STOCK POSITION PDF — branch wise · stock type wise · item rows
  // -------------------------------------------------------------------
  static Future<File> buildStockPosition({
    required String item,
    required String type,
    String range = 'All dates',
    required String branch,
    required Map<String, List<_PosRow>> groups,
  }) async {
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final all = groups.values.expand((e) => e).toList();
    double sum(Iterable<_PosRow> ls, double Function(_PosRow) f) => ls.fold(0, (a, l) => a + f(l));

    String wt(double v) => v == 0 ? '-' : w(v);
    String am(double v) => v == 0 ? '-' : a(v);
    PdfColor tone(double v) => v < 0 ? _red : _ink;

    pw.Widget cell(String t, {bool head = false, bool left = false, PdfColor? color, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        t,
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: head ? 7.6 : 8.1,
          color: head ? PdfColors.white : (color ?? _ink),
          fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    final content = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(children: [
          _kv('Item', item),
          _kv('Stock type', type),
          _kv('Range', range),
          _kv('Branch', branch),
          _kv('Generated', made),
        ]),
      ),
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          _bannerKv('TOTAL PCS', q(sum(all, (r) => r.qty)), _gold, big: true),
          _bannerKv('Gross wt', '${w(sum(all, (r) => r.gross))} g', PdfColors.white),
          _bannerKv('Less wt', '${w(sum(all, (r) => r.less))} g', PdfColors.white),
          _bannerKv('NET WT', '${w(sum(all, (r) => r.net))} g', _gold, big: true),
          _bannerKv('FINE WT', '${w(sum(all, (r) => r.fine))} g', _gold, big: true),
          _bannerKv('Image / No image', '${q(sum(all, (r) => r.withImage))} / ${q(sum(all, (r) => r.withoutImage))}',
              PdfColors.white),
          if (groups.length > 1) _bannerKv('Branches', '${groups.length}', PdfColors.white),
        ]),
      ),
    ];

    // 🏢 BRANCH WISE OVERVIEW
    if (groups.length > 1) {
      content.add(pw.Text('BRANCH WISE OVERVIEW',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)));
      content.add(pw.SizedBox(height: 5));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {0: pw.FlexColumnWidth(2.2)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _navy), children: [
            cell('Branch', head: true, left: true),
            cell('Rows', head: true),
            cell('Pcs', head: true),
            cell('Gross (g)', head: true),
            cell('Less (g)', head: true),
            cell('Net (g)', head: true),
            cell('Fine (g)', head: true),
            cell('Labour', head: true),
            cell('Other', head: true),
          ]),
          for (final (i, e) in groups.entries.indexed)
            pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
              cell(e.key, left: true, bold: true),
              cell('${e.value.length}'),
              cell(q(sum(e.value, (r) => r.qty))),
              cell(w(sum(e.value, (r) => r.gross))),
              cell(w(sum(e.value, (r) => r.less))),
              cell(w(sum(e.value, (r) => r.net)), bold: true),
              cell(w(sum(e.value, (r) => r.fine)), bold: true, color: _navy),
              cell(am(sum(e.value, (r) => r.labour))),
              cell(am(sum(e.value, (r) => r.other))),
            ]),
          pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
            cell('TOTAL', left: true, bold: true),
            cell('${all.length}', bold: true),
            cell(q(sum(all, (r) => r.qty)), bold: true),
            cell(w(sum(all, (r) => r.gross)), bold: true),
            cell(w(sum(all, (r) => r.less)), bold: true),
            cell(w(sum(all, (r) => r.net)), bold: true),
            cell(w(sum(all, (r) => r.fine)), bold: true, color: _navy),
            cell(am(sum(all, (r) => r.labour)), bold: true),
            cell(am(sum(all, (r) => r.other)), bold: true),
          ]),
        ],
      ));
      content.add(pw.SizedBox(height: 16));
    }

    if (all.isEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        child: pw.Text('No stock found for this item and stock type.', style: const pw.TextStyle(color: _grey, fontSize: 10)),
      ));
    }

    // ---- one section per branch ----
    for (final e in groups.entries) {
      final ls = e.value;
      content.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 6, top: 4),
        decoration: const pw.BoxDecoration(
          color: _goldSoft,
          border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('BRANCH  ${e.key.toUpperCase()}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
          ),
          pw.Text(
              '${q(sum(ls, (r) => r.qty))} pcs  ·  net ${w(sum(ls, (r) => r.net))} g  ·  fine ${w(sum(ls, (r) => r.fine))} g',
              style: pw.TextStyle(fontSize: 8.5, color: _navy, fontWeight: pw.FontWeight.bold)),
        ]),
      ));

      // stock type → rows (type order as in API, items A-Z)
      final byType = <String, List<_PosRow>>{};
      for (final r in ls) {
        byType.putIfAbsent(r.typeName, () => []).add(r);
      }

      final rows = <pw.TableRow>[
        pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
          cell('#', head: true, left: true),
          cell('Item', head: true, left: true),
          cell('Customer', head: true, left: true),
          cell('Added on', head: true, left: true),
          cell('Pcs', head: true),
          cell('Img / No', head: true),
          cell('Gross (g)', head: true),
          cell('Less (g)', head: true),
          cell('Net (g)', head: true),
          cell('Fine (g)', head: true),
          cell('Labour', head: true),
          cell('Other', head: true),
        ]),
      ];
      var serial = 0;
      for (final t in byType.entries) {
        final tl = [...t.value]..sort((x, y) => x.item.toLowerCase().compareTo(y.item.toLowerCase()));
        // type heading row
        rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffEEF1F7)), children: [
          cell(''),
          cell(t.key.toUpperCase(), left: true, bold: true, color: _navy),
          for (var i = 0; i < 10; i++) cell(''),
        ]));
        for (var i = 0; i < tl.length; i++) {
          final r = tl[i];
          serial++;
          rows.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
            cell('$serial', left: true, color: _grey),
            cell(r.item, left: true, bold: true),
            cell(r.customer.isEmpty ? '-' : r.customer, left: true, color: _grey),
            cell(r.date == null ? '-' : DateFormat('dd-MM-yyyy').format(r.date!), left: true, color: _grey),
            cell(q(r.qty), color: tone(r.qty)),
            cell('${q(r.withImage)} / ${q(r.withoutImage)}', color: _grey),
            cell(wt(r.gross), color: tone(r.gross)),
            cell(wt(r.less)),
            cell(wt(r.net), bold: true, color: tone(r.net)),
            cell(wt(r.fine), bold: true, color: r.fine < 0 ? _red : _navy),
            cell(am(r.labour)),
            cell(am(r.other)),
          ]));
        }
        // type subtotal
        rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
          cell(''),
          cell('${t.key} total', left: true, bold: true),
          cell('${tl.length} rows', left: true, color: _grey),
          cell(''),
          cell(q(sum(tl, (r) => r.qty)), bold: true),
          cell(''),
          cell(w(sum(tl, (r) => r.gross)), bold: true),
          cell(w(sum(tl, (r) => r.less)), bold: true),
          cell(w(sum(tl, (r) => r.net)), bold: true),
          cell(w(sum(tl, (r) => r.fine)), bold: true, color: _navy),
          cell(am(sum(tl, (r) => r.labour)), bold: true),
          cell(am(sum(tl, (r) => r.other)), bold: true),
        ]));
      }
      // branch total
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _navy), children: [
        cell('', head: true),
        cell('BRANCH TOTAL', head: true, left: true),
        cell('${ls.length} rows', head: true, left: true),
        cell('', head: true),
        cell(q(sum(ls, (r) => r.qty)), head: true),
        cell('${q(sum(ls, (r) => r.withImage))} / ${q(sum(ls, (r) => r.withoutImage))}', head: true),
        cell(w(sum(ls, (r) => r.gross)), head: true),
        cell(w(sum(ls, (r) => r.less)), head: true),
        cell(w(sum(ls, (r) => r.net)), head: true),
        cell(w(sum(ls, (r) => r.fine)), head: true),
        cell(am(sum(ls, (r) => r.labour)), head: true),
        cell(am(sum(ls, (r) => r.other)), head: true),
      ]));

      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(2.2),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(0.9),
          4: pw.FlexColumnWidth(0.6),
          5: pw.FlexColumnWidth(0.8),
          6: pw.FlexColumnWidth(1.0),
          7: pw.FlexColumnWidth(0.8),
          8: pw.FlexColumnWidth(1.0),
          9: pw.FlexColumnWidth(1.0),
          10: pw.FlexColumnWidth(0.9),
          11: pw.FlexColumnWidth(0.9),
        },
        children: rows,
      ));
      content.add(pw.SizedBox(height: 14));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand, 'STOCK POSITION', '$type · $range · ${groups.length > 1 ? 'branch wise' : branch}'),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · Stock position · $item', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = item.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/Stock_Position_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  // -------------------------------------------------------------------
  //  🧾 VOUCHER HISTORY PDF — one voucher, every stage
  // -------------------------------------------------------------------
  static Future<File> buildHistory({
    required Map<String, dynamic> voucher,
    required Map<String, dynamic> history,
    required List<_HistStage> stages,
  }) async {
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final sum = history['summary'] is Map ? history['summary'] as Map : const {};
    String val(List<dynamic> xs, [String d = '-']) {
      for (final x in xs) {
        final s = (x ?? '').toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
      return d;
    }

    final vno = val([voucher['voucher_no']]);
    final totalLoss = stages.fold<double>(0, (a, s) => a + s.loss);

    pw.Widget cell(String t, {bool head = false, bool left = false, PdfColor? color, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        t,
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: head ? 7.8 : 8.2,
          color: head ? PdfColors.white : (color ?? _ink),
          fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    // text columns left, numbers right
    bool isText(String k) => k == 'buch_no' || k == 'worker_name' || k == 'item' || k.endsWith('_view') || k == 'sr';

    final content = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(children: [
          _kv('Voucher No', vno),
          _kv('Voucher Date', val([voucher['voucher_date_view'], voucher['voucher_date']])),
          _kv('Process', val([voucher['process_name']])),
          _kv('Worker', val([voucher['worker_name']])),
          _kv('Created At', val([voucher['created_at_view']])),
          _kv('Generated', made),
        ]),
      ),
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          _bannerKv('GROSS WT', '${val([sum['gross_wt'], voucher['gross_wt_total']], '0.000')} g', _gold, big: true),
          _bannerKv('Buch wt', '${val([sum['buch_wt'], voucher['buch_wt_total']], '0.000')} g', PdfColors.white),
          _bannerKv('NET WT', '${val([sum['net_wt'], voucher['net_wt_total']], '0.000')} g', _gold, big: true),
          _bannerKv('Silver wt', '${val([sum['silver_wt'], voucher['silver_wt_total']], '0.000')} g', PdfColors.white),
          _bannerKv('Total pcs', val([sum['total_pcs'], voucher['total_pcs']], '0'), PdfColors.white),
          _bannerKv('Total loss', '${w(totalLoss)} g',
              totalLoss > 0.0005 ? const PdfColor.fromInt(0xffFCA5A5) : PdfColors.white),
        ]),
      ),
    ];

    // ---- stage progress strip ----
    content.add(pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < stages.length; i++)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: stages[i].rows.isNotEmpty ? const PdfColor.fromInt(0xffE8F6EE) : _cream,
              border: pw.Border.all(color: stages[i].rows.isNotEmpty ? _green : _line, width: 0.6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text('${i + 1}. ${stages[i].title}${stages[i].rows.isNotEmpty ? '  (done)' : ''}',
                style: pw.TextStyle(
                    fontSize: 7.8,
                    fontWeight: pw.FontWeight.bold,
                    color: stages[i].rows.isNotEmpty ? _green : _grey)),
          ),
      ]),
    ));

    if (stages.isEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        child: pw.Text('No history found for this voucher.', style: const pw.TextStyle(color: _grey, fontSize: 10)),
      ));
    }

    for (var si = 0; si < stages.length; si++) {
      final st = stages[si];
      content.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 6, top: 4),
        decoration: const pw.BoxDecoration(color: _goldSoft, border: pw.Border(left: pw.BorderSide(color: _gold, width: 4))),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('STEP ${si + 1}  ·  ${st.title.toUpperCase()}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
          ),
          pw.Text(st.status, style: pw.TextStyle(fontSize: 8.5, color: _navy, fontWeight: pw.FontWeight.bold)),
        ]),
      ));
      if (st.rows.isEmpty) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10, left: 4),
          child: pw.Text('No data yet for this stage.', style: const pw.TextStyle(color: _grey, fontSize: 8.5)),
        ));
        continue;
      }
      final rows = <pw.TableRow>[
        pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
          for (var c = 0; c < st.columns.length; c++) cell(st.columns[c], head: true, left: isText(st.keys[c])),
        ]),
      ];
      for (var i = 0; i < st.rows.length; i++) {
        final r = st.rows[i];
        rows.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
          for (var c = 0; c < st.keys.length; c++)
            cell(
              st.keys[c] == 'sr' ? val([r['sr']], '${i + 1}') : val([r[st.keys[c]]]),
              left: isText(st.keys[c]),
              color: st.keys[c] == 'loss' ? _red : (st.keys[c] == 'sr' || st.keys[c].endsWith('_view') ? _grey : null),
              bold: st.keys[c] == 'buch_no' || st.keys[c] == 'item',
            ),
        ]));
      }
      if (st.total != null) {
        rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
          for (var c = 0; c < st.columns.length; c++)
            cell(
              c == 1 ? 'TOTAL' : (st.total![st.columns[c]] ?? ''),
              left: c == 1 || isText(st.keys[c]),
              bold: true,
              color: st.columns[c] == 'Loss' ? _red : _navy,
            ),
        ]));
      }
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: {
          for (var c = 0; c < st.keys.length; c++)
            c: st.keys[c] == 'sr'
                ? const pw.FixedColumnWidth(26)
                : pw.FlexColumnWidth(st.keys[c].endsWith('_view') ? 1.4 : (st.keys[c] == 'item' ? 2.0 : 1.0)),
        },
        children: rows,
      ));
      content.add(pw.SizedBox(height: 12));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand, 'VOUCHER HISTORY', '$vno · all stages'),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · Voucher history · $vno', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = vno.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/Voucher_History_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  // -------------------------------------------------------------------
  //  🛠️ JOB WORK PDF — issue · receive · loss / profit
  // -------------------------------------------------------------------
  static Future<File> buildJob({
    required String worker,
    required String range,
    required List<_JobIssue> issues,
    required List<_JobRecv> recvs,
    required bool showIssue,
    required bool showReceive,
  }) async {
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final both = showIssue && showReceive;
    final df = DateFormat('dd-MM-yyyy');
    String d(DateTime? x) => x == null ? '-' : df.format(x);
    double sumI(double Function(_JobIssue) f) => issues.fold(0, (a, e) => a + f(e));
    double sumR(Iterable<_JobRecv> ls, double Function(_JobRecv) f) => ls.fold(0, (a, e) => a + f(e));
    final what = both ? 'Issue + Receive' : (showIssue ? 'Issue' : 'Receive');

    pw.Widget cell(String t, {bool head = false, bool left = false, PdfColor? color, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        t,
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: head ? 7.8 : 8.2,
          color: head ? PdfColors.white : (color ?? _ink),
          fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    pw.Widget badge(String t, PdfColor bg, PdfColor fg) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Text(t, textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7.3, fontWeight: pw.FontWeight.bold, color: fg)),
      ),
    );

    pw.Widget statusBadge(_JobRecv r) => r.completed
        ? badge('Completed', const PdfColor.fromInt(0xffE8F6EE), _green)
        : r.received > 0.0005
        ? badge('Partial', const PdfColor.fromInt(0xffE6F0FF), const PdfColor.fromInt(0xff1D4ED8))
        : badge('Pending', const PdfColor.fromInt(0xffFFF4E5), _orange);

    String lp(double v) => v > 0.0005 ? 'Loss ${w(v)}' : (v < -0.0005 ? 'Profit ${w(-v)}' : '0.000');
    PdfColor lpColor(double v) => v > 0.0005 ? _red : (v < -0.0005 ? _green : _grey);

    pw.Widget title(String t, String right) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const pw.EdgeInsets.only(bottom: 6, top: 4),
      decoration: const pw.BoxDecoration(color: _goldSoft, border: pw.Border(left: pw.BorderSide(color: _gold, width: 4))),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy))),
        pw.Text(right, style: pw.TextStyle(fontSize: 8.5, color: _navy, fontWeight: pw.FontWeight.bold)),
      ]),
    );

    pw.Widget empty(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Text(t, style: const pw.TextStyle(color: _grey, fontSize: 9)),
    );

    final totalLp = sumR(recvs, (e) => e.lossGain);
    final content = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(children: [
          _kv('Worker', worker),
          _kv('Report', what),
          _kv('Range', range),
          _kv('Generated', made),
        ]),
      ),
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          if (showIssue) _bannerKv('ISSUED (net)', '${w(sumI((e) => e.net))} g', _gold, big: true),
          if (showIssue) _bannerKv('Issue vouchers', '${issues.length}', PdfColors.white),
          if (showReceive) _bannerKv('RECEIVED (net)', '${w(sumR(recvs, (e) => e.received))} g', _gold, big: !showIssue),
          if (showReceive) _bannerKv('Pending', '${w(sumR(recvs, (e) => e.pending))} g', PdfColors.white),
          if (both)
            _bannerKv(totalLp > 0.0005 ? 'LOSS' : (totalLp < -0.0005 ? 'PROFIT (gain)' : 'LOSS / PROFIT'),
                '${w(totalLp.abs())} g', totalLp > 0.0005 ? const PdfColor.fromInt(0xffFCA5A5) : const PdfColor.fromInt(0xff86EFAC),
                big: true),
        ]),
      ),
    ];

    double si(List<_JobIssue> ls, double Function(_JobIssue) f) => ls.fold(0, (a, e) => a + f(e));

    void jobBlocks(List<_JobIssue> issues, List<_JobRecv> recvs, String sfx) {
      // ---------------- 📤 ISSUE ----------------
      if (showIssue) {
        content.add(title('JOB WORK ISSUE$sfx',
            '${issues.length} vouchers · gross ${w(si(issues, (e) => e.gross))} g · net ${w(si(issues, (e) => e.net))} g'));
        if (issues.isEmpty) {
          content.add(empty('No job work issue found for this worker and range.'));
        } else {
          final rows = <pw.TableRow>[
            pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
              cell('#', head: true, left: true),
              cell('Date', head: true, left: true),
              cell('Voucher', head: true, left: true),
              cell('Worker', head: true, left: true),
              cell('Step', head: true, left: true),
              cell('Items', head: true, left: true),
              cell('Pcs', head: true),
              cell('Gross (g)', head: true),
              cell('Net (g)', head: true),
            ]),
          ];
          for (var i = 0; i < issues.length; i++) {
            final e = issues[i];
            rows.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
              cell('${i + 1}', left: true, color: _grey),
              cell(d(e.date), left: true),
              cell(e.voucher, left: true, bold: true),
              cell(e.worker, left: true),
              cell(e.step.isEmpty ? '-' : e.step, left: true, color: _grey),
              cell(e.items.isEmpty ? '-' : e.items, left: true),
              cell(e.pcs == 0 ? '-' : q(e.pcs)),
              cell(w(e.gross)),
              cell(w(e.net), bold: true),
            ]));
          }
          rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
            cell(''),
            cell('TOTAL', left: true, bold: true),
            cell('${issues.length} vouchers', left: true, bold: true),
            cell(''),
            cell(''),
            cell(''),
            cell(q(si(issues, (e) => e.pcs)), bold: true),
            cell(w(si(issues, (e) => e.gross)), bold: true),
            cell(w(si(issues, (e) => e.net)), bold: true, color: _navy),
          ]));
          content.add(pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(0.95),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(2.2),
              6: pw.FlexColumnWidth(0.6),
              7: pw.FlexColumnWidth(0.95),
              8: pw.FlexColumnWidth(0.95),
            },
            children: rows,
          ));
        }
        content.add(pw.SizedBox(height: 14));
      }

      // ---------------- 📥 RECEIVE (+ loss / profit when both) ----------------
      if (showReceive) {
        content.add(title('${both ? 'JOB WORK RECEIVE · LOSS / PROFIT' : 'JOB WORK RECEIVE'}$sfx',
            '${recvs.length} vouchers · issued ${w(sumR(recvs, (e) => e.issued))} g · received ${w(sumR(recvs, (e) => e.received))} g'));
        if (recvs.isEmpty) {
          content.add(empty('No job work receive found for this worker and range.'));
        } else {
          final rows = <pw.TableRow>[
            pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
              cell('#', head: true, left: true),
              cell('Date', head: true, left: true),
              cell('Voucher', head: true, left: true),
              cell('Worker', head: true, left: true),
              cell('Step', head: true, left: true),
              cell('Issued (g)', head: true),
              cell('Received (g)', head: true),
              cell('Pending (g)', head: true),
              if (both) cell('Loss / Profit (g)', head: true),
              cell('Status', head: true, left: true),
            ]),
          ];
          for (var i = 0; i < recvs.length; i++) {
            final e = recvs[i];
            rows.add(pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.middle,
              decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream),
              children: [
                cell('${i + 1}', left: true, color: _grey),
                cell(d(e.date), left: true),
                cell(e.voucher, left: true, bold: true),
                cell(e.worker, left: true),
                cell(e.step.isEmpty ? '-' : e.step, left: true, color: _grey),
                cell(w(e.issued)),
                cell(w(e.received), bold: true),
                cell(e.pending > 0.0005 ? w(e.pending) : '-', color: e.pending > 0.0005 ? _orange : _grey),
                if (both) cell(lp(e.lossGain), bold: true, color: lpColor(e.lossGain)),
                statusBadge(e),
              ],
            ));
          }
          rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
            cell(''),
            cell('TOTAL', left: true, bold: true),
            cell('${recvs.length} vouchers', left: true, bold: true),
            cell(''),
            cell(''),
            cell(w(sumR(recvs, (e) => e.issued)), bold: true),
            cell(w(sumR(recvs, (e) => e.received)), bold: true, color: _navy),
            cell(w(sumR(recvs, (e) => e.pending)), bold: true, color: _orange),
            if (both) cell(lp(sumR(recvs, (e) => e.lossGain)), bold: true, color: lpColor(sumR(recvs, (e) => e.lossGain))),
            cell(''),
          ]));
          content.add(pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(0.95),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(0.95),
              6: const pw.FlexColumnWidth(0.95),
              7: const pw.FlexColumnWidth(0.9),
              if (both) 8: const pw.FlexColumnWidth(1.1),
              (both ? 9 : 8): const pw.FlexColumnWidth(0.9),
            },
            children: rows,
          ));
        }
        content.add(pw.SizedBox(height: 14));
      }
    }

    // 🏢 branch merge → like Sale / Approval: overview + one block per branch
    final branchNames = <String>{...issues.map((e) => e.branch), ...recvs.map((e) => e.branch)}.toList();
    final byBranch = branchNames.any((b) => b.isNotEmpty);
    if (byBranch) {
      final rowsB = <pw.TableRow>[
        pw.TableRow(decoration: const pw.BoxDecoration(color: _navy), children: [
          cell('Branch', head: true, left: true),
          if (showIssue) cell('Issue vouchers', head: true),
          if (showIssue) cell('Issued (g)', head: true),
          if (showReceive) cell('Received (g)', head: true),
          if (showReceive) cell('Pending (g)', head: true),
          if (both) cell('Loss / Profit (g)', head: true),
        ]),
      ];
      for (var i = 0; i < branchNames.length; i++) {
        final bn = branchNames[i];
        final bi = issues.where((e) => e.branch == bn).toList();
        final brc = recvs.where((e) => e.branch == bn).toList();
        final v = sumR(brc, (e) => e.lossGain);
        rowsB.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
          cell(bn.isEmpty ? 'Other' : bn, left: true, bold: true, color: _navy),
          if (showIssue) cell('${bi.length}'),
          if (showIssue) cell(w(si(bi, (e) => e.net))),
          if (showReceive) cell(w(sumR(brc, (e) => e.received))),
          if (showReceive) cell(w(sumR(brc, (e) => e.pending)), color: _orange),
          if (both) cell(lp(v), bold: true, color: lpColor(v)),
        ]));
      }
      rowsB.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
        cell('TOTAL', left: true, bold: true),
        if (showIssue) cell('${issues.length}', bold: true),
        if (showIssue) cell(w(sumI((e) => e.net)), bold: true),
        if (showReceive) cell(w(sumR(recvs, (e) => e.received)), bold: true),
        if (showReceive) cell(w(sumR(recvs, (e) => e.pending)), bold: true, color: _orange),
        if (both) cell(lp(totalLp), bold: true, color: lpColor(totalLp)),
      ]));
      content.add(title('BRANCH WISE OVERVIEW', '${branchNames.length} branches'));
      content.add(pw.Table(border: pw.TableBorder.all(color: _line, width: 0.5), children: rowsB));
      content.add(pw.SizedBox(height: 14));

      for (final bn in branchNames) {
        content.add(pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6, top: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Text('BRANCH  ·  ${(bn.isEmpty ? 'Other' : bn).toUpperCase()}',
              style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _gold)),
        ));
        jobBlocks(issues.where((e) => e.branch == bn).toList(), recvs.where((e) => e.branch == bn).toList(),
            ' · ${bn.isEmpty ? 'Other' : bn}');
      }
    } else {
      jobBlocks(issues, recvs, '');
    }

    // ---------------- ⚖️ WORKER WISE LOSS / PROFIT (both) ----------------
    if (both && recvs.isNotEmpty) {
      String wk(String w, String b) => b.isEmpty ? w : '$w · $b';
      final byW = <String, List<_JobRecv>>{};
      for (final e in recvs) {
        byW.putIfAbsent(wk(e.worker, e.branch), () => []).add(e);
      }
      final issByW = <String, double>{};
      for (final e in issues) {
        issByW[wk(e.worker, e.branch)] = (issByW[wk(e.worker, e.branch)] ?? 0) + e.net;
      }
      final keys = byW.keys.toList()
        ..sort((a, b) => sumR(byW[b]!, (e) => e.lossGain).compareTo(sumR(byW[a]!, (e) => e.lossGain)));
      content.add(title('WORKER WISE LOSS / PROFIT', '+ loss = less metal came back · profit = more came back'));
      final rows = <pw.TableRow>[
        pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
          cell('#', head: true, left: true),
          cell('Worker', head: true, left: true),
          cell('Issued in range (g)', head: true),
          cell('Vouchers', head: true),
          cell('Issued (g)', head: true),
          cell('Received (g)', head: true),
          cell('Pending (g)', head: true),
          cell('Loss / Profit (g)', head: true),
          cell('Loss %', head: true),
        ]),
      ];
      for (var i = 0; i < keys.length; i++) {
        final ls = byW[keys[i]]!;
        final iss = sumR(ls, (e) => e.issued);
        final v = sumR(ls, (e) => e.lossGain);
        rows.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
          cell('${i + 1}', left: true, color: _grey),
          cell(keys[i], left: true, bold: true),
          cell(w(issByW[keys[i]] ?? 0), color: _grey),
          cell('${ls.length}'),
          cell(w(iss)),
          cell(w(sumR(ls, (e) => e.received))),
          cell(w(sumR(ls, (e) => e.pending)), color: _orange),
          cell(lp(v), bold: true, color: lpColor(v)),
          cell(iss > 0 ? '${(v / iss * 100).toStringAsFixed(2)}%' : '-', color: lpColor(v)),
        ]));
      }
      final allIss = sumR(recvs, (e) => e.issued);
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
        cell(''),
        cell('TOTAL', left: true, bold: true),
        cell(w(sumI((e) => e.net)), bold: true),
        cell('${recvs.length}', bold: true),
        cell(w(allIss), bold: true),
        cell(w(sumR(recvs, (e) => e.received)), bold: true),
        cell(w(sumR(recvs, (e) => e.pending)), bold: true, color: _orange),
        cell(lp(totalLp), bold: true, color: lpColor(totalLp)),
        cell(allIss > 0 ? '${(totalLp / allIss * 100).toStringAsFixed(2)}%' : '-', bold: true, color: lpColor(totalLp)),
      ]));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(1.8),
          2: pw.FlexColumnWidth(1.1),
          3: pw.FlexColumnWidth(0.7),
          4: pw.FlexColumnWidth(1.0),
          5: pw.FlexColumnWidth(1.0),
          6: pw.FlexColumnWidth(0.9),
          7: pw.FlexColumnWidth(1.2),
          8: pw.FlexColumnWidth(0.8),
        },
        children: rows,
      ));
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
            'Loss / Profit = Issued − Received − Pending. Completed vouchers: whatever did not come back is loss. '
                'Partial vouchers: only the part already settled counts.',
            style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand, 'JOB WORK REPORT', '$what${both ? ' · loss / profit' : ''} · voucher-wise'),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · Job work report · $worker', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = worker.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/JobWork_${both ? 'IssueReceive' : (showIssue ? 'Issue' : 'Receive')}_${safe}_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  // -------------------------------------------------------------------
  //  🏷️ ITEM LABELS PDF — item-wise count + date wise list
  // -------------------------------------------------------------------
  static Future<File> buildLabels({
    required String item,
    required String range,
    required String status, // all | printed | pending
    required List<_LabelLine> lines,
  }) async {
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final statusText =
    status == 'printed' ? 'Printed labels' : (status == 'pending' ? 'Pending labels (not printed)' : 'All labels');
    double sum(Iterable<_LabelLine> ls, double Function(_LabelLine) f) => ls.fold(0, (a, l) => a + f(l));
    final printedCount = lines.where((l) => l.printed).length;
    final pendingCount = lines.length - printedCount;

    // ---- date wise (newest first) ----
    final sorted = [...lines]..sort((a, b) => (b.created ?? DateTime(1900)).compareTo(a.created ?? DateTime(1900)));
    final groups = <String, List<_LabelLine>>{};
    for (final l in sorted) {
      groups.putIfAbsent(l.created == null ? 'No date' : DateFormat('dd-MM-yyyy').format(l.created!), () => []).add(l);
    }
    // ---- item wise count ----
    final byItem = <String, List<_LabelLine>>{};
    for (final l in lines) {
      byItem.putIfAbsent(l.item, () => []).add(l);
    }
    final itemKeys = byItem.keys.toList()..sort((a, b) => byItem[b]!.length.compareTo(byItem[a]!.length));

    // ---- 📍 where is it now ----
    const placeOrder = ['In stock', 'On approval', 'Sold', 'Sold from approval', 'Returned', 'Unknown'];
    final byPlace = <String, List<_LabelLine>>{};
    for (final l in lines) {
      byPlace.putIfAbsent(l.place.isEmpty ? 'Unknown' : l.place, () => []).add(l);
    }
    ({PdfColor bg, PdfColor fg}) placeColor(String p) => switch (p) {
      'In stock' => (bg: const PdfColor.fromInt(0xffE8F6EE), fg: _green),
      'On approval' => (bg: const PdfColor.fromInt(0xffFFF4E5), fg: _orange),
      'Sold' => (bg: const PdfColor.fromInt(0xffFDECEC), fg: _red),
      'Sold from approval' => (bg: const PdfColor.fromInt(0xffF3E8FF), fg: const PdfColor.fromInt(0xff7C3AED)),
      'Returned' => (bg: const PdfColor.fromInt(0xffE6F0FF), fg: const PdfColor.fromInt(0xff1D4ED8)),
      _ => (bg: _cream, fg: _grey),
    };

    pw.Widget cell(String t, {bool head = false, bool left = false, PdfColor? color, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        t,
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: head ? 7.8 : 8.3,
          color: head ? PdfColors.white : (color ?? _ink),
          fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    pw.Widget statusCell(bool printed) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: pw.BoxDecoration(
          color: printed ? const PdfColor.fromInt(0xffE8F6EE) : const PdfColor.fromInt(0xffFFF4E5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Text(printed ? 'Printed' : 'Pending',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: printed ? _green : _orange)),
      ),
    );

    pw.Widget placeCell(_LabelLine l) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: pw.BoxDecoration(
            color: placeColor(l.place).bg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text(l.place.isEmpty ? 'Unknown' : l.place,
              style: pw.TextStyle(fontSize: 7.3, fontWeight: pw.FontWeight.bold, color: placeColor(l.place).fg)),
        ),
        if (l.placeVoucher.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1.5),
            child: pw.Text('${l.placeVoucher}${l.placeDate.isNotEmpty ? ' · ${l.placeDate}' : ''}',
                style: const pw.TextStyle(fontSize: 6.8, color: _grey)),
          ),
      ]),
    );

    pw.Widget title(String t, String right) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const pw.EdgeInsets.only(bottom: 6, top: 4),
      decoration: const pw.BoxDecoration(color: _goldSoft, border: pw.Border(left: pw.BorderSide(color: _gold, width: 4))),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy))),
        pw.Text(right, style: pw.TextStyle(fontSize: 8.5, color: _navy, fontWeight: pw.FontWeight.bold)),
      ]),
    );

    final content = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(children: [
          _kv('Item', item),
          _kv('Status', statusText),
          _kv('Range', range),
          _kv('Generated', made),
        ]),
      ),
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          _bannerKv(status == 'all' ? 'LABELS CREATED' : statusText.toUpperCase(), '${lines.length}', _gold, big: true),
          if (status == 'all') _bannerKv('Printed', '$printedCount', PdfColors.white),
          if (status == 'all') _bannerKv('Pending (not printed)', '$pendingCount', _gold),
          _bannerKv('Items', '${byItem.length}', PdfColors.white),
          _bannerKv('In stock', '${byPlace['In stock']?.length ?? 0}', PdfColors.white),
          _bannerKv('On approval', '${byPlace['On approval']?.length ?? 0}', PdfColors.white),
          _bannerKv('Sold', '${(byPlace['Sold']?.length ?? 0) + (byPlace['Sold from approval']?.length ?? 0)}', PdfColors.white),
          _bannerKv('NET WT', '${w(sum(lines, (l) => l.net))} g', _gold, big: true),
        ]),
      ),
    ];

    if (lines.isEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        child: pw.Text('No labels found for this item and range.', style: const pw.TextStyle(color: _grey, fontSize: 10)),
      ));
    } else {
      // ---------- 📍 WHERE ARE THE LABELS NOW ----------
      content.add(title('WHERE ARE THEY NOW', 'In stock · approval · sold · sold from approval · returned'));
      final pRows = <pw.TableRow>[
        pw.TableRow(decoration: const pw.BoxDecoration(color: _navy), children: [
          cell('Now at', head: true, left: true),
          cell('Labels', head: true),
          cell('Items', head: true),
          cell('Gross (g)', head: true),
          cell('Net (g)', head: true),
        ]),
      ];
      var pi = 0;
      for (final k in placeOrder) {
        final ls = byPlace[k];
        if (ls == null || ls.isEmpty) continue;
        pRows.add(pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          decoration: pw.BoxDecoration(color: (pi++).isEven ? PdfColors.white : _cream),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: pw.Row(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                      color: placeColor(k).bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                  child: pw.Text(k, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: placeColor(k).fg)),
                ),
              ]),
            ),
            cell('${ls.length}', bold: true),
            cell('${ls.map((l) => l.item).toSet().length}'),
            cell(w(sum(ls, (l) => l.gross))),
            cell(w(sum(ls, (l) => l.net)), bold: true),
          ],
        ));
      }
      pRows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
        cell('TOTAL', left: true, bold: true),
        cell('${lines.length}', bold: true),
        cell('${byItem.length}', bold: true),
        cell(w(sum(lines, (l) => l.gross)), bold: true),
        cell(w(sum(lines, (l) => l.net)), bold: true, color: _navy),
      ]));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(0.9),
          2: pw.FlexColumnWidth(0.9),
          3: pw.FlexColumnWidth(1.1),
          4: pw.FlexColumnWidth(1.1),
        },
        children: pRows,
      ));
      content.add(pw.SizedBox(height: 14));

      // ---------- ITEM WISE COUNT ----------
      content.add(title('ITEM WISE LABELS', '${byItem.length} items · ${lines.length} labels'));
      final iRows = <pw.TableRow>[
        pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
          cell('#', head: true, left: true),
          cell('Item', head: true, left: true),
          cell('Labels', head: true),
          cell('Printed', head: true),
          cell('Pending', head: true),
          cell('In stock', head: true),
          cell('Approval', head: true),
          cell('Sold', head: true),
          cell('Returned', head: true),
          cell('Gross (g)', head: true),
          cell('Net (g)', head: true),
        ]),
      ];
      int cnt(Iterable<_LabelLine> ls, String p) =>
          ls.where((l) => p == 'Sold' ? (l.place == 'Sold' || l.place == 'Sold from approval') : l.place == p).length;
      String n0(int v) => v == 0 ? '-' : '$v';
      for (var i = 0; i < itemKeys.length; i++) {
        final ls = byItem[itemKeys[i]]!;
        final pr = ls.where((l) => l.printed).length;
        iRows.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
          cell('${i + 1}', left: true, color: _grey),
          cell(itemKeys[i], left: true, bold: true),
          cell('${ls.length}', bold: true),
          cell('$pr', color: _green),
          cell('${ls.length - pr}', color: ls.length - pr > 0 ? _orange : _grey),
          cell(n0(cnt(ls, 'In stock')), color: _green),
          cell(n0(cnt(ls, 'On approval')), color: _orange),
          cell(n0(cnt(ls, 'Sold')), color: _red),
          cell(n0(cnt(ls, 'Returned')), color: const PdfColor.fromInt(0xff1D4ED8)),
          cell(w(sum(ls, (l) => l.gross))),
          cell(w(sum(ls, (l) => l.net)), bold: true),
        ]));
      }
      iRows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
        cell(''),
        cell('TOTAL', left: true, bold: true),
        cell('${lines.length}', bold: true),
        cell('$printedCount', bold: true, color: _green),
        cell('$pendingCount', bold: true, color: _orange),
        cell(n0(cnt(lines, 'In stock')), bold: true, color: _green),
        cell(n0(cnt(lines, 'On approval')), bold: true, color: _orange),
        cell(n0(cnt(lines, 'Sold')), bold: true, color: _red),
        cell(n0(cnt(lines, 'Returned')), bold: true, color: const PdfColor.fromInt(0xff1D4ED8)),
        cell(w(sum(lines, (l) => l.gross)), bold: true),
        cell(w(sum(lines, (l) => l.net)), bold: true, color: _navy),
      ]));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(26),
          1: pw.FlexColumnWidth(2.6),
          2: pw.FlexColumnWidth(0.8),
          3: pw.FlexColumnWidth(0.8),
          4: pw.FlexColumnWidth(0.8),
          5: pw.FlexColumnWidth(0.8),
          6: pw.FlexColumnWidth(0.8),
          7: pw.FlexColumnWidth(0.8),
          8: pw.FlexColumnWidth(0.8),
          9: pw.FlexColumnWidth(1.0),
          10: pw.FlexColumnWidth(1.0),
        },
        children: iRows,
      ));
      content.add(pw.SizedBox(height: 14));
    }

    // ---------- DATE WISE LIST ----------
    var serial = 0;
    for (final e in groups.entries) {
      final ls = e.value;
      final pr = ls.where((l) => l.printed).length;
      content.add(title('CREATED ON  ${e.key}',
          '${ls.length} labels${status == 'all' ? ' · printed $pr · pending ${ls.length - pr}' : ''}  ·  net ${w(sum(ls, (l) => l.net))} g'));
      final rows = <pw.TableRow>[
        pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: _navy), children: [
          cell('#', head: true, left: true),
          cell('Label', head: true, left: true),
          cell('Item', head: true, left: true),
          cell('HUID', head: true, left: true),
          cell('Gross (g)', head: true),
          cell('Other (g)', head: true),
          cell('Net (g)', head: true),
          cell('Print', head: true, left: true),
          cell('Printed on', head: true, left: true),
          cell('Now at · voucher', head: true, left: true),
        ]),
      ];
      for (var i = 0; i < ls.length; i++) {
        final l = ls[i];
        serial++;
        rows.add(pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream),
          children: [
            cell('$serial', left: true, color: _grey),
            cell(l.label.isEmpty ? '-' : l.label, left: true, bold: true),
            cell(l.item, left: true),
            cell(l.huid.isEmpty ? '-' : l.huid, left: true, color: _grey),
            cell(w(l.gross)),
            cell(l.other == 0 ? '-' : w(l.other)),
            cell(w(l.net), bold: true),
            statusCell(l.printed),
            cell(l.printed && l.printedAt.isNotEmpty ? l.printedAt : '-', left: true, color: _grey),
            placeCell(l),
          ],
        ));
      }
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _goldSoft), children: [
        cell(''),
        cell('TOTAL', left: true, bold: true),
        cell('${ls.length} labels', left: true, bold: true),
        cell(''),
        cell(w(sum(ls, (l) => l.gross)), bold: true),
        cell(w(sum(ls, (l) => l.other)), bold: true),
        cell(w(sum(ls, (l) => l.net)), bold: true, color: _navy),
        cell(''),
        cell(''),
        cell(''),
      ]));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(1.1),
          2: pw.FlexColumnWidth(2.0),
          3: pw.FlexColumnWidth(1.0),
          4: pw.FlexColumnWidth(0.8),
          5: pw.FlexColumnWidth(0.75),
          6: pw.FlexColumnWidth(0.8),
          7: pw.FlexColumnWidth(0.8),
          8: pw.FlexColumnWidth(1.25),
          9: pw.FlexColumnWidth(1.7),
        },
        children: rows,
      ));
      content.add(pw.SizedBox(height: 12));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand, 'ITEM LABEL REPORT', '$statusText · date wise · where now'),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · Label report · $item', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = item.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/Labels_${status}_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  // -------------------------------------------------------------------
  //  📒 DAY-WISE METAL LEDGER PDF (Worker loss)
  // -------------------------------------------------------------------
  static Future<File> buildLedger({
    required String worker,
    required String range,
    required List<_LGroup> groups,
    bool detailed = false,
  }) async {
    final brand = await _brand();
    final doc = pw.Document();
    final made = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final multiMetal = groups.map((g) => g.metal).toSet().length > 1;

    final dr = groups.fold<double>(0, (a, g) => a + g.debit);
    final cr = groups.fold<double>(0, (a, g) => a + g.credit);
    final opening = groups.fold<double>(0, (a, g) => a + g.opening);
    final pending = groups.where((g) => g.closing > 0.0005).fold<double>(0, (a, g) => a + g.closing);
    final extra = groups.where((g) => g.closing < -0.0005).fold<double>(0, (a, g) => a + g.closing.abs());

    pw.Widget cell(String t,
        {bool head = false, bool left = false, PdfColor? color, PdfColor? bg, bool bold = false, double size = 8.3}) =>
        pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
          child: pw.Text(
            t,
            textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: head ? 7.8 : size,
              color: head ? PdfColors.white : (color ?? _ink),
              fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    final content = <pw.Widget>[
      // info
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            color: _cream, border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Row(children: [
          _kv('Worker', worker),
          _kv('Range', range),
          _kv('Format', detailed ? 'Detailed · item wise' : 'Day wise'),
          _kv('Generated', made),
        ]),
      ),
      // banner
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(children: [
          _bannerKv('Workers', '${groups.length}', PdfColors.white),
          _bannerKv('Opening', bal(opening), PdfColors.white),
          _bannerKv('Issued (Dr)', '${w(dr)} g', PdfColors.white),
          _bannerKv('Received (Cr)', '${w(cr)} g', PdfColors.white),
          _bannerKv('METAL PENDING WITH WORKERS', '${w(pending)} g', _gold, big: true),
          if (extra > 0.0005) _bannerKv('Given extra (Cr)', '${w(extra)} g', PdfColors.white),
        ]),
      ),
    ];

    if (groups.isEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        child: pw.Text('No ledger entries for this worker and range.', style: const pw.TextStyle(color: _grey, fontSize: 10)),
      ));
    } else {
      // ---- summary: worker-wise closing ----
      content.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          color: _goldSoft,
          border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('WORKER WISE SUMMARY',
                style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _navy)),
          ),
          pw.Text('${groups.length} workers · closing = metal pending', style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
        ]),
      ));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(0.4),
          1: pw.FlexColumnWidth(2.4),
          2: pw.FlexColumnWidth(1.0),
          3: pw.FlexColumnWidth(1.2),
          4: pw.FlexColumnWidth(1.2),
          5: pw.FlexColumnWidth(1.2),
          6: pw.FlexColumnWidth(1.3),
          7: pw.FlexColumnWidth(0.7),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _navy),
            children: [
              cell('#', head: true, left: true),
              cell('Worker', head: true, left: true),
              cell('Metal', head: true, left: true),
              cell('Opening', head: true),
              cell('Issued (Dr)', head: true),
              cell('Received (Cr)', head: true),
              cell('Closing', head: true),
              cell('Days', head: true),
            ],
          ),
          for (var i = 0; i < groups.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream),
              children: [
                cell('${i + 1}', left: true),
                cell(groups[i].worker, left: true, bold: true),
                cell(groups[i].metal, left: true),
                cell(bal(groups[i].opening)),
                cell(w(groups[i].debit), color: _red),
                cell(w(groups[i].credit), color: _green),
                cell(bal(groups[i].closing),
                    bold: true, color: groups[i].closing > 0.0005 ? _red : (groups[i].closing < -0.0005 ? _green : _ink)),
                cell('${groups[i].rows.length}'),
              ],
            ),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _goldSoft),
            children: [
              cell(''),
              cell('TOTAL', left: true, bold: true),
              cell(''),
              cell(bal(opening), bold: true),
              cell(w(dr), bold: true, color: _red),
              cell(w(cr), bold: true, color: _green),
              cell(bal(groups.fold<double>(0, (a, g) => a + g.closing)), bold: true, color: _navy),
              cell('${groups.fold<int>(0, (a, g) => a + g.rows.length)}', bold: true),
            ],
          ),
        ],
      ));
      content.add(pw.SizedBox(height: 16));

      // ---- each worker: day-wise ledger ----
      for (final g in groups) {
        content.add(pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            color: _goldSoft,
            border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text('${g.worker.toUpperCase()}${multiMetal || g.metal != 'Metal' ? '  ·  ${g.metal}' : ''}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
            ),
            pw.Text('Opening ${bal(g.opening)}   ·   Closing ${bal(g.closing)}',
                style: pw.TextStyle(fontSize: 8.5, color: _navy, fontWeight: pw.FontWeight.bold)),
          ]),
        ));
        PdfColor typeColor(String t) {
          final l = t.toLowerCase();
          if (l.contains('issue')) return _red;
          if (l.contains('receive') || l.contains('return')) return _green;
          return _ink;
        }

        content.add(pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.5),
          columnWidths: detailed
              ? const {
            0: pw.FlexColumnWidth(1.0),
            1: pw.FlexColumnWidth(1.3),
            2: pw.FlexColumnWidth(0.9),
            3: pw.FlexColumnWidth(2.6),
            4: pw.FlexColumnWidth(1.15),
            5: pw.FlexColumnWidth(1.15),
            6: pw.FlexColumnWidth(1.3),
          }
              : const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(3.6),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.3),
            4: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _navy),
              children: [
                cell('Date', head: true, left: true),
                if (detailed) ...[
                  cell('Voucher', head: true, left: true),
                  cell('Type', head: true, left: true),
                  cell('Item', head: true, left: true),
                ] else
                  cell('Particulars', head: true, left: true),
                cell('Debit — Issued', head: true),
                cell('Credit — Received', head: true),
                cell('Running balance', head: true),
              ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cream),
              children: [
                cell('—', left: true, color: _grey),
                if (detailed) ...[
                  cell('—', left: true, color: _grey),
                  cell('—', left: true, color: _grey),
                ],
                cell('Opening balance brought forward', left: true, color: _grey),
                cell('—', color: _grey),
                cell('—', color: _grey),
                cell(bal(g.opening), bold: true),
              ],
            ),
            for (var i = 0; i < g.rows.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream),
                children: [
                  cell(DateFormat('dd-MM-yyyy').format(g.rows[i].date), left: true),
                  if (detailed) ...[
                    cell(g.rows[i].voucher.isEmpty ? '-' : g.rows[i].voucher, left: true, bold: true),
                    cell(g.rows[i].type.isEmpty ? '-' : g.rows[i].type,
                        left: true, bold: true, color: typeColor(g.rows[i].type)),
                    cell(g.rows[i].item.isEmpty ? '-' : g.rows[i].item, left: true),
                  ] else
                    cell(g.rows[i].text.isEmpty ? 'Daily total' : g.rows[i].text, left: true),
                  cell(g.rows[i].debit == 0 ? '-' : w(g.rows[i].debit), color: _red),
                  cell(g.rows[i].credit == 0 ? '-' : w(g.rows[i].credit), color: _green),
                  cell(bal(g.rows[i].balance), bold: true),
                ],
              ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _goldSoft),
              children: [
                cell(''),
                if (detailed) ...[cell(''), cell('')],
                cell('Period total / Closing', left: true, bold: true),
                cell(w(g.debit), bold: true, color: _red),
                cell(w(g.credit), bold: true, color: _green),
                cell(bal(g.closing), bold: true, color: _navy, size: 9),
              ],
            ),
          ],
        ));
        content.add(pw.SizedBox(height: 14));
      }
      content.add(pw.Text('Dr = metal still with the worker (to receive) · Cr = worker received extra.',
          style: const pw.TextStyle(fontSize: 8, color: _grey)));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 5000, // 🔥 big lists (All items) — default 20 pages gave an error
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
      header: (ctx) => _header(brand, 'METAL LEDGER', detailed ? 'Detailed · item wise' : 'Day wise · worker loss'),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${brand.name} · Metal ledger · $worker', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      ]),
      build: (_) => content,
    ));

    final dir = await getTemporaryDirectory();
    final safe = worker.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${dir.path}/Metal_Ledger_${detailed ? 'Detailed' : 'Daily'}_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  /// 👤 PARTY OVERVIEW — one line per section (vouchers · items · qty · gross · net · amount)
  static pw.Widget _partyOverview(List<_Section> sections, {String heading = 'PARTY OVERVIEW'}) {
    pw.Widget cell(String t, {bool head = false, bool left = false, bool bold = false, PdfColor? color}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(t,
          textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: head ? 8 : 8.5,
            color: head ? PdfColors.white : (color ?? _ink),
            fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          )),
    );
    String title(String t) => t == 'Sales' ? 'Sale Bills' : t;
    final rows = <pw.TableRow>[
      pw.TableRow(decoration: const pw.BoxDecoration(color: _navy), children: [
        cell('Section', head: true, left: true),
        cell('Vouchers', head: true),
        cell('Items', head: true),
        cell('Qty', head: true),
        cell('Gross Wt (g)', head: true),
        cell('Net Wt (g)', head: true),
        cell('Amount', head: true),
      ]),
    ];
    for (var i = 0; i < sections.length; i++) {
      final sec = sections[i];
      rows.add(pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream), children: [
        cell(title(sec.title), left: true, bold: true, color: _navy),
        cell('${sec.vouchers}'),
        cell('${sec.lines.length}'),
        cell(q(sec.sum((l) => l.qty))),
        cell(w(sec.sum((l) => l.gross))),
        cell(w(sec.sum((l) => l.net)), bold: true),
        cell(a(sec.sum((l) => l.amount)), bold: true),
      ]));
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(color: _goldSoft, border: pw.Border(left: pw.BorderSide(color: _gold, width: 4))),
        child: pw.Text(heading, style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _navy)),
      ),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.6),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(0.9),
          2: pw.FlexColumnWidth(0.9),
          3: pw.FlexColumnWidth(0.8),
          4: pw.FlexColumnWidth(1.2),
          5: pw.FlexColumnWidth(1.2),
          6: pw.FlexColumnWidth(1.4),
        },
        children: rows,
      ),
      pw.SizedBox(height: 12),
    ]);
  }

  static pw.Widget _kv(String k, String v) => pw.Expanded(
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(k, style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      pw.Text(v, style: pw.TextStyle(fontSize: 9.5, color: _ink, fontWeight: pw.FontWeight.bold)),
    ]),
  );

  static pw.Widget _sectionTitle(_Section s) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    margin: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      color: _goldSoft,
      border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
    ),
    child: pw.Row(children: [
      pw.Expanded(
        child: pw.Text(s.title.toUpperCase(),
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _navy)),
      ),
      pw.Text('${s.vouchers} voucher · ${s.lines.length} item', style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
    ]),
  );

  // -------------------------------------------------------------------
  //  ⚖️ BALANCE — given − returned = pending on approval
  // -------------------------------------------------------------------
  static String _fmtCol(int i, double v) => i == 0 ? q(v) : (i <= 3 ? w(v) : a(v));

  /// pending = given item that is not returned and not sold
  static bool isPending(_Line l) => l.status != 'Returned' && l.status != 'Sold' && l.status != 'Completed';

  static double _sumOf(Iterable<_Line> ls, double Function(_Line) f) => ls.fold(0, (a, l) => a + f(l));

  /// Total = Approval (pending) + Return + Sold  →  Total − Return − Sold = Pending
  static pw.Widget _pendingBanner(_Section given, _Section? ret, _Section? sold) {
    final pend = given.lines.where((l) => l.status != 'Sold').toList();
    final aNet = _sumOf(pend, (l) => l.net);
    final rNet = ret == null ? 0.0 : ret.sum((l) => l.net);
    final sNet = sold == null ? 0.0 : sold.sum((l) => l.net);
    final total = aNet + rNet + sNet;
    final pending = total - rNet - sNet;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(children: [
        _bannerKv('Total net', '${w(total)} g', PdfColors.white),
        _bannerKv('(−) Approval return', '− ${w(rNet)} g', PdfColors.white),
        if (sold != null) _bannerKv('(−) Sold from approval', '− ${w(sNet)} g', PdfColors.white),
        _bannerKv('PENDING NET (still on approval)', '${w(pending)} g', _gold, big: true),
        _bannerKv('Pending items', '${pend.length}', PdfColors.white),
      ]),
    );
  }

  static pw.Widget _bannerKv(String k, String v, PdfColor c, {bool big = false}) => pw.Expanded(
    flex: big ? 2 : 1,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(k, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey300)),
      pw.Text(v, style: pw.TextStyle(fontSize: big ? 14 : 10.5, color: c, fontWeight: pw.FontWeight.bold)),
    ]),
  );

  static pw.Widget _balance(_Section given, _Section? ret, _Section? sold) {
    List<double> tot(Iterable<_Line> ls) => [
      _sumOf(ls, (l) => l.qty),
      _sumOf(ls, (l) => l.gross),
      _sumOf(ls, (l) => l.less),
      _sumOf(ls, (l) => l.net),
      _sumOf(ls, (l) => l.labourAmt),
      _sumOf(ls, (l) => l.metalAmt),
      _sumOf(ls, (l) => l.other),
      _sumOf(ls, (l) => l.amount),
    ];
    final retLines = ret?.lines ?? const <_Line>[];
    final soldLines = sold?.lines ?? const <_Line>[];
    final issueLines = given.lines.where((l) => l.status != 'Sold').toList(); // sold ones counted below
    final g = tot(issueLines); // approval issue (still with customer)
    final r = tot(retLines); // approval return
    final sd = tot(soldLines); // sold from approval
    final t = List.generate(g.length, (i) => g[i] + r[i] + sd[i]); // total of all
    final p = List.generate(g.length, (i) => t[i] - r[i] - sd[i]); // total − return − sold = pending
    const heads = ['', 'Qty', 'Gross Wt (g)', 'Less Wt (g)', 'Net Wt (g)', 'Labour Amt', 'Metal Amt', 'Other Amt', 'Amount'];

    pw.Widget cell(String t, {bool head = false, bool left = false, PdfColor? color, bool bold = false, double size = 8.5}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            t,
            textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: head ? 8 : size,
              color: head ? PdfColors.white : (color ?? _ink),
              fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    pw.TableRow row(String label, List<double> v, {PdfColor? bg, PdfColor? color, bool bold = false, String sign = ''}) =>
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bg ?? PdfColors.white),
          children: [
            cell(label, left: true, bold: true, color: color),
            for (var i = 0; i < v.length; i++)
              cell('$sign${_fmtCol(i, v[i])}', color: color, bold: bold || i == 3, size: i == 3 && bold ? 10 : 8.5),
          ],
        );

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          color: _goldSoft,
          border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('BOTH TOTAL · PENDING ON APPROVAL',
                style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _navy)),
          ),
          pw.Text('Total − Approval return − Sold from approval = Pending',
              style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
        ]),
      ),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2.2),
          for (var i = 1; i < heads.length; i++) i: const pw.FlexColumnWidth(1.1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _navy),
            children: [for (var i = 0; i < heads.length; i++) cell(heads[i], head: true, left: i == 0)],
          ),
          row('Approval issue (${issueLines.length} item)', g),
          row('Approval return (${retLines.length} item)', r),
          if (sold != null) row('Sold from approval (${soldLines.length} item)', sd),
          row(sold != null ? 'Total (Issue + Return + Sold)' : 'Total (Issue + Return)', t, bg: _cream, bold: true),
          row('(−) Approval return', r, color: _green, sign: '− '),
          if (sold != null) row('(−) Sold from approval', sd, color: _red, sign: '− '),
          row('= Pending weight', p, bg: _goldSoft, color: _navy, bold: true),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Total ${w(t[3])} g − Approval return ${w(r[3])} g'
            '${sold != null ? ' − Sold ${w(sd[3])} g' : ''} = Pending ${w(p[3])} g still with the customer on approval.',
        style: const pw.TextStyle(fontSize: 8.5, color: _ink),
      ),
    ]);
  }

  static pw.Widget _summary(_Section s) {
    final boxes = <List<String>>[
      ['Qty', q(s.sum((l) => l.qty))],
      ['Gross Wt', '${w(s.sum((l) => l.gross))} g'],
      ['Less Wt', '${w(s.sum((l) => l.less))} g'],
      ['Net Wt', '${w(s.sum((l) => l.net))} g'],
      ['Avg Labour Rate', a(s.avgLabour)],
      ['Labour Amt', a(s.sum((l) => l.labourAmt))],
      ['Metal Amt', a(s.sum((l) => l.metalAmt))],
      ['Other Amt', a(s.sum((l) => l.other))],
      ['Amount', a(s.sum((l) => l.amount))],
    ];
    return pw.Row(
      children: boxes
          .map((b) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: pw.BoxDecoration(
            color: b[0] == 'Amount' ? _navy : PdfColors.white,
            border: pw.Border.all(color: b[0] == 'Amount' ? _navy : _line),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(b[0], style: pw.TextStyle(fontSize: 7, color: b[0] == 'Amount' ? PdfColors.grey300 : _grey)),
            pw.Text(b[1],
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold, color: b[0] == 'Amount' ? _gold : _ink)),
          ]),
        ),
      ))
          .toList(),
    );
  }

  static pw.Widget _table(_Section s, {String lastCol = 'Status'}) {
    final heads = ['#', 'Voucher / Date', 'Item', 'Qty', 'Gross', 'Less', 'Net', 'Labour Rate', 'Metal Rate', 'Amount', 'Other Amt', lastCol];
    final statusCol = lastCol == 'Status';
    const widths = [0.35, 1.5, 2.2, 0.5, 0.85, 0.75, 0.85, 0.9, 0.95, 1.1, 0.9, 0.85];
    final rightCols = {3, 4, 5, 6, 7, 8, 9, 10};

    pw.Widget cell(String t, int col, {bool head = false, PdfColor? color, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        t,
        textAlign: rightCols.contains(col) ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: head ? 7.8 : 8,
          color: head ? PdfColors.white : (color ?? _ink),
          fontWeight: head || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    PdfColor stColor(String st) => !statusCol
        ? _ink
        : st == 'Returned'
        ? _green
        : (st == 'Sold' ? _red : (st == 'Partial' ? _orange : _orange));

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _navy),
        children: [for (var i = 0; i < heads.length; i++) cell(heads[i], i, head: true)],
      ),
    ];
    for (var i = 0; i < s.lines.length; i++) {
      final l = s.lines[i];
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cream),
        children: [
          cell('${i + 1}', 0),
          cell('${l.voucher}\n${l.date}', 1),
          cell(l.barcode.isNotEmpty && l.barcode != l.item ? '${l.item}\n${l.barcode}' : l.item, 2),
          cell(q(l.qty), 3),
          cell(w(l.gross), 4),
          cell(w(l.less), 5),
          cell(w(l.net), 6),
          cell(a(l.labourRate), 7),
          cell(a(l.metalRate), 8),
          cell(a(l.amount), 9, bold: true),
          cell(a(l.other), 10),
          cell(l.status, 11, color: stColor(l.status), bold: statusCol),
        ],
      ));
    }
    // total row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: _goldSoft),
      children: [
        cell('', 0),
        cell('TOTAL', 1, bold: true),
        cell('${s.lines.length} items', 2, bold: true),
        cell(q(s.sum((l) => l.qty)), 3, bold: true),
        cell(w(s.sum((l) => l.gross)), 4, bold: true),
        cell(w(s.sum((l) => l.less)), 5, bold: true),
        cell(w(s.sum((l) => l.net)), 6, bold: true),
        cell(a(s.avgLabour), 7, bold: true),
        cell('', 8),
        cell(a(s.sum((l) => l.amount)), 9, bold: true),
        cell(a(s.sum((l) => l.other)), 10, bold: true),
        cell('', 11),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: {for (var i = 0; i < widths.length; i++) i: pw.FlexColumnWidth(widths[i])},
      children: rows,
    );
  }
}
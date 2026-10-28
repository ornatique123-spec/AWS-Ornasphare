import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppMessage.dart';


/// =======================================================================
///  VOUCHER DETAILS — BADHA voucher mate EK j look (Sale, Approval,
///  Job Work Issue / Receive, Return, ...)
///
///    await VoucherDetails.open(
///      context,
///      module: 'sales',            // niche `configs` ni key
///      id: '123',                  // voucher nu API id
///      voucherNo: 'PT-SL-008',
///      info: [MapEntry('Customer', 'Divya'), MapEntry('Date', '08-10-2026')],
///    );
///
///  Navo voucher type umervo hoy to fakt `configs` ma ek entry umero.
///  File: lib/Extra/VoucherDetails.dart
/// =======================================================================
class VoucherConfig {
  final String title;
  final String Function(String id) detailsUrl;
  final String Function(String id)? pdfUrl;
  final String Function(String id)? excelUrl;

  /// Table na column (item key) — kram pramane. null = API mathi auto.
  final List<String>? columns;

  /// 🔥 id na hoy tyare voucher no parthi id shodhva list API.
  /// [ymd] = voucher ni date (yyyy-MM-dd) athva null.
  final String Function(String? ymd)? lookupUrl;

  /// 🏢 detailsUrl gave no items → try these (other branch voucher)
  final List<String> Function(String id)? altUrls;

  const VoucherConfig({
    required this.title,
    required this.detailsUrl,
    this.pdfUrl,
    this.excelUrl,
    this.columns,
    this.lookupUrl,
    this.altUrls,
  });
}

class VoucherDetails {
  // ---------------- SALE ----------------
  static const List<String> saleColumns = [
    'label', 'huid', 'item_name', 'qty_pcs', 'gross_weight', 'net_weight', 'purity', 'waste_percent',
    'fine_weight', 'metal_rate', 'metal_amount', 'labour_rate', 'labour_amount', 'other_amount', 'net_total',
  ];
  static final String _saleCols = saleColumns.join(',');

  static final VoucherConfig _sale = VoucherConfig(
    title: 'Sale Details',
    detailsUrl: (id) => '${ApiConstants.Sale_Summary_report}/$id/details?columns=$_saleCols',
    pdfUrl: (id) => '${ApiConstants.Sale_Summary_report}/$id/details/pdf?columns=$_saleCols',
    excelUrl: (id) => '${ApiConstants.Sale_Summary_report}/$id/details/excel?columns=$_saleCols',
    columns: saleColumns,
    lookupUrl: (ymd) => '${ApiConstants.Sale_Summary_report}?columns=voucher_no,date,customer'
        '${ymd != null ? '&from_date=$ymd&to_date=$ymd' : ''}',
  );

  // ---------------- APPROVAL ----------------
  static final VoucherConfig _approval = VoucherConfig(
    title: 'Approval Details',
    detailsUrl: (id) => '${ApiConstants.Approval_dailog_list}/$id',
    pdfUrl: (id) => '${ApiConstants.Approval_pdf}/$id',
    lookupUrl: (ymd) => ApiConstants.Approval_list,
  );

  // ---------------- JOB WORK ----------------
  static final VoucherConfig _jobIssue = VoucherConfig(
    title: 'Job Work Issue Details',
    detailsUrl: (id) => '${ApiConstants.jobwork_issues}/$id',
    pdfUrl: (id) => '${ApiConstants.jobwork_issues_pdf}/$id',
    excelUrl: (id) => '${ApiConstants.jobwork_issues_exel}/$id',
    lookupUrl: (ymd) => ymd != null
        ? '${ApiConstants.jobwork_issues}?from=$ymd&to=$ymd'
        : ApiConstants.jobwork_issues,
  );

  static final VoucherConfig _jobReceive = VoucherConfig(
    title: 'Job Work Receive Details',
    detailsUrl: (id) => '${ApiConstants.jobwork_receive}/$id',
    pdfUrl: (id) => '${ApiConstants.jobwork_receive_pdf}/$id',
    altUrls: (id) => ['${ApiConstants.jobwork_issues}/$id'],
    lookupUrl: (ymd) => ymd != null
        ? '${ApiConstants.jobwork_receive}?from=$ymd&to=$ymd'
        : ApiConstants.jobwork_receive,
  );

  // ---------------- RETURN ----------------
  // 👉 ADJUST: return detail API alag hoy to ahi badlo
  static final VoucherConfig _return = VoucherConfig(
    title: 'Return Details',
    detailsUrl: (id) => '${ApiConstants.returns_vouchar}/$id',
    pdfUrl: (id) => '${ApiConstants.return_pdf}/$id',
    lookupUrl: (ymd) => ApiConstants.return_list,
  );

  // =====================================================================
  //  🏢 BRANCH vouchers (main company admin sees another branch)
  //  id = "<voucher id>|<branch slug>"  (stock: "<item_id>|<stock_type>|<slug>")
  //  same as Branch Reports screen:  …/{id}/details?…&report_branches=all
  // =====================================================================
  static const List<String> approvalColumns = [
    'label', 'huid', 'item_name', 'gross_weight', 'other_weight', 'net_weight', 'purity', 'waste_percent',
    'fine_weight', 'metal_rate', 'metal_amount', 'labour_rate', 'labour_amount', 'other_amount', 'net_total', 'status',
  ];
  static final String _apprCols = approvalColumns.join(',');
  /// same columns as the web Stock Position details
  static const List<String> stockColumns = [
    'date', 'label_code', 'item_name', 'stock_type_name', 'qty_pcs', 'gross_weight', 'net_weight', 'fine_weight',
    'image_status',
  ];

  static List<String> _parts(String id) => id.split('|');
  static String _vid(String id) => _parts(id).first;
  static String _slug(String id) => _parts(id).length > 1 && _parts(id)[1].isNotEmpty ? _parts(id)[1] : 'all';

  static final VoucherConfig _branchSale = VoucherConfig(
    title: 'Sale Details',
    detailsUrl: (id) => '${ApiConstants.Sale_Summary_report}/${_vid(id)}/details?columns=$_saleCols&report_branches=all',
    pdfUrl: (id) => '${ApiConstants.Sale_Summary_report}/${_vid(id)}/details/pdf?columns=$_saleCols&report_branches=all',
    excelUrl: (id) =>
    '${ApiConstants.Sale_Summary_report}/${_vid(id)}/details/excel?columns=$_saleCols&report_branches=all',
    columns: saleColumns,
    // same order as the Report Builder (branch merge)
    altUrls: (id) => [
      '${ApiConstants.Sale_Summary_report}/${_vid(id)}/details?columns=$_saleCols&report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/sale/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/sales/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/sales-summary/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.Sale_Summary_report}/${_vid(id)}/details?report_branches=all',
    ],
  );

  static final VoucherConfig _branchApproval = VoucherConfig(
    title: 'Approval Details',
    detailsUrl: (id) =>
    '${ApiConstants.Approval_Outstanding_report}/${_vid(id)}/details?columns=$_apprCols&report_branches=all',
    pdfUrl: (id) =>
    '${ApiConstants.Approval_Outstanding_report}/${_vid(id)}/details/pdf?columns=$_apprCols&report_branches=all',
    columns: approvalColumns,
    altUrls: (id) => [
      '${ApiConstants.baseUrl}company/branch-report-details/approval/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.Approval_Outstanding_report}/${_vid(id)}/details?columns=$_apprCols&report_branches=${_slug(id)}',
    ],
  );

  /// stock position item → reports/stock-position/details?item_id=…&stock_type=…&report_branches=<slug>
  static final VoucherConfig _branchStock = VoucherConfig(
    title: 'Stock Details',
    detailsUrl: (id) {
      final p = _parts(id);
      final slug = p.length > 2 && p[2].isNotEmpty ? p[2] : 'all';
      return '${ApiConstants.Stock_Position_report}/details?item_id=${p[0]}'
          '${p.length > 1 && p[1].isNotEmpty ? '&stock_type=${Uri.encodeQueryComponent(p[1])}' : ''}'
          '&report_branches=$slug';
    },
    columns: stockColumns,
  );

  /// 🏢 job work receive / issue of any branch (worker-loss entry → voucher)
  static final VoucherConfig _branchJobReceive = VoucherConfig(
    title: 'Job Work Receive Details',
    detailsUrl: (id) => '${ApiConstants.jobwork_receive}/${_vid(id)}',
    pdfUrl: (id) => '${ApiConstants.jobwork_receive_pdf}/${_vid(id)}',
    altUrls: (id) => [
      '${ApiConstants.jobwork_receive}/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/jobwork-receive/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/worker-loss/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.worker_loss_report}/${_vid(id)}/details?report_branches=all',
      '${ApiConstants.jobwork_issues}/${_vid(id)}?report_branches=${_slug(id)}',
    ],
  );

  static final VoucherConfig _branchJobIssue = VoucherConfig(
    title: 'Job Work Issue Details',
    detailsUrl: (id) => '${ApiConstants.jobwork_issues}/${_vid(id)}',
    pdfUrl: (id) => '${ApiConstants.jobwork_issues_pdf}/${_vid(id)}',
    excelUrl: (id) => '${ApiConstants.jobwork_issues_exel}/${_vid(id)}',
    altUrls: (id) => [
      '${ApiConstants.jobwork_issues}/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/jobwork-issue/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.baseUrl}company/branch-report-details/worker-loss/${_vid(id)}?report_branches=${_slug(id)}',
      '${ApiConstants.worker_loss_report}/${_vid(id)}/details?report_branches=all',
    ],
  );

  /// Ask AI module id → config (ek type na ghana naam chale)
  static final Map<String, VoucherConfig> configs = {
    'branch_jobwork_receive': _branchJobReceive,
    'branch_jobwork_issue': _branchJobIssue,
    'branch_sale': _branchSale,
    'branch_approval': _branchApproval,
    'branch_stock': _branchStock,
    'sales': _sale,
    'sale': _sale,
    'approval': _approval,
    'approvals': _approval,
    'jobwork_issue': _jobIssue,
    'jobwork-issue': _jobIssue,
    'jobwork_receive': _jobReceive,
    'jobwork-receive': _jobReceive,
    'jobwork': _jobReceive,
    'return': _return,
    'returns': _return,
  };

  static bool _opening = false;

  /// [module] ni config na hoy athva [id] na hoy to pan e j dialog
  /// khule — fakt [info] sathe (table / export vagar).
  static Future<void> open(
      BuildContext context, {
        String? module,
        String? id,
        String? title,
        String? voucherNo,
        List<MapEntry<String, String>> info = const [],
      }) async {
    if (_opening) return;
    final cfg = module == null ? null : configs[module.toLowerCase()];
    final dialogTitle = cfg?.title ?? title ?? 'Voucher Details';
    final canLookup = cfg?.lookupUrl != null && (voucherNo ?? '').trim().isNotEmpty;
    final hasId = id != null && id.trim().isNotEmpty;
    bool hasApi = cfg != null && (hasId || canLookup);

    Map<String, dynamic>? body;

    if (hasApi) {
      _opening = true;

      final nav = Navigator.of(context, rootNavigator: true);
      bool loaderOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (_) => Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            elevation: 12,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xffC9A24B))),
                SizedBox(width: 12),
                Text('Opening voucher…',
                    style: TextStyle(color: Color(0xff1A2033), fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
      void closeLoader() {
        if (loaderOpen) {
          loaderOpen = false;
          nav.pop();
        }
      }

      try {
        // 🔥 id na hoy to voucher no parthi shodho
        if (!hasId) {
          id = await _lookupId(cfg!, voucherNo!.trim(), _ymdFrom(info));
          debugPrint('🔎 VOUCHER LOOKUP "$voucherNo" => id=$id');
        }
        if (id == null || id!.trim().isEmpty) {
          // id na malyo → e j dialog, fakt info sathe
          hasApi = false;
          throw _NoId();
        }

        final url = cfg!.detailsUrl(id!);
        debugPrint('🧾 VOUCHER DETAILS ($module) => $url');
        final response = await ApiHelper().getRequest(url, showLoading: false);
        final decoded = _decode(response?.data);
        final ok = response?.statusCode == 200 && decoded is Map && decoded['success'] != false;
        if (ok) body = Map<String, dynamic>.from(decoded);
        // 🏢 other branch voucher: no items → try the branch detail urls
        if (cfg.altUrls != null && (body == null || _VoucherDialogState.itemCount(body!) == 0)) {
          for (final u in cfg.altUrls!(id!)) {
            try {
              debugPrint('🏢 VOUCHER DETAILS (alt) => $u');
              final r2 = await ApiHelper().getRequest(u, showLoading: false);
              final d2 = _decode(r2?.data);
              if (r2?.statusCode == 200 && d2 is Map && d2['success'] != false) {
                final b2 = Map<String, dynamic>.from(d2);
                if (_VoucherDialogState.itemCount(b2) > 0) {
                  body = b2;
                  break;
                }
                body ??= b2;
              }
            } catch (_) {}
          }
        }
        // 🏢 nothing worked for a branch voucher → open the info popup (no error toast)
        if (body == null && cfg.altUrls != null) hasApi = false;
        if (body == null && hasApi) {
          closeLoader();
          if (context.mounted) {
            AppMessage.error(
              context,
              decoded is Map
                  ? (decoded['message']?.toString() ?? 'Unable to load voucher details')
                  : 'Unable to load voucher details',
            );
          }
        }
      } on _NoId {
        closeLoader();
      } catch (e) {
        debugPrint('❌ VOUCHER DETAILS ERROR => $e');
        closeLoader();
        if (context.mounted) AppMessage.error(context, 'Something went wrong');
        _opening = false;
        return;
      } finally {
        closeLoader();
        _opening = false;
      }
      if (!context.mounted) return;
      if (hasApi && body == null) return; // API error message batavi didho
    }

    await showDialog(
      context: context,
      barrierColor: const Color(0xff0E1A3B).withOpacity(0.55),
      builder: (_) => _VoucherDialog(
        title: dialogTitle,
        body: body,
        config: hasApi ? cfg : null,
        id: id,
        voucherNo: voucherNo,
        info: info,
      ),
    );
  }

  /// List API mathi voucher no match kari ne "id" laavo
  static Future<String?> _lookupId(VoucherConfig cfg, String voucherNo, String? ymd) async {
    Future<String?> tryUrl(String url) async {
      debugPrint('🔎 LOOKUP URL => $url');
      final res = await ApiHelper().getRequest(url);
      final body = _decode(res?.data);
      if (body is! Map) return null;

      List rows = const [];
      final d = body['data'];
      if (d is List) {
        rows = d;
      } else if (d is Map && d['data'] is List) {
        rows = d['data'] as List; // Laravel paginate
      }

      final target = voucherNo.toLowerCase();
      for (final r in rows.whereType<Map>()) {
        for (final k in const ['voucher_no', 'approval_no', 'return_no', 'bill_no', 'invoice_no']) {
          if (r[k]?.toString().trim().toLowerCase() == target) {
            final v = r['id'] ?? r['voucher_id'] ?? r['sales_summary_id'];
            if (v != null) return v.toString();
          }
        }
      }
      return null;
    }

    final lookup = cfg.lookupUrl!;
    // pehla date sathe (nani list, fast), na male to date vagar
    if (ymd != null) {
      final found = await tryUrl(lookup(ymd));
      if (found != null) return found;
    }
    return tryUrl(lookup(null));
  }

  /// info ma "Date: 08-10-2026" hoy to → "2026-10-08"
  static String? _ymdFrom(List<MapEntry<String, String>> info) {
    for (final e in info) {
      if (!e.key.toLowerCase().contains('date')) continue;
      final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(e.value);
      if (m != null) {
        return '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
      }
      final iso = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(e.value);
      if (iso != null) return iso[0];
    }
    return null;
  }

  // =====================================================================
  //  📒 LEDGER POPUP (Worker Metal Ledger jevu j look)
  //  Koi pan object (AiRecord) sathe ledger jodo — tap thay tyare aa khule.
  // =====================================================================
  static final Expando<LedgerPopup> _ledgers = Expando<LedgerPopup>('ledger');

  /// [record] par tap → [popup] (record pachhu aape, `.map` ma vaprva)
  static T attachLedger<T extends Object>(T record, LedgerPopup popup) {
    _ledgers[record] = popup;
    return record;
  }

  static LedgerPopup? ledgerOf(Object record) => _ledgers[record];

  // =====================================================================
  //  🔗 VOUCHER LINK — koi pan record sathe "kayo voucher" jodo
  //  (Barcode history ma Sale / Approval / Return par tap → details)
  // =====================================================================
  static final Expando<VoucherRef> _refs = Expando<VoucherRef>('voucherRef');

  static T attachVoucher<T extends Object>(T record, VoucherRef ref) {
    _refs[record] = ref;
    return record;
  }

  static VoucherRef? voucherOf(Object record) => _refs[record];

  static Future<void> openRef(BuildContext context, VoucherRef r) => open(
    context,
    module: r.module,
    id: r.id,
    title: r.title,
    voucherNo: r.voucherNo,
    info: r.info,
  );

  static Future<void> openLedger(BuildContext context, LedgerPopup popup) async {
    final sheets = popup.build();
    if (sheets.isEmpty) {
      AppMessage.error(context, 'No entries in this ledger');
      return;
    }
    await showDialog(
      context: context,
      barrierColor: const Color(0xff0E1A3B).withOpacity(0.55),
      builder: (_) => _LedgerDialog(popup: popup, sheets: sheets),
    );
  }

  static dynamic _decode(dynamic data) {
    try {
      if (data is String) return jsonDecode(data);
      if (data is List<int>) return jsonDecode(utf8.decode(data));
    } catch (_) {}
    return data;
  }
}

/// Record → voucher (module = configs ni key: sales / approval / return ...)
class VoucherRef {
  final String module;
  final String id;
  final String? voucherNo;
  final String? title;
  final List<MapEntry<String, String>> info;

  const VoucherRef({required this.module, required this.id, this.voucherNo, this.title, this.info = const []});
}

class _NoId implements Exception {}

// =======================================================================
//  DIALOG — premium navy + gold look
// =======================================================================
class _VoucherDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? body;
  final VoucherConfig? config;
  final String? id;
  final String? voucherNo;
  final List<MapEntry<String, String>> info;

  const _VoucherDialog({
    required this.title,
    required this.body,
    required this.config,
    required this.id,
    required this.voucherNo,
    required this.info,
  });

  @override
  State<_VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<_VoucherDialog> {
  // ✨ premium palette — navy + gold on a soft ivory body
  static const Color bg = Color(0xffF6F5F1);
  static const Color card = Colors.white;
  static const Color navy = Color(0xff0E1A3B);
  static const Color navy2 = Color(0xff1E3370);
  static const Color gold = Color(0xffC9A24B);
  static const Color goldLight = Color(0xffE9CF8E);
  static const Color goldDeep = Color(0xff8A6A1F);
  static const Color goldSoft = Color(0xffFBF3DF);
  static const Color ink = Color(0xff1A2033);
  static const Color tableHead = navy;
  static const Color rowA = Colors.white;
  static const Color rowB = Color(0xffF8F9FC);
  static const Color border = Color(0xffE6E8EF);
  static const Color searchBorder = border;
  static const Color label = Color(0xff7A8197);
  static const Color excelBlue = Color(0xff15803D);
  static const Color pdfPink = Color(0xffE11D48);
  static const Color pdfDeep = Color(0xffBE123C);
  static const Color accent = gold;

  final TextEditingController _search = TextEditingController();
  final ScrollController _hScroll = ScrollController();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _rows = [];
  List<MapEntry<String, String>> _columns = []; // key → label
  late final List<MapEntry<String, String>> _info;

  bool _pdfLoading = false;
  bool _excelLoading = false;

  static final NumberFormat _amt = NumberFormat('#,##,##0.00', 'en_IN');
  static final NumberFormat _wt = NumberFormat('0.000');

  bool get _hasTable => widget.body != null;

  @override
  void initState() {
    super.initState();
    if (widget.body != null) _parse(widget.body!);
    _info = _buildInfo();
    _search.addListener(_applySearch);
  }

  @override
  void dispose() {
    _search.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  // =====================================================================
  //  DATA
  // =====================================================================
  void _parse(Map<String, dynamic> body) {
    _all = _extractItems(body).whereType<Map>().map((e) => _flat(Map<String, dynamic>.from(e))).toList();

    // 1) API column mokle (Sale summary)
    if (body['columns'] is List) {
      _columns = (body['columns'] as List)
          .whereType<Map>()
          .map((c) => MapEntry(c['key']?.toString() ?? '', c['label']?.toString() ?? ''))
          .where((c) => c.key.isNotEmpty)
          .map((c) => MapEntry(c.key, c.value.isEmpty ? _pretty(c.key) : c.value))
          .toList();
    }
    // 2) config na column (je data ma hoy te j)
    if (_columns.isEmpty && widget.config?.columns != null) {
      _columns = widget.config!.columns!
          .where((k) => _all.isEmpty || _all.any((r) => r.containsKey(k)))
          .map((k) => MapEntry(k, _pretty(k)))
          .toList();
    }
    // 3) auto: item na badha simple field
    if (_columns.isEmpty) {
      final keys = <String>[];
      for (final r in _all) {
        for (final e in r.entries) {
          if (!keys.contains(e.key) && _showKey(e.key, e.value)) keys.add(e.key);
        }
      }
      _columns = keys.map((k) => MapEntry(k, _pretty(k))).toList();
    }
    _rows = List.of(_all);
  }

  /// 🏢 branch details: lines[] → { source: { gross_weight…, item_set: { item: {…} } } } → one flat row
  static Map<String, dynamic> _flat(Map<String, dynamic> m) {
    // 🏢 stock-position details: Laravel model → real fields are inside "*attributes"
    //    (PHP sends the key as "\u0000*\u0000attributes" — so match by the letters only)
    dynamic attr;
    for (final e in m.entries) {
      final k = e.key.replaceAll(RegExp(r'[^a-zA-Z_]'), '');
      if (k == 'attributes' && e.value is Map) {
        attr = e.value;
        break;
      }
    }
    if (attr is Map) {
      final bn = m['branch_name'];
      m = Map<String, dynamic>.from(attr);
      if (bn != null) m['branch_name'] = bn;
      // Date: "2026-05-02 15:03:11" → "02-05-2026 03:03 PM"
      final sd = DateTime.tryParse('${m['source_date'] ?? ''}');
      if (sd != null) m['date'] ??= DateFormat('dd-MM-yyyy hh:mm a').format(sd);
      // Image status
      final hasImg = m['has_image'] == true ||
          '${m['has_image']}' == '1' ||
          ('${m['image_path'] ?? ''}'.trim().isNotEmpty && '${m['image_path']}' != 'null');
      m['image_status'] ??= hasImg ? 'With image' : 'Without image';
      return m; // stock row is complete — no label / huid guessing
    }
    final src = m['source'];
    if (src is Map) {
      final s = Map<String, dynamic>.from(src);
      m.remove('source');
      m = {...s, ...m};
    }
    String? str(dynamic v) {
      final t = (v ?? '').toString().trim();
      return t.isEmpty || t == 'null' ? null : t;
    }

    final set = m['item_set'] is Map ? m['item_set'] as Map : null;
    if (str(m['item_name']) == null) {
      final it = m['item'] is Map ? m['item'] as Map : (set?['item'] is Map ? set!['item'] as Map : null);
      final n = str(it?['item_name']) ?? str(it?['name']) ?? str(set?['item_name']);
      if (n != null) m['item_name'] = n;
    }
    m['label'] ??= str(m['qr_code']) ?? str(m['label_code']) ?? str(set?['qr_code']) ?? str(set?['barcode']);
    m['huid'] ??= str(m['HUID']) ?? str(set?['HUID']);
    m['fine_weight'] ??= m['total_fine_weight'];
    m['net_total'] ??= m['total_amount'];
    return m;
  }

  /// items with at least a name or a weight (branch alt-url check)
  static int itemCount(Map<String, dynamic> body) => _extractItemsS(body)
      .whereType<Map>()
      .map((e) => _flat(Map<String, dynamic>.from(e)))
      .where((m) =>
  (m['item_name'] ?? '').toString().trim().isNotEmpty ||
      (double.tryParse('${m['gross_weight'] ?? m['net_weight'] ?? ''}') ?? 0) > 0)
      .length;

  List _extractItems(Map<String, dynamic> body) => _extractItemsS(body);

  /// data: [...]  |  data: {items: [...]}  |  data: [{items: [...]}]
  static List _extractItemsS(Map<String, dynamic> body) {
    final d = body['data'];
    if (d is List) {
      if (d.isNotEmpty && d.first is Map) {
        final first = d.first as Map;
        for (final k in const ['items', 'lines', 'sale_items', 'details', 'rows']) {
          if (first[k] is List) return first[k] as List;
        }
      }
      return d;
    }
    if (d is Map) {
      for (final k in const ['items', 'lines', 'sale_items', 'details', 'rows']) {
        if (d[k] is List) return d[k] as List;
      }
    }
    for (final k in const ['items', 'details', 'rows']) {
      if (body[k] is List) return body[k] as List;
    }
    return const [];
  }

  static final RegExp _hiddenKey = RegExp(
      r'(^id$|_id$|^company|created_at|updated_at|deleted_at|image|_url$|^url$|checked|in_bhati|check_time|pivot|^is_)');

  bool _showKey(String k, dynamic v) {
    if (_hiddenKey.hasMatch(k)) return false;
    if (v is List) return false;
    if (v is Map) return v['name'] != null || v['item_name'] != null;
    return true;
  }

  String _cellText(dynamic v) {
    if (v == null) return '-';
    if (v is Map) return (v['name'] ?? v['item_name'] ?? '-').toString();
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  void _applySearch() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _rows = q.isEmpty
          ? List.of(_all)
          : _all.where((r) => r.values.any((v) => v != null && _cellText(v).toLowerCase().contains(q))).toList();
    });
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0;
  }

  // ---------------------------------------------------------------------
  //  INFO: web jevo j kram — Voucher No, Date, Customer, Created By,
  //  Qty, Gross, Net, Fine, Metal Amt, Labour Amt, Other Amt, Total
  // ---------------------------------------------------------------------
  static const List<List<Object>> _slots = [
    // [slot, display label, item keys (sum mate)]
    ['voucher', 'Voucher No', <String>[]],
    ['date', 'Date', <String>[]],
    ['customer', 'Customer', <String>[]],
    ['created', 'Created By', <String>[]],
    ['qty', 'Qty', <String>['qty_pcs', 'qty', 'pcs']],
    ['gross', 'Gross Wt', <String>['gross_weight', 'gross_wt']],
    ['net', 'Net Wt', <String>['net_weight', 'net_wt']],
    ['fine', 'Fine Wt', <String>['fine_weight', 'fine_wt']],
    ['metal', 'Metal Amt', <String>['metal_amount']],
    ['labour', 'Labour Amt', <String>['labour_amount']],
    ['other', 'Other Amt', <String>['other_amount']],
    ['total', 'Total', <String>['net_total', 'total_amount']],
  ];

  /// Record na label ne slot sathe jodo (total pehla check — "Net Total" total che)
  String? _slotFor(String label) {
    final l = label.toLowerCase();
    bool has(List<String> w) => w.any(l.contains);
    if (has(['total'])) return 'total';
    if (has(['voucher', 'bill no', 'approval no', 'vouchar'])) return 'voucher';
    if (has(['date', 'tarikh'])) return 'date';
    if (has(['customer', 'party', 'worker', 'karigar', 'grahak'])) return 'customer';
    if (has(['created', 'banavyu', 'banavnar', 'user'])) return 'created';
    if (has(['qty', 'pcs', 'piece', 'nang'])) return 'qty';
    if (has(['gross'])) return 'gross';
    if (has(['fine'])) return 'fine';
    if (has(['metal amt', 'metal amount'])) return 'metal';
    if (has(['labour amt', 'labour amount', 'majuri'])) return 'labour';
    if (has(['other amt', 'other amount'])) return 'other';
    if (l == 'net' || l.startsWith('net wt') || l.startsWith('net weight')) return 'net';
    return null;
  }

  String _fmt(String slot, double v) {
    if (slot == 'qty') return v.toStringAsFixed(0);
    if (['gross', 'net', 'fine'].contains(slot)) return _wt.format(v);
    return _amt.format(v);
  }

  List<MapEntry<String, String>> _buildInfo() {
    final values = <String, String>{};
    final extras = <MapEntry<String, String>>[];

    if (widget.voucherNo != null && widget.voucherNo!.trim().isNotEmpty) {
      values['voucher'] = widget.voucherNo!;
    }
    for (final e in widget.info) {
      if (e.value.trim().isEmpty || e.value == '-') continue;
      final slot = _slotFor(e.key);
      if (slot != null && !values.containsKey(slot)) {
        values[slot] = e.value;
      } else if (slot == null) {
        extras.add(e);
      }
    }
    // khali slot → items no sarvalo
    if (_all.isNotEmpty) {
      for (final s in _slots) {
        final slot = s[0] as String;
        final keys = s[2] as List<String>;
        if (values.containsKey(slot) || keys.isEmpty) continue;
        final key = keys.firstWhere((k) => _all.any((r) => r.containsKey(k)), orElse: () => '');
        if (key.isEmpty) continue;
        values[slot] = _fmt(slot, _all.fold(0.0, (a, r) => a + _num(r[key])));
      }
    }

    return [
      for (final s in _slots)
        if (values.containsKey(s[0])) MapEntry(s[1] as String, values[s[0]]!),
      ...extras,
    ];
  }

  // =====================================================================
  //  EXPORT
  // =====================================================================
  Future<void> _export(bool pdf) async {
    final cfg = widget.config;
    final builder = pdf ? cfg?.pdfUrl : cfg?.excelUrl;
    if (builder == null || widget.id == null) return;
    if (pdf ? _pdfLoading : _excelLoading) return;
    setState(() => pdf ? _pdfLoading = true : _excelLoading = true);

    try {
      final url = builder(widget.id!);
      debugPrint('🧾 VOUCHER ${pdf ? 'PDF' : 'EXCEL'} => $url');
      final response = await ApiHelper().getPdfRequest(url);
      if (response != null && response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final name = (widget.voucherNo ?? widget.id!).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
        final file = File('${dir.path}/voucher_$name.${pdf ? 'pdf' : 'xlsx'}');
        await file.writeAsBytes(List<int>.from(response.data));
        await OpenFile.open(file.path);
      } else if (mounted) {
        AppMessage.error(context, 'Unable to download ${pdf ? 'PDF' : 'Excel'}');
      }
    } catch (e) {
      debugPrint('❌ Voucher export error: $e');
      if (mounted) AppMessage.error(context, 'Something went wrong');
    } finally {
      if (mounted) setState(() => pdf ? _pdfLoading = false : _excelLoading = false);
    }
  }

  // =====================================================================
  //  UI — ✨ PREMIUM (navy + gold, light body)
  // =====================================================================
  IconData get _typeIcon {
    final t = widget.title.toLowerCase();
    if (t.contains('sale')) return Icons.receipt_long_rounded;
    if (t.contains('approval')) return Icons.assignment_turned_in_rounded;
    if (t.contains('return')) return Icons.assignment_return_rounded;
    if (t.contains('receive')) return Icons.move_to_inbox_rounded;
    if (t.contains('job') || t.contains('issue')) return Icons.handyman_rounded;
    return Icons.description_rounded;
  }

  String? _infoValue(List<String> keys) {
    for (final e in _info) {
      final k = e.key.toLowerCase();
      if (keys.any(k.contains)) return e.value;
    }
    return null;
  }

  static const _heroKeys = ['Qty', 'Gross Wt', 'Net Wt', 'Fine Wt', 'Total'];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mobile = size.width < 600;

    return Dialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 28, vertical: mobile ? 24 : 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: gold.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? size.width : 980,
          maxHeight: size.height * (mobile ? 0.88 : 0.84),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(mobile),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(mobile ? 12 : 20, 14, mobile ? 12 : 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroStrip(mobile),
                    _infoGrid(mobile),
                    if (_hasTable) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(
                          width: 3.5,
                          height: 16,
                          decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 8),
                        const Text('ITEMS', style: TextStyle(color: ink, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: goldSoft, borderRadius: BorderRadius.circular(20)),
                          child: Text('${_rows.length}',
                              style: const TextStyle(color: goldDeep, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                        const Spacer(),
                        if (!mobile) SizedBox(width: 280, child: _searchBox()),
                      ]),
                      if (mobile) ...[const SizedBox(height: 10), _searchBox()],
                      const SizedBox(height: 12),
                      _rows.isEmpty || _columns.isEmpty
                          ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: const Column(children: [
                          Icon(Icons.inventory_2_outlined, color: label, size: 26),
                          SizedBox(height: 8),
                          Text('No items found', style: TextStyle(color: label, fontSize: 12)),
                        ]),
                      )
                          : _table(),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.config?.pdfUrl != null || widget.config?.excelUrl != null) _footer(mobile),
          ],
        ),
      ),
    );
  }

  // ---- header: navy gradient + gold line ----
  Widget _header(bool mobile) {
    final status = _infoValue(['status']);
    final party = _infoValue(['customer', 'worker', 'party']);
    final date = _infoValue(['date']);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, navy2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: gold, width: 1.6)),
      ),
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 14, 6, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const LinearGradient(colors: [goldLight, gold]),
            boxShadow: [BoxShadow(color: gold.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Icon(_typeIcon, color: navy, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.title.toUpperCase(),
              style: TextStyle(
                  color: goldLight.withOpacity(0.95), fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              (widget.voucherNo ?? '').trim().isEmpty ? 'Voucher' : widget.voucherNo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white, fontSize: mobile ? 16 : 18, fontWeight: FontWeight.w800, letterSpacing: 0.3),
            ),
            const SizedBox(height: 7),
            Wrap(spacing: 5, runSpacing: 5, children: [
              if (party != null) _headChip(Icons.person_rounded, party),
              if (date != null) _headChip(Icons.event_rounded, date),
              if (status != null) _statusChip(status),
            ]),
          ]),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _headChip(IconData i, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 11.5, color: goldLight),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  Widget _statusChip(String s) {
    final l = s.toLowerCase();
    final Color c = l.contains('sold')
        ? const Color(0xffF87171)
        : l.contains('return')
        ? const Color(0xff60A5FA)
        : (l.contains('pending') || l.contains('approval') || l.contains('open') || l.contains('partial'))
        ? const Color(0xffFBBF24)
        : const Color(0xff34D399);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(s, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ---- totals as hero tiles ----
  Widget _heroStrip(bool mobile) {
    final tiles = _info.where((e) => _heroKeys.contains(e.key)).toList();
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (_, c) {
        final per = mobile ? 2 : tiles.length.clamp(1, 5);
        final w = (c.maxWidth - (per - 1) * 8) / per;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tiles.map((e) {
            final isTotal = e.key == 'Total';
            final v = e.value.trim();
            final unit = e.key.endsWith('Wt') && !RegExp(r'g$', caseSensitive: false).hasMatch(v) ? ' g' : '';
            final rupee = isTotal && !v.startsWith('₹') ? '₹ ' : '';
            return Container(
              width: isTotal && mobile && tiles.length.isOdd ? c.maxWidth : w,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                gradient: isTotal
                    ? const LinearGradient(colors: [navy, navy2], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: isTotal ? null : card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isTotal ? gold.withOpacity(0.6) : border),
                boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.key.toUpperCase(),
                    style: TextStyle(
                        color: isTotal ? goldLight : label, fontSize: 8.5, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$rupee$v$unit',
                      style: TextStyle(
                          color: isTotal ? Colors.white : ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
              ]),
            );
          }).toList(),
        );
      }),
    );
  }

  IconData _infoIcon(String k) {
    final l = k.toLowerCase();
    if (l.contains('voucher')) return Icons.tag_rounded;
    if (l.contains('date')) return Icons.event_rounded;
    if (l.contains('customer') || l.contains('worker') || l.contains('party')) return Icons.person_rounded;
    if (l.contains('created')) return Icons.badge_rounded;
    if (l.contains('status')) return Icons.flag_rounded;
    if (l.contains('barcode') || l.contains('label')) return Icons.qr_code_2_rounded;
    if (l.contains('amt') || l.contains('amount')) return Icons.currency_rupee_rounded;
    return Icons.info_outline_rounded;
  }

  // ---- details card (2 / 4 columns) ----
  Widget _infoGrid(bool mobile) {
    final rows = _info.where((e) => !_heroKeys.contains(e.key)).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final perRow = mobile ? 2 : 4;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(builder: (_, c) {
        final w = (c.maxWidth - (perRow - 1) * 12) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: rows
              .map((e) => SizedBox(
            width: w,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: goldSoft, borderRadius: BorderRadius.circular(8)),
                child: Icon(_infoIcon(e.key), size: 13.5, color: goldDeep),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.key,
                      style: const TextStyle(color: label, fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                  const SizedBox(height: 1),
                  Text(e.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ))
              .toList(),
        );
      }),
    );
  }

  // ---- bottom bar: premium PDF / Excel buttons ----
  Widget _footer(bool mobile) => Container(
    padding: EdgeInsets.fromLTRB(mobile ? 12 : 20, 10, mobile ? 12 : 20, 12),
    decoration: BoxDecoration(
      color: card,
      border: const Border(top: BorderSide(color: border)),
      boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
    ),
    child: SafeArea(
      top: false,
      child: Row(children: [
        if (widget.config?.excelUrl != null) ...[
          Expanded(
            child: _actionBtn('Excel', excelBlue, _excelLoading, () => _export(false),
                icon: Icons.table_chart_rounded, outlined: true),
          ),
          const SizedBox(width: 10),
        ],
        if (widget.config?.pdfUrl != null)
          Expanded(
            flex: 2,
            child: _actionBtn('Download PDF', pdfPink, _pdfLoading, () => _export(true),
                icon: Icons.picture_as_pdf_rounded),
          ),
      ]),
    ),
  );

  Widget _actionBtn(String text, Color color, bool loading, VoidCallback onTap,
      {IconData? icon, bool outlined = false}) {
    final child = loading
        ? SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? color : Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: outlined ? color : Colors.white),
        const SizedBox(width: 7),
      ],
      Text(text,
          style: TextStyle(
              color: outlined ? color : Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
    ]);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: outlined ? null : const LinearGradient(colors: [pdfPink, pdfDeep]),
            color: outlined ? color.withOpacity(0.07) : null,
            border: outlined ? Border.all(color: color.withOpacity(0.45), width: 1.2) : null,
            boxShadow: outlined
                ? null
                : [BoxShadow(color: pdfPink.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _searchBox() => TextField(
    controller: _search,
    style: const TextStyle(color: ink, fontSize: 12.5),
    cursorColor: navy,
    decoration: InputDecoration(
      isDense: true,
      hintText: 'Search label, HUID, item…',
      hintStyle: const TextStyle(color: label, fontSize: 12),
      prefixIcon: const Icon(Icons.search_rounded, color: label, size: 18),
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder:
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 1.5)),
    ),
  );

  // ---------------------------------------------------------------------
  //  TABLE
  // ---------------------------------------------------------------------
  /// Footer ma sarvalo karva layak (rate / purity / waste nahi)
  bool _isSumKey(String k) =>
      RegExp(r'(qty|pcs|weight|_wt$|amount|net_total|^total)').hasMatch(k) && !k.contains('rate');

  double _colWidth(String key) {
    if (key == 'label') return 84;
    if (key == 'huid') return 100;
    if (key.contains('name') || key == 'item' || key == 'remarks') return 148;
    if (key.contains('qty') || key == 'pcs') return 60;
    if (key.contains('total') || key.contains('amount')) return 110;
    return 94;
  }

  String _fmtSum(String key, double v) {
    if (key.contains('qty') || key == 'pcs') return v.toStringAsFixed(0);
    if (key.contains('weight') || key.endsWith('_wt')) return _wt.format(v);
    return _amt.format(v);
  }

  bool _isNumKey(String k) => RegExp(r'(qty|pcs|weight|_wt$|amount|total|rate|purity|percent)').hasMatch(k);

  Widget _cell(String text, double width,
      {bool bold = false, Color? color, Color? textColor, bool right = false, bool head = false}) =>
      Container(
        width: width,
        constraints: BoxConstraints(minHeight: head ? 36 : 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color,
          border: Border(bottom: BorderSide(color: head ? navy : border)),
        ),
        child: Text(
          head ? text.toUpperCase() : text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: textColor ?? ink,
            fontSize: head ? 9 : 11.5,
            letterSpacing: head ? 0.8 : 0,
            height: 1.2,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      );

  Widget _table() {
    const sr = 38.0;
    final width = sr + _columns.fold(0.0, (a, c) => a + _colWidth(c.key));

    return Container(
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        thickness: 4,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Row(children: [
                  _cell('#', sr, bold: true, color: tableHead, textColor: goldLight, head: true),
                  ..._columns.map((c) => _cell(c.value, _colWidth(c.key),
                      bold: true, color: tableHead, textColor: Colors.white, head: true, right: _isNumKey(c.key))),
                ]),
                ..._rows.asMap().entries.map((e) {
                  final color = e.key.isEven ? rowA : rowB;
                  return Row(children: [
                    _cell('${e.key + 1}', sr, color: color, textColor: label),
                    ..._columns.map((c) => _cell(_cellText(e.value[c.key]), _colWidth(c.key),
                        color: color, right: _isNumKey(c.key), bold: c.key.contains('total'))),
                  ]);
                }),
                if (_rows.length > 1)
                  Row(children: [
                    _cell('', sr, bold: true, color: goldSoft),
                    ..._columns.asMap().entries.map((e) {
                      final key = e.value.key;
                      String t = e.key == 0 ? 'TOTAL' : '';
                      if (_isSumKey(key)) t = _fmtSum(key, _rows.fold(0.0, (a, r) => a + _num(r[key])));
                      return _cell(t, _colWidth(key),
                          bold: true, color: goldSoft, textColor: goldDeep, right: _isNumKey(key));
                    }),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "gross_weight" → "Gross Wt"
  static String _pretty(String key) {
    const m = {
      'label': 'Label', 'huid': 'HUID', 'item_name': 'Item', 'qty_pcs': 'Qty', 'gross_weight': 'Gross Wt',
      'other_weight': 'Other Wt', 'net_weight': 'Net Wt', 'purity': 'Purity', 'waste_percent': 'Waste %',
      'fine_weight': 'Fine Wt', 'metal_rate': 'Metal Rate', 'metal_amount': 'Metal Amt',
      'labour_rate': 'Labour Rate', 'labour_amount': 'Labour Amt', 'other_amount': 'Other Amt',
      'net_total': 'Total', 'total_amount': 'Total', 'label_code': 'Label Code', 'qr_code': 'QR',
      'branch_name': 'Branch', 'customer_name': 'Customer', 'source_date': 'Date', 'source': 'Source',
      'stock_type_name': 'Stock Type', 'image_status': 'Image Status', 'date': 'Date',
    };
    if (m.containsKey(key)) return m[key]!;
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) {
      if (w == 'wt' || w == 'weight') return 'Wt';
      if (w == 'amount') return 'Amt';
      if (w == 'percent') return '%';
      return '${w[0].toUpperCase()}${w.substring(1)}';
    })
        .join(' ');
  }
}

// =======================================================================
//  📒 LEDGER POPUP — MODELS
//  balance = debit − credit :  + = Dr (worker paase baaki), − = Cr
// =======================================================================
class LedgerPopup {
  final String title; // "Worker Ledger — Avinash Mkt"
  final String? subtitle; // "Badho samay · Daily"
  final List<LedgerSheet> Function() build; // tap thay tyare j bane (lazy)
  final String Function(String type)? exportUrl; // type = pdf | excel

  const LedgerPopup({required this.title, this.subtitle, required this.build, this.exportUrl});
}

class LedgerSheet {
  final String title; // "Avinash Mkt — Silver"
  final double opening;
  final List<LedgerSheetRow> rows;
  final double? closing; // null = rows parthi
  final String debitLabel;
  final String creditLabel;
  final String netLabel;
  final String openingLabel;
  final String footerLabel;

  const LedgerSheet({
    required this.title,
    required this.rows,
    this.opening = 0,
    this.closing,
    this.debitLabel = 'Debit — Issued',
    this.creditLabel = 'Credit — Received',
    this.netLabel = 'Net pending',
    this.openingLabel = 'Opening balance brought forward',
    this.footerLabel = 'Period totals / Closing pending',
  });

  double get totalDebit => rows.fold(0.0, (a, r) => a + r.debit);
  double get totalCredit => rows.fold(0.0, (a, r) => a + r.credit);

  /// Running balance: API aape to e, nahi to opening + Σ(debit − credit)
  List<double> get running {
    var bal = opening;
    return rows.map((r) {
      bal = r.balance ?? (bal + r.debit - r.credit);
      return bal;
    }).toList();
  }

  double get closingBal => closing ?? (rows.isEmpty ? opening : running.last);
}

class LedgerSheetRow {
  final String date; // "30-09-2026"
  final String particulars;
  final double debit;
  final double credit;
  final double? balance;

  const LedgerSheetRow({
    required this.date,
    required this.particulars,
    required this.debit,
    required this.credit,
    this.balance,
  });
}

// =======================================================================
//  📒 LEDGER POPUP — DIALOG
// =======================================================================
class _LedgerDialog extends StatefulWidget {
  final LedgerPopup popup;
  final List<LedgerSheet> sheets;
  const _LedgerDialog({required this.popup, required this.sheets});

  @override
  State<_LedgerDialog> createState() => _LedgerDialogState();
}

class _LedgerDialogState extends State<_LedgerDialog> {
  // ✨ same premium palette as the voucher popup
  static const Color bg = Color(0xffF6F5F1);
  static const Color card = Colors.white;
  static const Color navy = Color(0xff0E1A3B);
  static const Color navy2 = Color(0xff1E3370);
  static const Color gold = Color(0xffC9A24B);
  static const Color goldLight = Color(0xffE9CF8E);
  static const Color goldDeep = Color(0xff8A6A1F);
  static const Color goldSoft = Color(0xffFBF3DF);
  static const Color ink = Color(0xff1A2033);
  static const Color headBg = navy;
  static const Color border = Color(0xffE6E8EF);
  static const Color muted = Color(0xff7A8197);
  static const Color drHead = Color(0xff9F1239);
  static const Color drCell = Color(0xffFFF1F3);
  static const Color crHead = Color(0xff1E40AF);
  static const Color crCell = Color(0xffEFF4FF);
  static const Color excelBlue = Color(0xff15803D);
  static const Color pdfPink = Color(0xffE11D48);
  static const Color pdfDeep = Color(0xffBE123C);

  static final NumberFormat _wt = NumberFormat('#,##0.000');

  bool _pdf = false, _excel = false;

  String _bal(double v) {
    if (v.abs() < 0.0005) return _wt.format(0);
    return '${_wt.format(v.abs())} ${v > 0 ? 'Dr' : 'Cr'}';
  }

  Future<void> _export(bool pdf) async {
    final b = widget.popup.exportUrl;
    if (b == null || (pdf ? _pdf : _excel)) return;
    setState(() => pdf ? _pdf = true : _excel = true);
    try {
      final url = b(pdf ? 'pdf' : 'excel');
      debugPrint('📒 LEDGER EXPORT => $url');
      final res = await ApiHelper().getPdfRequest(url);
      if (res != null && res.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final stamp = DateFormat('ddMMyyyy_HHmm').format(DateTime.now());
        final file = File('${dir.path}/worker_ledger_$stamp.${pdf ? 'pdf' : 'xlsx'}');
        await file.writeAsBytes(List<int>.from(res.data));
        await OpenFile.open(file.path);
      } else if (mounted) {
        AppMessage.error(context, 'Unable to download ${pdf ? 'PDF' : 'Excel'}');
      }
    } catch (e) {
      if (mounted) AppMessage.error(context, 'Something went wrong');
    } finally {
      if (mounted) setState(() => pdf ? _pdf = false : _excel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mobile = size.width < 600;

    return Dialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 28, vertical: mobile ? 24 : 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: gold.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? size.width : 1040,
          maxHeight: size.height * (mobile ? 0.88 : 0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(mobile),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(mobile ? 12 : 20, 14, mobile ? 12 : 20, 14),
                itemCount: widget.sheets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (_, i) => _sheet(widget.sheets[i], mobile),
              ),
            ),
            if (widget.popup.exportUrl != null) _footer(mobile),
          ],
        ),
      ),
    );
  }

  Widget _header(bool mobile) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [navy, navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
      border: Border(bottom: BorderSide(color: gold, width: 1.6)),
    ),
    padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 14, 6, 14),
    child: Row(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(colors: [goldLight, gold]),
          boxShadow: [BoxShadow(color: gold.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: const Icon(Icons.menu_book_rounded, color: navy, size: 19),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('LEDGER',
              style: TextStyle(color: goldLight, fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(widget.popup.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: mobile ? 15 : 17, fontWeight: FontWeight.w800)),
          if (widget.popup.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(widget.popup.subtitle!,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
            ),
        ]),
      ),
      IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
        ),
      ),
    ]),
  );

  Widget _footer(bool mobile) => Container(
    padding: EdgeInsets.fromLTRB(mobile ? 12 : 20, 10, mobile ? 12 : 20, 12),
    decoration: BoxDecoration(
      color: card,
      border: const Border(top: BorderSide(color: border)),
      boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
    ),
    child: SafeArea(
      top: false,
      child: Row(children: [
        Expanded(child: _btn('Excel', excelBlue, _excel, () => _export(false), Icons.table_chart_rounded, true)),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _btn('Download PDF', pdfPink, _pdf, () => _export(true), Icons.picture_as_pdf_rounded, false),
        ),
      ]),
    ),
  );

  Widget _btn(String t, Color c, bool loading, VoidCallback onTap, IconData icon, bool outlined) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: outlined ? null : const LinearGradient(colors: [pdfPink, pdfDeep]),
          color: outlined ? c.withOpacity(0.07) : null,
          border: outlined ? Border.all(color: c.withOpacity(0.45), width: 1.2) : null,
          boxShadow: outlined
              ? null
              : [BoxShadow(color: pdfPink.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Center(
          child: loading
              ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? c : Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: outlined ? c : Colors.white),
            const SizedBox(width: 7),
            Text(t,
                style: TextStyle(
                    color: outlined ? c : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    ),
  );

  /// "Avinash Mkt — Silver"  +  "Net pending: 301.500 Cr g"  +  table
  Widget _sheet(LedgerSheet s, bool mobile) {
    final run = s.running;
    final wDate = mobile ? 92.0 : 130.0;
    final wPart = mobile ? 190.0 : 320.0;
    final wDr = mobile ? 118.0 : 180.0;
    final wCr = mobile ? 126.0 : 200.0;
    final wBal = mobile ? 128.0 : 180.0;

    Widget cell(String t, double w,
        {Color? color, bool bold = false, Color text = ink, Color? head, bool right = false}) {
      final isHead = head != null;
      return Container(
        width: w,
        constraints: BoxConstraints(minHeight: isHead ? 36 : 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: head ?? color,
          border: Border(bottom: BorderSide(color: isHead ? Colors.transparent : border)),
        ),
        child: Text(
          isHead ? t.toUpperCase() : t,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: isHead ? Colors.white : text,
            fontSize: isHead ? 9.5 : 11.5,
            letterSpacing: isHead ? 0.7 : 0,
            fontWeight: bold || isHead ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      );
    }

    Row row(List<Widget> c) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: c);

    final table = Container(
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: row([
              cell('Date', wDate, head: headBg),
              cell('Particulars', wPart, head: headBg),
              cell(s.debitLabel, wDr, head: drHead, right: true),
              cell(s.creditLabel, wCr, head: crHead, right: true),
              cell('Balance', wBal, head: headBg, right: true),
            ]),
          ),
          IntrinsicHeight(
            child: row([
              cell('—', wDate, text: muted),
              cell(s.openingLabel, wPart, text: muted),
              cell('—', wDr, color: drCell, right: true, text: muted),
              cell('—', wCr, color: crCell, right: true, text: muted),
              cell(_bal(s.opening), wBal, right: true, bold: true),
            ]),
          ),
          for (var i = 0; i < s.rows.length; i++)
            IntrinsicHeight(
              child: row([
                cell(s.rows[i].date, wDate, text: muted),
                cell(s.rows[i].particulars, wPart),
                cell(_wt.format(s.rows[i].debit), wDr, color: drCell, right: true, text: drHead),
                cell(_wt.format(s.rows[i].credit), wCr, color: crCell, right: true, text: crHead),
                cell(_bal(run[i]), wBal, right: true, bold: true),
              ]),
            ),
          IntrinsicHeight(
            child: row([
              cell('', wDate, color: goldSoft),
              cell(s.footerLabel, wPart, color: goldSoft, bold: true, text: goldDeep),
              cell(_wt.format(s.totalDebit), wDr, color: goldSoft, bold: true, right: true, text: drHead),
              cell(_wt.format(s.totalCredit), wCr, color: goldSoft, bold: true, right: true, text: crHead),
              cell(_bal(s.closingBal), wBal, color: goldSoft, bold: true, right: true, text: goldDeep),
            ]),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3.5, height: 16, decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [navy, navy2]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${s.netLabel}  ', style: const TextStyle(color: goldLight)),
                TextSpan(text: '${_bal(s.closingBal)} g', style: const TextStyle(color: Colors.white)),
              ]),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
      ],
    );
  }
}
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Dashboard/HomeScreen.dart';
import '../../Extra/AppColors.dart';
import '../../Extra/AppMessage.dart';
import '../../Extra/PremiumSearchableDropdown.dart';

import 'package:pecifician_sysytem/Settings/BranchManagementScreen.dart'
    show BranchApi, Company, BranchTypeX;
import 'package:pecifician_sysytem/Reports/BranchAccess.dart';

class VoucherProcessHistoryScreen extends StatefulWidget {
  const VoucherProcessHistoryScreen({super.key});

  @override
  State<VoucherProcessHistoryScreen> createState() =>
      _VoucherProcessHistoryScreenState();
}

class _VoucherProcessHistoryScreenState
    extends State<VoucherProcessHistoryScreen> {
  bool isLoading = true;

  List vouchers = [];
  int? selectedVoucherId;

  Map<String, dynamic> voucher = {};
  Map<String, dynamic> history = {};
  Map<String, dynamic> summary = {};

  /// 🔥 Dark theme colors (screenshot pramane)
  static const Color bgColor = Color(0xff14151f);
  static const Color cardColor = Color(0xff1c1d2b);
  static const Color rowColor = Color(0xff23243b);
  static const Color borderColor = Color(0xff2c2d40);
  static const Color pink = Color(0xffE91E63);
  static const Color green = Color(0xff2ECC71);
  static const Color blue = Color(0xff2979FF);

  // ============================================================
  // 🔥 BRANCH REPORTS (Sale Summary jevu j)
  // ============================================================

  /// Branch API mathi aavti companies (main + branches)
  List<Company> branchCompanies = [];

  /// Dropdown ma select kareli (haju apply nathi thai)
  Set<int> selectedCompanyIds = {};

  /// "View" dabavya pachhi apply thayeli
  List<int> appliedCompanyIds = [];

  /// Branch report chalu chhe?
  bool get _branchMode => appliedCompanyIds.isNotEmpty;

  bool branchesLoading = false;
  bool canViewBranches = false;
  bool branchExpanded = true;
  bool branchReportLoading = false;

  /// Potani (main) company — single branch mate
  int? _mainCompanyId;

  /// 🔥 Kai branch mokalvi:
  ///   multi (View karyu) → pasand kareli badhi
  ///   single / normal    → potani company (main) — server ne joie j chhe
  List<int> get _activeBranchIds => appliedCompanyIds.isNotEmpty
      ? appliedCompanyIds
      : [if (_mainCompanyId != null) _mainCompanyId!];

  /// management_branches[]=1&management_branches[]=2
  String get _branchQuery => _activeBranchIds
      .map((id) => "management_branches[]=$id")
      .join("&");

  /// voucher-history?voucher_id=5&management_branches[]=9
  String _br(String url) => _activeBranchIds.isNotEmpty
      ? "$url${url.contains('?') ? '&' : '?'}$_branchQuery"
      : url;

  /// 🔥 Ek voucher pasand hoy → fakt e voucher ni j branch mokalo
  ///    (badhi branch sathe server 500 aape chhe)
  ///    voucher-history?voucher_id=95&management_branches[]=21
  /// Je branch thi voucher chalyo e yaad (voucher_id → branch id)
  final Map<int, int> _voucherBranch = {};

  /// Ek pachhi ek dar branch ekli → je chale e
  List<String> _perBranchUrls(String url) => [
    for (final id in _activeBranchIds)
      "$url${url.contains('?') ? '&' : '?'}management_branches[]=$id",
  ];

  int? _branchIdOfVoucher(int? voucherId) {
    if (voucherId == null) return null;
    if (_voucherBranch[voucherId] != null) return _voucherBranch[voucherId];
    for (final v in vouchers) {
      if (v is Map && "${v["id"]}" == "$voucherId") {
        // Server nu company_id pehla (sachu), pachhi aapde lagavelu
        if (v["_company_from_req"] == true) return null; // pakku nathi
        final int? id =
        int.tryParse("${v["company_id"] ?? v["branch_id"] ?? ""}");
        if (id != null) return id;
        // company_id na hoy to branch naam thi
        final String name = _branchOf(v).toLowerCase();
        for (final c in branchCompanies) {
          if (c.name.toLowerCase() == name) return c.id;
        }
      }
    }
    return null;
  }

  /// Voucher sathe URL: branch mode ma fakt e voucher ni branch
  String _brVoucher(String url, int? voucherId) {
    if (!_branchMode) return _br(url); // single → potani branch
    if (voucherId == null) return _br(url);
    final int? bid = _branchIdOfVoucher(voucherId);
    if (bid == null) return _br(url);
    return "$url${url.contains('?') ? '&' : '?'}management_branches[]=$bid";
  }

  /// voucher → branch name (company_id / branch / company_name)
  String _branchOf(Map v) {
    final int? id = int.tryParse("${v["company_id"] ?? ""}");
    if (id != null) {
      for (final c in branchCompanies) {
        if (c.id == id) return c.name;
      }
    }
    final dynamic b = v["branch"] ?? v["branch_name"] ?? v["company"];
    if (b is Map && b["name"] != null) return b["name"].toString();
    final String t = (b ?? v["company_name"] ?? "").toString().trim();
    return t.isEmpty || t == "null" ? "" : t;
  }

  @override
  void initState() {
    super.initState();
    loadHistory();
    _loadBranches();
  }

  static String get _historyUrl => "${ApiConstants.baseUrl}voucher-history";

  /// 🏢 Branch merge: dar branch na voucher ALAG mangavo
  ///    voucher-history?management_branches[]=9
  ///    voucher-history?management_branches[]=20 ...
  ///    → dar voucher sathe eni branch (_branch_id) — pachhi data / PDF
  ///      e j branch thi (badhi branch sathe server 500 aape chhe)
  Future<List<Map<String, dynamic>>> _loadBranchVouchers() async {
    final results = await Future.wait(appliedCompanyIds.map((bid) async {
      final String url = "$_historyUrl?management_branches[]=$bid";
      debugPrint("🏢 BRANCH VOUCHERS => $url");
      try {
        final res = await ApiHelper().getRequest(url);
        final data = res?.data;
        if (res?.statusCode == 200 && data is Map && data["success"] == true) {
          final dynamic d = data["data"] ?? {};
          final List list = d is Map && d["vouchers"] is List ? d["vouchers"] : [];
          return [
            for (final v in list)
              if (v is Map)
                {
                  ...Map<String, dynamic>.from(v),
                  "_branch_id": bid,
                  if (v["company_id"] == null) "company_id": bid,
                  if (v["company_id"] == null) "_company_from_req": true,
                },
          ];
        }
      } catch (e) {
        debugPrint("❌ Branch $bid vouchers => $e");
      }
      return <Map<String, dynamic>>[];
    }));

    // Ek list — same voucher be vaar na aave.
    // ⚠️ Server branch filter na gane to dar branch ma e j voucher aave →
    //    e voucher ni branch "pakki nathi" (PDF vakhte dar branch try thashe)
    final Map<String, Map<String, dynamic>> merged = {};
    final Map<String, int> seenCount = {};
    for (final list in results) {
      for (final v in list) {
        final String id = "${v["id"]}";
        seenCount[id] = (seenCount[id] ?? 0) + 1;
        merged.putIfAbsent(id, () => v);
      }
    }
    final all = merged.values.toList();
    for (final v in all) {
      final int? id = int.tryParse("${v["id"]}");
      if (id == null) continue;
      final int? serverBid =
      int.tryParse("${v["company_id"] ?? v["branch_id"] ?? ""}");
      final int? reqBid = int.tryParse("${v["_branch_id"]}");
      if (serverBid != null && !(v["_company_from_req"] == true)) {
        _voucherBranch[id] = serverBid; // ✅ server kahe e
      } else if ((seenCount["$id"] ?? 0) == 1 && reqBid != null) {
        _voucherBranch[id] = reqBid; // ✅ fakt ek branch ma j aavyo
      } else {
        _voucherBranch.remove(id); // ❓ pakku nathi → try karshe
        v.remove("company_id");
      }
    }
    debugPrint("🏢 Branch vouchers total: ${all.length} "
        "(known branch: ${all.where((v) => _voucherBranch.containsKey(int.tryParse("${v["id"]}"))).length})");
    return all;
  }

  /// ✅ API CALL
  Future<void> loadHistory({int? voucherId}) async {
    // 🏢 Branch merge + voucher nathi → badhi branch na voucher, pachhi pehlo
    if (_branchMode && voucherId == null) {
      final list = await _loadBranchVouchers();
      if (!mounted) return;
      setState(() {
        vouchers = list;
        isLoading = false;
      });
      if (list.isEmpty) {
        setState(() {
          selectedVoucherId = null;
          voucher = {};
          history = {};
          summary = {};
        });
        AppMessage.error(context, "No vouchers found in selected branches");
        return;
      }
      final int? first = int.tryParse("${list.first["id"]}");
      if (first != null) {
        setState(() => selectedVoucherId = first);
        await loadHistory(voucherId: first);
      }
      return;
    }

    String url = _historyUrl;
    if (voucherId != null) {
      url += "?voucher_id=$voucherId";
    }

    // 🔥 Badhi branch sathe: &management_branches[]=9&management_branches[]=20...
    final String base = url;
    url = _br(base);
    debugPrint("📜 VOUCHER HISTORY URL => $url");

    var response = await ApiHelper().getRequest(url);

    // ⚠️ Branch khabar na hoy / 500 → dar branch ekli, pachhi badhi, pachhi vagar
    if (_activeBranchIds.isNotEmpty &&
        voucherId != null &&
        (response == null || response.statusCode != 200)) {
      final Set<String> seen = {url};
      final List<String> tries = [
        _brVoucher(base, voucherId), // e voucher ni branch
        ..._perBranchUrls(base),
        base,
      ].where(seen.add).toList();
      for (int i = 0; i < tries.length; i++) {
        final String retry = tries[i];
        debugPrint("⚠️ VOUCHER HISTORY retry => $retry");
        response = await ApiHelper().getRequest(retry);
        if (response != null && response.statusCode == 200) {
          final m = RegExp(r'management_branches\[\]=(\d+)').allMatches(retry).toList();
          if (m.length == 1) {
            _voucherBranch[voucherId] = int.parse(m.first.group(1)!); // ✅ yaad
          }
          break;
        }
      }
    }

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      final data = response.data;

      if (data is Map && data["success"] == true) {
        final dynamic resData = data["data"] ?? {};

        // ✅ Server na voucher mathi sachi branch yaad rakho (PDF mate)
        if (_branchMode && voucherId != null && resData is Map) {
          final dynamic rv = resData["voucher"];
          if (rv is Map) {
            final int? vb = int.tryParse(
                "${rv["company_id"] ?? rv["branch_id"] ?? ""}");
            if (vb != null && _activeBranchIds.contains(vb)) {
              _voucherBranch[voucherId] = vb;
            }
          }
        }

        setState(() {
          // 🏢 Branch merge ma voucher list badhi branch ni j rahe
          if (!_branchMode) {
            vouchers = resData["vouchers"] ?? [];
            selectedVoucherId =
                int.tryParse("${resData["selected_voucher_id"] ?? ""}");
          } else {
            selectedVoucherId = voucherId;
          }
          voucher = Map<String, dynamic>.from(resData["voucher"] ?? {});
          // Branch naam mate voucher ma branch id
          if (_branchMode && voucherId != null && voucher["company_id"] == null) {
            final int? bid = _voucherBranch[voucherId];
            if (bid != null) voucher["company_id"] = bid;
          }
          history = Map<String, dynamic>.from(resData["history"] ?? {});
          summary = Map<String, dynamic>.from(history["summary"] ?? {});
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        AppMessage.error(
          context,
          (data is Map ? data["message"] : null) ?? "Failed to load data",
        );
      }
    } else {
      setState(() => isLoading = false);
      AppMessage.error(context, "Failed to load data");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final isMobile = width < 600;
    return Scaffold(
      //backgroundColor: bgColor,
      backgroundColor: Colors.white,
      body: SafeArea(
        // Loader fakt ApiHelper nu j (screen spinner nahi)
        child: RefreshIndicator(
          onRefresh: () => loadHistory(voucherId: selectedVoucherId),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 16),

                // 🔥 Branch Reports tab sauthi upar
                if (branchesLoading || canViewBranches) ...[
                  _buildBranchCard(),
                  const SizedBox(height: 12),
                ],

                _filterBar(),
                const SizedBox(height: 16),
                _summaryBar(),
                const SizedBox(height: 20),
                _timeline(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ HEADER
  Widget _header() {
    return Row(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () {
              Navigator.pop(context,true);
            },
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:AppColors.primaryDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          "Voucher Process History",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ✅ FILTER BAR (Voucher dropdown + Date/Process/Worker + Buttons)
  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;

          List<Widget> fields = [
            _voucherDropdown(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _readOnlyField(
                    "Date",
                    voucher["voucher_date_view"]?.toString() ?? "-",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _readOnlyField(
                    "Process",
                    voucher["process_name"]?.toString() ?? "-",
                  ),
                ),
              ],
            ),
            _readOnlyField(
              "Worker",
              voucher["worker_name"]?.toString() ?? "-",
            ),
          ];

          List<Widget> buttons = [
            _actionBtn("View", pink, () {
              loadHistory(voucherId: selectedVoucherId);
            }),
            pdfBtn(() {
              if (selectedVoucherId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select a voucher first."),
                  ),
                );
                return;
              }

              _export("pdf");
            }),
            _actionBtn("Excel", blue, () async {
              if (selectedVoucherId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select a voucher first."),
                  ),
                );
                return;
              }

              await _export("excel");
            }),
          ];

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ...fields.map(
                      (f) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: f,
                    ),
                  ),
                ),
                ...buttons.map(
                      (b) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: b,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...fields.map(
                    (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: f,
                ),
              ),
              Row(
                children: buttons
                    .map(
                      (b) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: b,
                    ),
                  ),
                )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _voucherDropdown() {
    final List<Map<String, dynamic>> voucherList = vouchers
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    Map<String, dynamic>? selectedVoucher;

    if (selectedVoucherId != null) {
      try {
        selectedVoucher = voucherList.firstWhere(
              (e) => e["id"]?.toString() == selectedVoucherId.toString(),
        );
      } catch (_) {
        selectedVoucher = null;
      }
    }

    return PremiumSearchableDropdown<Map<String, dynamic>>(
      label: "Select Voucher",
      hint: "Select Voucher",
      items: voucherList,
      value: selectedVoucher,
      prefixIcon: Icons.receipt_long_outlined,
      dropdownMaxHeight: 350,
      itemLabel: (v) {
        final String br = _branchMode ? _branchOf(v) : "";
        return "${v["voucher_no"] ?? ""} | ${v["voucher_date_view"] ?? ""}"
            "${br.isNotEmpty ? " | $br" : ""}";
      },
      searchText: (v) {
        return "${v["voucher_no"] ?? ""} ${v["voucher_date_view"] ?? ""} "
            "${_branchOf(v)}";
      },
      onChanged: (v) {
        final int? val = int.tryParse("${v?["id"] ?? ""}");

        setState(() => selectedVoucherId = val);
        loadHistory(voucherId: val);
      },
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// ✅ SUMMARY BAR (Voucher No, Date, Gross Wt, Buch Wt, Net Wt, Silver Wt, Total Pcs, Created At)
  Widget _summaryBar() {
    List<Map<String, String>> items = [
      {"title": "Voucher No", "value": voucher["voucher_no"]?.toString() ?? "-"},
      {
        "title": "Voucher Date",
        "value": voucher["voucher_date_view"]?.toString() ?? "-"
      },
      {
        "title": "Gross Wt",
        "value": summary["gross_wt"]?.toString() ??
            voucher["gross_wt_total"]?.toString() ??
            "0.000"
      },
      {
        "title": "Buch Wt",
        "value": summary["buch_wt"]?.toString() ??
            voucher["buch_wt_total"]?.toString() ??
            "0.000"
      },
      {
        "title": "Net Wt",
        "value": summary["net_wt"]?.toString() ??
            voucher["net_wt_total"]?.toString() ??
            "0.000"
      },
      {
        "title": "Silver Wt",
        "value": summary["silver_wt"]?.toString() ??
            voucher["silver_wt_total"]?.toString() ??
            "0.000"
      },
      {
        "title": "Total Pcs",
        "value": summary["total_pcs"]?.toString() ??
            voucher["total_pcs"]?.toString() ??
            "0"
      },
      {
        "title": "Created At",
        "value": voucher["created_at_view"]?.toString() ?? "-"
      },
      // 🏢 Branch mode ma branch nu naam
      if (_branchMode && _branchOf(voucher).isNotEmpty)
        {"title": "Branch", "value": _branchOf(voucher)},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔥 PREMIUM HEADER STRIP
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark,
                  AppColors.gradientBlue,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.summarize_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Voucher Summary",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          /// 🔥 SUMMARY GRID (exact same data/logic, refined styling)
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;
              int columns = isWide
                  ? items.length
                  : (constraints.maxWidth > 600 ? 4 : 2);

              double colWidth = constraints.maxWidth / columns;

              return Wrap(
                children: items.map((item) {
                  return Container(
                    width: colWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: AppColors.border),
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["title"]!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item["value"]!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// ✅ TIMELINE (Casting Heating -> Metal Issue -> Receive -> Tree Cutting -> Sorting)
  Widget _timeline() {
    List<Map<String, dynamic>> steps = [];

    if (history["casting_heating"] != null) {
      final h = history["casting_heating"];
      steps.add({
        "title": "Casting Heating",
        "status":
        "${h["in_bhati_count"] ?? 0} In Bhati / ${h["total_count"] ?? 0} Pcs",
        "columns": ["Sr No", "Buch No", "In Bhati", "Checked At"],
        "keys": ["sr", "buch_no", "in_bhati_view", "checked_at_view"],
        "rows": h["rows"] ?? [],
        "totalRow": null,
      });
    }

    if (history["casting_metal_issue"] != null) {
      final h = history["casting_metal_issue"];
      steps.add({
        "title": "Casting Metal Issue",
        "status": "${h["issued_count"] ?? 0} Issue",
        "columns": ["Sr No", "Buch No", "Silver Wt", "Issue Silver Wt", "Issued At"],
        "keys": ["sr", "buch_no", "silver_wt", "issue_silver_wt", "issued_at_view"],
        "rows": h["rows"] ?? [],
        "totalRow": {
          "Sr No": "",
          "Buch No": "Total",
          "Silver Wt": h["silver_wt_total"]?.toString() ?? "0.000",
          "Issue Silver Wt": h["issue_silver_wt_total"]?.toString() ?? "0.000",
          "Issued At": "",
        },
      });
    }

    if (history["casting_receive"] != null) {
      final h = history["casting_receive"];
      steps.add({
        "title": "Casting Receive",
        "status": "${h["received_count"] ?? 0} Received",
        "columns": [
          "Sr No",
          "Buch No",
          "Release Tree Wt",
          "Release Tree Bhuko",
          "Release Tree Total Wt", // 🔥 NEW
          "Loss",
          "Released At"
        ],
        "keys": [
          "sr",
          "buch_no",
          "release_tree_wt",
          "release_tree_bhuko",
          "release_tree_total_wt", // 🔥 NEW
          "loss",
          "released_at_view"
        ],
        "rows": h["rows"] ?? [],
        "totalRow": {
          "Sr No": "",
          "Buch No": "Total",
          "Release Tree Wt": h["release_tree_wt_total"]?.toString() ?? "0.000",
          "Release Tree Bhuko":
          h["release_tree_bhuko_total"]?.toString() ?? "0.000",
          "Release Tree Total Wt": // 🔥 NEW
          h["release_tree_total_wt_total"]?.toString() ?? "0.000",
          "Loss": h["loss_total"]?.toString() ?? "0.000",
          "Released At": "",
        },
      });
    }

    if (history["tree_cutting_office"] != null) {
      final h = history["tree_cutting_office"];

      steps.add({
        "title": "Tree Cutting Office",
        "status": "${h["office_count"] ?? 0} Office",

        "columns": [
          "Sr No",
          "Buch No",
          "Tree Wt",
          "Tree Bhuko",
          "Remaining Tree Wt",
          "Office At",
        ],

        "keys": [
          "sr",
          "buch_no",
          "tree_wt",
          "tree_bhuko",
          "remaining_tree_wt",
          "office_at_view",
        ],

        "rows": h["rows"] ?? [],

        "totalRow": {
          "Sr No": "",
          "Buch No": "Total",
          "Tree Wt":
          h["tree_wt_total"]?.toString() ?? "0.000",
          "Tree Bhuko":
          h["tree_bhuko_total"]?.toString() ?? "0.000",
          "Remaining Tree Wt":
          h["remaining_tree_wt_total"]?.toString() ??
              "0.000",
          "Office At": "",
        },
      });
    }

    if (history["tree_cutting_issue"] != null) {
      final h = history["tree_cutting_issue"];
      steps.add({
        "title": "Tree Cutting Issue",
        "status": "${h["issued_count"] ?? 0} Issue",
        "columns": ["Sr No", "Buch No", "Worker", "Receive Tree Wt", "Issued At"],
        "keys": ["sr", "buch_no", "worker_name", "receive_tree_wt", "issued_at_view"],
        "rows": h["rows"] ?? [],
        "totalRow": {
          "Sr No": "",
          "Buch No": "Total",
          "Worker": "",
          "Receive Tree Wt": h["receive_tree_wt_total"]?.toString() ?? "0.000",
          "Issued At": "",
        },
      });
    }

    if (history["tree_cutting_receive"] != null) {
      final h = history["tree_cutting_receive"];
      steps.add({
        "title": "Tree Cutting Receive",
        "status": "${h["received_count"] ?? 0} Received",
        "columns": [
          "Sr No",
          "Buch No",
          "Worker",
          "Receive Pc Wt",
          "Receive Tree Bhuko",
          "Loss",
          "Received At"
        ],
        "keys": [
          "sr",
          "buch_no",
          "worker_name",
          "receive_pc_wt",
          "receive_tree_bhuko",
          "loss",
          "received_at_view"
        ],
        "rows": h["rows"] ?? [],
        "totalRow": {
          "Sr No": "",
          "Buch No": "Total",
          "Worker": "",
          "Receive Pc Wt": h["receive_pc_wt_total"]?.toString() ?? "0.000",
          "Receive Tree Bhuko":
          h["receive_tree_bhuko_total"]?.toString() ?? "0.000",
          "Loss": h["loss_total"]?.toString() ?? "0.000",
          "Received At": "",
        },
      });
    }

    if (history["casting_sorting"] != null) {
      final h = history["casting_sorting"];

      steps.add({
        "title": "Casting Sorting",
        "status":
        "${h["sorting_count"] ?? 0} Sorted / ${h["quantity_total"] ?? 0} Qty",
        "columns": [
          "Sr No",
          "Item",
          "Weight",
          "Quantity",
          "Sorted At",
        ],
        "keys": [
          "sr",
          "item",          // "Kada - KD" આવશે
          "weight",
          "quantity",
          "sorted_at_view",
        ],
        "rows": h["rows"] ?? [],
        "totalRow": {
          "Sr No": "",
          "Item": "Total",
          "Weight": h["sorting_wt_total"]?.toString() ?? "0.000",
          "Quantity": h["quantity_total"]?.toString() ?? "0",
          "Sorted At": "",
        },
      });
    }

    if (steps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 50),
        child: Center(
          child: Text(
            "No Data Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(steps.length, (index) {
        return _timelineCard(steps[index], index + 1, index == steps.length - 1);
      }),
    );
  }

  /// ✅ SINGLE TIMELINE CARD (No IntrinsicHeight — Stack based line)
  Widget _timelineCard(Map<String, dynamic> step, int stepNo, bool isLast) {
    List rows = step["rows"] ?? [];
    List<String> columns = List<String>.from(step["columns"]);
    List<String> keys = List<String>.from(step["keys"]);
    Map? totalRow = step["totalRow"];

    return Stack(
      children: [
        /// 🔥 Connecting Line (background, fixed left position)
        if (!isLast)
          Positioned(
            left: 14, // circle center (38/2 - line width/2)
            top: 0,    // circle ni niche thi start
            bottom: 0,
            child: Container(width: 2, color: Colors.grey.shade700),
          ),

        /// 🔥 Foreground Content
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 30,
                width: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: pink,
                ),
                child: Text(
                  "$stepNo",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step["title"],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step["status"],
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (rows.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: rowColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Text(
                          "No Data",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      _dataTable(columns, keys, rows, totalRow),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );}

  Widget _dataTable(
      List<String> columns,
      List<String> keys,
      List rows,
      Map? totalRow,
      ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: borderColor),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header
          TableRow(
            decoration: const BoxDecoration( color:AppColors.background, ),
            children: columns
                .map((c) => _cell(c, true, color: Colors.black))
                .toList(),
          ),

          // Data
          ...List.generate(rows.length, (i) {
            final row = rows[i];
            return TableRow(
              children: keys.map((k) {
                if (k == "sr") {
                  return _cell("${i + 1}", false, color: Colors.black);
                }
                return _cell(
                  row[k]?.toString() ?? "-",
                  false,
                  color: Colors.black,
                );
              }).toList(),
            );
          }),

          // Total
          if (totalRow != null)
            TableRow(
              decoration: BoxDecoration(color: rowColor.withOpacity(0.2)),
              children: columns
                  .map((c) => _cell(
                totalRow[c]?.toString() ?? "",
                true,
                color: Colors.black, // <-- Total Row Black
              ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _cell(
      String text,
      bool bold, {
        Color color = Colors.black,
      }) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              "PDF",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================================
  /// 📄 EXPORT — PDF / EXCEL (getPdfRequest → bytes, branch wise)
  /// voucher-history?voucher_id=5&management_branches[]=1&management_branches[]=2&export=pdf
  /// =========================================================

  static String get _exportUrl => _historyUrl;

  /// "pdf" / "excel" chalu hoy tyare (bijo tap na thay)
  String? _exporting;

  Future<void> _export(String type) async {
    if (_exporting != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = type);

    try {
      // 📄 PDF (voucher pasand hoy): navi API → voucher_history_pdf/95
      final bool newPdf = type == "pdf" && selectedVoucherId != null;
      String plain = newPdf
          ? "${ApiConstants.baseUrl}voucher_history_pdf/$selectedVoucherId"
          : _exportUrl;
      if (!newPdf && selectedVoucherId != null) {
        plain += "?voucher_id=$selectedVoucherId";
      }
      String withExport(String u) => newPdf
          ? u // navi PDF API ma export= ni jarur nathi
          : "$u${u.contains('?') ? '&' : '?'}export=$type";

      // 🔥 Branch wise:
      //  single → voucher_history_pdf/95?management_branches[]=20
      //  merge  → voucher_history_pdf/95?management_branches[]=9&management_branches[]=20&management_branches[]=21
      final String url = withExport(_br(plain));
      debugPrint("📤 EXPORT $type URL => $url");

      var response = await ApiHelper().getPdfRequest(
        url,
        receiveTimeout: const Duration(minutes: 2),
      );

      // ⚠️ Server 500 → badhi branch / branch vagar fari try
      if ((_activeBranchIds.isNotEmpty || newPdf) &&
          (response == null || response.statusCode != 200)) {
        // Dar branch ekli → pachhi badhi → pachhi branch vagar
        // Ek j URL be vaar nahi (seen)
        final Set<String> seen = {url};
        final List<String> tries = [
          withExport(_brVoucher(plain, selectedVoucherId)), // voucher ni branch
          ..._perBranchUrls(plain).map(withExport),
          withExport(plain),
          // Navi API na chale to juni rit (voucher-history?...&export=pdf)
          if (newPdf)
            "${_brVoucher("$_exportUrl?voucher_id=$selectedVoucherId", selectedVoucherId)}&export=pdf",
        ].where(seen.add).toList();
        for (int i = 0; i < tries.length; i++) {
          final String retry = tries[i];
          debugPrint("⚠️ EXPORT retry => $retry");
          response = await ApiHelper().getPdfRequest(
            retry,
            receiveTimeout: const Duration(minutes: 2),
          );
          if (response != null && response.statusCode == 200) {
            // URL ma ek j branch hoy to e yaad rakho
            final m = RegExp(r'management_branches\[\]=(\d+)').allMatches(retry).toList();
            if (selectedVoucherId != null && m.length == 1) {
              _voucherBranch[selectedVoucherId!] = int.parse(m.first.group(1)!);
            }
            break;
          }
        }
      }

      if (!mounted) return;

      final String label = type == "pdf" ? "PDF" : "Excel";

      if (response == null || response.statusCode != 200) {
        debugPrint("❌ EXPORT $type: koi branch thi na chalyu (voucher $selectedVoucherId)");
        AppMessage.error(
          context,
          _fileError(response?.data) ??
              "$label could not be created for this voucher (server error)",
        );
        return;
      }

      final dynamic raw = response.data;
      final Uint8List? bytes = raw is Uint8List
          ? raw
          : (raw is List<int> ? Uint8List.fromList(raw) : null);

      // Bytes ni jagya e JSON error aave to
      if (bytes == null || bytes.isEmpty || bytes.first == 0x7B /* { */) {
        AppMessage.error(
          context,
          _fileError(raw) ?? "No file received from server",
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final String stamp =
          "${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}";
      final String ext = type == "pdf" ? "pdf" : "xlsx";
      final file = File(
          "${dir.path}/Voucher_History_${selectedVoucherId ?? 'all'}_$stamp.$ext");
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      AppMessage.success(context, "$label downloaded");
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ EXPORT $type ERROR => $e");
      if (mounted) AppMessage.error(context, "Download failed");
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  /// JSON (bytes / map / string) mathi message
  String? _fileError(dynamic data) {
    try {
      dynamic d = data;
      if (d is List<int>) d = utf8.decode(d);
      if (d is String) d = jsonDecode(d);
      if (d is Map && d["message"] != null) return d["message"].toString();
    } catch (_) {}
    return null;
  }

  /// =========================================================
  /// 🔥 LOAD BRANCHES (Sale Summary jevu j)
  /// =========================================================

  Future<void> _loadBranches() async {
    setState(() => branchesLoading = true);

    try {
      // 🔐 Fakt main company admin ne j Branch Reports dekhay
      final bool isAdmin = await BranchAccess.isMainCompanyAdmin();
      if (!isAdmin) {
        if (mounted) setState(() => canViewBranches = false);
        return;
      }

      final overview = await BranchApi.fetchOverview();

      if (!mounted) return;

      final List<Company> list = [
        if (overview.mainCompany != null) overview.mainCompany!,
        ...overview.branches,
      ];

      setState(() {
        branchCompanies = list;

        // Main company + ek branch hoy tyare j tab dekhay
        canViewBranches = list.length > 1;

        // Default: main company select
        selectedCompanyIds = {
          if (overview.mainCompany != null) overview.mainCompany!.id,
        };
        _mainCompanyId = overview.mainCompany?.id;
      });
    } catch (e) {
      // Branch access nathi (branch user / staff) → tab nahi dekhay
      debugPrint("❌ Branch list load failed: $e");
      if (mounted) setState(() => canViewBranches = false);
    } finally {
      if (mounted) setState(() => branchesLoading = false);
    }
  }

  String _companyLabel(Company c) =>
      c.isMain ? "${c.name} (Main Company)" : c.name;

  /// Branch badle etle voucher list pan badle → navo voucher select
  Future<void> _reloadHistory() async {
    setState(() {
      selectedVoucherId = null;
      voucher = {};
      history = {};
      summary = {};
    });
    await loadHistory();
  }

  /// 🔥 VIEW — fakt select kareli branches
  Future<void> viewBranchReport() async {
    if (selectedCompanyIds.isEmpty) {
      AppMessage.error(context, "Please select at least one branch");
      return;
    }

    setState(() {
      appliedCompanyIds = selectedCompanyIds.toList();
      branchReportLoading = true;
    });

    try {
      await _reloadHistory();
    } finally {
      if (mounted) setState(() => branchReportLoading = false);
    }
  }

  /// Branch report bandh kari ne potani company ni gallery
  Future<void> clearBranchReport() async {
    setState(() => appliedCompanyIds = []);
    await _reloadHistory();
  }

  // ============================================================
  // 🔥 BRANCH REPORTS (expand tab) — Sale Summary jevu j
  // ============================================================

  Widget _buildBranchCard() {
    if (branchesLoading) {
      return Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        decoration: _branchCardDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Loading branches...",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (!canViewBranches) return const SizedBox.shrink();

    final selectedList =
    branchCompanies.where((c) => selectedCompanyIds.contains(c.id)).toList();

    final bool appliedDiffers = appliedCompanyIds.toSet().length !=
        selectedCompanyIds.length ||
        !appliedCompanyIds.toSet().containsAll(selectedCompanyIds);

    return Container(
      margin: EdgeInsets.zero,
      decoration: _branchCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- HEADER (tap = expand) ----------------
          InkWell(
            onTap: () => setState(() => branchExpanded = !branchExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Branch Reports",
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selectedCompanyIds.length}/${branchCompanies.length}",
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: branchExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- BODY ----------------
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !branchExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Multi select box
                  InkWell(
                    onTap: _openBranchPicker,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: selectedList.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                "Select branches",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                                : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in selectedList)
                                  _branchChip(c),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Select one or more branches to see their voucher history.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _viewReportButton(highlight: appliedDiffers),

                  // Branch report chalu hoy tyare info + clear
                  if (_branchMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff16A34A).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xff16A34A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xff16A34A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Showing voucher history of "
                                  "${appliedCompanyIds.length} "
                                  "${appliedCompanyIds.length == 1 ? 'branch' : 'branches'}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff166534),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: clearBranchReport,
                            style: TextButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xffD32F2F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChip(Company c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.isMain ? Icons.verified_rounded : c.type.icon,
            size: 13,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _companyLabel(c),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => setState(() => selectedCompanyIds.remove(c.id)),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewReportButton({required bool highlight}) {
    return InkWell(
      onTap: branchReportLoading ? null : viewBranchReport,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff22C55E), Color(0xff16A34A)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color:
              const Color(0xff16A34A).withOpacity(highlight ? 0.35 : 0.15),
              blurRadius: highlight ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: branchReportLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_rounded, size: 17, color: Colors.white),
              SizedBox(width: 6),
              Text(
                "View",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔥 Multi-select bottom sheet
  Future<void> _openBranchPicker() async {
    final Set<int> temp = {...selectedCompanyIds};

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final bool allSelected = temp.length == branchCompanies.length;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Select Branches",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff172033),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                if (allSelected) {
                                  temp.clear();
                                } else {
                                  temp.addAll(branchCompanies.map((c) => c.id));
                                }
                              });
                            },
                            child: Text(
                              allSelected ? "Clear All" : "Select All",
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: branchCompanies.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, i) {
                          final c = branchCompanies[i];
                          final bool checked = temp.contains(c.id);

                          return InkWell(
                            onTap: () => setSheet(() {
                              checked ? temp.remove(c.id) : temp.add(c.id);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDark
                                          .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      c.isMain
                                          ? Icons.verified_rounded
                                          : c.type.icon,
                                      size: 17,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _companyLabel(c),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff172033),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            c.isMain ? "Main" : c.type.label,
                                            if (c.city != null) c.city!,
                                            if (!c.active) "Inactive",
                                          ].join(" • "),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.active
                                                ? Colors.grey.shade600
                                                : Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? AppColors.gradientBlue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: checked
                                            ? AppColors.gradientBlue
                                            : Colors.grey.shade400,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: checked
                                        ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => Navigator.pop(sheetContext, temp),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.secondaryDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(
                                    "Done (${temp.length})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => selectedCompanyIds = result);
    }
  }

  BoxDecoration _branchCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
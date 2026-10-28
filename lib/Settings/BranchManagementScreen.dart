import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppMessage.dart';

// ============================================================================
// API
//
//   GET    company/branches              -> list
//   POST   company/branches              -> create
//   PUT    company/branches/{id}         -> edit
//   PATCH  company/branches/{id}/status  -> active / deactive
//   PUT    company/opening-balances      -> opening balance save
// ============================================================================
class BranchApi {
  static String _branchUrl(int id) => '${ApiConstants.company_branches}/$id';

  /// company/branches → company/opening-balances
  /// (ApiConstants ma navo constant umervani jarur nathi)
  static String get _openingBalanceUrl => ApiConstants.company_branches
      .replaceFirst(RegExp(r'branches/?$'), 'opening-balances');

  static Future<BranchOverview> fetchOverview() async {
    final response =
    await ApiHelper().getRequest(ApiConstants.company_branches);

    final body = response?.data;
    if (response?.statusCode == 200 && body is Map && body['data'] is Map) {
      return BranchOverview.fromJson(
          Map<String, dynamic>.from(body['data'] as Map));
    }
    throw ApiException(_errorMessage(body, response?.statusCode ?? 0,
        fallback: 'Failed to load branches'));
  }

  static Future<void> createBranch(CreateBranchRequest req) async {
    final response = await ApiHelper().postRequest(
      ApiConstants.company_branches,
      req.toJson(),
    );
    _ensureOk(response, 'Failed to create branch');
  }

  static Future<void> updateBranch(int id, UpdateBranchRequest req) async {
    final response = await ApiHelper().putRequest(
      _branchUrl(id),
      req.toJson(),
    );
    _ensureOk(response, 'Failed to update branch');
  }

  static Future<void> updateStatus(int id, bool status) async {
    final response = await ApiHelper().patchRequest(
      '${_branchUrl(id)}/status',
      {'status': status},
      showLoading: false,
    );
    _ensureOk(response, 'Failed to change status');
  }

  /// PUT company/opening-balances
  static Future<void> updateOpeningBalance(OpeningBalanceRequest req) async {
    final response = await ApiHelper().putRequest(
      _openingBalanceUrl,
      req.toJson(),
    );
    _ensureOk(response, 'Failed to save opening balance');
  }

  static void _ensureOk(dynamic response, String fallback) {
    final code = response?.statusCode ?? 0;
    final body = response?.data;
    final ok = (code == 200 || code == 201) &&
        !(body is Map && body['success'] == false);
    if (!ok) throw ApiException(_errorMessage(body, code, fallback: fallback));
  }

  static String _errorMessage(dynamic body, int code,
      {required String fallback}) {
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (body['message'] != null) return body['message'].toString();
    }
    if (code == 401) return 'Session expired. Please login again.';
    return fallback;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

// ============================================================================
// Theme
// ============================================================================
class _C {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Colors.white;
  static const tile = Color(0xFFF6F8FE);
  static const border = Color(0xFFE3E8F6);
  static const dashed = Color(0xFFBCC8EA);
  static const bar = Color(0xFF1E4DB7);
  static const g1 = Color(0xFF5B8DEF);
  static const g2 = Color(0xFF3F63C7);
  static const g3 = Color(0xFF2B479F);
  static const primary = Color(0xFF3F6FDB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFE5484D);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF7A8194);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [g1, g2],
  );

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [g1, g2, g3],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: g2.withValues(alpha: 0.07),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

// ============================================================================
// Models
// ============================================================================
String? _s(dynamic v) =>
    (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

int _i(dynamic v, [int def = 0]) => int.tryParse('${v ?? ''}') ?? def;

bool _b(dynamic v, [bool def = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return def;
}

enum BranchType { retail, manufacturing }

extension BranchTypeX on BranchType {
  String get label => this == BranchType.retail ? 'Retail' : 'Manufacturing';
  String get apiValue => this == BranchType.retail ? 'retail' : 'manufacturing';
  IconData get icon => this == BranchType.retail
      ? Icons.storefront_rounded
      : Icons.factory_outlined;

  static BranchType fromApi(dynamic v) =>
      v?.toString().toLowerCase() == 'manufacturing'
          ? BranchType.manufacturing
          : BranchType.retail;
}

class CompanyPlan {
  final String? startedAt;
  final String? expiresAt;
  final bool expired;
  final int daysRemaining;
  final String? message;

  const CompanyPlan({
    this.startedAt,
    this.expiresAt,
    this.expired = false,
    this.daysRemaining = 0,
    this.message,
  });

  factory CompanyPlan.fromJson(Map<String, dynamic> j) {
    final alert = j['alert'] is Map ? j['alert'] as Map : const {};
    return CompanyPlan(
      startedAt: _s(j['started_at_view'] ?? j['started_at']),
      expiresAt: _s(j['expires_at_view'] ?? j['expires_at']),
      expired: _b(j['expired']),
      daysRemaining: _i(j['days_remaining']),
      message: _s(alert['message']),
    );
  }

  /// "09-09-2027 / 04:09 PM" -> "09-09-2027"
  String get expiresDate => (expiresAt ?? '-').split('/').first.trim();

  Color get color {
    if (expired) return _C.danger;
    if (daysRemaining <= 15) return _C.warning;
    return _C.success;
  }
}

class Company {
  final int id;
  final String name;
  final String? slug;
  final int? parentCompanyId;
  final BranchType type;
  final String? city;
  final String? address;
  final bool status;
  final bool effectiveActive;
  final bool isMain;
  final String? loginUrl;
  final CompanyPlan? plan;

  const Company({
    required this.id,
    required this.name,
    this.slug,
    this.parentCompanyId,
    required this.type,
    this.city,
    this.address,
    this.status = true,
    this.effectiveActive = true,
    this.isMain = false,
    this.loginUrl,
    this.plan,
  });

  factory Company.fromJson(Map<String, dynamic> j) => Company(
    id: _i(j['id']),
    name: _s(j['name']) ?? '-',
    slug: _s(j['slug']),
    parentCompanyId:
    j['parent_company_id'] == null ? null : _i(j['parent_company_id']),
    type: BranchTypeX.fromApi(j['branch_type']),
    city: _s(j['city']),
    address: _s(j['address_1']),
    status: _b(j['status'], true),
    effectiveActive: _b(j['effective_active'], true),
    isMain: _b(j['is_main']),
    loginUrl: _s(j['login_url']),
    plan: j['plan'] is Map
        ? CompanyPlan.fromJson(Map<String, dynamic>.from(j['plan']))
        : null,
  );

  Company copyWith({bool? status}) => Company(
    id: id,
    name: name,
    slug: slug,
    parentCompanyId: parentCompanyId,
    type: type,
    city: city,
    address: address,
    status: status ?? this.status,
    effectiveActive: status ?? effectiveActive,
    isMain: isMain,
    loginUrl: loginUrl,
    plan: plan,
  );

  bool get active => status && effectiveActive;
}

class BranchOverview {
  final bool canManageBranches;
  final int branchLimit;
  final int branchCount;
  final bool canCreateBranch;
  final String? limitMessage;
  final Company? mainCompany;
  final List<Company> branches;

  const BranchOverview({
    this.canManageBranches = false,
    this.branchLimit = 0,
    this.branchCount = 0,
    this.canCreateBranch = false,
    this.limitMessage,
    this.mainCompany,
    this.branches = const [],
  });

  factory BranchOverview.fromJson(Map<String, dynamic> j) {
    final all = (j['companies'] is List ? j['companies'] as List : const [])
        .whereType<Map>()
        .map((e) => Company.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    Company? main;
    for (final c in all) {
      if (c.isMain) {
        main = c;
        break;
      }
    }
    final branches = all.where((c) => !c.isMain).toList();

    return BranchOverview(
      canManageBranches: _b(j['can_manage_branches']),
      branchLimit: _i(j['branch_limit']),
      branchCount: _i(j['branch_count'], branches.length),
      canCreateBranch: _b(j['can_create_branch']),
      limitMessage: _s(j['limit_message']),
      mainCompany: main,
      branches: branches,
    );
  }

  BranchOverview replaceBranch(Company updated) => BranchOverview(
    canManageBranches: canManageBranches,
    branchLimit: branchLimit,
    branchCount: branchCount,
    canCreateBranch: canCreateBranch,
    limitMessage: limitMessage,
    mainCompany: mainCompany,
    branches: [
      for (final b in branches) b.id == updated.id ? updated : b,
    ],
  );
}

class CreateBranchRequest {
  final String name;
  final BranchType type;
  final String city;
  final String address;
  final String adminName;
  final String email;
  final String password;
  final String passwordConfirmation;

  const CreateBranchRequest({
    required this.name,
    required this.type,
    required this.city,
    required this.address,
    required this.adminName,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'branch_type': type.apiValue,
    'city': city,
    'address_1': address,
    'admin_name': adminName,
    'email': email,
    'password': password,
    'password_confirmation': passwordConfirmation,
  };
}

class UpdateBranchRequest {
  final String name;
  final BranchType type;
  final String city;
  final String address;
  final bool status;

  const UpdateBranchRequest({
    required this.name,
    required this.type,
    required this.city,
    required this.address,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'branch_type': type.apiValue,
    'city': city,
    'address_1': address,
    'status': status,
  };
}

/// PUT company/opening-balances
///
/// {
///   "opening_balance_date": "2026-10-14",
///   "opening_cash": 50000,
///   "opening_bank": 500000,
///   "opening_gold_fine": 250,
///   "opening_silver_fine": 5000
/// }
class OpeningBalanceRequest {
  final DateTime date;
  final double cash;
  final double bank;
  final double goldFine;
  final double silverFine;

  const OpeningBalanceRequest({
    required this.date,
    required this.cash,
    required this.bank,
    required this.goldFine,
    required this.silverFine,
  });

  /// 50000.0 → 50000 (Postman jevu j), 250.5 → 250.5
  static num _n(double v) => v == v.roundToDouble() ? v.toInt() : v;

  /// 2026-10-14
  static String apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'opening_balance_date': apiDate(date),
    'opening_cash': _n(cash),
    'opening_bank': _n(bank),
    'opening_gold_fine': _n(goldFine),
    'opening_silver_fine': _n(silverFine),
  };
}

// ============================================================================
// Screen
// ============================================================================
class BranchManagementScreen extends StatefulWidget {
  final dynamic userData;
  final VoidCallback? onAllBranchesDashboard;

  const BranchManagementScreen({
    super.key,
    this.userData,
    this.onAllBranchesDashboard,
  });

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  BranchOverview? _overview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Map<String, dynamic> get _userMap {
    final data = widget.userData;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  String get _companyName {
    final fromApi = _overview?.mainCompany?.name;
    if (fromApi != null && fromApi != '-') return fromApi;

    final m = _userMap;
    final company = m['company'];
    final direct = _s(m['company_name']) ??
        (company is Map ? _s(company['name']) : _s(company));
    if (direct != null) return direct;

    final name = _s(m['name']);
    if (name != null) {
      return name
          .replaceAll(
          RegExp(r'\s+(admin|owner|manager)$', caseSensitive: false), '')
          .trim();
    }
    return 'My Company';
  }

  String get _initials {
    final clean =
    _companyName.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').trim();
    if (clean.isEmpty) return 'BR';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  List<Company> get _branches => _overview?.branches ?? const [];
  int get _count => _overview?.branchCount ?? _branches.length;
  int get _limit => _overview?.branchLimit ?? 0;
  bool get _canCreate => _overview?.canCreateBranch ?? false;
  bool get _canManage => _overview?.canManageBranches ?? false;

  // --- actions ---------------------------------------------------------------
  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BranchApi.fetchOverview();
      if (!mounted) return;
      setState(() => _overview = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load branches');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _run(Future<void> Function() call, String success,
      String fallbackError) async {
    try {
      await call();
      if (!mounted) return true;
      _successToast(success);
      await _loadBranches();
      return true;
    } on ApiException catch (e) {
      if (mounted) AppMessage.error(context, e.message);
    } catch (_) {
      if (mounted) AppMessage.error(context, fallbackError);
    }
    return false;
  }

  Future<bool> _createBranch(CreateBranchRequest req) => _run(
        () => BranchApi.createBranch(req),
    'Branch "${req.name}" created',
    'Failed to create branch',
  );

  Future<bool> _updateBranch(Company b, UpdateBranchRequest req) => _run(
        () => BranchApi.updateBranch(b.id, req),
    'Branch "${req.name}" updated',
    'Failed to update branch',
  );

  Future<bool> _toggleStatus(Company b, bool value) async {
    final o = _overview;
    if (o == null) return false;
    setState(() => _overview = o.replaceBranch(b.copyWith(status: value)));
    try {
      await BranchApi.updateStatus(b.id, value);
      if (!mounted) return true;
      _successToast(
          '${b.name} ${value ? 'activated' : 'deactivated'} successfully');
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _overview = _overview?.replaceBranch(b));
      AppMessage.error(
          context, e is ApiException ? e.message : 'Failed to change status');
      return false;
    }
  }

  /// 💰 Opening balance save (branch list reload ni jarur nathi)
  Future<bool> _saveOpeningBalance(OpeningBalanceRequest req) async {
    try {
      await BranchApi.updateOpeningBalance(req);
      if (!mounted) return true;
      _successToast('Opening balance saved');
      return true;
    } on ApiException catch (e) {
      if (mounted) AppMessage.error(context, e.message);
    } catch (_) {
      if (mounted) AppMessage.error(context, 'Failed to save opening balance');
    }
    return false;
  }

  void _successToast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: _C.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  // --- UI --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _PremiumHeader(
              companyName: _companyName,
              count: _count,
              limit: _limit,
              daysLeft: _overview?.mainCompany?.plan?.daysRemaining,
              loaded: _overview != null,
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _C.primary,
                onRefresh: _loadBranches,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _overview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          // Center(
          //   child: SizedBox(
          //     width: 26,
          //     height: 26,
          //     child: CircularProgressIndicator(
          //         strokeWidth: 2.5, color: _C.primary),
          //   ),
          // ),
        ],
      );
    }

    if (_error != null && _overview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          const Icon(Icons.cloud_off_rounded, size: 36, color: _C.muted),
          const SizedBox(height: 10),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, fontSize: 13)),
          const SizedBox(height: 14),
          Center(
            child: _GradientButton(
                label: 'Retry', compact: true, onPressed: _loadBranches),
          ),
        ],
      );
    }

    final o = _overview!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        _MainCompanyCard(
          initials: _initials,
          name: _companyName,
          company: o.mainCompany,
          count: _count,
          limit: _limit,
          canCreate: _canCreate,
          onDashboard: widget.onAllBranchesDashboard,
        ),

        /// 💰 OPENING BALANCE
        const _SectionTitle('Opening Balance'),
        _OpeningBalanceCard(onSubmit: _saveOpeningBalance),

        if (o.canManageBranches) ...[
          const _SectionTitle('Create New Branch'),
          _CreateBranchCard(
            canCreate: _canCreate,
            limitMessage: o.limitMessage,
            onSubmit: _createBranch,
          ),
        ],
        _SectionTitle('Branches', count: _count),
        if (_branches.isEmpty)
          const _EmptyState()
        else
          for (final b in _branches)
            _BranchCard(
              key: ValueKey('branch-${b.id}'),
              branch: b,
              canManage: _canManage,
              onUpdate: (req) => _updateBranch(b, req),
              onToggleStatus: (v) => _toggleStatus(b, v),
            ),
      ],
    );
  }
}

// ============================================================================
// Header
// ============================================================================
class _PremiumHeader extends StatelessWidget {
  final String companyName;
  final int count;
  final int limit;
  final int? daysLeft;
  final bool loaded;
  final VoidCallback onBack;

  const _PremiumHeader({
    required this.companyName,
    required this.count,
    required this.limit,
    required this.daysLeft,
    required this.loaded,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    const radius = BorderRadius.vertical(bottom: Radius.circular(22));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _C.headerGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _C.g2.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(right: -30, top: -40, child: _glow(130, 0.10)),
            Positioned(left: -20, bottom: -60, child: _glow(110, 0.06)),
            Padding(
              padding: EdgeInsets.fromLTRB(14, top + 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onBack,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Branch Management',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderStat(
                          icon: Icons.account_tree_rounded,
                          label: 'Branches',
                          value: loaded ? '$count / $limit' : '—',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStat(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Plan',
                          value: daysLeft == null ? '—' : '$daysLeft days',
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
    );
  }

  Widget _glow(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Main company card
// ============================================================================
class _MainCompanyCard extends StatelessWidget {
  final String initials;
  final String name;
  final Company? company;
  final int count;
  final int limit;
  final bool canCreate;
  final VoidCallback? onDashboard;

  const _MainCompanyCard({
    required this.initials,
    required this.name,
    required this.company,
    required this.count,
    required this.limit,
    required this.canCreate,
    this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final plan = company?.plan;
    final progress = limit == 0 ? 0.0 : (count / limit).clamp(0.0, 1.0);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _C.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: _C.g2.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const _Badge(
                      text: 'Main Company',
                      color: _C.primary,
                      icon: Icons.verified_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TileRow(
            left: _MiniTile(
              icon: Icons.account_tree_outlined,
              label: 'Branch Slots',
              value: '$count / $limit',
              valueColor: canCreate ? _C.success : _C.danger,
            ),
            right: _MiniTile(
              icon: Icons.location_city_outlined,
              label: 'City',
              value: company?.city ?? '-',
            ),
          ),
          const SizedBox(height: 8),
          _TileRow(
            left: _MiniTile(
              icon: Icons.event_outlined,
              label: 'Plan Expires',
              value: plan?.expiresDate ?? '-',
            ),
            right: _MiniTile(
              icon: Icons.timelapse_rounded,
              label: 'Days Left',
              value: plan == null
                  ? '-'
                  : (plan.expired ? 'Expired' : '${plan.daysRemaining}'),
              valueColor: plan?.color,
            ),
          ),
          if (company?.address != null) ...[
            const SizedBox(height: 10),
            _IconLine(Icons.location_on_outlined, company!.address!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Slots used',
                  style: TextStyle(color: _C.muted, fontSize: 11)),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      color: _C.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: _C.border,
              valueColor: AlwaysStoppedAnimation(
                  canCreate ? _C.primary : _C.danger),
            ),
          ),
          const SizedBox(height: 12),
          _GradientButton(
            label: 'All Branches Dashboard',
            icon: Icons.dashboard_rounded,
            onPressed: onDashboard,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Building blocks
// ============================================================================
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding,
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? _C.border,
          width: borderColor != null ? 1.4 : 1,
        ),
        boxShadow: _C.softShadow,
      ),
      child: child,
    );
  }
}

class _MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.tile,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _C.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.muted, fontSize: 10.5)),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? '-' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? _C.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TileRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _C.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.muted, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool dot;

  const _Badge({
    required this.text,
    required this.color,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionTitle(this.title, {this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _C.bar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _C.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: _C.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;
  final bool loading;

  const _GradientButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final content = loading
        ? const SizedBox(
      width: 18,
      height: 18,
      child:
      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    )
        : Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _C.g2.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: _C.gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                    : const EdgeInsets.symmetric(vertical: 12),
                child: Center(widthFactor: compact ? 1 : null, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _OutlineButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.muted,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _C.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  const _IconBtn({
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ============================================================================
// Form helpers
// ============================================================================
InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB4BACB), fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 36),
    errorStyle: const TextStyle(fontSize: 11),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: border(_C.border),
    disabledBorder: border(_C.border),
    focusedBorder: border(_C.primary, 1.3),
    errorBorder: border(_C.danger),
    focusedErrorBorder: border(_C.danger, 1.3),
  );
}

Widget _labeledField({
  required String label,
  required TextEditingController controller,
  required bool enabled,
  String? hint,
  String? Function(String?)? validator,
  TextInputType? keyboard,
  List<TextInputFormatter>? formatters,
  TextCapitalization caps = TextCapitalization.none,
  bool obscure = false,
  Widget? suffix,
  TextInputAction action = TextInputAction.next,
  int maxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: caps,
        obscureText: obscure,
        textInputAction: action,
        enabled: enabled,
        maxLines: obscure ? 1 : maxLines,
        style: const TextStyle(color: _C.text, fontSize: 13),
        decoration: _inputDecoration(hint: hint, suffix: suffix),
      ),
    ],
  );
}

String? _requiredValidator(String? v, String field) =>
    (v == null || v.trim().isEmpty) ? 'Enter $field' : null;

Widget _pair(bool wide, Widget a, Widget b) {
  if (!wide) return Column(children: [a, const SizedBox(height: 10), b]);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 10),
      Expanded(child: b),
    ],
  );
}

class _TypeSelector extends StatelessWidget {
  final BranchType value;
  final bool enabled;
  final ValueChanged<BranchType> onChanged;

  const _TypeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Branch type',
            style: TextStyle(
                color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _C.tile,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              for (final t in BranchType.values) Expanded(child: _option(t)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option(BranchType t) {
    final selected = value == t;
    return GestureDetector(
      onTap: enabled ? () => onChanged(t) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? _C.gradient : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _C.g2.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(t.icon, size: 15, color: selected ? Colors.white : _C.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                t.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : _C.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 💰 Opening Balance
// ============================================================================
class _OpeningBalanceCard extends StatefulWidget {
  final Future<bool> Function(OpeningBalanceRequest req) onSubmit;

  const _OpeningBalanceCard({required this.onSubmit});

  @override
  State<_OpeningBalanceCard> createState() => _OpeningBalanceCardState();
}

class _OpeningBalanceCardState extends State<_OpeningBalanceCard> {
  final _formKey = GlobalKey<FormState>();
  final _cashCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _goldCtrl = TextEditingController();
  final _silverCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  bool _expanded = false;
  bool _submitting = false;

  /// Chhello save thayelo summary (card band hoy tyare dekhay)
  String? _savedSummary;

  /// Rupiya: 2 decimal, Fine: 3 decimal
  static final _moneyFormat =
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));
  static final _fineFormat =
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'));

  @override
  void dispose() {
    _cashCtrl.dispose();
    _bankCtrl.dispose();
    _goldCtrl.dispose();
    _silverCtrl.dispose();
    super.dispose();
  }

  String get _viewDate =>
      '${_date.day.toString().padLeft(2, '0')}-'
          '${_date.month.toString().padLeft(2, '0')}-${_date.year}';

  /// Khali → 0
  double _val(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  String _show(TextEditingController c) =>
      c.text.trim().isEmpty ? '0' : c.text.trim();

  String? _numValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null; // khali = 0
    final d = double.tryParse(t);
    if (d == null) return 'Enter a valid number';
    if (d < 0) return 'Cannot be negative';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
          Theme.of(ctx).colorScheme.copyWith(primary: _C.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final req = OpeningBalanceRequest(
      date: _date,
      cash: _val(_cashCtrl),
      bank: _val(_bankCtrl),
      goldFine: _val(_goldCtrl),
      silverFine: _val(_silverCtrl),
    );

    setState(() => _submitting = true);
    final ok = await widget.onSubmit(req);
    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (ok) {
        _savedSummary = '$_viewDate  •  Cash ₹${_show(_cashCtrl)}'
            '  •  Gold ${_show(_goldCtrl)} g';
        _expanded = false; // values rakho → farithi kholo to edit thay
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      borderColor: _expanded ? _C.primary : null,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: _C.gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Set Opening Balance',
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _savedSummary ?? 'Cash, bank, gold & silver fine',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                            _savedSummary != null ? _C.success : _C.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _C.muted, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _buildBody()
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Opening balance date',
            style: TextStyle(
                color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: enabled ? _pickDate : null,
          child: InputDecorator(
            decoration: _inputDecoration(
              suffix: const Icon(Icons.calendar_month_rounded,
                  size: 18, color: _C.primary),
            ),
            child: Text(
              _viewDate,
              style: const TextStyle(color: _C.text, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _unit(String text) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Text(text,
        style: const TextStyle(
            color: _C.muted, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _buildBody() {
    final enabled = !_submitting;
    const numKeyboard = TextInputType.numberWithOptions(decimal: true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 520;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: _C.border),
              const SizedBox(height: 12),
              _buildDateField(enabled),
              const SizedBox(height: 10),
              _pair(
                wide,
                _labeledField(
                  label: 'Opening cash',
                  controller: _cashCtrl,
                  enabled: enabled,
                  hint: '0',
                  keyboard: numKeyboard,
                  formatters: [_moneyFormat],
                  validator: _numValidator,
                  suffix: _unit('₹'),
                ),
                _labeledField(
                  label: 'Opening bank',
                  controller: _bankCtrl,
                  enabled: enabled,
                  hint: '0',
                  keyboard: numKeyboard,
                  formatters: [_moneyFormat],
                  validator: _numValidator,
                  suffix: _unit('₹'),
                ),
              ),
              const SizedBox(height: 10),
              _pair(
                wide,
                _labeledField(
                  label: 'Opening gold fine',
                  controller: _goldCtrl,
                  enabled: enabled,
                  hint: '0.000',
                  keyboard: numKeyboard,
                  formatters: [_fineFormat],
                  validator: _numValidator,
                  suffix: _unit('g'),
                ),
                _labeledField(
                  label: 'Opening silver fine',
                  controller: _silverCtrl,
                  enabled: enabled,
                  hint: '0.000',
                  keyboard: numKeyboard,
                  formatters: [_fineFormat],
                  validator: _numValidator,
                  suffix: _unit('g'),
                  action: TextInputAction.done,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Khali field 0 tarike save thashe.',
                style: TextStyle(color: _C.muted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              _GradientButton(
                label: 'Save Opening Balance',
                icon: Icons.check_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================================================
// Create New Branch
// ============================================================================
class _CreateBranchCard extends StatefulWidget {
  final bool canCreate;
  final String? limitMessage;
  final Future<bool> Function(CreateBranchRequest req) onSubmit;

  const _CreateBranchCard({
    required this.canCreate,
    required this.onSubmit,
    this.limitMessage,
  });

  @override
  State<_CreateBranchCard> createState() => _CreateBranchCardState();
}

class _CreateBranchCardState extends State<_CreateBranchCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  List<TextEditingController> get _all => [
    _nameCtrl,
    _cityCtrl,
    _addressCtrl,
    _adminNameCtrl,
    _emailCtrl,
    _passwordCtrl,
    _confirmCtrl,
  ];

  BranchType _type = BranchType.retail;
  bool _expanded = false;
  bool _submitting = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    final ok = await widget.onSubmit(CreateBranchRequest(
      name: _nameCtrl.text.trim(),
      type: _type,
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      passwordConfirmation: _confirmCtrl.text,
    ));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        for (final c in _all) {
          c.clear();
        }
        _type = BranchType.retail;
        _expanded = false;
      }
    });
  }

  String? _emailValidator(String? v) {
    final r = _requiredValidator(v, 'email');
    if (r != null) return r;
    final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(v!.trim());
    return ok ? null : 'Enter a valid email';
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Enter password';
    if (v.length < 12) return 'Minimum 12 characters';
    return null;
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.isEmpty) return 'Confirm password';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Widget _eye(bool visible, VoidCallback toggle) => IconButton(
    onPressed: toggle,
    visualDensity: VisualDensity.compact,
    icon: Icon(
      visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: _C.muted,
      size: 18,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      borderColor: _expanded ? _C.primary : null,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: _C.gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_business_rounded,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Branch',
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.canCreate
                              ? 'Branch details & admin login'
                              : 'Branch limit reached',
                          style: TextStyle(
                            color: widget.canCreate ? _C.muted : _C.danger,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _C.muted, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _buildBody()
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!widget.canCreate) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _C.danger.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: _C.danger, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.limitMessage ??
                      'All branch slots are used. Please contact super admin to add more branches.',
                  style: const TextStyle(color: _C.text, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final enabled = !_submitting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 520;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: _C.border),
              const SizedBox(height: 12),
              _pair(
                wide,
                _labeledField(
                  label: 'Branch name',
                  controller: _nameCtrl,
                  enabled: enabled,
                  hint: 'e.g. Retail North',
                  caps: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, 'branch name'),
                ),
                _labeledField(
                  label: 'City',
                  controller: _cityCtrl,
                  enabled: enabled,
                  hint: 'e.g. Ahmedabad',
                  caps: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, 'city'),
                ),
              ),
              const SizedBox(height: 10),
              _pair(
                wide,
                _labeledField(
                  label: 'Address',
                  controller: _addressCtrl,
                  enabled: enabled,
                  hint: 'Street / Area',
                  caps: TextCapitalization.sentences,
                  validator: (v) => _requiredValidator(v, 'address'),
                ),
                _labeledField(
                  label: 'Branch admin name',
                  controller: _adminNameCtrl,
                  enabled: enabled,
                  hint: 'e.g. Branch Manager',
                  caps: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, 'admin name'),
                ),
              ),
              const SizedBox(height: 10),
              _pair(
                wide,
                _labeledField(
                  label: 'Branch admin email',
                  controller: _emailCtrl,
                  enabled: enabled,
                  hint: 'manager@example.com',
                  keyboard: TextInputType.emailAddress,
                  validator: _emailValidator,
                ),
                _TypeSelector(
                  value: _type,
                  enabled: enabled,
                  onChanged: (t) => setState(() => _type = t),
                ),
              ),
              const SizedBox(height: 10),
              _pair(
                wide,
                _labeledField(
                  label: 'Admin password (min 12 characters)',
                  controller: _passwordCtrl,
                  enabled: enabled,
                  obscure: !_showPassword,
                  validator: _passwordValidator,
                  suffix: _eye(_showPassword,
                          () => setState(() => _showPassword = !_showPassword)),
                ),
                _labeledField(
                  label: 'Confirm password',
                  controller: _confirmCtrl,
                  enabled: enabled,
                  obscure: !_showConfirm,
                  validator: _confirmValidator,
                  action: TextInputAction.done,
                  suffix: _eye(_showConfirm,
                          () => setState(() => _showConfirm = !_showConfirm)),
                ),
              ),
              const SizedBox(height: 14),
              _GradientButton(
                label: 'Create Branch',
                icon: Icons.add_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================================================
// Branch card
// ============================================================================
class _BranchCard extends StatefulWidget {
  final Company branch;
  final bool canManage;
  final Future<bool> Function(UpdateBranchRequest req) onUpdate;
  final Future<bool> Function(bool value) onToggleStatus;

  const _BranchCard({
    super.key,
    required this.branch,
    required this.canManage,
    required this.onUpdate,
    required this.onToggleStatus,
  });

  @override
  State<_BranchCard> createState() => _BranchCardState();
}

class _BranchCardState extends State<_BranchCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _addressCtrl;
  late BranchType _type;
  late bool _status;

  bool _editing = false;
  bool _saving = false;
  bool _statusBusy = false;

  Company get b => widget.branch;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _fillForm();
  }

  void _fillForm() {
    _nameCtrl.text = b.name == '-' ? '' : b.name;
    _cityCtrl.text = b.city ?? '';
    _addressCtrl.text = b.address ?? '';
    _type = b.type;
    _status = b.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      if (!_editing) _fillForm();
      _editing = !_editing;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _saving = true);
    final ok = await widget.onUpdate(UpdateBranchRequest(
      name: _nameCtrl.text.trim(),
      type: _type,
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      status: _status,
    ));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
  }

  Future<void> _onStatusChanged(bool value) async {
    if (_statusBusy) return;
    final confirmed = value ? true : await _confirmDeactivate();
    if (confirmed != true) return;
    setState(() => _statusBusy = true);
    await widget.onToggleStatus(value);
    if (mounted) setState(() => _statusBusy = false);
  }

  Future<bool?> _confirmDeactivate() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      title: const Text('Deactivate branch?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(
        '"${b.name}" na users login nahi kari shake. Pachhi active kari shakasho.',
        style: const TextStyle(fontSize: 13, color: _C.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Deactivate',
              style: TextStyle(color: _C.danger)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return _Panel(
      borderColor: _editing ? _C.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTop(),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _editing ? _buildEditForm() : _buildDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildTop() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _C.gradient,
            boxShadow: [
              BoxShadow(
                color: _C.g2.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(b.type.icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  _Badge(text: b.type.label, color: _C.primary),
                  _Badge(
                    text: b.active ? 'Active' : 'Inactive',
                    color: b.active ? _C.success : _C.danger,
                    dot: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.canManage)
          _IconBtn(
            icon: _editing ? Icons.close_rounded : Icons.edit_rounded,
            color: _editing ? _C.danger : _C.primary,
            tooltip: _editing ? 'Close' : 'Edit',
            onTap: _saving ? null : _toggleEdit,
          ),
      ],
    );
  }

  Widget _buildDetails() {
    final plan = b.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TileRow(
          left: _MiniTile(
            icon: Icons.location_city_outlined,
            label: 'City',
            value: b.city ?? '-',
          ),
          right: _MiniTile(
            icon: Icons.event_outlined,
            label: 'Plan Expires',
            value: plan?.expiresDate ?? '-',
            valueColor: plan?.expired == true ? _C.danger : null,
          ),
        ),
        if (b.address != null) ...[
          const SizedBox(height: 8),
          _IconLine(Icons.location_on_outlined, b.address!),
        ],
        if (b.loginUrl != null) ...[
          const SizedBox(height: 8),
          _linkRow(b.loginUrl!),
        ],
        const SizedBox(height: 8),
        const Divider(height: 1, color: _C.border),
        const SizedBox(height: 6),
        Row(
          children: [
            if (plan != null) ...[
              Icon(Icons.timelapse_rounded, size: 14, color: plan.color),
              const SizedBox(width: 4),
              Text(
                plan.expired
                    ? 'Plan expired'
                    : '${plan.daysRemaining} days left',
                style: TextStyle(
                  color: plan.color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            Text(
              b.active ? 'Active' : 'Inactive',
              style: TextStyle(
                color: b.active ? _C.success : _C.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            if (widget.canManage)
              _statusBusy
                  ? const Padding(
                padding:
                EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _C.primary),
                ),
              )
                  : Transform.scale(
                scale: 0.78,
                child: Switch.adaptive(
                  value: b.status,
                  activeColor: _C.success,
                  materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
                  onChanged: _onStatusChanged,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _linkRow(String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: const Text('Login URL copied',
                style: TextStyle(fontSize: 13)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _C.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, size: 14, color: _C.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _C.primary, fontSize: 11.5),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 13, color: _C.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    final enabled = !_saving;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 500;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pair(
                wide,
                _labeledField(
                  label: 'Branch name',
                  controller: _nameCtrl,
                  enabled: enabled,
                  caps: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, 'branch name'),
                ),
                _labeledField(
                  label: 'City',
                  controller: _cityCtrl,
                  enabled: enabled,
                  caps: TextCapitalization.words,
                  validator: (v) => _requiredValidator(v, 'city'),
                ),
              ),
              const SizedBox(height: 10),
              _labeledField(
                label: 'Address',
                controller: _addressCtrl,
                enabled: enabled,
                caps: TextCapitalization.sentences,
                action: TextInputAction.done,
                maxLines: 2,
                validator: (v) => _requiredValidator(v, 'address'),
              ),
              const SizedBox(height: 10),
              _TypeSelector(
                value: _type,
                enabled: enabled,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 2, 2, 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: [
                    const Text('Status',
                        style: TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(
                      _status ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: _status ? _C.success : _C.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.78,
                      child: Switch.adaptive(
                        value: _status,
                        activeColor: _C.success,
                        materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                        onChanged: enabled
                            ? (v) => setState(() => _status = v)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OutlineButton(
                      label: 'Cancel',
                      onPressed: _saving ? null : _toggleEdit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _GradientButton(
                      label: 'Save Changes',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(color: _C.dashed, radius: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_tree_rounded,
                  color: _C.primary, size: 22),
            ),
            const SizedBox(height: 10),
            const Text(
              'No branches yet',
              style: TextStyle(
                color: _C.text,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use Add Branch above to create your first retail or manufacturing branch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 8,
    this.dash = 5,
    this.gap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
          old.radius != radius ||
          old.dash != dash ||
          old.gap != gap;
}
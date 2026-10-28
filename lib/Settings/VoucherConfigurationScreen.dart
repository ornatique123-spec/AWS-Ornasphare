import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pecifician_sysytem/Api_Constant/ApiConstants.dart';
import 'package:pecifician_sysytem/Api_Constant/api_helper.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:pecifician_sysytem/Extra/AppMessage.dart';

// ============================================================================
// 🧾 VOUCHER CONFIGURATION
//
// GET  company/voucher-series   → prefix + series list
// PUT  company/voucher-series   → { "prefix": "MJ" }
// ============================================================================
class VoucherSeriesApi {
  static String get _url => ApiConstants.company_branches
      .replaceFirst(RegExp(r'company/branches/?$'), 'company/voucher-series');

  static Future<VoucherConfig> fetch() async {
    final response = await ApiHelper().getRequest(_url);
    final data = response?.data;
    if (response?.statusCode == 200 && data is Map && data["data"] is Map) {
      return VoucherConfig.fromJson(Map<String, dynamic>.from(data["data"]));
    }
    throw Exception(_message(data, "Failed to load voucher configuration"));
  }

  /// prefix khali hoy to null → backend company initials vapre
  static Future<VoucherConfig?> save(String prefix) async {
    final body = {"prefix": prefix.isEmpty ? null : prefix};
    debugPrint("📤 VOUCHER SERIES BODY => $body");

    final response = await ApiHelper().putRequest(_url, body);
    final data = response?.data;
    final ok = response?.statusCode == 200 || response?.statusCode == 201;

    if (ok && (data is! Map || data["success"] != false)) {
      if (data is Map && data["data"] is Map) {
        final d = Map<String, dynamic>.from(data["data"]);
        if (d["series"] is List) return VoucherConfig.fromJson(d);
      }
      return null; // save thayu pan data nathi → screen reload karse
    }
    throw Exception(_message(data, "Failed to save configuration"));
  }

  static String _message(dynamic data, String fallback) {
    if (data is Map) {
      if (data["errors"] is Map) {
        final errors = (data["errors"] as Map).values
            .map((v) => v is List && v.isNotEmpty ? v.first.toString() : "$v")
            .where((s) => s.isNotEmpty)
            .join("\n");
        if (errors.isNotEmpty) return errors;
      }
      if (data["message"] != null) return data["message"].toString();
    }
    return fallback;
  }
}

// ============================================================================
// MODELS
// ============================================================================
class VoucherSeries {
  final String module;
  final String label;
  final int nextNumber;
  final String preview;

  const VoucherSeries({
    required this.module,
    required this.label,
    required this.nextNumber,
    required this.preview,
  });

  factory VoucherSeries.fromJson(Map<String, dynamic> j) => VoucherSeries(
    module: (j["module"] ?? "").toString(),
    label: (j["label"] ?? "").toString(),
    nextNumber: int.tryParse("${j["next_number"] ?? 1}") ?? 1,
    preview: (j["preview"] ?? "").toString(),
  );

  /// Type karta j live preview: MJ-SL-009
  String previewFor(String prefix) =>
      "$prefix-$module-${nextNumber.toString().padLeft(3, '0')}";
}

class VoucherConfig {
  final String prefix;
  final String? customPrefix;
  final String defaultPrefix;
  final List<VoucherSeries> series;

  const VoucherConfig({
    required this.prefix,
    this.customPrefix,
    required this.defaultPrefix,
    this.series = const [],
  });

  factory VoucherConfig.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) =>
        (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

    return VoucherConfig(
      prefix: s(j["prefix"]) ?? "",
      customPrefix: s(j["custom_prefix"]),
      defaultPrefix: s(j["default_prefix"]) ?? s(j["prefix"]) ?? "",
      series: (j["series"] is List ? j["series"] as List : const [])
          .whereType<Map>()
          .map((e) => VoucherSeries.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ============================================================================
// SCREEN
// ============================================================================
class VoucherConfigurationScreen extends StatefulWidget {
  const VoucherConfigurationScreen({super.key});

  @override
  State<VoucherConfigurationScreen> createState() =>
      _VoucherConfigurationScreenState();
}

class _VoucherConfigurationScreenState
    extends State<VoucherConfigurationScreen> {
  final _prefixCtrl = TextEditingController();

  VoucherConfig? _config;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefixCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    super.dispose();
  }

  /// Fakt ApiHelper nu loader j dekhase (screen par spinner nathi)
  Future<void> _load() async {
    try {
      final config = await VoucherSeriesApi.fetch();
      if (!mounted) return;
      setState(() {
        _apply(config);
        _error = null;
      });
    } catch (e) {
      debugPrint("❌ VOUCHER SERIES ERROR => $e");
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
      AppMessage.error(context, _error!);
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _apply(VoucherConfig config) {
    _config = config;
    _prefixCtrl.text = config.customPrefix ?? "";
  }

  /// Prefix khali → default (company initials)
  String get _effectivePrefix {
    final typed = _prefixCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return _config?.defaultPrefix ?? "";
  }

  bool get _isDirty =>
      _prefixCtrl.text.trim() != (_config?.customPrefix ?? "");

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_saving) return;

    final prefix = _prefixCtrl.text.trim().toUpperCase();
    if (prefix.isNotEmpty && !RegExp(r'^[A-Z0-9]+$').hasMatch(prefix)) {
      AppMessage.error(context, "Prefix can contain letters and numbers only");
      return;
    }

    _saving = true;
    try {
      final config = await VoucherSeriesApi.save(prefix);
      if (!mounted) return;
      AppMessage.success(context, "Voucher configuration saved");
      if (config != null) {
        setState(() => _apply(config));
      } else {
        await _load();
      }
    } catch (e) {
      debugPrint("❌ VOUCHER SAVE ERROR => $e");
      if (mounted) {
        AppMessage.error(context, e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      _saving = false;
    }
  }

  // ==========================================================================
  // UI
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryDark,
                onRefresh: () async {
                  _load(); // await nahi → fakt API loader
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 12),
                    _prefixCard(),
                    const SizedBox(height: 12),
                    _infoNote(),
                    const SizedBox(height: 14),
                    _seriesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient get _gradient => LinearGradient(
    colors: [
      AppColors.primaryDark.withOpacity(0.7),
      AppColors.secondaryDark.withOpacity(0.7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  BoxDecoration get _card => BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );

  /// HEADER (Settings jevu)
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            "Voucher Configuration",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// HERO — current prefix
  Widget _heroCard() {
    final prefix = _effectivePrefix;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Voucher Numbering",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Choose your company prefix and preview the next number for each voucher type.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  "PREFIX",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prefix.isEmpty ? "--" : prefix,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "monospace",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// PREFIX INPUT + SAVE
  Widget _prefixCard() {
    final defaultPrefix = _config?.defaultPrefix ?? "";
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Company voucher prefix",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _prefixCtrl,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
                _UpperCaseFormatter(),
              ],
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: defaultPrefix.isEmpty ? "e.g. MJ" : defaultPrefix,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                prefixIcon: Icon(Icons.tag_rounded,
                    size: 18, color: AppColors.primaryDark),
                prefixIconConstraints:
                const BoxConstraints(minWidth: 30, minHeight: 20),
                suffixIcon: _prefixCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey.shade600),
                  onPressed: _prefixCtrl.clear,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  defaultPrefix.isEmpty
                      ? "Leave empty for company initials. Letters and numbers only."
                      : "Leave empty for company initials: $defaultPrefix. Letters and numbers only.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _saveButton() {
    final enabled = _loaded && _config != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? _save : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.save_outlined, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                _isDirty ? "Save Configuration •" : "Save Configuration",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoNote() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Each voucher type has a separate counter shared by the website and API. "
                  "Changing the prefix continues the counter. Existing vouchers keep their numbers.",
              style: TextStyle(fontSize: 11.5, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// SERIES LIST
  Widget _seriesSection() {
    final series = _config?.series ?? const <VoucherSeries>[];
    final prefix = _effectivePrefix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(gradient: _gradient, shape: BoxShape.circle),
              child: const Icon(Icons.format_list_numbered_rounded,
                  color: Colors.white, size: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "NEXT VOUCHER PREVIEW",
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (series.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${series.length} types",
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (!_loaded)
          const SizedBox(height: 40)
        else if (series.isEmpty)
          _emptyState()
        else
          Container(
            decoration: _card,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                /// TABLE HEADER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  color: AppColors.primaryDark.withOpacity(0.07),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Voucher type",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Text(
                        "Next voucher",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                for (int i = 0; i < series.length; i++)
                  _seriesRow(series[i], prefix, isLast: i == series.length - 1),
              ],
            ),
          ),

        const SizedBox(height: 10),
        Text(
          "The final number is assigned when the voucher is saved. Counters do not reset yearly.",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
      ],
    );
  }

  Widget _seriesRow(VoucherSeries s, String prefix, {required bool isLast}) {
    final preview = prefix.isEmpty ? s.preview : s.previewFor(prefix);
    final changed = _isDirty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          /// MODULE BADGE
          Container(
            width: 42,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  s.module,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          /// LABEL + NEXT NO.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Next no. ${s.nextNumber}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          /// PREVIEW PILL
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: changed
                  ? AppColors.secondaryDark.withOpacity(0.1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: changed
                    ? AppColors.secondaryDark.withOpacity(0.4)
                    : AppColors.border,
              ),
            ),
            child: Text(
              preview,
              style: TextStyle(
                fontFamily: "monospace",
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: _card,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: AppColors.primaryDark, size: 22),
          ),
          const SizedBox(height: 10),
          const Text(
            "No data found",
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? "No voucher series available.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: AppColors.primaryDark),
            label: Text("Retry",
                style: TextStyle(color: AppColors.primaryDark)),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
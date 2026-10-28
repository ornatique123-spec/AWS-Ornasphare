import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Extra/AppColors.dart';
import '../Extra/AppMessage.dart';

// ⚠️ Createcustomer ni file jya hoy e path mukjo
// (jem ke 'package:pecifician_sysytem/Customer/CreteCustomer.dart')

import '../User/CreateCustomer.dart';

/// ================================================================
/// 🔎 GST SEARCH — Customer onboarding
///
/// API : POST gst-search   body: {"gstin": "24GDTPS5199L1ZB"}
///
/// Step 1: GSTIN lakho → Search
/// Step 2: Business details jovo (premium cards)
/// Step 3: Add Customer → onAddCustomer(details) callback
///         (callback na aapo to Navigator.pop(context, details))
/// ================================================================

class GstSearchScreen extends StatefulWidget {
  /// Add Customer dabavo tyare (customer form kholva mate)
  final void Function(BuildContext context, Map<String, dynamic> details)?
  onAddCustomer;

  /// "Enter customer manually" dabavo tyare
  final void Function(BuildContext context)? onEnterManually;

  const GstSearchScreen({
    super.key,
    this.onAddCustomer,
    this.onEnterManually,
  });

  @override
  State<GstSearchScreen> createState() => _GstSearchScreenState();
}

class _GstSearchScreenState extends State<GstSearchScreen> {
  static String get _url => "${ApiConstants.baseUrl}gst-search";

  static const Color _ink = Color(0xff172033);
  static const Color _muted = Color(0xff7A8194);
  static const Color _line = Color(0xffE3E7F0);
  static const Color _bg = Color(0xffF5F7FB);
  static const Color _green = Color(0xff16A34A);
  static const Color _red = Color(0xffD64545);

  /// 15 character GSTIN format
  static final RegExp _gstinRegex =
  RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  final TextEditingController _gstCtrl = TextEditingController();
  final FocusNode _gstFocus = FocusNode();

  bool _loading = false;
  String? _error;
  String? _fieldError;

  /// API mathi aavelu (normalize karelu) business
  Map<String, dynamic>? _biz;

  int get _step => _biz != null ? 2 : 1;

  @override
  void dispose() {
    _gstCtrl.dispose();
    _gstFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // API
  // ============================================================

  Future<void> _search() async {
    final String gstin = _gstCtrl.text.trim().toUpperCase();
    FocusManager.instance.primaryFocus?.unfocus();

    if (gstin.isEmpty) {
      setState(() => _fieldError = "Please enter GST number");
      return;
    }
    if (!_gstinRegex.hasMatch(gstin)) {
      setState(() => _fieldError = "Enter a valid 15-character GSTIN");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _fieldError = null;
      _biz = null;
    });

    debugPrint("🔎 GST SEARCH: $_url  {gstin: $gstin}");

    try {
      final response = await ApiHelper().postRequest(_url, {"gstin": gstin});
      final dynamic body = response?.data;

      debugPrint("🔎 GST RESPONSE: $body");

      if (!mounted) return;

      final bool ok = response?.statusCode == 200 &&
          body is Map &&
          body["success"] != false;

      if (ok) {
        final Map<String, dynamic> biz = _normalize(body, gstin);
        if (_s(biz["business_name"]).isEmpty &&
            _s(biz["legal_name"]).isEmpty) {
          setState(() => _error = "No business found for this GSTIN");
        } else {
          setState(() => _biz = biz);
        }
      } else {
        setState(() => _error = _errorMessage(body));
      }
    } catch (e) {
      debugPrint("❌ GST search error: $e");
      if (mounted) {
        setState(() => _error = "Could not search GSTIN. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(dynamic body) {
    if (body is Map) {
      final errors = body["errors"];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (body["message"] != null) return body["message"].toString();
    }
    return "Business details not found";
  }

  // ============================================================
  // RESPONSE → ek saral map
  // (GST portal style: lgnm, tradeNam, sts, pradr.addr ... ke
  //  snake_case: legal_name, trade_name, status, address ... banne chale)
  // ============================================================

  static String _s(dynamic v) {
    if (v == null) return "";
    if (v is List) return v.map(_s).where((e) => e.isNotEmpty).join(", ");
    final s = v.toString().trim();
    return s == "null" ? "" : s;
  }

  /// Nested map ma pehli male e key (BFS)
  static dynamic _deep(dynamic root, List<String> keys) {
    final List<dynamic> queue = [root];
    final Set<String> wanted = keys.map((k) => k.toLowerCase()).toSet();
    int guard = 0;

    while (queue.isNotEmpty && guard++ < 200) {
      final cur = queue.removeAt(0);
      if (cur is Map) {
        for (final e in cur.entries) {
          if (wanted.contains(e.key.toString().toLowerCase()) &&
              e.value != null &&
              _s(e.value).isNotEmpty &&
              e.value is! Map) {
            return e.value;
          }
        }
        for (final v in cur.values) {
          if (v is Map) queue.add(v);
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _normalize(Map body, String gstin) {
    final dynamic data = body["data"] ?? body;

    // 🔥 Aa API: data.business = business details,
    //            data.customer_form = customer form mate taiyar data
    final dynamic root =
    data is Map && data["business"] is Map ? data["business"] : data;
    final dynamic customerForm =
    data is Map && data["customer_form"] is Map ? data["customer_form"] : null;

    String pick(List<String> keys) => _s(_deep(root, keys));

    // ---- Address ----
    String address = pick(["address", "full_address", "principal_address"]);
    final dynamic addrObj = _deep(root, ["addr"]) == null
        ? _findMap(root, "addr")
        : null;
    if (address.isEmpty && addrObj is Map) {
      address = [
        addrObj["bno"],
        addrObj["bnm"],
        addrObj["flno"],
        addrObj["st"],
        addrObj["loc"],
        addrObj["dst"],
      ].map(_s).where((e) => e.isNotEmpty).join(", ");
    }

    // ---- PAN — GSTIN na 3 thi 12 akshar ----
    final String g = pick(["gstin", "gst_no", "gstin_no"]).isNotEmpty
        ? pick(["gstin", "gst_no", "gstin_no"])
        : gstin;
    String pan = pick(["pan", "pan_no", "pan_number"]);
    if (pan.isEmpty && g.length >= 12) pan = g.substring(2, 12);

    // ---- Registration date ----
    String regDate = pick(
        ["registration_date", "rgdt", "reg_date", "date_of_registration"]);
    final DateTime? d = DateTime.tryParse(regDate);
    if (d != null) regDate = DateFormat("dd-MM-yyyy").format(d);

    // ---- Nature of business (list) ----
    final dynamic nbaRaw =
        _findList(root, ["nature_of_business", "nba", "business_nature"]) ??
            _deep(root, ["nature_of_business", "nba", "business_nature"]);
    final List<String> nature = nbaRaw is List
        ? nbaRaw.map(_s).where((e) => e.isNotEmpty).toList()
        : _s(nbaRaw)
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return {
      "business_name": pick([
        "name", // 🔥 data.business.name = UNIVERSAL MOTORS
        "business_name",
        "trade_name",
        "tradeNam",
        "tradename",
        "trade_nam",
      ]),
      "legal_name": pick(["legal_name", "lgnm", "legal_name_of_business"]),
      "gstin": g,
      "pan": pan,
      "status": pick(["registration_status", "status", "sts", "gst_status"]),
      "entity_type": pick([
        "entity_type",
        "ctb",
        "constitution_of_business",
        "constitution",
        "business_type"
      ]),
      "address": address,
      "city": pick(["city", "loc", "dst", "district"]),
      "area": pick(["area"]),
      "landmark": pick(["landmark"]),
      "state": pick(["state", "stcd", "state_name"]),
      "pincode": pick(["pincode", "pncd", "pin_code", "postcode", "pin"]),
      "registration_type":
      pick(["registration_type", "dty", "taxpayer_type", "reg_type"]),
      "registration_date": regDate,
      "department": pick(["department", "ctj", "stj", "jurisdiction"]),
      "nature_of_business": nature,
      // Add Customer mate API nu taiyar form (category_person_id, remarks ...)
      if (customerForm is Map)
        "customer_form": Map<String, dynamic>.from(customerForm),
      "raw": root,
    };
  }

  static Map? _findMap(dynamic root, String key) {
    final List<dynamic> q = [root];
    int guard = 0;
    while (q.isNotEmpty && guard++ < 200) {
      final cur = q.removeAt(0);
      if (cur is Map) {
        if (cur[key] is Map) return cur[key];
        q.addAll(cur.values.whereType<Map>());
      }
    }
    return null;
  }

  static List? _findList(dynamic root, List<String> keys) {
    final List<dynamic> q = [root];
    int guard = 0;
    while (q.isNotEmpty && guard++ < 200) {
      final cur = q.removeAt(0);
      if (cur is Map) {
        for (final k in keys) {
          if (cur[k] is List) return cur[k];
        }
        q.addAll(cur.values.whereType<Map>());
      }
    }
    return null;
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  /// 🔥 Add Customer → Createcustomer form GST data sathe khule
  void _addCustomer() {
    final biz = _biz;
    if (biz == null) return;

    final Map<String, dynamic> details = Map.of(biz)..remove("raw");

    // Bahar thi callback aapyo hoy to e (optional)
    if (widget.onAddCustomer != null) {
      widget.onAddCustomer!(context, details);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => Createcustomer(gstData: details),
      ),
    );
  }

  /// "Manually" → khali Createcustomer form
  void _enterManually() {
    if (widget.onEnterManually != null) {
      widget.onEnterManually!(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const Createcustomer(),
      ),
    );
  }

  void _clear() {
    setState(() {
      _gstCtrl.clear();
      _biz = null;
      _error = null;
      _fieldError = null;
    });
    _gstFocus.requestFocus();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _biz == null ? null : _bottomBar(),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _hero(),
            _searchCard(),
            if (_error != null) _errorBanner(),
            if (_loading) _loadingCard(),
            if (_biz != null) ..._result(_biz!),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HERO HEADER (compact)
  // ============================================================

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.secondaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -26,
              top: -34,
              child: _glowCircle(96, 0.08),
            ),
            Positioned(
              right: 40,
              bottom: -30,
              child: _glowCircle(56, 0.06),
            ),
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 17),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.travel_explore_rounded,
                      color: AppColors.primaryDark, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CUSTOMER ONBOARDING",
                        style: TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        "GST Search",
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "Find a business by GSTIN to create a customer",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  // ============================================================
  // SEARCH CARD (compact)
  // ============================================================

  Widget _searchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "GST number",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (_gstCtrl.text.length == 15 ? _green : _muted)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_gstCtrl.text.length}/15",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _gstCtrl.text.length == 15 ? _green : _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),

          /// GSTIN FIELD
          TextField(
            controller: _gstCtrl,
            focusNode: _gstFocus,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() => _fieldError = null),
            maxLength: 15,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]')),
              _UpperCaseFormatter(),
            ],
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
            decoration: InputDecoration(
              counterText: "",
              isDense: true,
              hintText: "ENTER 15-CHARACTER GSTIN",
              hintStyle: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: _muted.withOpacity(0.7),
              ),
              prefixIcon: Icon(Icons.badge_outlined,
                  color: AppColors.primaryDark, size: 18),
              prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: _gstCtrl.text.isEmpty
                  ? null
                  : IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded,
                    size: 17, color: _muted),
                onPressed: _clear,
              ),
              filled: true,
              fillColor: _bg,
              errorText: _fieldError,
              errorStyle: const TextStyle(fontSize: 10.5),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                BorderSide(color: AppColors.primaryDark, width: 1.3),
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// BUTTONS
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _loading ? null : _search,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.secondaryDark
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withOpacity(0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded,
                              color: Colors.white, size: 17),
                          SizedBox(width: 5),
                          Text(
                            "Search GSTIN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _enterManually,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primaryDark.withOpacity(0.28)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded,
                            size: 17, color: AppColors.primaryDark),
                        const SizedBox(width: 4),
                        Text(
                          "Manually",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// STEPS
          _steps(),
        ],
      ),
    );
  }

  Widget _steps() {
    const labels = ["Search", "Review", "Add customer"];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            _stepItem(i + 1, labels[i]),
            if (i < 2)
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: i + 1 < _step ? _green : _line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepItem(int n, String label) {
    final bool done = n < _step;
    final bool active = n == _step;
    final Color c = done
        ? _green
        : active
        ? AppColors.primaryDark
        : _muted.withOpacity(0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? c : Colors.white,
            border: Border.all(color: c, width: 1.3),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                : Text(
              "$n",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : c,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active || done ? FontWeight.w700 : FontWeight.w500,
            color: active || done ? _ink : _muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATES
  // ============================================================

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: _card(),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Fetching business details...",
            style: TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 RESULT (compact premium)
  // ============================================================

  List<Widget> _result(Map<String, dynamic> b) {
    final String status = _s(b["status"]);
    final bool active = status.toLowerCase().contains("active") &&
        !status.toLowerCase().contains("inactive");
    final String name = _s(b["business_name"]).isNotEmpty
        ? _s(b["business_name"])
        : _s(b["legal_name"]);

    return [
      /// BUSINESS HERO — gradient card
      Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xff1E293B), Color(0xff0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff0F172A).withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(right: -24, top: -30, child: _glowCircle(90, 0.06)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// verified line
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 11, color: Color(0xff4ADE80)),
                              SizedBox(width: 4),
                              Text(
                                "BUSINESS FOUND",
                                style: TextStyle(
                                  fontSize: 8.5,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff4ADE80),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (status.isNotEmpty)
                          _darkChip(
                            active
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            status,
                            active
                                ? const Color(0xff4ADE80)
                                : const Color(0xffF87171),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    /// avatar + name
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.secondaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Center(
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              if (_s(b["legal_name"]).isNotEmpty &&
                                  _s(b["legal_name"]) != name)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Legal: ${_s(b["legal_name"])}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    /// GSTIN + entity
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _s(b["gstin"])));
                              AppMessage.success(context, "GSTIN copied");
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "GSTIN",
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            letterSpacing: 0.8,
                                            color:
                                            Colors.white.withOpacity(0.55),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _s(b["gstin"]),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              letterSpacing: 0.8,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.copy_rounded,
                                      size: 13,
                                      color: Colors.white.withOpacity(0.6)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_s(b["entity_type"]).isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "ENTITY",
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    letterSpacing: 0.8,
                                    color: Colors.white.withOpacity(0.55),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _s(b["entity_type"]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      /// Business identity
      _section(
        icon: Icons.badge_rounded,
        title: "Business identity",
        color: AppColors.primaryDark,
        fields: [
          ("Business name", _s(b["business_name"])),
          ("Legal name", _s(b["legal_name"])),
          ("GSTIN", _s(b["gstin"])),
          ("PAN", _s(b["pan"])),
          ("Registration status", status),
          ("Entity type", _s(b["entity_type"])),
        ],
      ),

      /// Registered address
      _section(
        icon: Icons.location_on_rounded,
        title: "Registered address",
        color: const Color(0xffE08A00),
        fullWidthFirst: true,
        fields: [
          ("Address", _s(b["address"])),
          ("City", _s(b["city"])),
          ("Area", _s(b["area"])),
          ("State", _s(b["state"])),
          ("Pincode", _s(b["pincode"])),
        ],
      ),

      /// Registration details
      _section(
        icon: Icons.assignment_turned_in_rounded,
        title: "Registration details",
        color: const Color(0xff2563EB),
        fields: [
          ("Registration type", _s(b["registration_type"])),
          ("Registration date", _s(b["registration_date"])),
          ("Department", _s(b["department"])),
        ],
        footer: _natureChips(b["nature_of_business"]),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: _muted),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                "Add Customer opens an editable form. Review the details and fill any missing fields before saving.",
                style: TextStyle(fontSize: 10, height: 1.4, color: _muted),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _darkChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Section card — label dabi baju, value jamni baju (compact rows)
  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required List<(String, String)> fields,
    bool fullWidthFirst = false,
    Widget? footer,
  }) {
    final List<(String, String)> rows =
    fullWidthFirst ? fields.skip(1).toList() : fields;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: _card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header strip
            Container(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.10), color.withOpacity(0.02)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 13, color: Colors.white),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Full width (address)
                  if (fullWidthFirst)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fields.first.$1,
                              style:
                              const TextStyle(fontSize: 10, color: _muted)),
                          const SizedBox(height: 2),
                          Text(
                            fields.first.$2.isEmpty
                                ? "Not provided"
                                : fields.first.$2,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: fields.first.$2.isEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: fields.first.$2.isEmpty ? _muted : _ink,
                            ),
                          ),
                        ],
                      ),
                    ),

                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0 || fullWidthFirst)
                      const Divider(height: 1, color: _line),
                    _row(rows[i].$1, rows[i].$2),
                  ],

                  if (footer != null) footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    final bool empty = value.trim().isEmpty;
    final bool isStatus = label == "Registration status";
    final bool active = value.toLowerCase().contains("active") &&
        !value.toLowerCase().contains("inactive");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: _muted),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: isStatus && !empty
                  ? Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (active ? _green : _red).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: active ? _green : _red,
                  ),
                ),
              )
                  : Text(
                empty ? "Not provided" : value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                  color: empty ? _muted : _ink,
                  fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _natureChips(dynamic list) {
    final List<String> items =
    list is List ? list.map(_s).where((e) => e.isNotEmpty).toList() : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: _line),
        const SizedBox(height: 7),
        const Text("Nature of business",
            style: TextStyle(fontSize: 10.5, color: _muted)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Text(
            "Not provided",
            style: TextStyle(
              fontSize: 11.5,
              color: _muted,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final n in items)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff2563EB).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xff2563EB).withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    n,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff2563EB),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 2),
      ],
    );
  }

  // ============================================================
  // BOTTOM — ADD CUSTOMER
  // ============================================================

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _line)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _clear,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                child: const Icon(Icons.refresh_rounded, color: _ink, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: _addCustomer,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff22C55E), Color(0xff15803D)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          color: Colors.white, size: 17),
                      SizedBox(width: 6),
                      Text(
                        "Add Customer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  BoxDecoration _card() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  String _initials(String name) {
    final parts =
    name.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Lakhta j CAPITAL
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
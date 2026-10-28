import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';

/// ===========================================================================
/// 🔐 BRANCH ACCESS
/// Fakt MAIN COMPANY na ADMIN ne j Branch Reports / Branch Management dekhay.
///
/// ✅ Server no flag sauthi pehla: profile.can_manage_branches
/// ✅ Result login (token) pramane yaad rahe chhe — logout kari ne biju
///    user login kare to aapo-aap navo check thay (clear() bhulay to pan)
/// ✅ Fail thay ke "false" aave to yaad nathi rakhtu — next screen par
///    farithi try kare
/// ===========================================================================
class BranchAccess {
  BranchAccess._();

  static String? _cachedToken;
  static bool? _cachedResult;

  /// Main company admin chhe? (profile API parthi)
  static Future<bool> isMainCompanyAdmin() async {
    final String token = await _currentToken();

    // E j login mate pehla "true" aavyu hoy to farithi API nahi
    if (_cachedResult == true && _cachedToken == token) return true;

    final bool result = await _load();

    if (result) {
      _cachedToken = token;
      _cachedResult = true;
    } else {
      clear();
    }
    return result;
  }

  /// Logout / company switch vakhte (optional — have token thi aapo-aap thay)
  static void clear() {
    _cachedToken = null;
    _cachedResult = null;
  }

  static Future<String> _currentToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString("token") ??
          prefs.getString("access_token") ??
          prefs.getString("auth_token") ??
          "";
    } catch (_) {
      return "";
    }
  }

  static Future<bool> _load() async {
    try {
      final response = await ApiHelper().getRequest(
        ApiConstants.company_profile,
        showLoading: false,
      );

      final dynamic body = response?.data;
      debugLog("🔐 BranchAccess status: ${response?.statusCode}");

      if (response?.statusCode == 200 && body is Map) {
        final bool ok = checkResponse(Map.from(body));
        debugLog("🔐 BranchAccess result: $ok");
        return ok;
      }
    } catch (e) {
      debugLog("🔐 BranchAccess error: $e");
    }
    return false;
  }

  // ignore: avoid_print
  static void debugLog(String s) => print(s);

  static bool _isTrue(dynamic v) =>
      v == true || v.toString() == "1" || v.toString().toLowerCase() == "true";

  /// Aakho profile API response (success, data, profile, company, role_names)
  static bool checkResponse(Map body) {
    final Map data = body["data"] is Map ? body["data"] : {};
    final Map profile = body["profile"] is Map ? body["profile"] : {};

    // ---- 1) Server flag: sauthi sacho ----
    final dynamic flag = profile["can_manage_branches"] ??
        data["can_manage_branches"] ??
        body["can_manage_branches"];
    if (flag != null) return _isTrue(flag);

    // ---- 2) Flag na hoy to role + company thi ----
    final Map merged = {
      ...data,
      ...profile,
      if (body["role_names"] != null) "role_names": body["role_names"],
      if (body["company"] is Map) "company": body["company"],
    };
    return checkUser(merged);
  }

  /// Fakt user map hoy tyare (SettingsScreen na userData mate pan chale)
  static bool checkUser(Map userData) {
    if (userData["can_manage_branches"] != null) {
      return _isTrue(userData["can_manage_branches"]);
    }

    // ---- Role: Admin hovo joie (Branch Admin nahi) ----
    // "company_admin" / "Company Admin" / "admin" — badha chale
    final roles = <String>[
      if (userData["role_names"] is List)
        ...(userData["role_names"] as List).map((e) => e.toString()),
      if (userData["roles"] is List)
        ...(userData["roles"] as List)
            .map((e) => e is Map ? (e["name"] ?? "").toString() : e.toString()),
      if (userData["role"] != null) userData["role"].toString(),
    ]
        .map((e) => e.trim().toLowerCase().replaceAll("_", " "))
        .toList();

    final isAdmin = roles.any((r) =>
    (r == "admin" || r == "company admin" || r == "owner") &&
        !r.contains("branch"));

    if (!isAdmin) return false;

    // ---- Company: main company hovi joie (branch nahi) ----
    if (userData.containsKey("parent_company_id")) {
      return userData["parent_company_id"] == null;
    }

    final company = userData["company"];
    if (company is Map) {
      if (company["is_main"] != null) return _isTrue(company["is_main"]);
      if (company.containsKey("parent_company_id")) {
        return company["parent_company_id"] == null;
      }
    }

    if (userData["is_main_company"] != null) {
      return _isTrue(userData["is_main_company"]);
    }
    if (userData["is_main"] != null) {
      return _isTrue(userData["is_main"]);
    }

    // Company info na male to — admin ne batavo
    return true;
  }
}
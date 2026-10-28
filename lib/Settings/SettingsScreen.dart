import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pecifician_sysytem/Settings/CompanyProfile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppMessage.dart';
import '../Extra/AppColors.dart';
import 'BranchManagementScreen.dart';
import 'ContactUsScreen.dart';
import 'FeedbackScreen.dart';
import 'FingerprintScreen.dart';
import 'HelpCenterScreen.dart';
import 'ProfileDetailsScreen.dart';
import 'UserManualScreen.dart';
import 'VideoTutorialsScreen.dart';
import 'VoucherConfigurationScreen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsOn = true;
  bool isLoading = true;
  String selectedLanguage = "English";
  bool fingerprintEnabled = false;
  Map userData = {};

  @override
  void initState() {
    super.initState();
    loadProfile();
    loadFingerprint();
  }

  Future<void> loadFingerprint() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      fingerprintEnabled = prefs.getBool("fingerprint_enabled") ?? false;
    });
  }

  /// ✅ API CALL — Profile Data
  Future<void> loadProfile() async {
    setState(() => isLoading = true);

    final response = await ApiHelper().getRequest(
      ApiConstants.company_profile,
    );

    if (response?.statusCode == 200 && response?.data["data"] != null) {
      final data = response!.data;

      setState(() {
        userData = data['data'];
        isLoading = false;
      });
    } else {
      setState(() {
        userData = {};
        isLoading = false;
      });

      AppMessage.error(context, "Failed to load profile data");
    }
  }

  String v(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return "-";
    return value.toString();
  }

  String get roleText {
    if (userData["role_names"] != null &&
        userData["role_names"] is List &&
        (userData["role_names"] as List).isNotEmpty) {
      return v((userData["role_names"] as List).first);
    }
    return v(userData["role"]);
  }

  // ===========================================================================
  // ✅ BRANCH MANAGEMENT ACCESS
  // Fakt main company no Admin hoy to j true.
  // Branch admin / staff / manager vagere ne false.
  // ===========================================================================
  bool _isTrue(dynamic v) =>
      v == true || v.toString() == "1" || v.toString().toLowerCase() == "true";

  bool get isMainCompanyAdmin {
    // ---- 1) Role: Admin hovo joie (Branch Admin nahi) ----
    final roles = <String>[
      if (userData["role_names"] is List)
        ...(userData["role_names"] as List).map((e) => e.toString()),
      if (userData["role"] != null) userData["role"].toString(),
    ].map((e) => e.trim().toLowerCase()).toList();

    final isAdmin = roles.any((r) =>
    (r == "admin" || r == "company admin" || r == "owner") &&
        !r.contains("branch"));

    if (!isAdmin) return false;

    // ---- 2) Company: main company hovi joie (branch nahi) ----
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
    if (userData.containsKey("parent_company_id")) {
      return userData["parent_company_id"] == null;
    }

    // Company info na male to — admin ne batavo
    return true;
  }

  String get initials {
    if (userData["avatar_initials"] != null &&
        userData["avatar_initials"].toString().isNotEmpty) {
      return userData["avatar_initials"].toString();
    }
    return (userData["name"] ?? "U")
        .toString()
        .trim()
        .split(" ")
        .map((e) => e.isNotEmpty ? e[0] : "")
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                onRefresh: loadProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileCard(),
                      const SizedBox(height: 10),

                      _sectionTitle(Icons.person, "ACCOUNT"),
                      const SizedBox(height: 10),
                      _cardGroup([
                        _tileItem(
                          icon: Icons.person_outline,
                          title: "Profile",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailsScreen(
                                  userData: userData,
                                ),
                              ),
                            );
                          },
                        ),

                        /// 🔒 Fakt main company admin ne j dekhay
                        if (isMainCompanyAdmin)
                          _tileItem(
                            icon: Icons.account_tree_outlined,
                            title: "Branch Management",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BranchManagementScreen(
                                    userData: userData,
                                    onAllBranchesDashboard: () {
                                      // TODO: All Branches Dashboard screen par navigate karo
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                        /// 🧾 Voucher Configuration (Branch Management ni niche)
                        if (isMainCompanyAdmin)
                          _tileItem(
                            icon: Icons.receipt_long_outlined,
                            title: "Voucher Configuration",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const VoucherConfigurationScreen(),
                                ),
                              );
                            },
                          ),

                        _tileItem(
                          icon: Icons.apartment_outlined,
                          title: "Company Profile",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Companyprofile(
                                  userData: userData,
                                ),
                              ),
                            );
                          },
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 10),

                      _sectionTitle(Icons.help_outline, "SUPPORT"),
                      const SizedBox(height: 10),
                      _cardGroup([
                        _tileItem(
                          icon: Icons.help_outline,
                          title: "Help Center",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const HelpCenterScreen()),
                            );
                          },
                        ),
                        _tileItem(
                          icon: Icons.menu_book_outlined,
                          title: "User Manual",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const UserManualScreen()),
                            );
                          },
                        ),
                        _tileItem(
                          icon: Icons.play_circle_outline,
                          title: "Video Tutorials",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const VideoTutorialsScreen()),
                            );
                          },
                        ),
                        _tileItem(
                          icon: Icons.call_outlined,
                          title: "Contact Us",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const ContactUsScreen()),
                            );
                          },
                        ),
                        _switchTile(
                          icon: Icons.fingerprint,
                          title: "Fingerprint Login",
                          value: fingerprintEnabled,
                          onChanged: _onFingerprintChanged,
                        ),
                        _tileItem(
                          icon: Icons.chat_bubble_outline,
                          title: "Feedback",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FeedbackScreen()),
                            );
                          },
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 10),

                      _sectionTitle(
                          Icons.settings_outlined, "APPLICATION"),
                      const SizedBox(height: 10),
                      _cardGroup([
                        _switchTile(
                          icon: Icons.notifications_none,
                          title: "Notifications",
                          value: notificationsOn,
                          onChanged: (val) {
                            setState(() => notificationsOn = val);
                          },
                        ),
                        _tileItem(
                          icon: Icons.language_outlined,
                          title: "Language",
                          trailingText: selectedLanguage,
                          onTap: () async {
                            final result = await showLanguageDialog(
                              context,
                              selectedLanguage: selectedLanguage,
                            );

                            if (result != null) {
                              setState(() {
                                selectedLanguage = result;
                              });
                            }
                          },
                        ),
                        _tileItem(
                          icon: Icons.shield_outlined,
                          title: "Privacy Policy",
                          onTap: () {},
                        ),
                        _tileItem(
                          icon: Icons.description_outlined,
                          title: "Terms & Conditions",
                          onTap: () {},
                        ),
                        _tileItem(
                          icon: Icons.info_outline,
                          title: "App Version",
                          trailingText: "v1.0.0",
                          showArrow: false,
                          onTap: null,
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 26),

                      _logoutButton(),

                      const SizedBox(height: 24),
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

  /// ✅ FINGERPRINT TOGGLE
  Future<void> _onFingerprintChanged(bool value) async {
    final auth = LocalAuthentication();

    final bool isSupported = await auth.isDeviceSupported();
    final bool canCheck = await auth.canCheckBiometrics;

    if (!mounted) return;

    if (!isSupported || !canCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fingerprint is not available on this device."),
        ),
      );
      return;
    }

    final biometrics = await auth.getAvailableBiometrics();

    final hasBiometric = biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong) ||
        biometrics.contains(BiometricType.weak);

    if (!mounted) return;

    if (!hasBiometric) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No biometric has been added to this device."),
        ),
      );
      return;
    }

    try {
      final success = await auth.authenticate(
        localizedReason:
        value ? "Enable fingerprint login" : "Disable fingerprint login",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!success) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("fingerprint_enabled", value);

      if (!mounted) return;

      setState(() {
        fingerprintEnabled = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "Fingerprint enabled successfully."
                : "Fingerprint disabled successfully.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// ✅ HEADER
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
            "Settings",
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
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ PROFILE CARD
  Widget _profileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark.withOpacity(0.7),
                  AppColors.secondaryDark.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v(userData["name"]),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    roleText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  v(userData["email"]),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileDetailsScreen(userData: userData),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark.withOpacity(0.7),
                    AppColors.secondaryDark.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.remove_red_eye_outlined,
                      size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    "View",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ SECTION TITLE
  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryDark.withOpacity(0.7),
                AppColors.secondaryDark.withOpacity(0.7),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  /// ✅ CARD GROUP WRAPPER
  Widget _cardGroup(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /// ✅ NORMAL TILE
  Widget _tileItem({
    required IconData icon,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    bool showArrow = true,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
        bottomLeft: Radius.circular(14),
        bottomRight: Radius.circular(14),
      )
          : BorderRadius.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailingWidget != null)
                  trailingWidget
                else ...[
                  if (trailingText != null)
                    Text(
                      trailingText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (showArrow)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              color: AppColors.border,
              indent: 14,
              endIndent: 14,
            ),
        ],
      ),
    );
  }

  /// ✅ SWITCH TILE
  Widget _switchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: AppColors.primaryDark,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade300,
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: AppColors.border,
          indent: 14,
          endIndent: 14,
        ),
      ],
    );
  }

  /// ✅ LOGOUT BUTTON
  Widget _logoutButton() {
    return InkWell(
      onTap: () {
        // 🔥 Tamaru logout logic ahiya call karo
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark.withOpacity(0.7),
              AppColors.secondaryDark.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.white, size: 19),
            SizedBox(width: 8),
            Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ LANGUAGE SELECTION DIALOG
  Future<String?> showLanguageDialog(
      BuildContext context, {
        required String selectedLanguage,
      }) async {
    return showGeneralDialog<String>(
      context: context,
      barrierLabel: "Language",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return _LanguageDialogContent(selectedLanguage: selectedLanguage);
      },
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }
}

class _LanguageDialogContent extends StatefulWidget {
  final String selectedLanguage;

  const _LanguageDialogContent({required this.selectedLanguage});

  @override
  State<_LanguageDialogContent> createState() => _LanguageDialogContentState();
}

class _LanguageDialogContentState extends State<_LanguageDialogContent> {
  late String tempSelected;

  /// 🔥 TAMARA SUPPORTED LANGUAGES AHIYA NAKHO
  final List<Map<String, String>> languages = [
    {"code": "en", "name": "English", "native": "English"},
    {"code": "gu", "name": "Gujarati", "native": "ગુજરાતી"},
    {"code": "hi", "name": "Hindi", "native": "हिन्दी"},
  ];

  @override
  void initState() {
    super.initState();
    tempSelected = widget.selectedLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenWidth * 0.85,
          constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔥 Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark.withOpacity(0.7),
                            AppColors.secondaryDark.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.language,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Select Language",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// 🔥 Language Options
                ...languages.map((lang) {
                  final isSelected = tempSelected == lang["name"];

                  return InkWell(
                    onTap: () {
                      setState(() => tempSelected = lang["name"]!);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryDark.withOpacity(0.08)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang["name"]!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : Colors.black87,
                                  ),
                                ),
                                if (lang["native"] != lang["name"])
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      lang["native"]!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: AppColors.primaryDark,
                              size: 20,
                            )
                          else
                            Icon(
                              Icons.circle_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                /// 🔥 Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context, tempSelected);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark.withOpacity(0.7),
                                AppColors.secondaryDark.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "Apply",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
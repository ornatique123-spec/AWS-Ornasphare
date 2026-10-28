import 'package:flutter/material.dart';

import '../Extra/AppColors.dart';

class Companyprofile extends StatefulWidget {
  final Map userData;

  const Companyprofile({super.key, required this.userData});

  @override
  State<Companyprofile> createState() => _CompanyprofileState();
}

class _CompanyprofileState extends State<Companyprofile> {
  Map get user => widget.userData;
  Map get company => user["company"] ?? {};

  /// 🔥 PLAN ALERT DATA (company["plan_alert"])
  Map get planAlert => company["plan_alert"] ?? {};

  String v(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return "-";
    return value.toString();
  }

  /// ✅ ROLE NAME FORMATTER
  ///
  /// Backend thi "company_admin" (ke similar admin role) aave to
  /// UI ma sidhu "Admin" j batavvanu. Baki roles hoy to
  /// normal format kari ne batavvanu (underscore -> space, capitalize).
  String _formatRoleName(String role) {
    if (role.trim().isEmpty || role == "-") return "-";

    final String normalized = role.toLowerCase().trim();

    /// 🔥 Company Admin / company_admin / Company-Admin -> "Admin"
    if (normalized == "company_admin" ||
        normalized == "company-admin" ||
        normalized == "companyadmin" ||
        normalized.contains("company_admin") ||
        normalized.contains("company admin")) {
      return "Admin";
    }

    /// Baki roles: underscore/hyphen ne space ma convert kari,
    /// dareek word capitalize karo
    final String spaced = role.replaceAll("_", " ").replaceAll("-", " ");

    return spaced
        .split(" ")
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(" ");
  }

  @override
  void initState() {
    super.initState();

    /// ============================================================
    /// 🔥 PLAN ALERT POPUP
    ///
    /// API response na "plan_alert.show_popup" true hoy to j popup
    /// dekhadvani. Frame build thai gaya pachi j dialog kholvi jaruri
    /// che, nahi to context still-building error aave.
    /// ============================================================
    if (planAlert["show_popup"] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPlanAlertDialog();
        }
      });
    }
  }

  /// ============================================================
  /// 🔥 PLAN ALERT TYPE -> COLOR MAPPING
  /// ============================================================
  Color _planAlertColor(String type) {
    switch (type.toLowerCase()) {
      case "expired":
        return const Color(0xffE53935);
      case "warning":
      case "expiring_soon":
      case "expiring":
        return const Color(0xffFF9800);
      case "active":
        return const Color(0xff2ECC71);
      default:
        return AppColors.primaryDark;
    }
  }

  IconData _planAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case "expired":
        return Icons.error_outline_rounded;
      case "warning":
      case "expiring_soon":
      case "expiring":
        return Icons.warning_amber_rounded;
      case "active":
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  void _showPlanAlertDialog() {
    final String type = (planAlert["type"] ?? "").toString();

    final String title = v(planAlert["title"]);
    final String message = v(planAlert["message"]);
    final String contactName = v(planAlert["contact_name"]);
    final String contactMessage = v(planAlert["contact_message"]);

    final Color alertColor = _planAlertColor(type);
    final IconData alertIcon = _planAlertIcon(type);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ICON
                Container(
                  height: 60,
                  width: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(alertIcon, color: alertColor, size: 32),
                ),

                const SizedBox(height: 16),

                /// TITLE
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 8),

                /// MESSAGE
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),

                /// CONTACT INFO (jo available hoy)
                if (contactName != "-" || contactMessage != "-") ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contactName != "-")
                          Row(
                            children: [
                              Icon(
                                Icons.support_agent_rounded,
                                size: 15,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                contactName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        if (contactMessage != "-") ...[
                          const SizedBox(height: 4),
                          Text(
                            contactMessage,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                /// CLOSE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: () => Navigator.pop(dialogContext),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.secondaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "OK, GOT IT",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    /// ============================================================
    /// 🔥 PLAN EXPIRED CHECK
    ///
    /// plan_expired == true hoy to Company Status hammesha "Inactive"
    /// (red) j dekhadvanu, chahe company["status"] Active j kem na hoy.
    /// ============================================================
    final bool planExpired = company["plan_expired"] == true;

    final String companyStatusLabel = planExpired
        ? "Inactive"
        : v(company["status"]);

    final Color companyStatusColor = planExpired
        ? Colors.red
        : (company["status"] == "Active"
        ? const Color(0xff2ECC71)
        : Colors.red);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(isMobile),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _twoFieldRow(
                      _infoBox("Name", v(user["name"])),
                      _infoBox("Email", v(user["email"])),
                    ),
                    _twoFieldRow(
                      _infoBox(
                        "Role",
                        (() {
                          final role = (user["role"] != null &&
                              user["role"] is List &&
                              (user["role"] as List).isNotEmpty)
                              ? v((user["role"] as List).first)
                              : v(user["role"]);

                          return role.isNotEmpty
                              ? role[0].toUpperCase() + role.substring(1)
                              : role;
                        })(),
                      ),
                      _infoBox(
                        "Status",
                        v(user["status"]),
                        valueColor: (user["is_active"] == true)
                            ? const Color(0xff2ECC71)
                            : Colors.red,
                      ),
                    ),

                    const SizedBox(height: 0),

                    if (company.isNotEmpty) ...[
                      const SizedBox(height: 0),
                      _sectionTitle("Company"),
                      const SizedBox(height: 10),

                      _twoFieldRow(
                        _infoBox("Company Name", v(company["name"])),
                        _infoBox("Company Email", v(company["email"])),
                      ),
                      _infoBox(
                        "Company Address",
                        v(company["address_1"]),
                        fullWidth: true,
                      ),
                      _twoFieldRow(
                        _infoBox("City", v(company["city"])),
                        _infoBox("State", v(company["state"])),
                      ),
                      _twoFieldRow(
                        _infoBox("Country", v(company["country"])),
                        _infoBox("Postcode", v(company["postcode"])),
                      ),
                      _twoFieldRow(
                        _infoBox(
                          "Plan",
                          v(company["plan"]).toString().toUpperCase(),
                        ),
                        _infoBox(
                          "Company Status",
                          companyStatusLabel,
                          valueColor: companyStatusColor,
                        ),
                      ),

                      /// 🔥 NEW: PLAN EXPIRY + DAYS REMAINING
                      _twoFieldRow(
                        _infoBox(
                          "Plan Expires",
                          v(company["plan_expires_at_view"]),
                        ),
                        _infoBox(
                          "Days Remaining",
                          planExpired
                              ? "Expired"
                              : v(company["plan_days_remaining"]),
                          valueColor: planExpired
                              ? Colors.red
                              : ((company["plan_days_remaining"] is num &&
                              (company["plan_days_remaining"]
                              as num) <=
                                  15)
                              ? const Color(0xffFF9800)
                              : null),
                        ),
                      ),
                    ],

                    const SizedBox(height: 0),
                    _sectionTitle("System"),
                    const SizedBox(height: 10),

                    _twoFieldRow(
                      _infoBox("Created At", v(user["created_at_view"])),
                      _infoBox("Updated At", v(user["updated_at_view"])),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ HEADER
  Widget _header(bool isMobile) {
    String initials = (user["avatar_initials"] ?? "").toString().isNotEmpty
        ? user["avatar_initials"].toString()
        : (user["name"] ?? "U")
        .toString()
        .trim()
        .split(" ")
        .map((e) => e.isNotEmpty ? e[0] : "")
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
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
                const Text(
                  "Company Details",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  v(company["name"]),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark.withOpacity(0.7),
                    AppColors.secondaryDark.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Back",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ SECTION TITLE
  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.secondaryDark],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  /// ✅ TWO FIELD ROW WRAPPER
  Widget _twoFieldRow(Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }

  /// ✅ INFO BOX (label + value card)
  Widget _infoBox(
      String label,
      String value, {
        Color? valueColor,
        bool fullWidth = false,
        bool isSpacer = false,
      }) {
    if (isSpacer) return const SizedBox.shrink();

    Widget box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );

    if (fullWidth) {
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: box);
    }

    return box;
  }
}
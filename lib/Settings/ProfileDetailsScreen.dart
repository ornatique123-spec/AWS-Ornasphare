import 'package:flutter/material.dart';

import '../Extra/AppColors.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final Map userData;

  const ProfileDetailsScreen({super.key, required this.userData});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  Map get user => widget.userData;
  Map get company => user["company"] ?? {};

  String v(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return "-";
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
                    _sectionTitle("Contact"),
                    const SizedBox(height: 10),

                    _twoFieldRow(
                      _infoBox("Mobile No", v(user["mobile_no"])),
                      _infoBox("Phone No", v(user["phone_no"])),
                    ),
                    _twoFieldRow(
                      _infoBox("Person Code", v(user["person_code"])),
                      _infoBox("City", v(user["city"])),
                    ),
                    _infoBox("Address", v(user["address"]), fullWidth: true),
                    _twoFieldRow(
                      _infoBox("Area", v(user["area"])),
                      _infoBox("Landmark", v(user["landmark"])),
                    ),
                    _twoFieldRow(
                      _infoBox("Pincode", v(user["pincode"])),
                      _infoBox("", "", isSpacer: true),
                    ),

                    const SizedBox(height: 0),
                    _sectionTitle("Contact Persons"),
                    const SizedBox(height: 10),

                    _twoFieldRow(
                      _infoBox(
                        "Contact Person 1",
                        v(user["contact_person1_name"]),
                      ),
                      _infoBox(
                        "Contact Person 1 Phone",
                        v(user["contact_person1_phone"]),
                      ),
                    ),
                    _twoFieldRow(
                      _infoBox(
                        "Contact Person 2",
                        v(user["contact_person2_name"]),
                      ),
                      _infoBox(
                        "Contact Person 2 Phone",
                        v(user["contact_person2_phone"]),
                      ),
                    ),

                    const SizedBox(height: 0),
                    _sectionTitle("Legal / Documents"),
                    const SizedBox(height: 10),

                    _twoFieldRow(
                      _infoBox("GST No", v(user["gst_no"])),
                      _infoBox("PAN No", v(user["pan_no"])),
                    ),
                    _twoFieldRow(
                      _infoBox("Aadhaar No", v(user["aadhaar_no"])),
                      _infoBox(
                        "Hallmark License No",
                        v(user["hallmark_license_no"]),
                      ),
                    ),

                    const SizedBox(height: 0),
                    _sectionTitle("Personal"),
                    const SizedBox(height: 10),

                    _twoFieldRow(
                      _infoBox("Birth Date", v(user["birth_date"])),
                      _infoBox(
                        "Anniversary Date",
                        v(user["anniversary_date"]),
                      ),
                    ),
                    _twoFieldRow(
                      _infoBox("Reference", v(user["reference"])),
                      _infoBox("", "", isSpacer: true),
                    ),
                    _infoBox("Remarks", v(user["remarks"]), fullWidth: true),

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
                          v(company["status"]),
                          valueColor: (company["status"] == "Active")
                              ? const Color(0xff2ECC71)
                              : Colors.red,
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
                  "Profile Details",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  v(user["name"]),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              colors: [
                AppColors.primaryDark,
                AppColors.secondaryDark,
              ],
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: box,
      );
    }

    return box;
  }
}
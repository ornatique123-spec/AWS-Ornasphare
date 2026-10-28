import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Extra/AppColors.dart';

class UserManualScreen extends StatefulWidget {
  const UserManualScreen({super.key});

  @override
  State<UserManualScreen> createState() => _UserManualScreenState();
}

class _UserManualScreenState extends State<UserManualScreen> {
  String searchQuery = "";
  final TextEditingController searchController = TextEditingController();

  /// 🔥 TAMARA ACTUAL PDF/DOC LINK AHIYA NAKHO
  static const String manualPdfUrl =
      "https://ornasphere.com/uploads/user_manual.pdf";

  /// 🔥 TAMARA ACTUAL MANUAL SECTIONS AHIYA NAKHO
  final List<Map<String, dynamic>> manualSections = [
    {
      "title": "Getting Started",
      "icon": Icons.rocket_launch_outlined,
      "topics": [
        "Login & Registration",
        "Understanding Dashboard",
        "Navigating the App",
      ],
    },
    {
      "title": "Vacuum Voucher",
      "icon": Icons.receipt_long_outlined,
      "topics": [
        "How to Create a Voucher",
        "Editing Voucher Details",
        "Viewing Voucher History",
        "Generating Voucher PDF",
      ],
    },
    {
      "title": "Vacuum Buch",
      "icon": Icons.inventory_2_outlined,
      "topics": [
        "Adding Buch Details",
        "Editing Buch Records",
        "Managing Multiple Buch Entries",
      ],
    },
    {
      "title": "User Management",
      "icon": Icons.people_outline,
      "topics": [
        "Creating New Users",
        "Assigning Roles & Permissions",
        "Managing User Access",
      ],
    },
    {
      "title": "Reports & History",
      "icon": Icons.bar_chart_outlined,
      "topics": [
        "Viewing Process History",
        "Filtering by Date Range",
        "Exporting Reports",
      ],
    },
    {
      "title": "Settings",
      "icon": Icons.settings_outlined,
      "topics": [
        "Updating Profile",
        "Changing Password",
        "Notification Preferences",
      ],
    },
  ];

  List<Map<String, dynamic>> get filteredSections {
    if (searchQuery.trim().isEmpty) return manualSections;

    List<Map<String, dynamic>> result = [];

    for (var section in manualSections) {
      List topics = section["topics"];
      bool sectionMatches =
      section["title"].toString().toLowerCase().contains(
        searchQuery.toLowerCase(),
      );

      List matchedTopics = topics
          .where((t) =>
          t.toString().toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      if (sectionMatches || matchedTopics.isNotEmpty) {
        result.add({
          ...section,
          "topics": sectionMatches ? topics : matchedTopics,
        });
      }
    }

    return result;
  }

  Future<void> _openManual() async {
    final uri = Uri.parse(manualPdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _introCard(),
                    const SizedBox(height: 16),
                    _searchField(),
                    const SizedBox(height: 16),

                    filteredSections.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "No Results Found",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    )
                        : Column(
                      children: filteredSections
                          .map((s) => _sectionCard(s))
                          .toList(),
                    ),
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
            "User Manual",
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
        ],
      ),
    );
  }

  /// ✅ INTRO CARD (with Download/View PDF button)
  Widget _introCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark.withOpacity(0.7),
            AppColors.secondaryDark.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Complete User Guide",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Everything you need to know about the app",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _openManual,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "View Full Manual (PDF)",
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
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

  /// ✅ SEARCH FIELD
  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.black, fontSize: 14),
        onChanged: (val) {
          setState(() => searchQuery = val);
        },
        decoration: InputDecoration(
          hintText: "Search topics...",
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade600,
            size: 20,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? InkWell(
            onTap: () {
              searchController.clear();
              setState(() => searchQuery = "");
            },
            child: Icon(
              Icons.close,
              color: Colors.grey.shade600,
              size: 18,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  /// ✅ SECTION CARD (Expandable)
  Widget _sectionCard(Map<String, dynamic> section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape:
          const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              section["icon"],
              color: AppColors.primaryDark,
              size: 18,
            ),
          ),
          title: Text(
            section["title"],
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            "${section["topics"].length} topics",
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
            ),
          ),
          iconColor: AppColors.primaryDark,
          collapsedIconColor: Colors.grey.shade500,
          children: (section["topics"] as List).map<Widget>((topic) {
            return InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topic,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
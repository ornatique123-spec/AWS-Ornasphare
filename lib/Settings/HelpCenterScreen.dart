import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Extra/AppColors.dart';
import 'ContactUsScreen.dart'; // 👈 tamara path pramane adjust karo

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String searchQuery = "";
  String selectedCategory = "All";
  final TextEditingController searchController = TextEditingController();

  final List<String> categories = [
    "All",
    "Account",
    "Voucher",
    "Buch",
    "Billing",
  ];

  /// 🔥 TAMARA ACTUAL FAQ DATA AHIYA NAKHO
  final List<Map<String, dynamic>> faqs = [
    {
      "question": "How do I reset my password?",
      "answer":
      "Go to Settings > Change Password, enter your current password and set a new one. You'll receive a confirmation once updated.",
      "category": "Account",
    },
    {
      "question": "How do I create a new Vacuum Voucher?",
      "answer":
      "Navigate to Voucher History screen and tap on '+ Create Vacuum Voucher'. Fill in the worker, process, date, and item details, then tap Save.",
      "category": "Voucher",
    },
    {
      "question": "Can I edit a voucher after creating it?",
      "answer":
      "Yes, open the voucher from Voucher History and tap the edit icon. Note that some fields may be locked once the process has started.",
      "category": "Voucher",
    },
    {
      "question": "How do I add multiple Buch entries at once?",
      "answer":
      "On the Create Buch screen, tap '+ Add Row' to add more entries, fill in Buch No, Size and Weight for each row, then tap Save.",
      "category": "Buch",
    },
    {
      "question": "Why can't I select an already used Buch number?",
      "answer":
      "Each Buch number can only be assigned once per voucher to avoid duplication. Once selected in one row, it's removed from other row options.",
      "category": "Buch",
    },
    {
      "question": "What subscription plans are available?",
      "answer":
      "We offer Free, Basic, and Premium plans with varying user limits and features. Check Settings > Company Profile for your current plan.",
      "category": "Billing",
    },
    {
      "question": "How do I update my company profile?",
      "answer":
      "Go to Settings > Company Profile to update your company name, address, GST details, and logo.",
      "category": "Account",
    },
  ];

  List<Map<String, dynamic>> get filteredFaqs {
    return faqs.where((faq) {
      bool matchesCategory =
          selectedCategory == "All" || faq["category"] == selectedCategory;
      bool matchesSearch = searchQuery.trim().isEmpty ||
          faq["question"]
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          faq["answer"]
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
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
                    _searchField(),
                    const SizedBox(height: 14),
                    _categoryTabs(),
                    const SizedBox(height: 16),

                    _sectionTitle(Icons.quiz_outlined, "FREQUENTLY ASKED QUESTIONS"),
                    const SizedBox(height: 10),

                    filteredFaqs.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.only(top: 30),
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
                      children: List.generate(filteredFaqs.length, (i) {
                        return _faqTile(filteredFaqs[i], i);
                      }),
                    ),

                    const SizedBox(height: 20),

                    _sectionTitle(Icons.support_agent_outlined, "STILL NEED HELP?"),
                    const SizedBox(height: 10),
                    _needHelpCard(),

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
            "Help Center",
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
          hintText: "Search for help...",
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

  /// ✅ CATEGORY TABS
  Widget _categoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          bool isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => selectedCategory = cat);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      AppColors.primaryDark.withOpacity(0.7),
                      AppColors.secondaryDark.withOpacity(0.7),
                    ],
                  )
                      : null,
                  color: isSelected ? null : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                    isSelected ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  /// ✅ FAQ TILE (Expandable)
  Widget _faqTile(Map<String, dynamic> faq, int index) {
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
          childrenPadding:
          const EdgeInsets.fromLTRB(14, 0, 14, 14),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape:
          const RoundedRectangleBorder(side: BorderSide.none),
          iconColor: AppColors.primaryDark,
          collapsedIconColor: Colors.grey.shade500,
          title: Text(
            faq["question"],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq["answer"],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ NEED HELP CARD (Contact Support fallback)
  Widget _needHelpCard() {
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
                  Icons.headset_mic_outlined,
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
                      "Didn't find your answer?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Our support team is ready to help you",
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContactUsScreen(),
                ),
              );
            },
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
                    Icons.contact_support_outlined,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Contact Support",
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
}
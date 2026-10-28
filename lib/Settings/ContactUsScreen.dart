import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Extra/AppColors.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  /// 🔥 TAMARA ACTUAL CONTACT DETAILS AHIYA NAKHO
  static const String phoneNumber = "+91 99258 23290";
  static const String whatsappNumber = "9199258 23290"; // country code + number, no + or spaces
  static const String email = "support@ornasphere.com";
  static const String address =
      "D-22, Ravi Estate Dudheshwar, \nAhmedabad, Gujarat, India";
  static const String website = "www.ornasphere.com";

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _introCard(),
                    const SizedBox(height: 18),

                    _sectionTitle(Icons.contact_phone_outlined, "GET IN TOUCH"),
                    const SizedBox(height: 10),
                    _cardGroup([
                      _contactTile(
                        icon: Icons.call_outlined,
                        title: "Call Us",
                        subtitle: phoneNumber,
                        iconBg: const Color(0xff2ECC71),
                        onTap: () => _launch("tel:$phoneNumber"),
                      ),
                      _contactTile(
                        icon: Icons.chat_outlined,
                        title: "WhatsApp",
                        subtitle: "Chat with our support team",
                        iconBg: const Color(0xff25D366),
                        onTap: () =>
                            _launch("https://wa.me/$whatsappNumber"),
                      ),
                      _contactTile(
                        icon: Icons.email_outlined,
                        title: "Email Us",
                        subtitle: email,
                        iconBg: const Color(0xff3B82F6),
                        onTap: () => _launch("mailto:$email"),
                        isLast: true,
                      ),
                    ]),

                    const SizedBox(height: 18),

                    _sectionTitle(Icons.location_on_outlined, "OFFICE ADDRESS"),
                    const SizedBox(height: 10),
                    _addressCard(),

                    const SizedBox(height: 18),

                    _sectionTitle(Icons.access_time_outlined, "WORKING HOURS"),
                    const SizedBox(height: 10),
                    _workingHoursCard(),

                    const SizedBox(height: 18),

                    _sectionTitle(Icons.share_outlined, "FOLLOW US"),
                    const SizedBox(height: 10),
                    _socialRow(),

                    const SizedBox(height: 24),
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
  Widget _header(BuildContext context) {
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
            "Contact Us",
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

  /// ✅ INTRO CARD
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.support_agent_outlined,
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
                  "We're here to help",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Reach out to us anytime, we'd love to hear from you",
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

  /// ✅ CONTACT TILE (Call / WhatsApp / Email)
  Widget _contactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required VoidCallback onTap,
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
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconBg.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconBg, size: 19),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
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

  /// ✅ ADDRESS CARD
  Widget _addressCard() {
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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.location_on_outlined,
              color: AppColors.primaryDark,
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Head Office",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _launch(
                    "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}",
                  ),
                  child: Text(
                    "View on Map",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ WORKING HOURS CARD
  Widget _workingHoursCard() {
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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _hourRow("Monday - Saturday", "9:30 AM - 7:00 PM"),
          Divider(height: 18, color: AppColors.border),
          _hourRow("Sunday", "Closed"),
        ],
      ),
    );
  }

  Widget _hourRow(String day, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(
            fontSize: 13.5,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: time == "Closed" ? Colors.red : AppColors.primaryDark,
          ),
        ),
      ],
    );
  }

  /// ✅ SOCIAL MEDIA ROW
  Widget _socialRow() {
    List<Map<String, dynamic>> socials = [
      {"icon": Icons.facebook, "color": const Color(0xff1877F2), "url": "https://facebook.com"},
      {"icon": Icons.camera_alt_outlined, "color": const Color(0xffE1306C), "url": "https://instagram.com"},
      {"icon": Icons.play_arrow_rounded, "color": const Color(0xffFF0000), "url": "https://youtube.com"},
      {"icon": Icons.language, "color": AppColors.primaryDark, "url": "https://$website"},
    ];

    return Row(
      children: socials.map((s) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () => _launch(s["url"]),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: (s["color"] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (s["color"] as Color).withOpacity(0.3),
                ),
              ),
              child: Icon(
                s["icon"],
                color: s["color"],
                size: 22,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
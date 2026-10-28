import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Extra/AppColors.dart';

class VideoTutorialsScreen extends StatefulWidget {
  const VideoTutorialsScreen({super.key});

  @override
  State<VideoTutorialsScreen> createState() => _VideoTutorialsScreenState();
}

class _VideoTutorialsScreenState extends State<VideoTutorialsScreen> {
  String selectedCategory = "All";

  final List<String> categories = [
    "All",
    "Getting Started",
    "Voucher",
    "Buch",
    "Reports",
  ];

  /// 🔥 TAMARA ACTUAL VIDEO DATA AHIYA NAKHO (title, duration, category, thumbnail, url)
  final List<Map<String, dynamic>> videos = [
    {
      "title": "Getting Started with the App",
      "duration": "3:45",
      "category": "Getting Started",
      "thumbnail": "assets/static/tutorial1.png",
      "url": "https://youtube.com/watch?v=xxxxxxx",
    },
    {
      "title": "How to Create a Vacuum Voucher",
      "duration": "5:12",
      "category": "Voucher",
      "thumbnail": "assets/static/tutorial2.png",
      "url": "https://youtube.com/watch?v=xxxxxxx",
    },
    {
      "title": "How to Add Buch Details",
      "duration": "2:58",
      "category": "Buch",
      "thumbnail": "assets/static/tutorial3.png",
      "url": "https://youtube.com/watch?v=xxxxxxx",
    },
    {
      "title": "Understanding Voucher History",
      "duration": "4:20",
      "category": "Voucher",
      "thumbnail": "assets/static/tutorial4.png",
      "url": "https://youtube.com/watch?v=xxxxxxx",
    },
    {
      "title": "Generating Reports",
      "duration": "6:10",
      "category": "Reports",
      "thumbnail": "assets/static/tutorial5.png",
      "url": "https://youtube.com/watch?v=xxxxxxx",
    },
  ];

  List<Map<String, dynamic>> get filteredVideos {
    if (selectedCategory == "All") return videos;
    return videos.where((v) => v["category"] == selectedCategory).toList();
  }

  Future<void> _openVideo(String url) async {
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
            _header(),
            _categoryTabs(),
            Expanded(
              child: filteredVideos.isEmpty
                  ? const Center(
                child: Text(
                  "No Videos Found",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              )
                  : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                child: Column(
                  children: filteredVideos
                      .map((video) => _videoCard(video))
                      .toList(),
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
            "Video Tutorials",
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

  /// ✅ CATEGORY TABS (horizontal chips)
  Widget _categoryTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.border,
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
      ),
    );
  }

  /// ✅ VIDEO CARD
  Widget _videoCard(Map<String, dynamic> video) {
    return InkWell(
      onTap: () => _openVideo(video["url"]),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
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
          children: [
            /// 🔥 Thumbnail with Play Button Overlay
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: Container(
                    height: 80,
                    width: 100,
                    color: AppColors.background,
                    child: video["thumbnail"] != null
                        ? Image.asset(
                      video["thumbnail"],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.videocam_outlined,
                        color: Colors.grey.shade400,
                        size: 30,
                      ),
                    )
                        : Icon(
                      Icons.videocam_outlined,
                      color: Colors.grey.shade400,
                      size: 30,
                    ),
                  ),
                ),
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video["duration"] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            /// 🔥 Video Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video["title"] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        video["category"] ?? "",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
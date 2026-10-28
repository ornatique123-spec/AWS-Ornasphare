import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import 'ArViewScreen.dart';
import 'RemoveBackgroundScreen.dart';

class MyImagesScreen extends StatefulWidget {
  const MyImagesScreen({super.key});

  @override
  State<MyImagesScreen> createState() => _MyImagesScreenState();
}

class _MyImagesScreenState extends State<MyImagesScreen> {
  // ૧. ડેટા ટાઇપ સ્પષ્ટ કરો (List<dynamic> અથવા List<Map<String, dynamic>>)
  List<dynamic> images = [];
  List<dynamic> filteredImages = [];

  bool isLoading = false;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  // ૨. ફિલ્ટર ફંક્શનમાં null safety અને ટાઇપિંગ સુધારો
  void filterSearch(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredImages = List.from(images); // ઓરિજિનલ લિસ્ટની કોપી
      } else {
        filteredImages = images.where((item) {
          // 'title' કી ચેક કરો અને તેને String માં ફેરવો
          final String title = (item["title"] ?? "").toString().toLowerCase();
          return title.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  /// 🔥 INIT
  @override
  void initState() {
    super.initState();

    getRemovedImagesList();
  }

  /// 🔥 API LIST CALL
  Future<void> getRemovedImagesList() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await ApiHelper().getRequest(ApiConstants.removebg_list);

      print("LIST RESPONSE => ${response!.data}");

      if (response.statusCode == 200) {
        final data = response.data;

        if (data["success"] == true) {
          setState(() {
            images = data["data"]; // API માંથી આવતો ડેટા
            filteredImages = List.from(images); // શરૂઆતમાં ફિલ્ટર લિસ્ટમાં પણ બધો ડેટા
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("ERROR => $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 🔥 IMAGE URL PARSER — FIXES "images not showing" BUG
  /// API sometimes returns a real JSON array (["url"]), and sometimes a
  /// value that only *looks* like one (a plain string containing the
  /// brackets/quotes, e.g. "[\"url\"]" or "[url]"). Both used to break
  /// `Image.network` silently. This normalises either shape into a clean
  /// list of real, loadable URLs.
  List<String> _extractUrls(dynamic raw) {
    if (raw == null) return [];

    if (raw is List) {
      return raw
          .map((e) => _cleanUrl(e.toString()))
          .where((u) => u.isNotEmpty)
          .toList();
    }

    if (raw is String) {
      final trimmed = raw.trim();

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => _cleanUrl(e.toString()))
                .where((u) => u.isNotEmpty)
                .toList();
          }
        } catch (_) {
          // not valid JSON — fall through and clean it manually
        }
      }

      final cleaned = _cleanUrl(trimmed);
      return cleaned.isEmpty ? [] : [cleaned];
    }

    return [];
  }

  /// 🔥 Strips stray brackets/quotes/whitespace that break Image.network
  String _cleanUrl(String raw) {
    return raw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    /// 🔥 RESPONSIVE
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      //backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            /// 🔥 BACKGROUND
            // Container(
            //   decoration: const BoxDecoration(
            //     image: DecorationImage(
            //       image: AssetImage("assets/static/img_3.png"),
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // ),

            /// 🔥 MAIN UI
            Column(
              children: [
                SizedBox(height: height * 0.09),

                /// 🔥 SEARCH
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.03),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xffBBDEFB),
                            ),
                          ),
                          child: TextField(
                            controller: searchController,
                            onChanged: (value) => filterSearch(value),
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: width * 0.034,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              hintText: "Search images...",
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: width * 0.032,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xff1976D2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: width * 0.03),
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff64B5F6),
                              Color(0xff1976D2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: height * 0.02),

                /// 🔥 IMAGE LIST
                Expanded(
                  child: isLoading
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : filteredImages.isEmpty
                      ? Center(
                    child: Text(
                      "No Images Found",
                      style: GoogleFonts.poppins(
                        fontSize: width * 0.035,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.03,
                    ),
                    itemCount: filteredImages.length,
                    itemBuilder: (context, index) {
                      final item = filteredImages[index];

                      /// 🔥 SAFE URL PARSING (fixes missing images)
                      final List<String> originalList =
                      _extractUrls(item["original_image_url"]);
                      final List<String> removedList =
                      _extractUrls(item["removed_image_url"]);

                      final int pairCount =
                      originalList.length < removedList.length
                          ? originalList.length
                          : removedList.length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xffBBDEFB)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            /// 🔝 TOP SECTION: Title and Delete Icon
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                /// 🏷️ TITLE
                                Expanded(
                                  child: Text(
                                    item["title"] ?? "Untitled Image",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: const Color(0xff0D3B66),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// ✏️ EDIT ICON
                                GestureDetector(
                                  onTap: () {
                                    // અહીં તમારી એડિટ કરવાની મેથડ કોલ કરો
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffE3F2FD),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Color(0xff1976D2),
                                      size: 18,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                /// 🗑️ DELETE ICON
                                GestureDetector(
                                  onTap: () =>
                                      deleteImage(item["id"]),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffFFE2E2),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(
                                height: 1, color: Color(0xffBBDEFB)),
                            const SizedBox(height: 12),

                            /// 🖼️ IMAGES LIST (Vertical)
                            pairCount == 0
                                ? Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                  vertical: 8),
                              child: Text(
                                "Image not available",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                                : Column(
                              children: List.generate(
                                  pairCount, (imgIndex) {
                                final String
                                currentOriginalImg =
                                originalList[imgIndex];
                                final String
                                currentRemovedImg =
                                removedList[imgIndex];

                                return Padding(
                                  padding: const EdgeInsets
                                      .only(bottom: 15),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .center,
                                    children: [
                                      // Original Image with Label
                                      Expanded(
                                        child: Column(
                                          children: [
                                            imagePreviewCard(
                                                "Original",
                                                currentOriginalImg,
                                                width,
                                                height * 0.18),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Removed BG Image with Label
                                      Expanded(
                                        child: Column(
                                          children: [
                                            imagePreviewCard(
                                                "Removed BG",
                                                currentRemovedImg,
                                                width,
                                                height * 0.18),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 12),

                                      // 🔥 Sidebar Icons (Download & Edit)
                                      buildActionIcons(
                                          item,
                                          currentRemovedImg,
                                          imgIndex,
                                          isSmall: true),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                /// 🔥 PREMIUM BANNER
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.04,
                    vertical: height * 0.018,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xffE3F2FD),
                        Color(0xffBBDEFB),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xffBBDEFB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xff64B5F6),
                              Color(0xff1976D2),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: width * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Premium Feature",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: width * 0.035,
                                color: const Color(0xff0D3B66),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Unlimited background removal with premium quality",
                              style: GoogleFonts.poppins(
                                fontSize: width * 0.028,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: width * 0.03,
                          vertical: height * 0.015,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff64B5F6),
                              Color(0xff1976D2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "Go Premium",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: width * 0.03,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            /// 🔥 APPBAR
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: height * 0.02,
                  left: width * 0.04,
                  right: width * 0.04,
                  bottom: height * 0.015,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      "My Images",
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: width * 0.06,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      /// 🔥 BOTTOM BUTTON
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            width * 0.04,
            10,
            width * 0.04,
            15,
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RemoveBackgroundScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff64B5F6),
                    Color(0xff1976D2),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff1976D2).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: width * 0.03),
                  Text(
                    "Upload Image",
                    style: GoogleFonts.poppins(
                      fontSize: width * 0.04,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget actionIconButton(
      IconData icon,
      Color bgColor,
      Color iconColor,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor,
        ),
      ),
    );
  }

  Widget imagePreviewCard(
      String title,
      String imageUrl,
      double width,
      double height,
      ) {
    return Container(
      width: width * 0.35,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// 🔥 IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: imageUrl.isEmpty
                ? Container(
              height: height * 0.14,
              color: Colors.grey.shade100,
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                ),
              ),
            )
                : Image.network(
              imageUrl,
              height: height * 0.7,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: height * 0.14,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return SizedBox(
                  height: height * 0.14,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            ),
          ),

          /// 🔥 TITLE
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: height * 0.01,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff64B5F6),
                  Color(0xff1976D2),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: width * 0.03,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 DELETE IMAGE API
  Future<void> deleteImage(int id) async {
    try {
      /// 🔥 LOADER
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.delete_removebg_image}/$id",
      );

      Navigator.pop(context);

      print("DELETE RESPONSE => ${response?.data}");

      if (response != null && response.statusCode == 200) {
        final data = response.data;

        if (data["success"] == true) {
          /// 🔥 REMOVE FROM LIST
          setState(() {
            images.removeWhere((item) => item["id"] == id);
          });

          getRemovedImagesList();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data["message"] ?? "Deleted Successfully",
              ),
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);

      print("DELETE ERROR => $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong"),
        ),
      );
    }
  }

  Future<void> deletesingleImage(
      Map<String, dynamic> item, int imgIndex) async {
    // અત્યારે કેટલી ઈમેજ છે તે ચેક કરો
    final List imagesList = item["removed_image_url"] ?? [];

    // 🔥 જો લિસ્ટમાં માત્ર ૧ જ ઈમેજ બાકી હોય અને તેને પણ ડીલીટ કરવાની હોય
    // તો આખું કાર્ડ ડીલીટ કરવા માટે deleteImage કોલ કરો
    if (imagesList.length <= 1) {
      deleteImage(item["id"]); // આખા રેકોર્ડને ડીલીટ કરવાની API
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(child: CircularProgressIndicator()),
      );

      // સિંગલ ઈમેજ ડીલીટ કરવાની બોડી
      Map<String, dynamic> body = {
        "remove_images": [imgIndex],
      };

      final response = await ApiHelper().postRequest(
        "${ApiConstants.deletesingle_removebg_image}/${item["id"]}",
        body,
      );

      if (Navigator.canPop(context)) Navigator.pop(context);

      if (response != null && response.statusCode == 200) {
        if (response.data["success"] == true) {
          getRemovedImagesList(); // લિસ્ટ રિફ્રેશ કરો
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      print("SINGLE DELETE ERROR => $e");
    }
  }

  /// 🔥 DOWNLOAD IMAGE
  Future<void> downloadImage(String imageUrl) async {
    try {
      // સાફ કરો URL (બ્રેકેટ્સ કે વધારાના કેરેક્ટર હોય તો હટાવવા માટે)
      String cleanUrl = _cleanUrl(imageUrl);

      if (cleanUrl.isEmpty || cleanUrl == "null") return;

      await Permission.storage.request();
      await Permission.photos.request();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(child: CircularProgressIndicator()),
      );

      final dir = await getTemporaryDirectory();
      final filePath =
          "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png";

      // સિંગલ ડાઉનલોડ
      await Dio().download(cleanUrl, filePath);
      await GallerySaver.saveImage(filePath);

      Navigator.pop(context); // Loader off

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image saved to gallery")),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      print("DOWNLOAD ERROR => $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download failed")),
      );
    }
  }

  // buildActionIcons માં imageUrl પેરામીટર ઉમેરો
  Widget buildActionIcons(
      Map<String, dynamic> item, String singleImageUrl, int imgIndex,
      {bool isSmall = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        actionIconButton(
          Icons.edit,
          const Color(0xffE3F2FD),
          const Color(0xff1976D2),
              () {},
        ),
        const SizedBox(height: 8),
        actionIconButton(
          Icons.delete_outline,
          const Color(0xffFFE2E2),
          Colors.red,
              () => deletesingleImage(item, imgIndex),
        ),
        const SizedBox(height: 8),
        actionIconButton(
          Icons.download,
          const Color(0xffDDF7E4),
          Colors.green,
          // 🔥 અહીં આખું લિસ્ટ મોકલવાને બદલે માત્ર સિંગલ URL મોકલો
              () => downloadImage(singleImageUrl),
        ),
      ],
    );
  }
}
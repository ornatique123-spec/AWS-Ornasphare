import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pecifician_sysytem/Dashboard/HomeScreen.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import 'MyImagesScreen.dart';

class RemoveBackgroundScreen extends StatefulWidget {
  const RemoveBackgroundScreen({super.key});

  @override
  State<RemoveBackgroundScreen> createState() => _RemoveBackgroundScreenState();
}

class _RemoveBackgroundScreenState extends State<RemoveBackgroundScreen> {
  File? selectedImage;

  final ImagePicker picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });

      /// 🔥 HERE API CALL KARSO
      /// background remove api
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F3EE),

      body: SafeArea(
        child: Stack(
          children: [
            /// 🔥 TOP DESIGN
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/static/img_3.png"),
                  fit: BoxFit.fill,
                ),
              ),
            ),

            /// MAIN UI
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),

                  /// 🔥 TITLE
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Upload an image and get a transparent background",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// 🔥 UPLOAD CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: const Color(0xffF4EFE8),

                      borderRadius: BorderRadius.circular(20),

                      border: Border.all(color: const Color(0xffE4D2B0)),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),

                    child: Column(
                      children: [
                        /// IMAGE AREA
                        Container(
                          height: 240,
                          width: double.infinity,

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),

                            // border: Border.all(
                            //   color: const Color(0xffD8B06B),
                            //   style: BorderStyle.solid,
                            // ),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.9),
                                const Color(0xffEFE6D9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),

                          child: selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),

                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: const Color(0xffD4A954),
                                        ),
                                      ),

                                      child: const Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 48,
                                        color: Color(0xffD4A954),
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    Text(
                                      "Upload Image",
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xff2B2B2B),
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Text(
                                      "PNG, JPG up to 10MB",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(18),

                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 24),

                        /// OR
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade400),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),

                              child: Text(
                                "OR",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Divider(color: Colors.grey.shade400),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        /// BUTTON
                        InkWell(
                          onTap: () {
                            pickImageOption();
                          },

                          borderRadius: BorderRadius.circular(14),

                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),

                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xffE8C67A), Color(0xffC89A3D)],
                              ),

                              borderRadius: BorderRadius.circular(14),

                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xffC89A3D,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),

                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.black,
                                ),

                                const SizedBox(width: 10),

                                Text(
                                  "Choose from Gallery",
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// FEATURES
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 18,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),

                      borderRadius: BorderRadius.circular(18),

                      border: Border.all(color: Colors.grey.shade200),
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,

                      children: [
                        featureItem(
                          Icons.auto_awesome,
                          "AI Powered",
                          "Advanced AI Technology",
                        ),

                        featureItem(
                          Icons.verified,
                          "High Quality",
                          "Perfect cutout results",
                        ),

                        featureItem(
                          Icons.security,
                          "Secure",
                          "Your images are safe",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  /// PREMIUM TAG
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),

                        border: Border.all(color: const Color(0xffE4D2B0)),
                      ),

                      child: Text(
                        "✨ Premium quality • Fast Processing • 100% Secure",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xffB88A2E),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            /// ✅ APPBAR (OVERLAY)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  top: 30,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    /// ✅ CENTER TITLE
                    Text(
                      "Remove Background",
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),

                    /// ✅ LEFT BACK ICON
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
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
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
    );
  }

  Widget featureItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),

          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xffE8C67A), Color(0xffC89A3D)],
            ),
          ),

          child: Icon(icon, color: Colors.white, size: 22),
        ),

        const SizedBox(height: 10),

        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: const Color(0xff2B2B2B),
          ),
        ),

        const SizedBox(height: 4),

        SizedBox(
          width: 80,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> pickImageOption() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),

      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// TOP LINE
              Container(
                width: 60,
                height: 5,

                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 25),

              Text(
                "Select Image",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 25),

              Row(
                children: [
                  /// CAMERA
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);

                        final XFile? image = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 100,
                        );

                        if (image != null) {
                          setState(() {
                            selectedImage = File(image.path);
                          });
                        }
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),

                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffE8C67A), Color(0xffC89A3D)],
                          ),

                          borderRadius: BorderRadius.circular(18),
                        ),

                        child: Column(
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                              size: 34,
                            ),

                            const SizedBox(height: 10),

                            Text(
                              "Camera",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 15),

                  /// GALLERY
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);

                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 100,
                        );

                        if (image != null) {
                          setState(() {
                            selectedImage = File(image.path);
                          });
                        }

                        uploadImageToApi();
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),

                        decoration: BoxDecoration(
                          color: const Color(0xffF4EFE8),

                          borderRadius: BorderRadius.circular(18),

                          border: Border.all(color: const Color(0xffE4D2B0)),
                        ),

                        child: Column(
                          children: [
                            const Icon(
                              Icons.photo_library,
                              color: Color(0xffC89A3D),
                              size: 34,
                            ),

                            const SizedBox(height: 10),

                            Text(
                              "Gallery",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff2B2B2B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),
            ],
          ),
        );
      },
    );
  }

  Future<void> uploadImageToApi() async {
    if (selectedImage == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xffC89A3D)),
        ),
      );

      FormData formData = FormData.fromMap({
        "image_name": "IMG_${DateTime.now().millisecondsSinceEpoch}",
        "image[]": [
          await MultipartFile.fromFile(
            selectedImage!.path,
            filename: selectedImage!.path.split('/').last,
          ),
        ],
      });

      // final response = await ApiHelper().postFormData(
      //   "https://development.ornatique.co/public/api/store",
      //   formData,
      // );
      final response = await ApiHelper()
          .postFormData(ApiConstants.upload_removebg_image, formData);

      if (Navigator.canPop(context)) Navigator.pop(context);

      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        final responseData = response.data;

        if (responseData["success"] == true) {
          String message = responseData["message"] ?? "Success";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            selectedImage = null;
          });

          // 🔥 સુધારો: MyImagesScreen પર રિડાયરેક્ટ કરો
          // pushReplacement વાપરવાથી યુઝર બેક બટન દબાવશે તો ફરી અપલોડ પેજ પર નહીં આવે
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyImagesScreen()),
          );

        } else {
          String errorMsg = responseData["message"] ?? "Upload failed";
          _showErrorSnackBar(errorMsg);
        }
      } else {
        _showErrorSnackBar("Server Error: ${response?.statusCode}");
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      print("UPLOAD ERROR => $e");
      _showErrorSnackBar("Something went wrong!");
    }
  }

// એરર મેસેજ બતાવવા માટે હેલ્પર
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

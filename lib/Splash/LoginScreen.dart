import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isLoading = false;

  Map<String, String>? cachedDeviceDetails;
  Map<String, dynamic>? cachedLocation;

  Future<void>? loginMetaFuture;

  @override
  void initState() {
    super.initState();
    emailController.text = "";
    passwordController.text = "";
  }

  Future<void> prepareLoginMeta() async {
    try {
      final results = await Future.wait([
        getDeviceDetails(),
        getCurrentLocation(),
      ]);

      cachedDeviceDetails = results[0] as Map<String, String>;
      cachedLocation = results[1] as Map<String, dynamic>;

      debugPrint(
        "LOGIN META READY => Device: $cachedDeviceDetails Location: $cachedLocation",
      );
    } catch (e) {
      debugPrint("Prepare Login Meta Error => $e");
    }
  }

  void loginUser() {
    setState(() {
      isLoading = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });
      FocusManager.instance.primaryFocus?.unfocus();
      login_Api();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double topHeight = MediaQuery.of(context).size.height * 0.34;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            /// ==========================================================
            /// 🔵 PREMIUM CURVED HEADER
            /// ==========================================================
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipPath(
                  clipper: _HeaderCurveClipper(),
                  child: Container(
                    height: topHeight,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gradientBlue,
                          AppColors.secondaryDark,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        /// Decorative soft circles for depth
                        Positioned(
                          top: -40,
                          right: -30,
                          child: Container(
                            height: 140,
                            width: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white.withOpacity(0.06),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 60,
                          left: -40,
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white.withOpacity(0.05),
                            ),
                          ),
                        ),

                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30,left: 10),
                            child: Column(
                              children: [
                                Container(
                                  height: 72,
                                  width: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.secondaryDark
                                            .withOpacity(0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: AppColors.iconBlue,
                                    size: 34,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                const Text(
                                  "Pacifican",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppColors.white,
                                  ),
                                ),

                                const SizedBox(height: 0),

                                Text(
                                  "Sign in to your account",
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                    color: AppColors.white.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            /// ==========================================================
            /// 🔵 FLOATING LOGIN CARD (overlaps the header)
            /// ==========================================================
            Transform.translate(
              offset: const Offset(0, -50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome back 👋",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Enter your credentials to continue",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 26),

                      /// Email
                      _buildLabel("Email Address"),
                      const SizedBox(height: 8),
                      _premiumField(
                        controller: emailController,
                        hint: "you@example.com",
                        icon: Icons.email_outlined,
                      ),

                      const SizedBox(height: 18),

                      /// Password
                      _buildLabel("Password"),
                      const SizedBox(height: 8),
                      _premiumField(
                        controller: passwordController,
                        hint: "••••••••",
                        icon: Icons.lock_outline,
                        obscure: isPasswordHidden,
                        suffix: IconButton(
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordHidden = !isPasswordHidden;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: AppColors.iconBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      /// 🔵 Premium Login Button
                      _premiumButton(
                        label: "LOGIN",
                        icon: Icons.login_rounded,
                        onTap: isLoading ? null : loginUser,
                        loading: isLoading,
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 1,
                            width: 40,
                            color: AppColors.border,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "Secure Access",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            width: 40,
                            color: AppColors.border,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Small field label used above every input
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Reusable premium-styled input field
  Widget _premiumField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.iconBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.iconBlue, size: 20),
          suffixIcon: suffix,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// Reusable premium gradient button with loading state
  Widget _premiumButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryDark.withOpacity(0.35),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gradientBlue,
              AppColors.secondaryDark,
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Center(
              child: loading
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.white,
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

  Future<Map<String, String>> getDeviceDetails() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    String deviceId = "";
    String deviceName = "";
    String platform = "";
    String appVersion = "1.0.0";

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (e) {
      debugPrint("PackageInfo Error: $e");
    }

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
        platform = "android";
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "";
        deviceName = iosInfo.name;
        platform = "ios";
      }
    } catch (e) {
      debugPrint("DeviceInfo Error: $e");
    }

    final data = {
      "device_id": deviceId,
      "device_name": deviceName,
      "platform": platform,
      "app_version": appVersion,
    };

    debugPrint("DEVICE DETAILS => $data");

    return data;
  }

  Future<void> login_Api() async {
    try {
      final body = {
        "email": emailController.text.trim(),
        "password": passwordController.text.trim(),
      };

      debugPrint("Login Request: $body");
      debugPrint("Login API URL: ${ApiConstants.login}");

      final response = await ApiHelper().postRequest(ApiConstants.login, body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;
      debugPrint("Login Response: $data");

      // 🚫 USER INACTIVE
      if (data["code"] == "USER_INACTIVE" ||
          data["message"] == "User inactive") {
        await AppDialog.showInactiveDialog(
          data["message"] ??
              "Your account has been deactivated. Please contact your company admin.",
          logout: false,
        );
        return;
      }

      // ✅ SUCCESS
      if (response.statusCode == 200) {
        if (data['otp_required'] == true) {
          /// Device + location background ma atyarthi j fetch karo
          loginMetaFuture = prepareLoginMeta();
          showOtpDialog(data['user_id']);
        } else {
          // Normal login flow
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', data['user_id'].toString());
          await prefs.setString('token', data['token']);

          ApiHelper().setBearerToken(data['token']);

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }
      }

      // 🔴 INVALID CREDENTIALS
      else if (response.statusCode == 401) {
        showError(data['message'] ?? "Invalid credentials");
      }

      // 🔴 VALIDATION ERROR
      else if (response.statusCode == 422) {
        String errorMessage = "";

        if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];
          errors.forEach((key, value) {
            errorMessage += "${value[0]}\n";
          });
        } else {
          errorMessage = data['message'] ?? "Validation error";
        }

        showError(errorMessage);
      }

      // 🔴 OTHER ERRORS
      else {
        showError(data['message'] ?? "Server error (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Login Exception: $e");
      showError("Something went wrong. Please try again.");
    }
  }

  void showError(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? "Something went wrong"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void showOtpDialog(int userId) {
    TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: AppColors.cardBackground,
          title: Column(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.iconBg,
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  color: AppColors.iconBlue,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "OTP Verification",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter the 6 digit OTP sent to you",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  cursorColor: AppColors.primaryDark,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                  decoration: const InputDecoration(
                    hintText: "------",
                    hintStyle: TextStyle(color: AppColors.textLight),
                    counterText: "",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              _premiumButton(
                label: "VERIFY OTP",
                icon: Icons.verified_rounded,
                loading: isLoading,
                onTap: () {
                  if (otpController.text.length == 6) {
                    verifyOtpApi(userId, otpController.text);
                  } else {
                    showError("Enter valid 6 digit OTP");
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> verifyOtpApi(int userId, String otp) async {
    try {
      /// 🔥 API call start thai etle tarat j keyboard unfocus
      /// ane 1 second loading dekhado
      FocusManager.instance.primaryFocus?.unfocus();

      setState(() {
        isLoading = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      /// =====================================================
      /// PRE-FETCHED DATA COMPLETE THAVA DO
      /// Usually user OTP enter kare tya sudhi ready hase
      /// =====================================================
      if (loginMetaFuture != null) {
        await loginMetaFuture;
      }

      /// Cached data
      final deviceDetails = cachedDeviceDetails ??
          <String, String>{
            "device_id": "",
            "device_name": "",
            "platform": "",
            "app_version": "",
          };

      final location = cachedLocation ??
          <String, dynamic>{
            "latitude": null,
            "longitude": null,
          };

      final body = {
        "user_id": userId,
        "otp": otp,
        "device_id": deviceDetails["device_id"],
        "device_name": deviceDetails["device_name"],
        "platform": deviceDetails["platform"],
        "app_version": deviceDetails["app_version"],
        "latitude": location["latitude"],
        "longitude": location["longitude"],
      };

      debugPrint("VERIFY OTP BODY => $body");

      final response =
      await ApiHelper().postRequest(ApiConstants.verify_otp, body);

      if (response == null) {
        showError("No response from server");
        return;
      }

      final data = response.data;

      if (response.statusCode == 200) {
        if (!mounted) return;

        final SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('user_id', userId.toString());
        await prefs.setString('token', data['token'].toString());

        ApiHelper().setBearerToken(data['token'].toString());

        /// ===================================================
        /// FINGERPRINT
        /// ===================================================
        final bool fingerprintEnabled =
            prefs.getBool("fingerprint_enabled") ?? false;

        if (fingerprintEnabled) {
          final auth = LocalAuthentication();

          try {
            final success = await auth.authenticate(
              localizedReason: "Verify fingerprint to continue",
              options: const AuthenticationOptions(
                biometricOnly: true,
                stickyAuth: true,
                useErrorDialogs: true,
              ),
            );

            if (!success) {
              return;
            }
          } catch (e) {
            showError("Fingerprint authentication failed.");
            return;
          }
        }

        if (!mounted) return;

        Navigator.pop(context); // OTP dialog band karo

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        showError(data['message'] ?? "Invalid OTP");
      }
    } catch (e) {
      debugPrint("VERIFY OTP ERROR => $e");
      showError("Something went wrong. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      /// Location service ON che?
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return {"latitude": null, "longitude": null};
      }

      /// Permission check
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      /// Permission deny
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return {"latitude": null, "longitude": null};
      }

      /// Current location
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return {
        "latitude": position.latitude,
        "longitude": position.longitude,
      };
    } catch (e) {
      debugPrint("Location Error => $e");
      return {"latitude": null, "longitude": null};
    }
  }
}

/// Custom clipper for the smooth curved bottom edge of the header banner.
/// Uses a cubic bezier (instead of a single quadratic dip) so the curve
/// eases in and out smoothly on both sides instead of forming a sharp "V".
class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double dip = size.height * 0.12; // how deep the curve dips

    final path = Path();
    path.lineTo(0, size.height - dip);

    path.cubicTo(
      size.width * 0.28, size.height, // left control point — eases down
      size.width * 0.72, size.height, // right control point — eases back up
      size.width, size.height - dip,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
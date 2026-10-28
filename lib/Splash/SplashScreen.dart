import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import 'LoginScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? userId;

  /// Splash image
  static const String _splashImage = "assets/static/img_8.png";

  @override
  void initState() {
    super.initState();

    /// ============================================
    /// PREF CHECK
    /// ============================================
    checkPref();

    /// ============================================
    /// SPLASH DELAY
    /// NO ANIMATION
    /// ============================================
    Timer(
      const Duration(seconds: 1),
          () {
        if (!mounted) return;

        navigateNext();
      },
    );
  }

  /// Image pehla thi memory ma — splash par flicker na thay
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_splashImage), context);
  }

  /// =========================================================
  /// CHECK PREF
  /// =========================================================
  Future<void> checkPref() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    userId = prefs.getString("user_id");

    /// Existing functionality
    await prefs.remove("firstTimePopup");
  }

  /// =========================================================
  /// NAVIGATE NEXT
  /// =========================================================
  Future<void> navigateNext() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? userId = prefs.getString("user_id");

    final String? token = prefs.getString("token");

    final bool fingerprintEnabled =
        prefs.getBool("fingerprint_enabled") ?? false;

    if (!mounted) return;

    /// =========================================================
    /// USER NOT LOGGED IN
    /// =========================================================
    if (userId == null ||
        userId.isEmpty ||
        token == null ||
        token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );

      return;
    }

    /// =========================================================
    /// SET BEARER TOKEN
    /// =========================================================
    ApiHelper().setBearerToken(token);

    /// =========================================================
    /// FINGERPRINT DISABLED
    /// DIRECT HOME
    /// =========================================================
    if (!fingerprintEnabled) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
            (Route<dynamic> route) => false,
      );

      return;
    }

    /// =========================================================
    /// FINGERPRINT ENABLED
    /// =========================================================
    final LocalAuthentication auth = LocalAuthentication();

    try {
      final bool success = await auth.authenticate(
        localizedReason: "Verify your fingerprint",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      /// =======================================================
      /// FINGERPRINT SUCCESS
      /// =======================================================
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
              (Route<dynamic> route) => false,
        );
      }

      /// =======================================================
      /// FINGERPRINT CANCEL / FAILED
      /// =======================================================
      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "BIOMETRIC ERROR => $e",
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  /// =========================================================
  /// UI — RESPONSIVE (phone / tablet / landscape)
  ///
  /// Phone portrait  → cover (aakhi screen)
  /// Tablet / wide   → aakhi image vachche (kapay nahi)
  ///                   + pachhal e j image no blur background
  /// =========================================================
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, box) {
            final double w = box.maxWidth;
            final double h = box.maxHeight;

            /// Phone portrait: nani baju < 600 ane screen ubhi
            final bool isPhonePortrait =
                box.biggest.shortestSide < 600 && h > w;

            /// ---------------------------------------------
            /// PHONE PORTRAIT — pehla jem j full screen
            /// ---------------------------------------------
            if (isPhonePortrait) {
              return SizedBox.expand(
                child: Image.asset(
                  _splashImage,
                  fit: BoxFit.cover,
                ),
              );
            }

            /// ---------------------------------------------
            /// TABLET / LANDSCAPE — kapay nahi
            /// ---------------------------------------------
            return Stack(
              fit: StackFit.expand,
              children: [
                /// Pachhal — e j image, blur
                ClipRect(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Image.asset(
                      _splashImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                /// Halko overlay — aagal ni image uthi ne dekhay
                Container(color: Colors.black.withOpacity(0.08)),

                /// Aagal — aakhi image, koi bhag kapay nahi
                SafeArea(
                  child: Center(
                    child: Image.asset(
                      _splashImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
import 'dart:math';

import 'package:flutter/material.dart';

import '../Extra/AppColors.dart';
import '../main.dart' as NavigationService;

class LoadingService {
  LoadingService._();

  static final LoadingService instance = LoadingService._();

  int _requestCount = 0;
  bool _isShowing = false;

  // ============================================================
  // SHOW LOADER
  // ============================================================

  void show() {
    _requestCount++;

    debugPrint(
      "🔄 LOADER SHOW | requestCount=$_requestCount | showing=$_isShowing",
    );

    // Loader already showing
    if (_isShowing) return;

    final context =
        NavigationService.navigatorKey.currentContext;

    if (context == null) {
      debugPrint("⚠️ LOADER: Navigator context is null");
      return;
    }

    _isShowing = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      barrierLabel: "",
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ==================================================
                    // COMPANY LOGO
                    // ==================================================

                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: 1,
                      ),
                      duration: const Duration(seconds: 2),
                      onEnd: () {},
                      builder: (
                          context,
                          value,
                          child,
                          ) {
                        return Transform.rotate(
                          angle: value * 2 * pi,
                          child: child,
                        );
                      },
                      child: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            "assets/static/img.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 0),

                    const Text(
                      "Please Wait",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (
          _,
          animation,
          __,
          child,
          ) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  // ============================================================
  // HIDE LOADER
  // ============================================================

  void hide() {
    if (_requestCount > 0) {
      _requestCount--;
    }

    debugPrint(
      "🔽 LOADER HIDE | requestCount=$_requestCount | showing=$_isShowing",
    );

    if (_requestCount == 0 && _isShowing) {
      _closeLoader();
    }
  }

  // ============================================================
  // RESET / FORCE HIDE
  // ============================================================

  void reset() {
    debugPrint(
      "🧹 LOADER RESET | oldRequestCount=$_requestCount | showing=$_isShowing",
    );

    // Remove all pending loader requests
    _requestCount = 0;

    if (!_isShowing) {
      return;
    }

    _closeLoader();
  }

  // ============================================================
  // CLOSE LOADER
  // ============================================================

  void _closeLoader() {
    if (!_isShowing) return;

    _isShowing = false;

    final context =
        NavigationService.navigatorKey.currentContext;

    if (context == null) {
      debugPrint(
        "⚠️ LOADER CLOSE: Navigator context is null",
      );
      return;
    }

    try {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      debugPrint("✅ LOADER CLOSED");
    } catch (e) {
      debugPrint(
        "❌ LOADER CLOSE ERROR: $e",
      );
    }
  }

  // ============================================================
  // OPTIONAL DEBUG
  // ============================================================

  int get requestCount => _requestCount;

  bool get isShowing => _isShowing;
}
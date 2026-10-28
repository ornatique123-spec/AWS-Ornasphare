import 'package:flutter/material.dart';

class Responsive {

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) =>
      screenWidth(context) < 600;

  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= 600 && screenWidth(context) < 1024;

  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= 1024;

  static double w(BuildContext context, double size) {
    return size * (screenWidth(context) / 390);
  }

  static double h(BuildContext context, double size) {
    return size * (screenHeight(context) / 844);
  }

  static double font(BuildContext context, double size) {
    double scale = screenWidth(context) / 390;

    if (scale < 0.85) scale = 0.85;
    if (scale > 1.35) scale = 1.35;

    return size * scale;
  }

  static double radius(BuildContext context) {
    return isDesktop(context)
        ? 14
        : isTablet(context)
        ? 12
        : 10;
  }

  static double icon(BuildContext context) {
    return isDesktop(context)
        ? 28
        : isTablet(context)
        ? 24
        : 22;
  }
}
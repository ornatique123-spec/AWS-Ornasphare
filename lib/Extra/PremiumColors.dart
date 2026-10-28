import 'package:flutter/material.dart';

class PremiumColors {
  // 🔹 SELECT COMBINATION BY INDEX (0-9)
  static int selectedTheme = 0;

  // 🔹 DEFINE TOP 10 PREMIUM COLOR COMBINATIONS
  static final List<Map<String, Color>> themes = [
    {
      // 0️⃣ Classic Gold
      "primaryGold": Color(0xFFD4AF37),
      "secondaryGold": Color(0xFFFFE7B2),
      "ivory": Color(0xFFFFF9F0),
      "iconShadow": Color(0xFFD4AF37).withOpacity(0.4),
      "textDark": Color(0xFF4B4B4B),
      "cardBackground": Colors.white,
      "badgeRed": Colors.red,
    },

    {
      "primaryGold": Color(0xFFB9784A),       // Main highlight
      "secondaryGold": Color(0xFFD8C6B8),     // Soft background tone
      "ivory": Color(0xFFF2EDE8),             // Screen bg
      "iconShadow": Color(0xFFC17C4E).withOpacity(0.4),
      "textDark": Color(0xFF313131),          // Text
      "cardBackground": Colors.white,
      "badgeRed": Color(0xFFE53935),
    },

    //0️⃣ Vibrant Orange & Soft Orange
    {
      "primaryGold": Color(0xFFFF6F00),       // Vibrant Orange
      "secondaryGold": Color(0xFFFFCC80),     // Soft Orange
      "ivory": Color(0xFFFFF3E0),             // Warm neutral
      "iconShadow": Color(0xFFFF6F00).withOpacity(0.4),
      "textDark": Color(0xFFE65100),          // Dark Orange text
      "cardBackground": Colors.white,
      "badgeRed": Color(0xFFFF3D00),
    },

// 1️⃣ Teal Green & Mint
    {
      "primaryGold": Color(0xFF004D40),       // Deep Teal
      "secondaryGold": Color(0xFF80CBC4),     // Mint
      "ivory": Color(0xFFE0F2F1),
      "iconShadow": Color(0xFF004D40).withOpacity(0.4),
      "textDark": Color(0xFF00251A),
      "cardBackground": Colors.white,
      "badgeRed": Color(0xFF1DE9B6),
    },

// 2️⃣ Magenta / Plum & Lavender
    {
      "primaryGold": Color(0xFF8E24AA),       // Magenta / Plum
      "secondaryGold": Color(0xFFCE93D8),     // Lavender
      "ivory": Color(0xFFF3E5F5),
      "iconShadow": Color(0xFF8E24AA).withOpacity(0.4),
      "textDark": Color(0xFF4A0072),
      "cardBackground": Colors.white,
      "badgeRed": Color(0xFFD500F9),
    },

// 3️⃣ Charcoal & Slate Grey
    {
      "primaryGold": Color(0xFF263238),       // Charcoal
      "secondaryGold": Color(0xFFB0BEC5),     // Slate Grey
      "ivory": Color(0xFFECEFF1),
      "iconShadow": Color(0xFF263238).withOpacity(0.4),
      "textDark": Color(0xFF000000),
      "cardBackground": Colors.white,
      "badgeRed": Color(0xFFFF5252),
    },

// 4️⃣ Deep Orange / Terracotta & Peach
    {
      "primaryGold": Color(0xFFD84315),       // Deep Orange / Terracotta
      "secondaryGold": Color(0xFFFFAB91),     // Peach
      "ivory": Color(0xFFFFF3E0),
      "iconShadow": Color(0xFFD84315).withOpacity(0.4),
      "textDark": Color(0xFFBF360C),
      "cardBackground": Colors.white,
      "badgeRed": Color(0xFFFF5722),
    },

    {
      "primaryGold": Color(0xFF0A1931),       // Navy Blue
      "secondaryGold": Color(0xFFD4AF37),     // Gold
      "ivory": Color(0xFF162447),
      "iconShadow": Color(0xFFD4AF37).withOpacity(0.5),
      "textDark": Colors.white,
      "cardBackground": Color(0xFF1F4068),
      "badgeRed": Color(0xFFFF4D4D),
    }


  ];

  // 🔹 GETTERS FOR SELECTED THEME
  static Color get primaryGold => themes[selectedTheme]["primaryGold"]!;
  static Color get secondaryGold => themes[selectedTheme]["secondaryGold"]!;
  static Color get ivory => themes[selectedTheme]["ivory"]!;
  static Color get iconShadow => themes[selectedTheme]["iconShadow"]!;
  static Color get textDark => themes[selectedTheme]["textDark"]!;
  static Color get cardBackground => themes[selectedTheme]["cardBackground"]!;
  static Color get badgeRed => themes[selectedTheme]["badgeRed"]!;
}

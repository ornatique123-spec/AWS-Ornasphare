import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import 'JewelleryCaptionComposer.dart';

/// ================================================================
/// 💎 BATCH BACKGROUND TEMPLATES (AI-STYLE)
///
/// - 40+ templates: Studio, Luxury, AI Style, Nature, Festive
/// - Podium par jewellery mukay, mirror floor ma reflection aave,
///   bokeh / mesh gradient / satin / marble / petals / mandala...
/// - Badha code thi j bane (koi asset / internet ni jarur nahi)
/// - Preview ane final share image ek j painter thi bane
///
/// 🔥 HQ:
///  - Jewellery 1:1 size par j mukay (koi resize nahi)
///  - Final JPG quality 97 (pachi caption ma farithi JPG thay che)
///  - Gallery / asset background 2400px sudhi (pehla 1400)
/// ================================================================

enum BgKind {
  solid,
  linear,
  radial,
  spotlight,
  studio,
  marble,
  silk,
  frame,
  image,
  // 🔥 AI-style
  mesh,
  bokeh,
  podium,
  mirror,
  window,
  leaves,
  ripple,
  wood,
  petals,
  mandala,
  glitter,
  satin,
  // 💎 PREMIUM (photo-studio look)
  silkWave,
  glowTable,
  velvet,
  arch,
  goldFoil,
  jewelBox,
  // 👑 ULTRA PREMIUM
  marbleLux,
  stageBeam,
  liquidMetal,
  sparkle,
}

class BgCategory {
  BgCategory._();

  static const String all = "All";
  static const String studio = "Studio";
  static const String luxury = "Luxury";
  static const String ai = "AI Style";
  static const String nature = "Nature";
  static const String festive = "Festive";
  static const String premium = "Premium";

  static const List<String> list = [all, premium, ai, studio, luxury, nature, festive];
}

class BgTemplate {
  const BgTemplate({
    required this.id,
    required this.name,
    required this.kind,
    this.colors = const [],
    this.accent,
    this.assetPath,
    this.filePath,
    this.category = BgCategory.studio,
    this.floorPad = 0,
    this.reflection = false,
    this.dark,
    this.flip = false,
  });

  factory BgTemplate.solid(Color c) => BgTemplate(
    id: "solid_${c.value.toRadixString(16)}",
    name: "",
    kind: BgKind.solid,
    colors: [c],
  );

  factory BgTemplate.asset(String name, String path) => BgTemplate(
    id: "asset_$path",
    name: name,
    kind: BgKind.image,
    assetPath: path,
    category: BgCategory.studio,
  );

  factory BgTemplate.file(String path) => BgTemplate(
    id: "file_$path",
    name: "My Photo",
    kind: BgKind.image,
    filePath: path,
  );

  final String id;
  final String name;
  final BgKind kind;
  final List<Color> colors;
  final Color? accent;
  final String? assetPath;
  final String? filePath;
  final String category;

  /// Jewellery niche vadhu jagya (podium / mirror floor mate)
  /// image ni moti baju na % ma
  final double floorPad;

  /// Mirror floor par jewellery nu pratibimb
  final bool reflection;

  final bool? dark;

  /// Glow table: light on the right side instead of left
  final bool flip;

  bool get isImage => kind == BgKind.image;

  bool get onFloor => floorPad > 0;

  bool get isDark =>
      dark ?? (colors.isNotEmpty && colors.last.computeLuminance() < 0.3);

  String get cacheKey => id;

  @override
  bool operator ==(Object other) => other is BgTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// ================================================================
/// 🎨 READY-MADE COLLECTION
/// ================================================================

class BgLibrary {
  BgLibrary._();

  /// Solid colours (24)
  static const List<Color> colors = [
    Color(0xffFFFFFF), Color(0xffFBF8F1), Color(0xffF5F5F7), Color(0xffECE9E4),
    Color(0xffD9D6D0), Color(0xff9E9A94),
    Color(0xffF3E5C8), Color(0xffEAD7A8), Color(0xffF6E1E3), Color(0xffEBC3CB),
    Color(0xffF4D6C6), Color(0xffC98B6B),
    Color(0xffE6EEF6), Color(0xffD6E4F5), Color(0xffDDEFE7), Color(0xffE8E3F3),
    Color(0xff141414), Color(0xff2A2A2E), Color(0xff14234B), Color(0xff0B3D6B),
    Color(0xff0F3D2E), Color(0xff5A1220), Color(0xff4A1D5C), Color(0xff6B4E16),
  ];

  static const List<BgTemplate> templates = [
    // =====================================================
    // 💎 PREMIUM — flowing silk waves & glowing dark table
    //   (like high-end jewellery photo shoots; centre stays clean)
    //   silkWave colours: [base, highlight, shadow]
    //   glowTable colours: [back wall, table, light, (optional tint)]
    // =====================================================
    // =====================================================
    // 👑 ULTRA PREMIUM — gold-vein marble, stage beam,
    //   liquid metal, diamond sparkle
    // =====================================================
    BgTemplate(
      id: "ux_calacatta_gold",
      name: "Calacatta Gold",
      kind: BgKind.marbleLux,
      category: BgCategory.premium,
      colors: [
        Color(0xffF4F1EB),
        Color(0xff8C8A88),
      ],
      accent: Color(0xffC9A24A),
      dark: false,
    ),
    BgTemplate(
      id: "ux_nero_gold",
      name: "Nero Gold Marble",
      kind: BgKind.marbleLux,
      category: BgCategory.premium,
      colors: [
        Color(0xff141416),
        Color(0xff8A8A90),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "ux_verde_marble",
      name: "Verde Emerald Marble",
      kind: BgKind.marbleLux,
      category: BgCategory.premium,
      colors: [
        Color(0xff0E3B2C),
        Color(0xff6FA58E),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "ux_rosa_marble",
      name: "Rosa Marble",
      kind: BgKind.marbleLux,
      category: BgCategory.premium,
      colors: [
        Color(0xffF1DDD8),
        Color(0xffB48A84),
      ],
      accent: Color(0xffC9A24A),
      dark: false,
    ),
    BgTemplate(
      id: "ux_beam_gold",
      name: "Golden Stage Beam",
      kind: BgKind.stageBeam,
      category: BgCategory.premium,
      colors: [
        Color(0xff0D0C0A),
        Color(0xffF5D38A),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_beam_white",
      name: "White Stage Beam",
      kind: BgKind.stageBeam,
      category: BgCategory.premium,
      colors: [
        Color(0xff0E0F12),
        Color(0xffE8ECF5),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_beam_ruby",
      name: "Ruby Stage Beam",
      kind: BgKind.stageBeam,
      category: BgCategory.premium,
      colors: [
        Color(0xff17060A),
        Color(0xffFF8C9E),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_liquid_gold",
      name: "Liquid Gold",
      kind: BgKind.liquidMetal,
      category: BgCategory.premium,
      colors: [
        Color(0xffB8892F),
        Color(0xffFFF2C2),
        Color(0xff4A3008),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_liquid_rosegold",
      name: "Liquid Rose Gold",
      kind: BgKind.liquidMetal,
      category: BgCategory.premium,
      colors: [
        Color(0xffC98A78),
        Color(0xffFFE6DC),
        Color(0xff5A2C22),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_liquid_silver",
      name: "Liquid Silver",
      kind: BgKind.liquidMetal,
      category: BgCategory.premium,
      colors: [
        Color(0xff8E9098),
        Color(0xffFFFFFF),
        Color(0xff2C2E34),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_diamond_night",
      name: "Diamond Night",
      kind: BgKind.sparkle,
      category: BgCategory.premium,
      colors: [
        Color(0xff0D0E14),
        Color(0xffD8E4FF),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_champagne_sparkle",
      name: "Champagne Sparkle",
      kind: BgKind.sparkle,
      category: BgCategory.premium,
      colors: [
        Color(0xff2A2216),
        Color(0xffF5DCA0),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_sapphire_sparkle",
      name: "Sapphire Sparkle",
      kind: BgKind.sparkle,
      category: BgCategory.premium,
      colors: [
        Color(0xff0A1636),
        Color(0xff8CB4FF),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ux_rose_sparkle",
      name: "Rose Sparkle",
      kind: BgKind.sparkle,
      category: BgCategory.premium,
      colors: [
        Color(0xff2A1218),
        Color(0xffFFB8C6),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_mint_silk",
      name: "Mint Silk",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xff9CC9AE), Color(0xffE8F7EE), Color(0xff4F806A)],
      dark: false,
    ),
    BgTemplate(
      id: "pr_champagne_dune",
      name: "Champagne Dune",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xffDCC9A0), Color(0xffFBF3DE), Color(0xff9C845A)],
      dark: false,
    ),
    BgTemplate(
      id: "pr_ivory_silk",
      name: "Ivory Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xffEDE5D6), Color(0xffFFFFFF), Color(0xffAFA084)],
      dark: false,
    ),
    BgTemplate(
      id: "pr_blush_silk",
      name: "Blush Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xffE9C2C9), Color(0xffFFF1F3), Color(0xffA56C77)],
      dark: false,
    ),
    BgTemplate(
      id: "pr_black_silk",
      name: "Black Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xff1E1E22), Color(0xff7A7A86), Color(0xff000000)],
      dark: true,
    ),
    BgTemplate(
      id: "pr_navy_silk",
      name: "Navy Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xff1C2D57), Color(0xff6680BD), Color(0xff050A1A)],
      dark: true,
    ),
    BgTemplate(
      id: "pr_emerald_silk",
      name: "Emerald Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xff1E6A4F), Color(0xff74C4A0), Color(0xff04241A)],
      dark: true,
    ),
    BgTemplate(
      id: "pr_maroon_silk",
      name: "Maroon Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [Color(0xff6E1A2C), Color(0xffC85A70), Color(0xff26040B)],
      dark: true,
    ),
    BgTemplate(
      id: "pr_velvet_royal",
      name: "Royal Blue Velvet",
      kind: BgKind.velvet,
      category: BgCategory.premium,
      colors: [
        Color(0xff1E3A8A),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_velvet_wine",
      name: "Wine Velvet",
      kind: BgKind.velvet,
      category: BgCategory.premium,
      colors: [
        Color(0xff5E1224),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_velvet_emerald",
      name: "Emerald Velvet",
      kind: BgKind.velvet,
      category: BgCategory.premium,
      colors: [
        Color(0xff0F5A40),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_velvet_black",
      name: "Black Velvet",
      kind: BgKind.velvet,
      category: BgCategory.premium,
      colors: [
        Color(0xff1A1A1E),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_velvet_plum",
      name: "Plum Velvet",
      kind: BgKind.velvet,
      category: BgCategory.premium,
      colors: [
        Color(0xff4A1D5C),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_arch_ivory",
      name: "Ivory Arch",
      kind: BgKind.arch,
      category: BgCategory.premium,
      colors: [
        Color(0xffEFE6D8),
        Color(0xffE6DAC6),
      ],
      accent: Color(0xffC9A24A),
      dark: false,
    ),
    BgTemplate(
      id: "pr_arch_blush",
      name: "Blush Arch",
      kind: BgKind.arch,
      category: BgCategory.premium,
      colors: [
        Color(0xffF3DCDD),
        Color(0xffEBCBCD),
      ],
      accent: Color(0xffB8902E),
      dark: false,
    ),
    BgTemplate(
      id: "pr_arch_sage",
      name: "Sage Arch",
      kind: BgKind.arch,
      category: BgCategory.premium,
      colors: [
        Color(0xffDDE6DA),
        Color(0xffCFDACB),
      ],
      accent: Color(0xffB8902E),
      dark: false,
    ),
    BgTemplate(
      id: "pr_arch_champagne",
      name: "Champagne Arch",
      kind: BgKind.arch,
      category: BgCategory.premium,
      colors: [
        Color(0xffEADBC0),
        Color(0xffE0CDAA),
      ],
      accent: Color(0xffA9822E),
      dark: false,
    ),
    BgTemplate(
      id: "pr_arch_black",
      name: "Black Gold Arch",
      kind: BgKind.arch,
      category: BgCategory.premium,
      colors: [
        Color(0xff1A1A1E),
        Color(0xff121215),
      ],
      accent: Color(0xffC9A24A),
      dark: true,
    ),
    BgTemplate(
      id: "pr_foil_black",
      name: "Black Gold Foil",
      kind: BgKind.goldFoil,
      category: BgCategory.premium,
      colors: [
        Color(0xff111114),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_foil_navy",
      name: "Navy Gold Foil",
      kind: BgKind.goldFoil,
      category: BgCategory.premium,
      colors: [
        Color(0xff0E1A3A),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_foil_emerald",
      name: "Emerald Gold Foil",
      kind: BgKind.goldFoil,
      category: BgCategory.premium,
      colors: [
        Color(0xff0B3226),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_foil_ivory",
      name: "Ivory Gold Foil",
      kind: BgKind.goldFoil,
      category: BgCategory.premium,
      colors: [
        Color(0xffF6F0E4),
      ],
      accent: Color(0xffC9A24A),
      dark: false,
    ),
    BgTemplate(
      id: "pr_foil_maroon",
      name: "Maroon Gold Foil",
      kind: BgKind.goldFoil,
      category: BgCategory.premium,
      colors: [
        Color(0xff3A0A14),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_box_ruby",
      name: "Ruby Jewel Box",
      kind: BgKind.jewelBox,
      category: BgCategory.premium,
      colors: [
        Color(0xff7A1022),
        Color(0xff1A1A1D),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_box_navy",
      name: "Navy Jewel Box",
      kind: BgKind.jewelBox,
      category: BgCategory.premium,
      colors: [
        Color(0xff1B2C5C),
        Color(0xff101012),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_box_black",
      name: "Black Jewel Box",
      kind: BgKind.jewelBox,
      category: BgCategory.premium,
      colors: [
        Color(0xff1C1C20),
        Color(0xff0A0A0C),
      ],
      accent: Color(0xffC9A24A),
      dark: true,
    ),
    BgTemplate(
      id: "pr_box_cream",
      name: "Cream Jewel Box",
      kind: BgKind.jewelBox,
      category: BgCategory.premium,
      colors: [
        Color(0xffEFE5D2),
        Color(0xff6B4A2E),
      ],
      accent: Color(0xffD4AF37),
      dark: false,
    ),
    BgTemplate(
      id: "pr_box_emerald",
      name: "Emerald Jewel Box",
      kind: BgKind.jewelBox,
      category: BgCategory.premium,
      colors: [
        Color(0xff0F4D37),
        Color(0xff151517),
      ],
      accent: Color(0xffD4AF37),
      dark: true,
    ),
    BgTemplate(
      id: "pr_pearl_silk",
      name: "Pearl Silk Wave",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [
        Color(0xffF2F0EC),
        Color(0xffFFFFFF),
        Color(0xffB9B4AC),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "pr_rosegold_silk",
      name: "Rose Gold Silk",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [
        Color(0xffE7B9A6),
        Color(0xffFCE6DC),
        Color(0xffA86F5A),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "pr_lavender_silk",
      name: "Lavender Silk",
      kind: BgKind.silkWave,
      category: BgCategory.premium,
      colors: [
        Color(0xffCBBCE6),
        Color(0xffF2ECFF),
        Color(0xff7E6AA8),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "pr_purple_glow",
      name: "Royal Purple Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [
        Color(0xff120E1A),
        Color(0xff2A2733),
        Color(0xffB48CFF),
      ],
      dark: true,
      flip: true,
    ),
    BgTemplate(
      id: "pr_emerald_glow",
      name: "Emerald Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [
        Color(0xff0B1512),
        Color(0xff252C2A),
        Color(0xff4FD1A0),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "pr_amber_glow",
      name: "Amber Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [Color(0xff1A1510), Color(0xff2C2D33), Color(0xffFF9A3C)],
      dark: true,
    ),
    BgTemplate(
      id: "pr_copper_teal",
      name: "Copper Teal Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [
        Color(0xff15161A),
        Color(0xff2E2F35),
        Color(0xffEE8A5C),
        Color(0xff2E6F7A),
      ],
      dark: true,
      flip: true,
    ),
    BgTemplate(
      id: "pr_golden_night",
      name: "Golden Night",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [Color(0xff16130C), Color(0xff2A2822), Color(0xffEBB54E)],
      dark: true,
      flip: true,
    ),
    BgTemplate(
      id: "pr_candle_glow",
      name: "Candle Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [Color(0xff1B120C), Color(0xff2D2723), Color(0xffFFB766)],
      dark: true,
    ),
    BgTemplate(
      id: "pr_rose_glow",
      name: "Rose Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [Color(0xff1A1214), Color(0xff2E2A2D), Color(0xffF09AA8)],
      dark: true,
      flip: true,
    ),
    BgTemplate(
      id: "pr_ice_glow",
      name: "Ice Glow",
      kind: BgKind.glowTable,
      category: BgCategory.premium,
      colors: [
        Color(0xff0D121C),
        Color(0xff262B35),
        Color(0xff9CC4FF),
        Color(0xff6A4FA0),
      ],
      dark: true,
    ),

    // =====================================================
    // 🤖 AI STYLE — mesh gradient, bokeh, podium, mirror
    // =====================================================
    BgTemplate(
      id: "ai_aurora",
      name: "Aurora",
      kind: BgKind.mesh,
      category: BgCategory.ai,
      colors: [
        Color(0xffF6F2FF),
        Color(0xffC9B8FF),
        Color(0xff9FD8FF),
        Color(0xffFFC9E3),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "ai_peach",
      name: "Peach Dream",
      kind: BgKind.mesh,
      category: BgCategory.ai,
      colors: [
        Color(0xffFFF5EE),
        Color(0xffFFC6A6),
        Color(0xffFFE2B5),
        Color(0xffF5A8B8),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "ai_lavender",
      name: "Lavender Mist",
      kind: BgKind.mesh,
      category: BgCategory.ai,
      colors: [
        Color(0xffF7F4FF),
        Color(0xffD8CBFF),
        Color(0xffC6E2FF),
        Color(0xffEED9FF),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "ai_ocean",
      name: "Ocean Mist",
      kind: BgKind.mesh,
      category: BgCategory.ai,
      colors: [
        Color(0xffEFF8FB),
        Color(0xffA6DCEA),
        Color(0xffBCD2FF),
        Color(0xffD5F2E8),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "ai_midnight_aurora",
      name: "Night Aurora",
      kind: BgKind.mesh,
      category: BgCategory.ai,
      colors: [
        Color(0xff0B1026),
        Color(0xff3B2A8C),
        Color(0xff12607E),
        Color(0xff6B2A6E),
      ],
      dark: true,
    ),
    BgTemplate(
      id: "ai_golden_bokeh",
      name: "Golden Bokeh",
      kind: BgKind.bokeh,
      category: BgCategory.ai,
      colors: [Color(0xff2E200B), Color(0xff0E0904), Color(0xffF5C76A)],
      dark: true,
    ),
    BgTemplate(
      id: "ai_champagne_bokeh",
      name: "Light Bokeh",
      kind: BgKind.bokeh,
      category: BgCategory.ai,
      colors: [Color(0xffFFF8EC), Color(0xffEAD6AE), Color(0xffFFFFFF)],
      dark: false,
    ),
    BgTemplate(
      id: "ai_night_bokeh",
      name: "Night Bokeh",
      kind: BgKind.bokeh,
      category: BgCategory.ai,
      colors: [Color(0xff16264F), Color(0xff060B1C), Color(0xff9CC4FF)],
      dark: true,
    ),
    BgTemplate(
      id: "ai_ivory_podium",
      name: "Ivory Podium",
      kind: BgKind.podium,
      category: BgCategory.ai,
      colors: [Color(0xffFBF8F1), Color(0xffEDE4D1), Color(0xffF6EFE0)],
      floorPad: 0.30,
      dark: false,
    ),
    BgTemplate(
      id: "ai_blush_podium",
      name: "Blush Podium",
      kind: BgKind.podium,
      category: BgCategory.ai,
      colors: [Color(0xffFCEBEE), Color(0xffF0CDD4), Color(0xffF7DDE2)],
      floorPad: 0.30,
      dark: false,
    ),
    BgTemplate(
      id: "ai_gold_podium",
      name: "Gold Podium",
      kind: BgKind.podium,
      category: BgCategory.ai,
      colors: [Color(0xffFFF7E3), Color(0xffEFDCAD), Color(0xffD7B05A)],
      floorPad: 0.30,
      dark: false,
    ),
    BgTemplate(
      id: "ai_black_podium",
      name: "Black Podium",
      kind: BgKind.podium,
      category: BgCategory.ai,
      colors: [Color(0xff2C2C31), Color(0xff0D0D0F), Color(0xff222226)],
      floorPad: 0.30,
      dark: true,
    ),
    BgTemplate(
      id: "ai_mirror_white",
      name: "Mirror White",
      kind: BgKind.mirror,
      category: BgCategory.ai,
      colors: [Color(0xffFFFFFF), Color(0xffEBEBF0), Color(0xffD6D6DE)],
      floorPad: 0.28,
      reflection: true,
      dark: false,
    ),
    BgTemplate(
      id: "ai_mirror_black",
      name: "Mirror Black",
      kind: BgKind.mirror,
      category: BgCategory.ai,
      colors: [Color(0xff2A2A2F), Color(0xff0B0B0D), Color(0xff1A1A1D)],
      floorPad: 0.28,
      reflection: true,
      dark: true,
    ),

    // =====================================================
    // 📸 STUDIO
    // =====================================================
    BgTemplate(
      id: "studio_white",
      name: "Studio White",
      kind: BgKind.studio,
      category: BgCategory.studio,
      colors: [Color(0xffFFFFFF), Color(0xffF0F0F2), Color(0xffE2E2E7)],
    ),
    BgTemplate(
      id: "pearl_glow",
      name: "Pearl Glow",
      kind: BgKind.radial,
      category: BgCategory.studio,
      colors: [Color(0xffFFFFFF), Color(0xffEAE5DC)],
    ),
    BgTemplate(
      id: "sky_studio",
      name: "Sky Studio",
      kind: BgKind.studio,
      category: BgCategory.studio,
      colors: [Color(0xffF2F6FF), Color(0xffDCE6FA), Color(0xffC6D5F2)],
    ),
    BgTemplate(
      id: "champagne_glow",
      name: "Champagne",
      kind: BgKind.radial,
      category: BgCategory.studio,
      colors: [Color(0xffFFF7E8), Color(0xffE6CC9A)],
    ),
    BgTemplate(
      id: "rose_gold",
      name: "Rose Gold",
      kind: BgKind.linear,
      category: BgCategory.studio,
      colors: [Color(0xffFBE6DF), Color(0xffEBBBAA), Color(0xffD69A88)],
    ),
    BgTemplate(
      id: "midnight_spot",
      name: "Spotlight",
      kind: BgKind.spotlight,
      category: BgCategory.studio,
      colors: [Color(0xff4A4A52), Color(0xff0C0C0F)],
    ),
    BgTemplate(
      id: "gold_spot",
      name: "Gold Spotlight",
      kind: BgKind.spotlight,
      category: BgCategory.studio,
      colors: [Color(0xffFFF1C9), Color(0xffA9831A)],
    ),

    // =====================================================
    // 👑 LUXURY
    // =====================================================
    BgTemplate(
      id: "royal_velvet",
      name: "Royal Velvet",
      kind: BgKind.radial,
      category: BgCategory.luxury,
      colors: [Color(0xff2D52B0), Color(0xff0B1E4A)],
    ),
    BgTemplate(
      id: "maroon_velvet",
      name: "Maroon Velvet",
      kind: BgKind.radial,
      category: BgCategory.luxury,
      colors: [Color(0xff8E2239), Color(0xff320812)],
    ),
    BgTemplate(
      id: "emerald_luxe",
      name: "Emerald Luxe",
      kind: BgKind.radial,
      category: BgCategory.luxury,
      colors: [Color(0xff21765A), Color(0xff05261B)],
    ),
    BgTemplate(
      id: "champagne_satin",
      name: "Champagne Satin",
      kind: BgKind.satin,
      category: BgCategory.luxury,
      colors: [Color(0xffE8D4AE), Color(0xffFFF7E4), Color(0xffA98A55)],
      dark: false,
    ),
    BgTemplate(
      id: "black_satin",
      name: "Black Satin",
      kind: BgKind.satin,
      category: BgCategory.luxury,
      colors: [Color(0xff19191C), Color(0xff6A6A72), Color(0xff000000)],
      dark: true,
    ),
    BgTemplate(
      id: "red_satin",
      name: "Red Satin",
      kind: BgKind.satin,
      category: BgCategory.luxury,
      colors: [Color(0xff8C1A2B), Color(0xffE0607A), Color(0xff3A0610)],
      dark: true,
    ),
    BgTemplate(
      id: "white_marble",
      name: "White Marble",
      kind: BgKind.marble,
      category: BgCategory.luxury,
      colors: [Color(0xffF8F7F5), Color(0xff8E8E92)],
      dark: false,
    ),
    BgTemplate(
      id: "black_marble",
      name: "Black Marble",
      kind: BgKind.marble,
      category: BgCategory.luxury,
      colors: [Color(0xff18181B), Color(0xffD9D9DE)],
      dark: true,
    ),
    BgTemplate(
      id: "gold_frame",
      name: "Gold Frame",
      kind: BgKind.frame,
      category: BgCategory.luxury,
      colors: [Color(0xffFFFFFF)],
      accent: Color(0xffC9A227),
    ),
    BgTemplate(
      id: "ivory_frame",
      name: "Ivory Frame",
      kind: BgKind.frame,
      category: BgCategory.luxury,
      colors: [Color(0xffFBF6EA)],
      accent: Color(0xff9C7A1E),
    ),
    BgTemplate(
      id: "diamond_dust",
      name: "Diamond Dust",
      kind: BgKind.glitter,
      category: BgCategory.luxury,
      colors: [Color(0xff2D2D36), Color(0xff09090C), Color(0xffFFFFFF)],
      dark: true,
    ),
    BgTemplate(
      id: "gold_glitter",
      name: "Gold Glitter",
      kind: BgKind.glitter,
      category: BgCategory.luxury,
      colors: [Color(0xff3B2B0E), Color(0xff110B03), Color(0xffF4D27A)],
      dark: true,
    ),

    // =====================================================
    // 🌿 NATURE
    // =====================================================
    BgTemplate(
      id: "sunlit_window",
      name: "Sunlit Window",
      kind: BgKind.window,
      category: BgCategory.nature,
      colors: [Color(0xffEFE1C8), Color(0xffDCC6A0), Color(0xffFFF8E8)],
      dark: false,
    ),
    BgTemplate(
      id: "palm_shadow",
      name: "Palm Shadow",
      kind: BgKind.leaves,
      category: BgCategory.nature,
      colors: [Color(0xffF7F0E4), Color(0xffE7DAC4), Color(0xff4E3F2C)],
      dark: false,
    ),
    BgTemplate(
      id: "sage_leaves",
      name: "Sage Leaves",
      kind: BgKind.leaves,
      category: BgCategory.nature,
      colors: [Color(0xffEEF3EC), Color(0xffD5E0D1), Color(0xff2F4A33)],
      dark: false,
    ),
    BgTemplate(
      id: "aqua_ripple",
      name: "Aqua Ripple",
      kind: BgKind.ripple,
      category: BgCategory.nature,
      colors: [Color(0xffE2F5F8), Color(0xff94CFDD)],
      dark: false,
    ),
    BgTemplate(
      id: "oak_table",
      name: "Oak Table",
      kind: BgKind.wood,
      category: BgCategory.nature,
      colors: [Color(0xffC99C6B), Color(0xff6E4626)],
      dark: false,
    ),
    BgTemplate(
      id: "walnut_table",
      name: "Walnut",
      kind: BgKind.wood,
      category: BgCategory.nature,
      colors: [Color(0xff6A452E), Color(0xff23140B)],
      dark: true,
    ),
    BgTemplate(
      id: "rose_petals",
      name: "Rose Petals",
      kind: BgKind.petals,
      category: BgCategory.nature,
      colors: [
        Color(0xffFFF8F7),
        Color(0xffF6DCE0),
        Color(0xffC2185B),
        Color(0xffF48FB1),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "ivory_silk",
      name: "Ivory Silk",
      kind: BgKind.silk,
      category: BgCategory.nature,
      colors: [Color(0xffFDFBF6), Color(0xffEFE5D0)],
    ),
    BgTemplate(
      id: "blush_silk",
      name: "Blush Silk",
      kind: BgKind.silk,
      category: BgCategory.nature,
      colors: [Color(0xffFDEFF1), Color(0xffEBC3CB)],
    ),

    // =====================================================
    // 🪔 FESTIVE (Indian jewellery mate)
    // =====================================================
    BgTemplate(
      id: "royal_mandala",
      name: "Royal Mandala",
      kind: BgKind.mandala,
      category: BgCategory.festive,
      colors: [Color(0xff7E1628), Color(0xff2E050D)],
      accent: Color(0xffE3B94F),
      dark: true,
    ),
    BgTemplate(
      id: "emerald_mandala",
      name: "Emerald Mandala",
      kind: BgKind.mandala,
      category: BgCategory.festive,
      colors: [Color(0xff11593F), Color(0xff04211A)],
      accent: Color(0xffE3B94F),
      dark: true,
    ),
    BgTemplate(
      id: "ivory_mandala",
      name: "Ivory Mandala",
      kind: BgKind.mandala,
      category: BgCategory.festive,
      colors: [Color(0xffFFFBF2), Color(0xffF1E3C4)],
      accent: Color(0xffB8902E),
      dark: false,
    ),
    BgTemplate(
      id: "marigold",
      name: "Marigold",
      kind: BgKind.petals,
      category: BgCategory.festive,
      colors: [
        Color(0xffFFF8E6),
        Color(0xffFBE1AE),
        Color(0xffF57C00),
        Color(0xffFFC107),
      ],
      dark: false,
    ),
    BgTemplate(
      id: "festive_bokeh",
      name: "Diwali Lights",
      kind: BgKind.bokeh,
      category: BgCategory.festive,
      colors: [Color(0xff4A0E1C), Color(0xff16030A), Color(0xffFFC65C)],
      dark: true,
    ),
  ];

  /// 🔥 Potani background images (optional)
  ///
  /// Image `assets/batch_bg/` folder ma muko, pubspec.yaml ma
  ///   assets:
  ///     - assets/batch_bg/
  /// lakho, ane ahiya ek line umero.
  static final List<BgTemplate> assetTemplates = [
    // BgTemplate.asset("Velvet Box", "assets/batch_bg/velvet_box.jpg"),
  ];
}

/// ================================================================
/// 🖌️ PAINTER — preview ane final banne mate ek j code
///
/// floorY = jewellery no niche no chhedo (podium / mirror mate)
/// ================================================================

class BgTemplatePainter {
  BgTemplatePainter._();

  static void paint(
      Canvas canvas,
      Size size,
      BgTemplate t, {
        ui.Image? image,
        double? floorY,
      }) {
    final Rect rect = Offset.zero & size;
    final double fy = floorY ?? size.height * 0.74;

    switch (t.kind) {
      case BgKind.solid:
        canvas.drawRect(rect, Paint()..color = t.colors.first);
        return;
      case BgKind.linear:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.colors,
            ).createShader(rect),
        );
        return;
      case BgKind.radial:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 0.95,
              colors: t.colors,
            ).createShader(rect),
        );
        return;
      case BgKind.spotlight:
        _spotlight(canvas, size, t);
        return;
      case BgKind.studio:
        _studio(canvas, size, t);
        return;
      case BgKind.marble:
        _marble(canvas, size, t);
        return;
      case BgKind.silk:
        _silk(canvas, size, t);
        return;
      case BgKind.frame:
        _frame(canvas, size, t);
        return;
      case BgKind.mesh:
        _mesh(canvas, size, t);
        return;
      case BgKind.bokeh:
        _bokeh(canvas, size, t);
        return;
      case BgKind.podium:
        _podium(canvas, size, t, fy);
        return;
      case BgKind.mirror:
        _mirror(canvas, size, t, fy);
        return;
      case BgKind.window:
        _window(canvas, size, t);
        return;
      case BgKind.leaves:
        _leaves(canvas, size, t);
        return;
      case BgKind.ripple:
        _ripple(canvas, size, t);
        return;
      case BgKind.wood:
        _wood(canvas, size, t);
        return;
      case BgKind.petals:
        _petals(canvas, size, t);
        return;
      case BgKind.mandala:
        _mandala(canvas, size, t);
        return;
      case BgKind.glitter:
        _glitter(canvas, size, t);
        return;
      case BgKind.satin:
        _satin(canvas, size, t);
        return;
      case BgKind.silkWave:
        _silkWave(canvas, size, t);
        return;
      case BgKind.glowTable:
        _glowTable(canvas, size, t);
        return;
      case BgKind.velvet:
        _velvet(canvas, size, t);
        return;
      case BgKind.arch:
        _arch(canvas, size, t);
        return;
      case BgKind.goldFoil:
        _goldFoil(canvas, size, t);
        return;
      case BgKind.jewelBox:
        _jewelBox(canvas, size, t);
        return;
      case BgKind.marbleLux:
        _marbleLux(canvas, size, t);
        return;
      case BgKind.stageBeam:
        _stageBeam(canvas, size, t);
        return;
      case BgKind.liquidMetal:
        _liquidMetal(canvas, size, t);
        return;
      case BgKind.sparkle:
        _sparkle(canvas, size, t);
        return;
      case BgKind.image:
        canvas.drawRect(rect, Paint()..color = const Color(0xffEDEDED));
        if (image != null) {
          paintImage(
            canvas: canvas,
            rect: rect,
            image: image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          );
        }
        return;
    }
  }

  // ---------------------------------------------------------
  // SMALL HELPERS
  // ---------------------------------------------------------

  static Color _shade(Color c, double amount) {
    final HSLColor h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static void _vGrad(Canvas c, Rect r, List<Color> colors) {
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(r),
    );
  }

  static void _dGrad(Canvas c, Rect r, List<Color> colors) {
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(r),
    );
  }

  static void _glow(
      Canvas c,
      Rect r,
      Alignment center,
      double radius,
      Color color,
      double opacity,
      ) {
    c.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: center,
          radius: radius,
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ).createShader(r),
    );
  }

  static void _vignette(Canvas c, Rect r, double strength) {
    c.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          stops: const [0.55, 1],
          colors: [
            Colors.black.withOpacity(0),
            Colors.black.withOpacity(strength),
          ],
        ).createShader(r),
    );
  }

  /// Soft gol prakash (blur vagar — fast)
  static void _softDot(Canvas c, Offset p, double r, Color color, double op) {
    final Rect b = Rect.fromCircle(center: p, radius: r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(op), color.withOpacity(0)],
        ).createShader(b),
    );
  }

  // ---------------------------------------------------------
  // ORIGINAL TEMPLATES
  // ---------------------------------------------------------

  static void _spotlight(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;

    c.drawRect(rect, Paint()..color = t.colors[1]);

    _glow(c, rect, const Alignment(0, -0.9), 1.25, t.colors[0], 1);

    final Rect floor = Rect.fromCenter(
      center: Offset(s.width / 2, s.height * 0.86),
      width: s.width * 0.9,
      height: s.height * 0.28,
    );

    c.drawOval(
      floor,
      Paint()
        ..shader = RadialGradient(
          colors: [
            t.colors[0].withOpacity(0.35),
            t.colors[0].withOpacity(0),
          ],
        ).createShader(floor),
    );
  }

  static void _studio(Canvas c, Size s, BgTemplate t) {
    final double horizon = s.height * 0.72;
    final double m = s.shortestSide;

    _vGrad(c, Rect.fromLTWH(0, 0, s.width, horizon), [t.colors[0], t.colors[1]]);
    _vGrad(
      c,
      Rect.fromLTWH(0, horizon, s.width, s.height - horizon),
      [t.colors[1], t.colors[2]],
    );

    c.drawRect(
      Rect.fromLTWH(0, horizon - m * 0.03, s.width, m * 0.06),
      Paint()
        ..color = t.colors[1]
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.03),
    );

    _glow(c, Offset.zero & s, const Alignment(0, -1), 1.0, Colors.white, 0.55);
  }

  static void _marble(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final Color base = t.colors[0];
    final Color vein = t.colors[1];
    final double m = s.shortestSide;

    _dGrad(c, rect, [base, Color.lerp(base, vein, 0.10)!, base]);

    final math.Random rnd = math.Random(11);

    for (int i = 0; i < 8; i++) {
      final Path path = Path();

      double x = rnd.nextDouble() * s.width * 1.2 - s.width * 0.1;
      double y = -m * 0.05;

      path.moveTo(x, y);

      while (y < s.height + m * 0.05) {
        final double nx = x + (rnd.nextDouble() - 0.5) * m * 0.35;
        final double ny = y + m * (0.12 + rnd.nextDouble() * 0.18);

        path.quadraticBezierTo(
          x + (rnd.nextDouble() - 0.5) * m * 0.3,
          (y + ny) / 2,
          nx,
          ny,
        );

        x = nx;
        y = ny;
      }

      final double w = m * (0.002 + rnd.nextDouble() * 0.006);

      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = vein.withOpacity(0.15 + rnd.nextDouble() * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.8),
      );
    }
  }

  static void _silk(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;

    _dGrad(c, rect, t.colors);

    for (int i = 0; i < 4; i++) {
      final double y = s.height * (0.18 + i * 0.22);

      final Path wave = Path()
        ..moveTo(0, y)
        ..cubicTo(
          s.width * 0.3,
          y - m * 0.22,
          s.width * 0.65,
          y + m * 0.22,
          s.width,
          y - m * 0.08,
        )
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close();

      c.drawPath(
        wave,
        Paint()
          ..color = (i.isEven ? Colors.white : t.colors.last)
              .withOpacity(i.isEven ? 0.16 : 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.01),
      );
    }
  }

  static void _frame(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Color gold = t.accent ?? const Color(0xffC9A227);

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [t.colors.first, Color.lerp(t.colors.first, gold, 0.06)!],
        ).createShader(rect),
    );

    final Rect outer = rect.deflate(m * 0.04);
    final Rect inner = rect.deflate(m * 0.058);

    c.drawRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.006
        ..color = gold,
    );

    c.drawRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.0022
        ..color = gold.withOpacity(0.8),
    );

    final double d = m * 0.012;

    for (final Offset p in [
      outer.topLeft,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomRight,
    ]) {
      c.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - d)
          ..lineTo(p.dx + d, p.dy)
          ..lineTo(p.dx, p.dy + d)
          ..lineTo(p.dx - d, p.dy)
          ..close(),
        Paint()..color = gold,
      );
    }
  }

  // ---------------------------------------------------------
  // 🤖 AI STYLE
  // ---------------------------------------------------------

  /// Mesh gradient — moti soft rang ni dhaba (AI wallpaper jevu)
  static void _mesh(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;

    c.drawRect(rect, Paint()..color = t.colors[0]);

    const List<Offset> spots = [
      Offset(0.10, 0.15),
      Offset(0.92, 0.20),
      Offset(0.18, 0.88),
      Offset(0.88, 0.85),
      Offset(0.55, 0.02),
      Offset(0.50, 1.02),
    ];

    final List<Color> blobs = t.colors.sublist(1);

    for (int i = 0; i < spots.length; i++) {
      _softDot(
        c,
        Offset(spots[i].dx * s.width, spots[i].dy * s.height),
        m * 0.62,
        blobs[i % blobs.length],
        t.isDark ? 0.75 : 0.85,
      );
    }

    // Vachche halko prakash — jewellery uthi ne dekhay
    _glow(c, rect, Alignment.center, 0.55, Colors.white, t.isDark ? 0.10 : 0.55);
  }

  /// Bokeh — pachhal blur thayel lights
  static void _bokeh(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Offset center = rect.center;
    final Color light = t.colors[2];

    _vGrad(c, rect, [t.colors[0], t.colors[1]]);

    final math.Random rnd = math.Random(21);

    for (int i = 0; i < 30; i++) {
      final double r = m * (0.025 + rnd.nextDouble() * 0.10);
      final Offset p = Offset(
        rnd.nextDouble() * s.width,
        rnd.nextDouble() * s.height,
      );

      double op = 0.10 + rnd.nextDouble() * 0.32;

      final double d = (p - center).distance / (m * 0.5);
      if (d < 0.7) op *= 0.3;

      final Rect circle = Rect.fromCircle(center: p, radius: r);

      c.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            stops: const [0, 0.82, 1],
            colors: [
              light.withOpacity(op * 0.55),
              light.withOpacity(op),
              light.withOpacity(0),
            ],
          ).createShader(circle),
      );
    }

    _glow(c, rect, Alignment.center, 0.5, light, t.isDark ? 0.10 : 0.25);
    _vignette(c, rect, t.isDark ? 0.35 : 0.06);
  }

  /// Podium — jewellery gol stand par
  static void _podium(Canvas c, Size s, BgTemplate t, double floorY) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Color pc = t.colors[2];

    _vGrad(c, rect, [t.colors[0], t.colors[1]]);
    _glow(c, rect, const Alignment(0, -0.35), 0.75, Colors.white,
        t.isDark ? 0.10 : 0.45);

    final double podW = s.width * 0.68;
    final double left = (s.width - podW) / 2;
    final double ellH = podW * 0.16;
    final double topY = floorY - ellH * 0.22;

    // Podium no body
    final Rect body = Rect.fromLTWH(left, topY, podW, s.height - topY + ellH);

    c.drawRect(
      body,
      Paint()
        ..shader = LinearGradient(
          stops: const [0, 0.3, 0.6, 1],
          colors: [
            _shade(pc, -0.16),
            _shade(pc, 0.06),
            pc,
            _shade(pc, -0.20),
          ],
        ).createShader(body),
    );

    // Upar ni gol sapati
    final Rect top = Rect.fromCenter(
      center: Offset(s.width / 2, topY),
      width: podW,
      height: ellH,
    );

    c.drawOval(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(pc, 0.10), _shade(pc, -0.03)],
        ).createShader(top),
    );

    c.drawOval(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.0025
        ..color = Colors.white.withOpacity(t.isDark ? 0.15 : 0.45),
    );
  }

  /// Mirror floor — chamakto floor (reflection composer kare che)
  static void _mirror(Canvas c, Size s, BgTemplate t, double floorY) {
    final double m = s.shortestSide;
    final double horizon = (floorY - m * 0.05).clamp(0.0, s.height);

    _vGrad(c, Rect.fromLTWH(0, 0, s.width, horizon), [t.colors[0], t.colors[1]]);
    _vGrad(
      c,
      Rect.fromLTWH(0, horizon, s.width, s.height - horizon),
      [_shade(t.colors[1], t.isDark ? 0.04 : -0.02), t.colors[2]],
    );

    // Floor par chamak
    c.drawRect(
      Rect.fromLTWH(0, horizon - m * 0.006, s.width, m * 0.012),
      Paint()
        ..color = Colors.white.withOpacity(t.isDark ? 0.10 : 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.006),
    );

    _glow(c, Offset.zero & s, const Alignment(0, -1), 1.0, Colors.white,
        t.isDark ? 0.10 : 0.5);
  }

  // ---------------------------------------------------------
  // 🌿 NATURE
  // ---------------------------------------------------------

  /// Bari mathi aavto taadko (window light)
  static void _window(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;

    _dGrad(c, rect, [t.colors[0], t.colors[1]]);

    c.save();
    c.translate(s.width * 0.60, s.height * 0.32);
    c.rotate(-0.40);
    c.skew(0.30, 0);

    final double pane = m * 0.24;
    final double gap = m * 0.028;

    final Paint light = Paint()
      ..color = t.colors[2].withOpacity(0.75)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.018);

    for (int r = 0; r < 2; r++) {
      for (int col = 0; col < 2; col++) {
        c.drawRect(
          Rect.fromLTWH(
            -pane - gap / 2 + col * (pane + gap),
            -pane - gap / 2 + r * (pane * 1.25 + gap),
            pane,
            pane * 1.25,
          ),
          light,
        );
      }
    }

    c.restore();

    _glow(c, rect, const Alignment(0.8, -0.8), 1.1, t.colors[2], 0.35);
  }

  /// Palm / paan no padchhayo
  static void _leaves(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;

    _dGrad(c, rect, [t.colors[0], t.colors[1]]);

    final Paint leaf = Paint()
      ..color = t.colors[2].withOpacity(0.15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.012);

    final Paint stem = Paint()
      ..color = t.colors[2].withOpacity(0.15)
      ..strokeWidth = m * 0.006
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.008);

    final List<List<double>> fronds = [
      // x, y (relative), angle
      [-0.05, -0.05, 0.65],
      [1.05, 0.08, math.pi + 0.45],
      [-0.06, 0.96, -0.55],
      [1.04, 1.02, math.pi - 0.6],
    ];

    for (final List<double> f in fronds) {
      c.save();
      c.translate(f[0] * s.width, f[1] * s.height);
      c.rotate(f[2]);

      c.drawLine(Offset.zero, Offset(m * 0.6, 0), stem);

      for (int j = 1; j <= 10; j++) {
        final double x = m * 0.055 * j;
        final double len = m * (0.21 - j * 0.013);

        for (final int side in [-1, 1]) {
          c.save();
          c.translate(x, 0);
          c.rotate(side * 0.75);
          c.drawOval(
            Rect.fromLTWH(0, -m * 0.012, len, m * 0.024),
            leaf,
          );
          c.restore();
        }
      }

      c.restore();
    }

    _glow(c, rect, Alignment.center, 0.6, Colors.white, 0.35);
  }

  /// Paani ni lahero
  static void _ripple(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;

    _dGrad(c, rect, [t.colors[0], t.colors[1]]);

    for (final Offset rel in const [Offset(0.28, 0.30), Offset(0.76, 0.72)]) {
      final Offset ctr = Offset(rel.dx * s.width, rel.dy * s.height);

      for (int k = 0; k < 7; k++) {
        c.drawOval(
          Rect.fromCenter(
            center: ctr,
            width: m * (0.12 + k * 0.13),
            height: m * (0.05 + k * 0.055),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = m * 0.004
            ..color = Colors.white.withOpacity(0.30 - k * 0.035)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.003),
        );
      }
    }

    // Caustic light lines
    final math.Random rnd = math.Random(3);

    for (int i = 0; i < 14; i++) {
      final double y0 = rnd.nextDouble() * s.height;

      final Path p = Path()
        ..moveTo(-m * 0.05, y0)
        ..cubicTo(
          s.width * 0.3,
          y0 + (rnd.nextDouble() - 0.5) * m * 0.3,
          s.width * 0.7,
          y0 + (rnd.nextDouble() - 0.5) * m * 0.3,
          s.width + m * 0.05,
          y0 + (rnd.nextDouble() - 0.5) * m * 0.2,
        );

      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = m * (0.002 + rnd.nextDouble() * 0.004)
          ..color = Colors.white.withOpacity(0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.004),
      );
    }

    _glow(c, rect, Alignment.center, 0.55, Colors.white, 0.35);
  }

  /// Lakda nu table
  static void _wood(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color grain = t.colors[1];

    _vGrad(c, rect, [_shade(base, 0.04), base, _shade(base, -0.05)]);

    final math.Random rnd = math.Random(9);

    for (int i = 0; i < 70; i++) {
      final double y0 =
          s.height * i / 70 + (rnd.nextDouble() - 0.5) * s.height * 0.01;
      final double freq = 1 + rnd.nextDouble() * 2;
      final double phase = rnd.nextDouble() * math.pi * 2;

      final Path p = Path()..moveTo(0, y0);

      for (int k = 1; k <= 24; k++) {
        final double x = s.width * k / 24;
        p.lineTo(
          x,
          y0 + math.sin(x / s.width * math.pi * 2 * freq + phase) * m * 0.006,
        );
      }

      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = m * (0.0008 + rnd.nextDouble() * 0.003)
          ..color = grain.withOpacity(0.08 + rnd.nextDouble() * 0.22),
      );
    }

    // Patiya vachche ni line
    for (final double f in const [0.34, 0.67]) {
      final double y = s.height * f;

      c.drawLine(
        Offset(0, y),
        Offset(s.width, y),
        Paint()
          ..color = grain.withOpacity(0.55)
          ..strokeWidth = m * 0.003,
      );

      c.drawLine(
        Offset(0, y + m * 0.003),
        Offset(s.width, y + m * 0.003),
        Paint()
          ..color = Colors.white.withOpacity(0.10)
          ..strokeWidth = m * 0.002,
      );
    }

    _glow(c, rect, const Alignment(0, -0.2), 0.7, Colors.white, 0.18);
    _vignette(c, rect, 0.25);
  }

  /// Fool ni pankhudi (vachche khali jagya)
  static void _petals(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Offset center = rect.center;

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [t.colors[0], t.colors[1]],
        ).createShader(rect),
    );

    final math.Random rnd = math.Random(17);

    int placed = 0;
    int tries = 0;

    while (placed < 30 && tries < 500) {
      tries++;

      final Offset p = Offset(
        rnd.nextDouble() * s.width,
        rnd.nextDouble() * s.height,
      );

      final double size = m * (0.035 + rnd.nextDouble() * 0.045);
      final double ang = rnd.nextDouble() * math.pi * 2;
      final Color col = Color.lerp(t.colors[2], t.colors[3], rnd.nextDouble())!;

      if ((p - center).distance < m * 0.36) continue;

      placed++;

      final Path petal = Path()
        ..moveTo(0, -size)
        ..quadraticBezierTo(size * 0.9, -size * 0.2, 0, size)
        ..quadraticBezierTo(-size * 0.9, -size * 0.2, 0, -size)
        ..close();

      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(ang);

      c.drawPath(
        petal.shift(Offset(size * 0.08, size * 0.12)),
        Paint()
          ..color = Colors.black.withOpacity(0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.15),
      );

      c.drawPath(
        petal,
        Paint()
          ..shader = RadialGradient(
            colors: [_shade(col, 0.12), col],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: size)),
      );

      c.restore();
    }

    _glow(c, rect, Alignment.center, 0.45, Colors.white, 0.45);
  }

  // ---------------------------------------------------------
  // 🪔 FESTIVE / 👑 LUXURY
  // ---------------------------------------------------------

  /// Khuna ma golden mandala + border
  static void _mandala(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Color gold = t.accent ?? const Color(0xffE3B94F);

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [t.colors[0], t.colors[1]],
        ).createShader(rect),
    );

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = m * 0.0028
      ..color = gold.withOpacity(0.55);

    final Paint dot = Paint()..color = gold.withOpacity(0.6);

    for (final Offset corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      for (int k = 1; k <= 4; k++) {
        c.drawCircle(corner, m * 0.07 * k, line);
      }

      for (int i = 0; i < 16; i++) {
        c.save();
        c.translate(corner.dx, corner.dy);
        c.rotate(i * math.pi / 8);
        c.drawOval(
          Rect.fromLTWH(m * 0.10, -m * 0.022, m * 0.14, m * 0.044),
          line,
        );
        c.restore();
      }

      for (int i = 0; i < 28; i++) {
        final double a = i * math.pi * 2 / 28;
        c.drawCircle(
          corner + Offset(math.cos(a), math.sin(a)) * (m * 0.31),
          m * 0.006,
          dot,
        );
      }
    }

    c.drawRect(
      rect.deflate(m * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.004
        ..color = gold.withOpacity(0.8),
    );

    c.drawRect(
      rect.deflate(m * 0.042),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.0015
        ..color = gold.withOpacity(0.6),
    );

    _glow(c, rect, Alignment.center, 0.5, Colors.white, t.isDark ? 0.10 : 0.4);
  }

  /// Glitter + sparkle stars
  static void _glitter(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final Color light = t.colors[2];

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.0,
          colors: [t.colors[0], t.colors[1]],
        ).createShader(rect),
    );

    final math.Random rnd = math.Random(29);

    for (int i = 0; i < 340; i++) {
      final double x = rnd.nextDouble() * s.width;
      final double y = rnd.nextDouble() < 0.3
          ? rnd.nextDouble() * s.height
          : s.height * (0.55 + 0.45 * rnd.nextDouble());

      c.drawCircle(
        Offset(x, y),
        m * (0.0015 + rnd.nextDouble() * 0.004),
        Paint()..color = light.withOpacity(0.2 + rnd.nextDouble() * 0.8),
      );
    }

    for (int i = 0; i < 12; i++) {
      final Offset p = Offset(
        rnd.nextDouble() * s.width,
        rnd.nextDouble() * s.height,
      );
      final double sz = m * (0.012 + rnd.nextDouble() * 0.02);

      _softDot(c, p, sz * 1.4, light, 0.5);

      final double w = sz * 0.12;

      c.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - sz)
          ..lineTo(p.dx + w, p.dy - w)
          ..lineTo(p.dx + sz, p.dy)
          ..lineTo(p.dx + w, p.dy + w)
          ..lineTo(p.dx, p.dy + sz)
          ..lineTo(p.dx - w, p.dy + w)
          ..lineTo(p.dx - sz, p.dy)
          ..lineTo(p.dx - w, p.dy - w)
          ..close(),
        Paint()..color = light,
      );
    }

    _vignette(c, rect, 0.3);
  }

  /// Satin kapda na folds
  static void _satin(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double m = s.shortestSide;
    final double diag = math.sqrt(s.width * s.width + s.height * s.height);

    c.drawRect(rect, Paint()..color = t.colors[0]);

    final math.Random rnd = math.Random(41);

    c.save();
    c.translate(s.width / 2, s.height / 2);
    c.rotate(-0.55);

    for (int i = 0; i < 10; i++) {
      final bool highlight = i.isEven;
      final double x =
          -diag / 2 + i * diag / 9 + (rnd.nextDouble() - 0.5) * m * 0.06;
      final double bandW = m * (0.10 + rnd.nextDouble() * 0.14);
      final Rect band = Rect.fromLTWH(x, -diag / 2, bandW, diag);
      final Color col = highlight ? t.colors[1] : t.colors[2];

      c.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              col.withOpacity(0),
              col.withOpacity(highlight ? 0.55 : 0.45),
              col.withOpacity(0),
            ],
          ).createShader(band),
      );
    }

    c.restore();

    _glow(c, rect, Alignment.center, 0.55, Colors.white, t.isDark ? 0.06 : 0.25);
  }

  // ---------------------------------------------------------
  // 💎 PREMIUM
  // ---------------------------------------------------------

  /// Flowing silk / sand-dune waves — big soft folds with highlight
  /// + shadow (like a jewellery photo shoot on draped silk)
  static void _silkWave(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color light = t.colors.length > 1 ? t.colors[1] : _shade(base, 0.2);
    final Color shadow = t.colors.length > 2 ? t.colors[2] : _shade(base, -0.25);
    final bool dark = t.isDark;

    _dGrad(c, rect, [
      Color.lerp(base, light, 0.30)!,
      base,
      Color.lerp(base, shadow, 0.30)!,
    ]);

    final math.Random rnd = math.Random(t.id.hashCode & 0xffff);

    c.save();
    c.translate(w / 2, h / 2);
    c.rotate(-0.384); // ~22° diagonal flow
    c.translate(-w / 2, -h / 2);

    const int n = 6;
    for (int i = 0; i < n; i++) {
      final double y = h * (-0.25 + i * 1.5 / (n - 1));
      final double amp = m * (0.16 + rnd.nextDouble() * 0.10);
      final Path p = Path()
        ..moveTo(-w * 0.3, y)
        ..cubicTo(
          w * 0.15,
          y - amp,
          w * 0.55,
          y + amp * (0.6 + rnd.nextDouble() * 0.6),
          w * 1.3,
          y - amp * 0.5,
        );
      final double thick = m * (0.13 + rnd.nextDouble() * 0.08);

      // shadow side of the fold
      c.drawPath(
        p.shift(Offset(0, thick * 0.65)),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick
          ..color = shadow.withOpacity(dark ? 0.75 : 0.50)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 0.42),
      );

      // lit ridge
      c.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick * 0.55
          ..color = light.withOpacity(dark ? 0.40 : 0.70)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 0.30),
      );

      // fine sheen on the ridge
      c.drawPath(
        p.shift(Offset(0, -thick * 0.05)),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick * 0.12
          ..color = Colors.white.withOpacity(dark ? 0.14 : 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * 0.08),
      );
    }

    c.restore();

    // soft window light from top-left + gentle vignette
    _glow(c, rect, const Alignment(-0.7, -0.9), 1.0, Colors.white, dark ? 0.10 : 0.25);
    _vignette(c, rect, dark ? 0.45 : 0.16);
  }

  /// fine fibre / grain noise (velvet, leather, lining)
  static void _grain(Canvas c, Rect r, int seed, int count, double light, double dark) {
    final double m = r.shortestSide;
    final math.Random g = math.Random(seed);
    final List<Offset> pts = List.generate(
      count,
          (_) => Offset(r.left + g.nextDouble() * r.width, r.top + g.nextDouble() * r.height),
    );
    final int half = count ~/ 2;
    c.drawPoints(ui.PointMode.points, pts.sublist(0, half),
        Paint()..color = Colors.white.withOpacity(light)..strokeWidth = m * 0.0016);
    c.drawPoints(ui.PointMode.points, pts.sublist(half),
        Paint()..color = Colors.black.withOpacity(dark)..strokeWidth = m * 0.0016);
  }

  /// Crushed velvet with a soft spotlight in the middle
  static void _velvet(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.16),
          radius: 0.85,
          stops: const [0, 0.5, 1],
          colors: [_shade(base, 0.10), base, _shade(base, -0.12)],
        ).createShader(rect),
    );

    // crushed pile: soft light / dark patches
    final math.Random rnd = math.Random(5);
    for (int i = 0; i < 70; i++) {
      final double x = rnd.nextDouble() * w;
      final double y = rnd.nextDouble() * h;
      final double r = m * (0.04 + rnd.nextDouble() * 0.12);
      final bool lite = rnd.nextBool();
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 3.2, height: r * 1.2),
        Paint()
          ..color = (lite ? Colors.white : Colors.black).withOpacity(lite ? 0.05 : 0.09)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
    }

    _grain(c, rect, 11, 9000, 0.05, 0.10);
    _glow(c, rect, const Alignment(0, -0.2), 0.45, Colors.white, 0.16);
    _vignette(c, rect, 0.55);
  }

  /// Boutique arch niche on a plain wall (+ thin gold outline)
  static void _arch(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color wall = t.colors[0];
    final Color inner = t.colors.length > 1 ? t.colors[1] : _shade(wall, -0.04);
    final bool dark = t.isDark;

    _dGrad(c, rect, [_shade(wall, 0.05), wall, _shade(wall, -0.06)]);

    final double aw = w * 0.64;
    final double l = (w - aw) / 2;
    final double top = h * 0.10;
    final double bot = h * 0.86;
    final double r = aw / 2;

    final Path arch = Path()
      ..moveTo(l, bot)
      ..lineTo(l, top + r)
      ..arcTo(Rect.fromLTWH(l, top, aw, aw), math.pi, math.pi, false)
      ..lineTo(l + aw, bot)
      ..close();

    c.save();
    c.clipPath(arch);
    _vGrad(c, rect, [_shade(inner, -0.05), inner, _shade(inner, 0.03)]);
    // recess shadow
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.07
        ..color = Colors.black.withOpacity(dark ? 0.28 : 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.03),
    );
    _glow(c, rect, const Alignment(-0.16, -0.2), 0.45, Colors.white, dark ? 0.10 : 0.22);
    c.restore();

    if (t.accent != null) {
      c.drawPath(
        arch,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = m * 0.006
          ..color = t.accent!.withOpacity(0.85),
      );
    }

    // floor
    _vGrad(c, Rect.fromLTWH(0, bot, w, h - bot), [_shade(wall, 0.06), _shade(wall, -0.04)]);
    c.drawRect(
      Rect.fromLTWH(0, bot - m * 0.004, w, m * 0.014),
      Paint()
        ..color = Colors.black.withOpacity(dark ? 0.40 : 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.008),
    );

    _glow(c, rect, const Alignment(-0.7, -1), 1.0, Colors.white, dark ? 0.06 : 0.20);
    _vignette(c, rect, dark ? 0.45 : 0.18);
  }

  /// Gold-leaf flakes scattered in the corners (centre stays clean)
  static void _goldFoil(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color gold = t.accent ?? const Color(0xffD4AF37);
    final bool dark = t.isDark;

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.8,
          colors: [_shade(base, 0.06), base, _shade(base, -0.06)],
        ).createShader(rect),
    );

    final math.Random rnd = math.Random(7);
    const List<List<double>> corners = [
      [0, 0, 46],
      [1, 1, 46],
      [1, 0.05, 12],
      [0, 0.95, 10],
    ];
    final Color g1 = _shade(gold, 0.20), g2 = _shade(gold, -0.18);

    for (final List<double> k in corners) {
      final double sx = k[0] == 0 ? 1 : -1;
      final double sy = k[1] < 0.5 ? 1 : -1;
      for (int i = 0; i < k[2].toInt(); i++) {
        final double a = rnd.nextDouble() * math.pi / 2;
        final double d = math.pow(rnd.nextDouble(), 1.8).toDouble() * m * 0.55;
        final double x = w * k[0] + sx * math.cos(a) * d;
        final double y = h * k[1] + sy * math.sin(a) * d;
        final double sz = m * (0.008 + rnd.nextDouble() * 0.032) * (1.2 - d / (m * 0.55));
        final int n = 5 + rnd.nextInt(3);
        final Path flake = Path();
        for (int j = 0; j < n; j++) {
          final double ang = j * 2 * math.pi / n + rnd.nextDouble() * 0.6;
          final double rr = sz * (0.5 + rnd.nextDouble() * 0.7);
          final Offset pt = Offset(x + math.cos(ang) * rr, y + math.sin(ang) * rr);
          if (j == 0) {
            flake.moveTo(pt.dx, pt.dy);
          } else {
            flake.lineTo(pt.dx, pt.dy);
          }
        }
        flake.close();
        final Rect fb = Rect.fromCircle(center: Offset(x, y), radius: sz);
        c.drawPath(
          flake,
          Paint()
            ..isAntiAlias = true
            ..color = Colors.white.withOpacity(0.6 + rnd.nextDouble() * 0.4)
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [g1, gold, g2],
            ).createShader(fb),
        );
      }
    }

    // tiny gold specks (not in the middle)
    for (int i = 0; i < 260; i++) {
      final Offset p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      if ((p - rect.center).distance < m * 0.33) continue;
      c.drawCircle(
        p,
        m * (0.001 + rnd.nextDouble() * 0.003),
        Paint()..color = g1.withOpacity(0.3 + rnd.nextDouble() * 0.6),
      );
    }

    _glow(c, rect, Alignment.center, 0.42, Colors.white, dark ? 0.08 : 0.25);
    _vignette(c, rect, dark ? 0.35 : 0.08);
  }

  /// Open jewellery box: lacquer rim, gold trim, soft lining inside
  static void _jewelBox(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color lining = t.colors[0];
    final Color shell = t.colors.length > 1 ? t.colors[1] : _shade(lining, -0.3);
    final Color trim = t.accent ?? const Color(0xffD4AF37);

    _dGrad(c, rect, [_shade(shell, 0.10), shell, _shade(shell, -0.10)]);

    final double rim = m * 0.075;
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(rim, rim, w - rim, h - rim),
      Radius.circular(m * 0.03),
    );

    c.save();
    c.clipRRect(inner);
    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.7,
          colors: [_shade(lining, 0.12), lining, _shade(lining, -0.12)],
        ).createShader(rect),
    );
    _grain(c, rect, 4, 8000, 0.05, 0.09);
    // depth: shadow inside the rim
    c.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.09
        ..color = Colors.black.withOpacity(0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.035),
    );
    c.restore();

    // gold trim on the rim
    final Rect tr = Rect.fromLTRB(rim * 0.55, rim * 0.55, w - rim * 0.55, h - rim * 0.55);
    c.drawRRect(
      RRect.fromRectAndRadius(tr, Radius.circular(m * 0.035)),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = m * 0.005
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_shade(trim, 0.2), trim, _shade(trim, -0.2), trim],
        ).createShader(tr),
    );

    // lacquer reflection
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: const Alignment(0.2, 0.2),
          colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0)],
        ).createShader(rect),
    );
  }

  // ---------------------------------------------------------
  // 👑 ULTRA PREMIUM
  // ---------------------------------------------------------

  /// Polished luxury marble: cloudy wash, long diagonal veins with
  /// small branches, and 2 real-gold veins (Calacatta / Nero gold look)
  static void _marbleLux(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color vein = t.colors.length > 1 ? t.colors[1] : _shade(base, -0.4);
    final Color gold = t.accent ?? const Color(0xffC9A24A);
    final bool dark = t.isDark;
    final math.Random rnd = math.Random((t.id.hashCode & 0xffff) + 11);

    _dGrad(c, rect, [_shade(base, 0.04), base, _shade(base, -0.04)]);

    // cloudy wash
    for (int i = 0; i < 10; i++) {
      final double r = m * (0.15 + rnd.nextDouble() * 0.3);
      c.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
        r,
        Paint()
          ..color = vein.withOpacity(0.06)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
      );
    }

    Path veinPath(double x, double y, double ang, double length, int steps, double wig) {
      final Path p = Path()..moveTo(x, y);
      for (int k = 0; k < steps; k++) {
        final double a = ang + (rnd.nextDouble() - 0.5) * wig;
        final double nx = x + math.cos(a) * length / steps;
        final double ny = y + math.sin(a) * length / steps;
        p.quadraticBezierTo(
          (x + nx) / 2 + (rnd.nextDouble() - 0.5) * m * 0.05,
          (y + ny) / 2 + (rnd.nextDouble() - 0.5) * m * 0.05,
          nx,
          ny,
        );
        x = nx;
        y = ny;
      }
      return p;
    }

    Paint stroke(double width, Color col, double blur) => Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = col
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

    const double main = math.pi * 0.28;

    for (int i = 0; i < 7; i++) {
      final double x = -m * 0.2 + rnd.nextDouble() * w * 0.6;
      final double y = -m * 0.2 + rnd.nextDouble() * h * 0.9;
      final Path p = veinPath(x, y, main + (rnd.nextDouble() - 0.5) * 0.3, m * (1.0 + rnd.nextDouble() * 0.8), 7, 0.5);
      final double sw = m * (0.002 + rnd.nextDouble() * 0.005);
      c.drawPath(p, stroke(sw * 8, vein.withOpacity(0.10), sw * 6));
      c.drawPath(p, stroke(sw, vein.withOpacity(0.45 + rnd.nextDouble() * 0.3), sw * 0.6));
      for (int j = 0; j < 2; j++) {
        final Path q = veinPath(
          x + rnd.nextDouble() * m * 0.4,
          y + rnd.nextDouble() * m * 0.4,
          main + 0.6 + (rnd.nextDouble() - 0.5) * 0.4,
          m * 0.35,
          4,
          0.6,
        );
        c.drawPath(q, stroke(sw * 0.6, vein.withOpacity(0.35), sw * 0.5));
      }
    }

    // gold veins
    for (int i = 0; i < 2; i++) {
      final double x = -m * 0.1 + rnd.nextDouble() * w * 0.5;
      final double y = -m * 0.1 + rnd.nextDouble() * h * 0.5;
      final Path p = veinPath(x, y, main + (rnd.nextDouble() - 0.5) * 0.25, m * 1.6, 8, 0.45);
      final double sw = m * (0.004 + rnd.nextDouble() * 0.003);
      c.drawPath(p, stroke(sw * 5, gold.withOpacity(0.16), sw * 4));
      c.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_shade(gold, 0.25), gold, _shade(gold, -0.15), _shade(gold, 0.2)],
          ).createShader(rect),
      );
    }

    // polished gloss
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.25, 0.45, 0.65],
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(dark ? 0.08 : 0.18),
            Colors.white.withOpacity(0),
          ],
        ).createShader(rect),
    );
    _glow(c, rect, Alignment.center, 0.5, Colors.white, dark ? 0.05 : 0.10);
    _vignette(c, rect, dark ? 0.4 : 0.10);
  }

  /// Dark stage with a soft light beam from above + floating dust
  static void _stageBeam(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color light = t.colors.length > 1 ? t.colors[1] : const Color(0xffF5D38A);

    _vGrad(c, rect, [_shade(base, 0.03), base, _shade(base, -0.03)]);

    final Path cone = Path()
      ..moveTo(w * 0.44, -m * 0.02)
      ..lineTo(w * 0.56, -m * 0.02)
      ..lineTo(w * 0.95, h * 1.02)
      ..lineTo(w * 0.05, h * 1.02)
      ..close();
    c.drawPath(
      cone,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light.withOpacity(0.45), light.withOpacity(0.12), light.withOpacity(0.02)],
        ).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.05),
    );

    // source glow at the top
    _glow(c, rect, const Alignment(0, -1), 0.5, Color.lerp(light, Colors.white, 0.5)!, 0.6);

    // lit floor pool
    final Rect fl = Rect.fromLTRB(w * 0.12, h * 0.74, w * 0.88, h);
    c.drawOval(
      fl,
      Paint()
        ..shader = RadialGradient(
          radius: 0.75,
          colors: [light.withOpacity(0.40), light.withOpacity(0)],
        ).createShader(fl)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.03),
    );

    // dust in the beam
    final math.Random rnd = math.Random(2);
    final Color dust = Color.lerp(light, Colors.white, 0.6)!;
    for (int i = 0; i < 160; i++) {
      final double y = rnd.nextDouble() * h;
      final double half = (0.06 + 0.39 * y / h) * w;
      final double x = w / 2 + (rnd.nextDouble() * 2 - 1) * half;
      c.drawCircle(
        Offset(x, y),
        m * (0.0012 + rnd.nextDouble() * 0.0028),
        Paint()
          ..isAntiAlias = true
          ..color = dust.withOpacity(0.15 + rnd.nextDouble() * 0.5),
      );
    }

    _vignette(c, rect, 0.6);
  }

  /// Molten metal folds — gold / rose gold / silver with bright specular
  static void _liquidMetal(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color light = t.colors.length > 1 ? t.colors[1] : _shade(base, 0.3);
    final Color shadow = t.colors.length > 2 ? t.colors[2] : _shade(base, -0.35);
    final math.Random rnd = math.Random(4);

    _dGrad(c, rect, [_shade(base, 0.10), base, _shade(base, -0.15)]);

    c.save();
    c.translate(w / 2, h / 2);
    c.rotate(-0.5236); // 30°
    c.translate(-w / 2, -h / 2);

    const int n = 8;
    for (int i = 0; i < n; i++) {
      final double y = h * (-0.3 + i * 1.6 / (n - 1));
      final double amp = m * (0.12 + rnd.nextDouble() * 0.12);
      final Path p = Path()
        ..moveTo(-w * 0.4, y)
        ..cubicTo(w * 0.1, y - amp, w * 0.6, y + amp, w * 1.4, y - amp * 0.3);
      final double th = m * (0.08 + rnd.nextDouble() * 0.06);

      c.drawPath(
        p.shift(Offset(0, th * 0.6)),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = th
          ..color = shadow.withOpacity(0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, th * 0.35),
      );
      c.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = th * 0.5
          ..color = light.withOpacity(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, th * 0.22),
      );
      c.drawPath(
        p.shift(Offset(0, -th * 0.08)),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = th * 0.10
          ..color = Colors.white.withOpacity(0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, th * 0.05),
      );
    }

    c.restore();

    // calmer centre so the jewellery stands out
    _glow(c, rect, Alignment.center, 0.45, base, 0.55);
    _vignette(c, rect, 0.4);
  }

  /// Night sky of soft hexagon (lens) bokeh + diamond star glints
  static void _sparkle(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color base = t.colors[0];
    final Color light = t.colors.length > 1 ? t.colors[1] : Colors.white;
    final math.Random rnd = math.Random(6);

    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.8,
          colors: [_shade(base, 0.08), base, _shade(base, -0.05)],
        ).createShader(rect),
    );

    for (int i = 0; i < 34; i++) {
      final double x = rnd.nextDouble() * w;
      final double y = rnd.nextDouble() * h;
      final double dd = (Offset(x, y) - rect.center).distance / (m * 0.5);
      final double r = m * (0.02 + rnd.nextDouble() * 0.06);
      final double op = (0.08 + rnd.nextDouble() * 0.25) * (dd < 0.55 ? 0.25 : 1);
      final Path hex = Path();
      for (int k = 0; k < 6; k++) {
        final double a = k * math.pi / 3 + 0.3;
        final Offset pt = Offset(x + math.cos(a) * r, y + math.sin(a) * r);
        if (k == 0) {
          hex.moveTo(pt.dx, pt.dy);
        } else {
          hex.lineTo(pt.dx, pt.dy);
        }
      }
      hex.close();
      c.drawPath(
        hex,
        Paint()
          ..isAntiAlias = true
          ..color = Color.lerp(light, Colors.white, rnd.nextDouble() * 0.5)!.withOpacity(op)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
      );
    }

    // star glints (not in the middle)
    final Color glintGlow = Color.lerp(light, Colors.white, 0.5)!;
    for (int i = 0; i < 7; i++) {
      final double x = rnd.nextDouble() * w;
      final double y = rnd.nextDouble() * h;
      if ((Offset(x, y) - rect.center).distance < m * 0.3) continue;
      final double sz = m * (0.014 + rnd.nextDouble() * 0.02);
      for (final List<double> d in const [
        [1.0, 0.0],
        [0.0, 1.0],
      ]) {
        final double dx = d[0], dy = d[1];
        c.drawPath(
          Path()
            ..moveTo(x - dx * sz, y - dy * sz)
            ..lineTo(x + dy * sz * 0.08, y + dx * sz * 0.08)
            ..lineTo(x + dx * sz, y + dy * sz)
            ..lineTo(x - dy * sz * 0.08, y - dx * sz * 0.08)
            ..close(),
          Paint()
            ..isAntiAlias = true
            ..color = Colors.white.withOpacity(0.85),
        );
      }
      c.drawCircle(
        Offset(x, y),
        sz * 0.5,
        Paint()
          ..color = glintGlow.withOpacity(0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 0.3),
      );
    }

    _glow(c, rect, const Alignment(0, -0.1), 0.4, Colors.white, 0.07);
    _vignette(c, rect, 0.45);
  }

  /// Dark glossy table with a warm light glow, soft bokeh behind and
  /// a glossy reflection pool — like a luxury night-time product shot
  static void _glowTable(Canvas c, Size s, BgTemplate t) {
    final Rect rect = Offset.zero & s;
    final double w = s.width, h = s.height;
    final double m = s.shortestSide;
    final Color back = t.colors[0];
    final Color table = t.colors.length > 1 ? t.colors[1] : _shade(back, 0.08);
    final Color glow = t.colors.length > 2 ? t.colors[2] : (t.accent ?? const Color(0xffFF9A3C));
    final Color? tint = t.colors.length > 3 ? t.colors[3] : null;
    final double hz = h * 0.42; // table edge (blurred, no hard line)
    final double gx = w * (t.flip ? 0.90 : 0.10);
    final double dirX = t.flip ? -1 : 1; // bokeh spreads away from light
    final Color warmWhite = Color.lerp(glow, Colors.white, 0.35)!;

    // wall → table (soft depth-of-field blend)
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.36, 0.5, 1],
          colors: [
            back,
            Color.lerp(back, table, 0.6)!,
            table,
            Color.lerp(table, Colors.black, 0.5)!,
          ],
        ).createShader(rect),
    );

    // main light source
    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(gx / w * 2 - 1, hz * 0.5 / h * 2 - 1),
          radius: 0.9, // fraction of the shortest side
          stops: const [0, 0.16, 0.55, 1],
          colors: [
            Color.lerp(glow, Colors.white, 0.3)!.withOpacity(0.95),
            glow.withOpacity(0.55),
            glow.withOpacity(0.12),
            glow.withOpacity(0),
          ],
        ).createShader(rect),
    );

    // second colour light on the other side (optional)
    if (tint != null) {
      _glow(c, rect, Alignment((w - gx) / w * 2 - 1, hz * 0.6 / h * 2 - 1), 0.6, tint, 0.40);
    }

    // soft bokeh orbs on the back wall
    final math.Random rnd = math.Random(3);
    for (int i = 0; i < 10; i++) {
      final double x = gx + dirX * math.pow(rnd.nextDouble(), 1.4).toDouble() * w * 0.8;
      final double y = hz * (0.05 + rnd.nextDouble() * 0.75);
      final double r = m * (0.025 + rnd.nextDouble() * 0.05);
      final double near = math.max(0.0, 1 - (x - gx).abs() / (w * 0.8));
      final double op = (0.10 + rnd.nextDouble() * 0.22) * (0.35 + near);
      c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..isAntiAlias = true
          ..color = warmWhite.withOpacity(op.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
      );
    }

    // sheen across the table edge (no hard horizon)
    final Rect band = Rect.fromLTWH(0, hz - m * 0.12, w, m * 0.42);
    c.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.3, 1],
          colors: [
            glow.withOpacity(0),
            Color.lerp(glow, Colors.white, 0.3)!.withOpacity(0.16),
            glow.withOpacity(0),
          ],
        ).createShader(band),
    );

    // glossy reflection pool under the light
    final Rect pool = Rect.fromLTRB(gx - m * 0.40, hz - m * 0.05, gx + m * 0.40, hz + m * 0.60);
    c.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 0.65,
          colors: [glow.withOpacity(0.50), glow.withOpacity(0)],
        ).createShader(pool)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.04),
    );

    // light streaks reflected on the glossy surface
    for (int i = 0; i < 3; i++) {
      final double x = gx + dirX * m * (0.04 + i * 0.12);
      final double ww = m * 0.03;
      final Rect st = Rect.fromLTRB(x - ww, hz, x + ww, hz + m * 0.45);
      c.drawRect(
        st,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [warmWhite.withOpacity(0.28 - i * 0.07), glow.withOpacity(0)],
          ).createShader(st)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.035),
      );
    }

    // fine leather / matte grain on the table
    final math.Random g = math.Random(9);
    final List<Offset> pts = List.generate(
      7000,
          (_) => Offset(g.nextDouble() * w, hz + g.nextDouble() * (h - hz)),
    );
    c.drawPoints(
      ui.PointMode.points,
      pts.sublist(0, 3500),
      Paint()
        ..color = Colors.white.withOpacity(0.035)
        ..strokeWidth = m * 0.0017,
    );
    c.drawPoints(
      ui.PointMode.points,
      pts.sublist(3500),
      Paint()
        ..color = Colors.black.withOpacity(0.07)
        ..strokeWidth = m * 0.0017,
    );

    _vignette(c, rect, 0.5);
  }
}

/// ================================================================
/// 👀 PREVIEW — template tile (fakt background)
/// ================================================================

class BgTemplateView extends StatelessWidget {
  const BgTemplateView({Key? key, required this.template, this.floorY})
      : super(key: key);

  final BgTemplate template;
  final double? floorY;

  @override
  Widget build(BuildContext context) {
    if (template.isImage) {
      if (template.assetPath != null) {
        return Image.asset(
          template.assetPath!,
          fit: BoxFit.cover,
          cacheWidth: 400,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.grey),
        );
      }

      if (template.filePath != null) {
        return Image.file(
          File(template.filePath!),
          fit: BoxFit.cover,
          cacheWidth: 400,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.grey),
        );
      }
    }

    return SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(painter: _BgPainter(template, floorY)),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter(this.t, this.floorY);

  final BgTemplate t;
  final double? floorY;

  @override
  void paint(Canvas canvas, Size size) =>
      BgTemplatePainter.paint(canvas, size, t, floorY: floorY);

  @override
  bool shouldRepaint(_BgPainter old) =>
      old.t.id != t.id || old.floorY != floorY;
}

/// ================================================================
/// 💎 PREVIEW — background + jewellery (grid card mate)
///
/// Final share image jevu j layout: podium par besaade,
/// mirror ma reflection, floor par contact shadow.
/// (Aa fakt screen par dekhadva — share / PDF ni quality par
///  asar nathi)
/// ================================================================

class JewelOnBackground extends StatelessWidget {
  const JewelOnBackground({
    Key? key,
    required this.template,
    required this.png,
    this.shadow = true,
  }) : super(key: key);

  final BgTemplate template;
  final File png;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final double w = box.maxWidth;
        final double h = box.maxHeight;
        final double m = math.min(w, h);
        final double pad = m * 0.08;
        final double bottom = pad + m * template.floorPad;
        final double floorY = h - bottom;
        final bool onFloor = template.onFloor;

        Widget jewel() => Image.file(
          png,
          fit: BoxFit.contain,
          alignment: onFloor ? Alignment.bottomCenter : Alignment.center,
          cacheWidth: 450,
          gaplessPlayback: true,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            BgTemplateView(template: template, floorY: floorY),

            /// REFLECTION
            if (template.reflection)
              Positioned(
                left: pad,
                right: pad,
                top: floorY,
                height: h - pad - bottom,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: template.isDark ? 0.30 : 0.22,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.45],
                        colors: [Colors.white, Colors.transparent],
                      ).createShader(r),
                      child: Transform.flip(flipY: true, child: jewel()),
                    ),
                  ),
                ),
              ),

            /// CONTACT SHADOW (floor par)
            if (onFloor && shadow)
              Positioned(
                left: w * 0.22,
                right: w * 0.22,
                top: floorY - m * 0.025,
                height: m * 0.05,
                child: const IgnorePointer(
                  child: CustomPaint(painter: _ContactShadowPainter()),
                ),
              ),

            /// JEWELLERY
            Positioned(
              left: pad,
              right: pad,
              top: pad,
              bottom: bottom,
              child: jewel(),
            ),
          ],
        );
      },
    );
  }
}

class _ContactShadowPainter extends CustomPainter {
  const _ContactShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.4),
    );
  }

  @override
  bool shouldRepaint(_ContactShadowPainter old) => false;
}

/// ================================================================
/// ✂️ PNG TRIM (isolate) — aaspas ni khali transparent jagya kadhe
/// Etle jewellery barabar podium / floor par bese.
/// (PNG = lossless — quality par koi asar nathi)
/// ================================================================

Uint8List _trimPngIsolate(Uint8List bytes) {
  try {
    final img.Image? im = img.decodePng(bytes);
    if (im == null) return bytes;

    final img.Image trimmed = img.trim(im, mode: img.TrimMode.transparent);

    if (trimmed.width < 4 || trimmed.height < 4) return bytes;

    return Uint8List.fromList(img.encodePng(trimmed, level: 1));
  } catch (_) {
    return bytes;
  }
}

/// ================================================================
/// 🧩 COMPOSER — transparent PNG + template + shadow → JPG (HQ)
/// ================================================================

class BgComposer {
  BgComposer._();

  /// 🔥 Final JPG quality (pachi caption ma farithi JPG thay che,
  /// etle ahiya lagbhag lossless rakhvi)
  static const int jpgQuality = 97;

  /// 🔥 Gallery / asset background ni max size
  static const int maxBgImageWidth = 2400;

  static String? _bgImageKey;
  static ui.Image? _bgImage;

  /// Background remove pachi ek vaar call karo
  static Future<Uint8List> trimTransparent(Uint8List png) =>
      compute(_trimPngIsolate, png);

  /// Gallery / asset background — moti hoy to j nani (nani ne moti nahi)
  static Future<ui.Image?> _loadTemplateImage(BgTemplate t) async {
    if (_bgImageKey == t.id && _bgImage != null) return _bgImage;

    Uint8List? bytes;

    if (t.assetPath != null) {
      final ByteData data = await rootBundle.load(t.assetPath!);
      bytes = data.buffer.asUint8List();
    } else if (t.filePath != null) {
      bytes = await File(t.filePath!).readAsBytes();
    }

    if (bytes == null) return null;

    final ui.ImmutableBuffer buf = await ui.ImmutableBuffer.fromUint8List(bytes);
    final ui.ImageDescriptor desc = await ui.ImageDescriptor.encoded(buf);

    final ui.Codec codec = await desc.instantiateCodec(
      targetWidth: desc.width > maxBgImageWidth ? maxBgImageWidth : null,
    );

    final ui.Image image = (await codec.getNextFrame()).image;

    codec.dispose();
    desc.dispose();
    buf.dispose();

    /// Juni cache image memory mathi kadho
    _bgImage?.dispose();

    _bgImageKey = t.id;
    _bgImage = image;

    return image;
  }

  /// Jewellery 1:1 size par (koi resize nahi) background par mukay
  static Future<Uint8List> compose(
      Uint8List transparentPng,
      BgTemplate template, {
        bool shadow = true,
        double paddingFactor = 0.08,
        int quality = jpgQuality,
      }) async {
    final ui.Codec codec = await ui.instantiateImageCodec(transparentPng);
    final ui.Image jewel = (await codec.getNextFrame()).image;
    codec.dispose();

    final double jw = jewel.width.toDouble();
    final double jh = jewel.height.toDouble();
    final double big = math.max(jw, jh);
    final double pad = big * paddingFactor;
    final double padBottom = pad + big * template.floorPad;

    final double outW = jw + pad * 2;
    final double outH = jh + pad + padBottom;

    final Rect src = Rect.fromLTWH(0, 0, jw, jh);
    final Rect dst = Rect.fromLTWH(pad, pad, jw, jh);

    final ui.Image? bgImage =
    template.isImage ? await _loadTemplateImage(template) : null;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

    // 1) BACKGROUND
    BgTemplatePainter.paint(
      canvas,
      Size(outW, outH),
      template,
      image: bgImage,
      floorY: dst.bottom,
    );

    // 2) REFLECTION (mirror floor)
    if (template.reflection) {
      final Rect reflRect =
      Rect.fromLTWH(0, dst.bottom, outW, outH - dst.bottom);

      canvas.saveLayer(reflRect, Paint());
      canvas.save();
      canvas.translate(0, dst.bottom * 2);
      canvas.scale(1, -1);
      canvas.drawImageRect(
        jewel,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Colors.white.withOpacity(template.isDark ? 0.30 : 0.22),
      );
      canvas.restore();

      canvas.drawRect(
        reflRect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.8],
            colors: [Colors.white, Colors.transparent],
          ).createShader(reflRect),
      );
      canvas.restore();
    }

    // 3) SHADOW
    if (shadow) {
      if (template.onFloor) {
        // Floor par contact shadow
        final Rect contact = Rect.fromCenter(
          center: Offset(dst.center.dx, dst.bottom - big * 0.005),
          width: jw * 0.75,
          height: big * 0.05,
        );

        canvas.drawOval(
          contact,
          Paint()
            ..color = Colors.black.withOpacity(template.isDark ? 0.45 : 0.22)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, big * 0.02),
        );
      } else {
        final double sigma = big * 0.012;

        canvas.drawImageRect(
          jewel,
          src,
          dst.shift(Offset(0, big * 0.015)),
          Paint()
            ..colorFilter = ColorFilter.mode(
              Colors.black.withOpacity(template.isDark ? 0.55 : 0.28),
              BlendMode.srcIn,
            )
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        );
      }
    }

    // 4) JEWELLERY (1:1 — koi resize nahi)
    canvas.drawImageRect(
      jewel,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );

    final ui.Picture picture = recorder.endRecording();
    final int w = outW.round();
    final int h = outH.round();

    final ui.Image out = await picture.toImage(w, h);
    final ByteData? raw =
    await out.toByteData(format: ui.ImageByteFormat.rawRgba);

    jewel.dispose();
    out.dispose();
    picture.dispose();

    if (raw == null) throw Exception("Compose failed");

    /// 🔥 HQ JPG (97)
    return compute(encodeRgbaToJpgIsolate, {
      "w": w,
      "h": h,
      "rgba": raw.buffer.asUint8List(),
      "q": quality,
    });
  }
}

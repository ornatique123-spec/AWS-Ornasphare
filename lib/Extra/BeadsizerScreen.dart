import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../Extra/AppColors.dart';

/// ================================================================
/// 💎 GB BEAD SIZER — ERP THEME (PHONE + FOLD + TAB RESPONSIVE)
///
/// - Bead size have screen/DPR par nahi, preview box par depend kare che
///   → phone, fold, tablet (portrait / landscape) badhe SAME proportion
/// - Phone par look pehla jevo j
/// - Circle hamesha perfect gol (oval / cut nahi thay)
/// - Volume calculation, slider, size list, decimal logic BILKUL SAME
/// ================================================================

class BeadSizerScreen extends StatefulWidget {
  const BeadSizerScreen({super.key});

  @override
  State<BeadSizerScreen> createState() => _BeadSizerScreenState();
}

class _BeadSizerScreenState extends State<BeadSizerScreen> {
  // ============================================================
  // ORIGINAL FUNCTIONALITY
  // ============================================================

  double _diameter = 1.0;
  int? _expandedIndex;

  // ============================================================
  // 💎 ERP BLUE PREMIUM PALETTE
  // ============================================================

  static const Color _bNavy = Color(0xff0B1E4A);
  static const Color _bRoyal = Color(0xff1E4FD8);
  static const Color _bSky = Color(0xff5B93FF);
  static const Color _bIce = Color(0xffEEF4FF);
  static const Color _bLine = Color(0xffDCE6FA);
  static const Color _bText = Color(0xff5C6B8A);

  static const Color _goldColor = Color(0xFFB99852);
  static const Color _goldDark = Color(0xFF9A793A);

  // ============================================================
  // RESPONSIVE SETTINGS
  // ============================================================

  /// Ketla mm ni bead preview box ne puri bhari de.
  /// 33 rakhvathi phone par look pehla jevo j rahe che.
  /// Jo 1 thi 50 badhi size ma farak dekhavo joie to 50 karo.
  static const double _fillMm = 33.0;

  /// Preview box nu width : height ratio (phone par ≈ 340 x 180)
  static const double _previewAspect = 1.9;

  /// Preview box screen ni height na ketla % thi vadhu nahi thay
  /// (tab landscape / fold ma list mate jagya rahe)
  static const double _previewMaxHeightFactor = 0.38;

  static const double _previewMinHeight = 140;

  // ============================================================
  // TAB / FOLD SETTINGS (phone par aa lagu nathi thatu)
  // ============================================================

  /// Screen ni nani baju aa thi moti hoy to Tab / Fold ganvu
  static const double _tabBreakpoint = 600;

  /// Phone par 1 mm ≈ 5.2 px dekhay che (171 px box / 33 mm).
  /// Tab / Fold par pan same j rakhiye etle bead phone jevi j dekhay.
  static const double _tabPxPerMm = 5.2;

  /// Tab par preview box bahu moto na thay (50 mm = 260 px samay jay)
  static const double _tabPreviewMaxHeight = 280;

  bool _isTabOrFold(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= _tabBreakpoint;

  // ============================================================
  // ORIGINAL BEAD VOLUME CALCULATION — NO CHANGE
  // ============================================================

  double calculateBeadVolume(double diameter) {
    double radius = diameter / 2;

    return (4 / 3) * 3.1416 * radius * radius * radius;
  }

  // ============================================================
  // ORIGINAL MM TO PIXEL CALCULATION — NO CHANGE
  // ============================================================

  double mmToPixels(double mm, BuildContext context) {
    double dpi = MediaQuery.of(context).devicePixelRatio * 160;

    double inches = mm / 25.4;

    return inches * dpi;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    double volume = calculateBeadVolume(_diameter);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  /// Card ni width (left + right padding 10 + 10)
                  final double cardWidth = constraints.maxWidth - 20;

                  /// Preview height: width pramane, pan screen height
                  /// na 38% thi vadhu nahi
                  double previewHeight = cardWidth / _previewAspect;
                  previewHeight = math.min(
                    previewHeight,
                    constraints.maxHeight * _previewMaxHeightFactor,
                  );
                  previewHeight = math.max(previewHeight, _previewMinHeight);

                  /// 🔥 Fakt Tab / Fold: box bahu moto na thay
                  if (_isTabOrFold(context)) {
                    previewHeight =
                        math.min(previewHeight, _tabPreviewMaxHeight);
                  }

                  /// Nani height (landscape / fold cover) ma hero hide
                  final bool showHero = constraints.maxHeight > 520;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: Column(
                          children: [
                            if (showHero) ...[
                              _buildHeroCard(),
                              const SizedBox(height: 10),
                            ],
                            _buildBeadCard(volume, previewHeight),
                            const SizedBox(height: 12),
                            _buildSizeHeader(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                          child: _buildSizeList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER — back + title + MM chip
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "GB Bead Sizer",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              "Unit: MM",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bNavy, _bRoyal, _bSky],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _bRoyal.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -45,
            right: -30,
            child: _glowCircle(110, 0.10),
          ),
          Positioned(
            bottom: -55,
            right: 60,
            child: _glowCircle(90, 0.07),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.4,
                  ),
                ),
                child: const Icon(
                  Icons.straighten_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bead Size Guide",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Select the required diameter and compare the bead size.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  // ============================================================
  // BEAD CARD
  // ============================================================

  Widget _buildBeadCard(double volume, double previewHeight) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          /// TOP INFO — diameter + volume
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Selected Diameter",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _diameter.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 2),
                            child: Text(
                              "mm",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _bIce,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Volume",
                        style: TextStyle(
                          color: _bText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${volume.toStringAsFixed(2)} mm³",
                        style: const TextStyle(
                          color: _bNavy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.border),

          /// ACTUAL BEAD PREVIEW (box pramane size)
          SizedBox(
            height: previewHeight,
            child: LayoutBuilder(
              builder: (context, box) {
                /// Box ma fit thay evo sauthi moto square
                final double maxCircle = math.max(
                  0.0,
                  math.min(box.maxWidth - 36, box.maxHeight - 8),
                );

                /// 1 mm = ketla px — box pramane, device pramane nahi
                final double pxPerMm = _isTabOrFold(context)
                    ? _tabPxPerMm
                    : maxCircle / _fillMm;

                final double circleSize =
                math.min(_diameter * pxPerMm, maxCircle);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    /// HORIZONTAL GUIDE
                    Positioned(
                      left: 18,
                      right: 18,
                      child: Container(height: 1, color: _bLine),
                    ),

                    /// VERTICAL GUIDE
                    Positioned(
                      top: 14,
                      bottom: 14,
                      child: Container(width: 1, color: _bLine),
                    ),

                    /// CIRCLE — width & height hamesha same
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.35, -0.40),
                          radius: 0.9,
                          colors: [
                            Color(0xFFFFFAEC),
                            Color(0xFFEAD294),
                            Color(0xFFB8944D),
                          ],
                          stops: [0.05, 0.58, 1.0],
                        ),
                        border: Border.all(color: _goldDark, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _goldColor.withOpacity(0.18),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                          const BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),

                    /// SIZE LABEL
                    Positioned(
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          "Ø ${_diameter.toStringAsFixed(1)} mm",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          /// SLIDER AREA
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "1 mm",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Drag to adjust",
                      style: TextStyle(color: Colors.black45, fontSize: 10),
                    ),
                    Text(
                      "50 mm",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primaryDark,
                    inactiveTrackColor: _bLine,
                    trackHeight: 4,
                    thumbColor: Colors.white,
                    overlayColor: AppColors.primaryDark.withOpacity(0.10),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                      elevation: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    min: 1,
                    max: 50,
                    value: _diameter,
                    onChanged: (value) {
                      setState(() {
                        _diameter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIZE HEADER
  // ============================================================

  Widget _buildSizeHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Size Reference",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Tap any size to select • Tap again to close decimals",
                style: TextStyle(color: Colors.black54, fontSize: 10.5),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            "${_diameter.toStringAsFixed(1)} mm",
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SIZE LIST
  // ============================================================

  Widget _buildSizeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 50,
          itemBuilder: (context, index) {
            final int size = index + 1;
            return _buildMainSizeRow(size);
          },
        ),
      ),
    );
  }

  // ============================================================
  // MAIN SIZE ROW
  // ============================================================

  Widget _buildMainSizeRow(int size) {
    final bool isExpanded = _expandedIndex == size;

    final bool isSelected =
        _diameter.toStringAsFixed(1) == size.toDouble().toStringAsFixed(1);

    return Column(
      children: [
        Material(
          color: isSelected
              ? AppColors.primaryDark.withOpacity(0.06)
              : Colors.white,
          child: InkWell(
            onTap: () {
              setState(() {
                if (_expandedIndex == size) {
                  _expandedIndex = null;
                } else {
                  _expandedIndex = size;
                }

                _diameter = size.toDouble();
              });
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.primaryDark.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$size",
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Indian Size $size",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpanded
                              ? "Select decimal size below"
                              : "Tap to select & view decimals",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${size.toStringAsFixed(1)} mm",
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryDark
                          : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isSelected
                          ? AppColors.primaryDark
                          : Colors.black45,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildSubSizeSection(size),
          crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (size != 50) Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  // ============================================================
  // SUB SIZE SECTION — SAME 0.1 → 0.9 LOGIC
  // ============================================================

  Widget _buildSubSizeSection(int mainSize) {
    return Container(
      width: double.infinity,
      color: _bIce,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: List.generate(9, (index) {
          double subSize = mainSize + (index + 1) * 0.1;

          bool isSelected =
              _diameter.toStringAsFixed(1) == subSize.toStringAsFixed(1);

          return _buildSubSizeChip(subSize, isSelected);
        }),
      ),
    );
  }

  // ============================================================
  // SUB SIZE CHIP
  // ============================================================

  Widget _buildSubSizeChip(double size, bool isSelected) {
    return Material(
      color: isSelected ? AppColors.primaryDark : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _diameter = size;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 62,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : _bLine,
            ),
          ),
          child: Text(
            size.toStringAsFixed(1),
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

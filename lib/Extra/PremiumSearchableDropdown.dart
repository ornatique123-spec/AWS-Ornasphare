import 'package:flutter/material.dart';

import 'AppColors.dart';

class PremiumSearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;

  final List<T> items;
  final T? value;

  /// Dropdown માં બતાવવાનું text
  final String Function(T item) itemLabel;

  /// Search માટે custom searchable text
  final String Function(T item)? searchText;

  final ValueChanged<T?> onChanged;

  final bool enabled;
  final bool requiredField;

  final IconData? prefixIcon;

  final double? width;

  /// Maximum dropdown height
  final double dropdownMaxHeight;

  /// ✅ Dropdown (popup) ni width — na aapo to field jetli j.
  /// Field karta nani hoy to field jetli j rahe.
  final double? menuWidth;

  const PremiumSearchableDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onChanged,
    this.searchText,
    this.enabled = true,
    this.requiredField = false,
    this.prefixIcon,
    this.width,
    this.dropdownMaxHeight = 300,
    this.menuWidth,
  });

  @override
  State<PremiumSearchableDropdown<T>> createState() =>
      _PremiumSearchableDropdownState<T>();
}

class _PremiumSearchableDropdownState<T>
    extends State<PremiumSearchableDropdown<T>>
    with WidgetsBindingObserver {
  /// ============================================================
  /// KEY
  /// ============================================================

  final GlobalKey _fieldKey = GlobalKey();

  /// ============================================================
  /// SEARCH
  /// ============================================================

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  /// ============================================================
  /// OVERLAY
  /// ============================================================

  OverlayEntry? _overlayEntry;

  bool isDropdownOpen = false;

  /// ============================================================
  /// DATA
  /// ============================================================

  List<T> filteredItems = [];

  /// Field position
  Size _fieldSize = Size.zero;

  Offset _fieldPosition = Offset.zero;

  /// ============================================================
  /// INIT
  /// ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    filteredItems =
    List<T>.from(widget.items);
  }

  /// ============================================================
  /// UPDATE ITEMS
  /// ============================================================

  @override
  void didUpdateWidget(
      covariant PremiumSearchableDropdown<T> oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items != widget.items) {
      filteredItems = List<T>.from(widget.items);

      /// IMPORTANT:
      /// didUpdateWidget build phase દરમિયાન call થઈ શકે છે.
      /// એટલે markNeedsBuild() direct call નહીં કરવો.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_overlayEntry != null &&
            isDropdownOpen) {
          _overlayEntry?.markNeedsBuild();
        }
      });
    }
  }

  /// ============================================================
  /// KEYBOARD / METRICS CHANGE
  /// ============================================================

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    if (!isDropdownOpen) {
      return;
    }

    /// Keyboard animation complete થવા માટે
    /// next frame પર overlay rebuild
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!mounted) {
          return;
        }

        if (!isDropdownOpen) {
          return;
        }

        _overlayEntry?.markNeedsBuild();
      },
    );
  }

  /// ============================================================
  /// TOGGLE
  /// ============================================================

  void _toggleDropdown() {
    if (!widget.enabled) {
      return;
    }

    if (isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  /// ============================================================
  /// GET FIELD POSITION
  /// ============================================================

  bool _updateFieldPosition() {
    final BuildContext? fieldContext =
        _fieldKey.currentContext;

    if (fieldContext == null) {
      return false;
    }

    final RenderObject? renderObject =
    fieldContext.findRenderObject();

    if (renderObject == null) {
      return false;
    }

    if (renderObject is! RenderBox) {
      return false;
    }

    if (!renderObject.attached) {
      return false;
    }

    try {
      _fieldSize =
          renderObject.size;

      _fieldPosition =
          renderObject.localToGlobal(
            Offset.zero,
          );

      return true;
    } catch (e) {
      debugPrint(
        "Dropdown position error: $e",
      );

      return false;
    }
  }

  /// ============================================================
  /// OPEN DROPDOWN
  /// ============================================================

  void _openDropdown() {
    if (_overlayEntry != null) {
      return;
    }

    /// Existing keyboard close
    FocusManager.instance.primaryFocus
        ?.unfocus();

    /// Get position
    final bool positionAvailable =
    _updateFieldPosition();

    if (!positionAvailable) {
      return;
    }

    /// Reset search
    _searchController.clear();

    filteredItems =
    List<T>.from(widget.items);

    /// Create overlay
    _overlayEntry =
        _createOverlayEntry();

    /// Root overlay
    final OverlayState overlay =
    Overlay.of(
      context,
      rootOverlay: true,
    );

    overlay.insert(
      _overlayEntry!,
    );

    if (mounted) {
      setState(() {
        isDropdownOpen = true;
      });
    }

    /// IMPORTANT:
    /// અહીં requestFocus નથી.
    ///
    /// Dropdown open થાય ત્યારે keyboard નહીં આવે.
    /// Search field tap કર્યા પછી જ keyboard આવશે.
  }

  /// ============================================================
  /// CLOSE DROPDOWN
  /// ============================================================

  void _closeDropdown() {
    _searchFocusNode.unfocus();

    try {
      _overlayEntry?.remove();
    } catch (e) {
      debugPrint(
        "Dropdown remove error: $e",
      );
    }

    _overlayEntry = null;

    if (mounted) {
      setState(() {
        isDropdownOpen = false;
      });
    }
  }

  /// ============================================================
  /// SEARCH
  /// ============================================================

  void _search(String value) {
    final String query =
    value
        .trim()
        .toLowerCase();

    if (query.isEmpty) {
      filteredItems =
      List<T>.from(widget.items);
    } else {
      filteredItems =
          widget.items.where(
                (item) {
              final String text =
              widget.searchText != null
                  ? widget.searchText!(
                item,
              )
                  : widget.itemLabel(
                item,
              );

              return text
                  .toLowerCase()
                  .contains(
                query,
              );
            },
          ).toList();
    }

    _overlayEntry
        ?.markNeedsBuild();
  }

  /// ============================================================
  /// 🔍 KEYBOARD NU SEARCH BUTTON
  ///
  /// - Lakhela text thi list filter
  /// - Ek j item male, athva naam barabar match thay → select + close
  /// - Vadhare male → keyboard band, list dekhay (user pasand kare)
  /// ============================================================

  void _onSearchSubmitted(String value) {
    _search(value);

    final String query = value.trim().toLowerCase();

    if (query.isEmpty) {
      _searchFocusNode.unfocus();
      return;
    }

    T? pick;

    if (filteredItems.length == 1) {
      pick = filteredItems.first;
    } else {
      for (final T item in filteredItems) {
        if (widget.itemLabel(item).trim().toLowerCase() == query) {
          pick = item;
          break;
        }
      }
    }

    if (pick != null) {
      widget.onChanged(pick);
      _closeDropdown();
      return;
    }

    // Vadhare items → keyboard band kari ne list puri dekhay
    _searchFocusNode.unfocus();
    _overlayEntry?.markNeedsBuild();
  }

  /// ============================================================
  /// CREATE OVERLAY
  /// ============================================================

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final MediaQueryData mediaQuery =
        MediaQuery.of(
          overlayContext,
        );

        final Size screenSize =
            mediaQuery.size;

        /// ======================================================
        /// KEYBOARD HEIGHT
        /// ======================================================

        final double keyboardHeight =
            mediaQuery
                .viewInsets
                .bottom;

        /// Screenનો usable bottom
        final double usableBottom =
            screenSize.height -
                keyboardHeight;

        /// Safe area top
        final double safeTop =
            mediaQuery.padding.top;

        /// ======================================================
        /// AVAILABLE SPACE
        /// ======================================================

        double spaceBelow =
            usableBottom -
                _fieldPosition.dy -
                _fieldSize.height -
                8;

        double spaceAbove =
            _fieldPosition.dy -
                safeTop -
                8;

        /// Negative space avoid
        if (spaceBelow < 0) {
          spaceBelow = 0;
        }

        if (spaceAbove < 0) {
          spaceAbove = 0;
        }

        /// ======================================================
        /// OPEN ABOVE OR BELOW
        /// ======================================================

        final bool showAbove =
            spaceBelow < 180 &&
                spaceAbove >
                    spaceBelow;

        final double availableHeight =
        showAbove
            ? spaceAbove
            : spaceBelow;

        /// જો keyboardના કારણે space બહુ ઓછી હોય
        if (availableHeight < 70) {
          return const SizedBox
              .shrink();
        }

        /// ======================================================
        /// DROPDOWN HEIGHT
        /// ======================================================

        double dropdownHeight =
            widget.dropdownMaxHeight;

        if (dropdownHeight >
            availableHeight) {
          dropdownHeight =
              availableHeight;
        }

        /// Extra screen safety
        if (dropdownHeight >
            screenSize.height) {
          dropdownHeight =
              screenSize.height;
        }

        /// IMPORTANT:
        /// અહીં minimum 100 / 120 force નથી કરતા.
        /// એટલે keyboard open થાય ત્યારે overflow નહીં આવે.

        /// ======================================================
        /// TOP POSITION
        /// ======================================================

        double topPosition;

        if (showAbove) {
          topPosition =
              _fieldPosition.dy -
                  dropdownHeight -
                  6;
        } else {
          topPosition =
              _fieldPosition.dy +
                  _fieldSize.height +
                  6;
        }

        /// Safe area protection
        if (topPosition <
            safeTop + 4) {
          topPosition =
              safeTop + 4;
        }

        /// ======================================================
        /// HORIZONTAL POSITION
        /// ======================================================

        double leftPosition =
            _fieldPosition.dx;

        double dropdownWidth =
            _fieldSize.width;

        /// ✅ menuWidth aapyu hoy to popup pahoLo (screen ma j rahe)
        if (widget.menuWidth != null &&
            widget.menuWidth! > dropdownWidth) {
          dropdownWidth = widget.menuWidth!;
        }

        if (dropdownWidth > screenSize.width - 10) {
          dropdownWidth = screenSize.width - 10;
        }

        /// Right side overflow protection
        if (leftPosition +
            dropdownWidth >
            screenSize.width - 5) {
          leftPosition =
              screenSize.width -
                  dropdownWidth -
                  5;
        }

        if (leftPosition < 5) {
          leftPosition = 5;
        }

        /// ======================================================
        /// OVERLAY
        /// ======================================================

        return Stack(
          children: [
            /// ==================================================
            /// OUTSIDE TAP
            /// ==================================================

            Positioned.fill(
              child:
              GestureDetector(
                behavior:
                HitTestBehavior
                    .translucent,
                onTap:
                _closeDropdown,
                child:
                const SizedBox
                    .expand(),
              ),
            ),

            /// ==================================================
            /// DROPDOWN
            /// ==================================================

            Positioned(
              left:
              leftPosition,
              top:
              topPosition,
              width:
              dropdownWidth,
              height:
              dropdownHeight,
              child:
              Material(
                color:
                Colors.transparent,
                child:
                Container(
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white,
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                    border:
                    Border.all(
                      color:
                      AppColors
                          .border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withOpacity(
                          0.15,
                        ),
                        blurRadius:
                        18,
                        spreadRadius:
                        1,
                        offset:
                        const Offset(
                          0,
                          6,
                        ),
                      ),
                    ],
                  ),
                  child:
                  ClipRRect(
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                    child:
                    Column(
                      children: [
                        /// =======================================
                        /// SEARCH
                        /// =======================================

                        Padding(
                          padding:
                          const EdgeInsets
                              .all(
                            8,
                          ),
                          child:
                          SizedBox(
                            height:
                            42,
                            child:
                            TextField(
                              controller:
                              _searchController,

                              focusNode:
                              _searchFocusNode,

                              onChanged:
                              _search,

                              /// ✅ Keyboard nu search button
                              onSubmitted:
                              _onSearchSubmitted,

                              /// IMPORTANT
                              scrollPadding:
                              EdgeInsets.zero,

                              textInputAction:
                              TextInputAction.search,

                              style:
                              const TextStyle(
                                color:
                                Colors.black87,
                                fontSize:
                                13,
                              ),

                              decoration:
                              InputDecoration(
                                hintText:
                                widget.label.isEmpty
                                    ? "Search..."
                                    : "Search ${widget.label}...",

                                hintStyle:
                                TextStyle(
                                  color: Colors
                                      .grey
                                      .shade500,
                                  fontSize:
                                  12,
                                ),

                                prefixIcon:
                                Icon(
                                  Icons
                                      .search_rounded,
                                  size:
                                  18,
                                  color:
                                  AppColors.primaryDark,
                                ),

                                suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _searchController.clear();

                                    _search(
                                      "",
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                  ),
                                )
                                    : null,

                                filled:
                                true,

                                fillColor:
                                Colors.grey.shade50,

                                isDense:
                                true,

                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal:
                                  10,
                                  vertical:
                                  10,
                                ),

                                border:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    7,
                                  ),
                                  borderSide:
                                  BorderSide(
                                    color:
                                    AppColors.border,
                                  ),
                                ),

                                enabledBorder:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    7,
                                  ),
                                  borderSide:
                                  BorderSide(
                                    color:
                                    AppColors.border,
                                  ),
                                ),

                                focusedBorder:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    7,
                                  ),
                                  borderSide:
                                  BorderSide(
                                    color:
                                    AppColors.primaryDark,
                                    width:
                                    1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// =======================================
                        /// DIVIDER
                        /// =======================================

                        Divider(
                          height:
                          1,
                          color:
                          AppColors.border,
                        ),

                        /// =======================================
                        /// COUNT
                        /// =======================================

                        Container(
                          width:
                          double.infinity,
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal:
                            12,
                            vertical:
                            6,
                          ),
                          child:
                          Text(
                            "${filteredItems.length} records found",
                            style:
                            TextStyle(
                              fontSize:
                              10,
                              color: Colors
                                  .grey
                                  .shade500,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ),

                        Divider(
                          height:
                          1,
                          color: Colors
                              .grey
                              .shade200,
                        ),

                        /// =======================================
                        /// LIST
                        /// =======================================

                        Expanded(
                          child:
                          filteredItems.isEmpty
                              ? _emptyWidget()
                              : ListView.separated(
                            padding: const EdgeInsets.only(
                              bottom: 5,
                            ),

                            keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,

                            itemCount:
                            filteredItems.length,

                            separatorBuilder: (
                                context,
                                index,
                                ) {
                              return Divider(
                                height: 1,
                                indent: 10,
                                endIndent: 10,
                                color: Colors.grey.shade200,
                              );
                            },

                            itemBuilder: (
                                context,
                                index,
                                ) {
                              final T item =
                              filteredItems[index];

                              final bool isSelected =
                              _isSelected(
                                item,
                              );

                              return _dropdownItem(
                                item: item,
                                isSelected: isSelected,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ============================================================
  /// DROPDOWN ITEM
  /// ============================================================

  Widget _dropdownItem({
    required T item,
    required bool isSelected,
  }) {
    return Material(
      color:
      Colors.transparent,
      child:
      InkWell(
        onTap: () {
          widget.onChanged(
            item,
          );

          _closeDropdown();
        },
        child:
        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            10,
            vertical:
            9,
          ),
          color:
          isSelected
              ? AppColors.primaryDark
              .withOpacity(
            0.06,
          )
              : Colors.transparent,
          child:
          Row(
            children: [
              /// ================================================
              /// ICON
              /// ================================================

              Container(
                width:
                32,
                height:
                32,
                alignment:
                Alignment.center,
                decoration:
                BoxDecoration(
                  color:
                  isSelected
                      ? AppColors.primaryDark
                      : AppColors.primaryDark.withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    7,
                  ),
                ),
                child:
                Icon(
                  widget.prefixIcon ??
                      Icons.person_outline_rounded,
                  size:
                  17,
                  color:
                  isSelected
                      ? Colors.white
                      : AppColors.primaryDark,
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              /// ================================================
              /// LABEL
              /// ================================================

              Expanded(
                child:
                Text(
                  widget.itemLabel(
                    item,
                  ),
                  maxLines:
                  1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  TextStyle(
                    fontSize:
                    12,
                    color:
                    Colors.black87,
                    fontWeight:
                    isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(
                width:
                5,
              ),

              /// ================================================
              /// SELECTED
              /// ================================================

              if (isSelected)
                Container(
                  width:
                  21,
                  height:
                  21,
                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.primaryDark,
                    shape:
                    BoxShape.circle,
                  ),
                  child:
                  const Icon(
                    Icons.check,
                    color:
                    Colors.white,
                    size:
                    13,
                  ),
                )
              else
                Icon(
                  Icons
                      .keyboard_arrow_right_rounded,
                  size:
                  18,
                  color:
                  Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// SELECTED CHECK
  /// ============================================================

  bool _isSelected(T item) {
    if (widget.value == null) {
      return false;
    }

    /// Normal equality
    if (widget.value == item) {
      return true;
    }

    /// Map હોય તો ID compare
    if (widget.value is Map &&
        item is Map) {
      final dynamic selectedId =
      (widget.value as Map)["id"];

      final dynamic itemId =
      (item as Map)["id"];

      if (selectedId != null &&
          itemId != null) {
        return selectedId
            .toString() ==
            itemId.toString();
      }
    }

    return false;
  }

  /// ============================================================
  /// EMPTY
  /// ============================================================

  Widget _emptyWidget() {
    return Center(
      child:
      SingleChildScrollView(
        child:
        Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical:
            15,
            horizontal:
            10,
          ),
          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width:
                42,
                height:
                42,
                decoration:
                BoxDecoration(
                  color:
                  AppColors.primaryDark.withOpacity(
                    0.07,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child:
                Icon(
                  Icons.search_off_rounded,
                  size:
                  22,
                  color:
                  AppColors.primaryDark,
                ),
              ),

              const SizedBox(
                height:
                8,
              ),

              const Text(
                "No Data Found",
                style:
                TextStyle(
                  fontSize:
                  12,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  Colors.black87,
                ),
              ),

              const SizedBox(
                height:
                3,
              ),

              Text(
                "Try another keyword",
                style:
                TextStyle(
                  fontSize:
                  10,
                  color:
                  Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// BUILD
  /// ============================================================

  @override
  Widget build(BuildContext context) {
    String selectedText = "";

    if (widget.value != null) {
      try {
        selectedText =
            widget.itemLabel(
              widget.value as T,
            );
      } catch (_) {
        selectedText = "";
      }
    }

    return SizedBox(
      width:
      widget.width,
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        mainAxisSize:
        MainAxisSize.min,
        children: [
          /// ====================================================
          /// LABEL
          /// ====================================================

          if (widget.label.isNotEmpty)
            Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style:
                  const TextStyle(
                    fontSize:
                    12,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Colors.black87,
                  ),
                ),

                if (widget.requiredField)
                  const Text(
                    " *",
                    style:
                    TextStyle(
                      color:
                      Colors.red,
                      fontSize:
                      13,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
              ],
            ),

          if (widget.label.isNotEmpty)
            const SizedBox(
              height:
              6,
            ),

          /// ====================================================
          /// FIELD
          /// ====================================================

          InkWell(
            key:
            _fieldKey,
            onTap:
            _toggleDropdown,
            borderRadius:
            BorderRadius.circular(
              8,
            ),
            child:
            AnimatedContainer(
              duration:
              const Duration(
                milliseconds:
                150,
              ),
              height:
              48,
              padding:
              const EdgeInsets.symmetric(
                horizontal:
                12,
              ),
              decoration:
              BoxDecoration(
                color:
                widget.enabled
                    ? Colors.white
                    : Colors.grey.shade100,

                borderRadius:
                BorderRadius.circular(
                  8,
                ),

                border:
                Border.all(
                  color:
                  isDropdownOpen
                      ? AppColors.primaryDark
                      : AppColors.border,
                  width:
                  isDropdownOpen
                      ? 1.3
                      : 1,
                ),

                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withOpacity(
                      0.035,
                    ),
                    blurRadius:
                    6,
                    offset:
                    const Offset(
                      0,
                      2,
                    ),
                  ),
                ],
              ),
              child:
              Row(
                children: [
                  /// ============================================
                  /// PREFIX ICON
                  /// ============================================

                  if (widget.prefixIcon != null) ...[
                    Container(
                      width:
                      30,
                      height:
                      30,
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.primaryDark.withOpacity(
                          0.08,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          6,
                        ),
                      ),
                      child:
                      Icon(
                        widget.prefixIcon,
                        size:
                        17,
                        color:
                        AppColors.primaryDark,
                      ),
                    ),

                    const SizedBox(
                      width:
                      10,
                    ),
                  ],

                  /// ============================================
                  /// TEXT
                  /// ============================================

                  Expanded(
                    child:
                    Text(
                      selectedText.isEmpty
                          ? widget.hint
                          : selectedText,
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      TextStyle(
                        fontSize:
                        13,
                        fontWeight:
                        selectedText.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w500,
                        color:
                        selectedText.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                    6,
                  ),

                  /// ============================================
                  /// SEARCH ICON
                  /// ============================================

                  Icon(
                    Icons.search_rounded,
                    size:
                    18,
                    color:
                    AppColors.primaryDark,
                  ),

                  const SizedBox(
                    width:
                    3,
                  ),

                  /// ============================================
                  /// ARROW
                  /// ============================================

                  AnimatedRotation(
                    turns:
                    isDropdownOpen
                        ? 0.5
                        : 0,
                    duration:
                    const Duration(
                      milliseconds:
                      180,
                    ),
                    child:
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size:
                      22,
                      color:
                      Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// DISPOSE
  /// ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(
      this,
    );

    try {
      _overlayEntry?.remove();
    } catch (_) {}

    _overlayEntry = null;

    _searchController.dispose();

    _searchFocusNode.dispose();

    super.dispose();
  }
}


// item



class PremiumCompactSearchDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;

  final List<T> items;
  final T? value;

  final String Function(T item) itemLabel;
  final String Function(T item)? searchText;

  final ValueChanged<T?> onChanged;

  final double width;
  final double height;
  final double dropdownHeight;

  final bool enabled;

  const PremiumCompactSearchDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onChanged,
    this.searchText,
    this.width = 155,
    this.height = 55,
    this.dropdownHeight = 260,
    this.enabled = true,
  });

  @override
  State<PremiumCompactSearchDropdown<T>> createState() =>
      _PremiumCompactSearchDropdownState<T>();
}

class _PremiumCompactSearchDropdownState<T>
    extends State<PremiumCompactSearchDropdown<T>> {

  final MenuController _menuController =
  MenuController();

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode =
  FocusNode();

  /// 🔥 IMPORTANT
  /// Search વખતે આખું widget rebuild નહીં થાય
  late ValueNotifier<List<T>> _filteredItemsNotifier;

  @override
  void initState() {
    super.initState();

    _filteredItemsNotifier =
        ValueNotifier<List<T>>(
          List<T>.from(widget.items),
        );
  }

  /// ============================================================
  /// SEARCH
  /// ============================================================

  void _search(String value) {
    final String query =
    value.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredItemsNotifier.value =
      List<T>.from(widget.items);

      return;
    }

    final List<T> result =
    widget.items.where(
          (item) {
        final String text =
        widget.searchText != null
            ? widget.searchText!(item)
            : widget.itemLabel(item);

        return text
            .toLowerCase()
            .contains(query);
      },
    ).toList();

    /// 🔥 Only list updates
    _filteredItemsNotifier.value =
        result;
  }

  /// ============================================================
  /// OPEN MENU
  /// ============================================================

  void _openMenu() {
    if (!widget.enabled) {
      return;
    }

    if (_menuController.isOpen) {
      _menuController.close();

      _searchFocusNode.unfocus();

      return;
    }

    /// Reset search
    _searchController.clear();

    _filteredItemsNotifier.value =
    List<T>.from(widget.items);

    /// Open dropdown
    _menuController.open();

    /// ❌ અહીં keyboard requestFocus નથી કરવાનું
    /// User Search field touch કરે ત્યારે જ keyboard open થશે.
  }

  /// ============================================================
  /// SELECTED CHECK
  /// ============================================================

  bool _isSelected(T item) {
    if (widget.value == null) {
      return false;
    }

    /// Map હોય તો ID compare
    if (widget.value is Map &&
        item is Map) {
      final dynamic selectedId =
      (widget.value as Map)["id"];

      final dynamic currentId =
      (item as Map)["id"];

      if (selectedId != null &&
          currentId != null) {
        return selectedId.toString() ==
            currentId.toString();
      }
    }

    return widget.itemLabel(
      widget.value as T,
    ) ==
        widget.itemLabel(item);
  }

  /// ============================================================
  /// BUILD
  /// ============================================================

  @override
  Widget build(BuildContext context) {
    final String selectedText =
    widget.value == null
        ? ""
        : widget.itemLabel(
      widget.value as T,
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [

          /// ==========================================
          /// LABEL
          /// ==========================================

          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 4),

          /// ==========================================
          /// MENU
          /// ==========================================

          Expanded(
            child: MenuAnchor(
              controller:
              _menuController,

              alignmentOffset:
              const Offset(0, 3),

              style: MenuStyle(
                backgroundColor:
                const WidgetStatePropertyAll(
                  Colors.white,
                ),

                elevation:
                const WidgetStatePropertyAll(
                  8,
                ),

                padding:
                const WidgetStatePropertyAll(
                  EdgeInsets.zero,
                ),

                shape:
                WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      8,
                    ),
                    side: BorderSide(
                      color:
                      AppColors.border,
                    ),
                  ),
                ),
              ),

              /// ========================================
              /// DROPDOWN CONTENT
              /// ========================================

              menuChildren: [
                SizedBox(
                  width: widget.width > 220
                      ? widget.width
                      : 240,

                  height:
                  widget.dropdownHeight,

                  child: Column(
                    children: [

                      /// =================================
                      /// SEARCH FIELD
                      /// =================================

                      Padding(
                        padding:
                        const EdgeInsets.all(
                          8,
                        ),
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller:
                            _searchController,

                            focusNode:
                            _searchFocusNode,

                            onChanged:
                            _search,

                            /// ✅ Keyboard search button — ek j item hoy to select
                            onSubmitted: (value) {
                              _search(value);
                              final list =
                                  _filteredItemsNotifier.value;
                              _searchFocusNode.unfocus();
                              if (value.trim().isNotEmpty &&
                                  list.length == 1) {
                                widget.onChanged(list.first);
                                _menuController.close();
                              }
                            },

                            /// 🔥 keyboard open થાય ત્યારે
                            /// parent scroll jump ઓછું થશે
                            scrollPadding:
                            EdgeInsets.zero,

                            textInputAction:
                            TextInputAction.search,

                            style:
                            const TextStyle(
                              color:
                              Colors.black,
                              fontSize: 12,
                            ),

                            decoration:
                            InputDecoration(
                              hintText:
                              "Search ${widget.label}...",

                              hintStyle:
                              TextStyle(
                                color: Colors
                                    .grey
                                    .shade500,
                                fontSize: 11,
                              ),

                              prefixIcon:
                              Icon(
                                Icons.search,
                                size: 17,
                                color: AppColors
                                    .primaryDark,
                              ),

                              prefixIconConstraints:
                              const BoxConstraints(
                                minWidth: 34,
                              ),

                              filled: true,

                              fillColor: Colors
                                  .grey.shade50,

                              isDense: true,

                              contentPadding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),

                              border:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  6,
                                ),
                                borderSide:
                                BorderSide(
                                  color: AppColors
                                      .border,
                                ),
                              ),

                              enabledBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  6,
                                ),
                                borderSide:
                                BorderSide(
                                  color: AppColors
                                      .border,
                                ),
                              ),

                              focusedBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  6,
                                ),
                                borderSide:
                                BorderSide(
                                  color: AppColors
                                      .primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Divider(
                        height: 1,
                        color:
                        AppColors.border,
                      ),

                      /// =================================
                      /// LIST
                      /// Only this rebuilds while search
                      /// =================================

                      Expanded(
                        child:
                        ValueListenableBuilder<
                            List<T>>(
                          valueListenable:
                          _filteredItemsNotifier,

                          builder: (
                              context,
                              filteredItems,
                              child,
                              ) {
                            if (filteredItems
                                .isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize:
                                  MainAxisSize
                                      .min,
                                  children: [
                                    Icon(
                                      Icons
                                          .search_off_rounded,
                                      size: 26,
                                      color: Colors
                                          .grey
                                          .shade400,
                                    ),

                                    const SizedBox(
                                      height: 5,
                                    ),

                                    const Text(
                                      "No Data Found",
                                      style:
                                      TextStyle(
                                        color: Colors
                                            .black54,
                                        fontSize:
                                        11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              padding:
                              EdgeInsets.zero,

                              keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior
                                  .onDrag,

                              itemCount:
                              filteredItems
                                  .length,

                              itemExtent: 42,

                              itemBuilder:
                                  (
                                  context,
                                  index,
                                  ) {
                                final T item =
                                filteredItems[
                                index];

                                final bool
                                selected =
                                _isSelected(
                                  item,
                                );

                                return InkWell(
                                  onTap: () {
                                    /// Keyboard close first
                                    _searchFocusNode
                                        .unfocus();

                                    /// Value select
                                    widget
                                        .onChanged(
                                      item,
                                    );

                                    /// Dropdown close
                                    _menuController
                                        .close();
                                  },

                                  child:
                                  Container(
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal:
                                      10,
                                    ),

                                    color: selected
                                        ? AppColors
                                        .primaryDark
                                        .withOpacity(
                                      0.08,
                                    )
                                        : Colors
                                        .white,

                                    child: Row(
                                      children: [
                                        Expanded(
                                          child:
                                          Text(
                                            widget
                                                .itemLabel(
                                              item,
                                            ),

                                            maxLines:
                                            1,

                                            overflow:
                                            TextOverflow
                                                .ellipsis,

                                            style:
                                            TextStyle(
                                              color: Colors
                                                  .black87,

                                              fontSize:
                                              12,

                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),

                                        if (selected)
                                          Icon(
                                            Icons
                                                .check_rounded,
                                            size:
                                            16,
                                            color: AppColors
                                                .primaryDark,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              /// ========================================
              /// MAIN FIELD
              /// ========================================

              builder: (
                  context,
                  controller,
                  child,
                  ) {
                return InkWell(
                  onTap:
                  _openMenu,

                  borderRadius:
                  BorderRadius.circular(
                    4,
                  ),

                  child: Container(
                    width:
                    double.infinity,

                    height:
                    double.infinity,

                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 6,
                    ),

                    decoration:
                    BoxDecoration(
                      color: widget.enabled
                          ? Colors.white
                          : Colors.grey
                          .shade100,

                      borderRadius:
                      BorderRadius.circular(
                        4,
                      ),
                    ),

                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedText
                                .isEmpty
                                ? widget.hint
                                : selectedText,

                            maxLines: 1,

                            overflow:
                            TextOverflow
                                .ellipsis,

                            style:
                            TextStyle(
                              color: selectedText
                                  .isEmpty
                                  ? Colors.grey
                                  : Colors.black,

                              fontSize: 12,

                              fontWeight:
                              FontWeight
                                  .w500,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 3,
                        ),

                        const Icon(
                          Icons
                              .keyboard_arrow_down_rounded,
                          size: 18,
                          color:
                          Colors.black54,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// DISPOSE
  /// ============================================================

  @override
  void dispose() {
    _filteredItemsNotifier.dispose();

    _searchController.dispose();

    _searchFocusNode.dispose();

    super.dispose();
  }
}


class PremiumItemSearchDropdown extends StatefulWidget {
  final String label;
  final String hint;

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? value;

  final ValueChanged<Map<String, dynamic>?> onChanged;

  final bool enabled;
  final bool requiredField;

  final double? width;
  final double dropdownMaxHeight;

  const PremiumItemSearchDropdown({
    super.key,
    this.label = "Item",
    this.hint = "Select Item",
    required this.items,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.requiredField = true,
    this.width,
    this.dropdownMaxHeight = 300,
  });

  @override
  State<PremiumItemSearchDropdown> createState() =>
      _PremiumItemSearchDropdownState();
}

class _PremiumItemSearchDropdownState
    extends State<PremiumItemSearchDropdown>
    with WidgetsBindingObserver {
  /// ============================================================
  /// KEY
  /// ============================================================

  final GlobalKey _fieldKey = GlobalKey();

  /// ============================================================
  /// SEARCH
  /// ============================================================

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  /// ============================================================
  /// OVERLAY
  /// ============================================================

  OverlayEntry? _overlayEntry;

  bool isDropdownOpen = false;

  /// ============================================================
  /// DATA
  /// ============================================================

  List<Map<String, dynamic>> filteredItems = [];

  Size _fieldSize = Size.zero;

  Offset _fieldPosition = Offset.zero;

  /// ============================================================
  /// INIT
  /// ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    filteredItems =
    List<Map<String, dynamic>>.from(widget.items);
  }

  /// ============================================================
  /// UPDATE ITEMS
  /// ============================================================

  @override
  void didUpdateWidget(
      covariant PremiumItemSearchDropdown oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items != widget.items) {
      filteredItems =
      List<Map<String, dynamic>>.from(widget.items);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_overlayEntry != null &&
            isDropdownOpen) {
          _overlayEntry?.markNeedsBuild();
        }
      });
    }
  }

  /// ============================================================
  /// KEYBOARD CHANGE
  /// ============================================================

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    if (!isDropdownOpen) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!isDropdownOpen) return;

      _overlayEntry?.markNeedsBuild();
    });
  }

  /// ============================================================
  /// ITEM NAME
  /// ============================================================

  String _itemName(Map<String, dynamic> item) {
    return item["item_name"]?.toString() ??
        item["name"]?.toString() ??
        "";
  }

  /// ============================================================
  /// SEARCH TEXT
  /// ============================================================

  String _itemSearchText(Map<String, dynamic> item) {
    final String name =
        item["item_name"]?.toString() ??
            item["name"]?.toString() ??
            "";

    final String id =
        item["id"]?.toString() ?? "";

    final String code =
        item["item_code"]?.toString() ??
            item["code"]?.toString() ??
            "";

    final String carat =
        item["inward_carat"]?.toString() ?? "";

    final String purity =
        item["inward_purity"]?.toString() ?? "";

    return "$name $id $code $carat $purity";
  }

  /// ============================================================
  /// TOGGLE
  /// ============================================================

  void _toggleDropdown() {
    if (!widget.enabled) return;

    if (isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  /// ============================================================
  /// POSITION
  /// ============================================================

  bool _updateFieldPosition() {
    final BuildContext? fieldContext =
        _fieldKey.currentContext;

    if (fieldContext == null) {
      return false;
    }

    final RenderObject? renderObject =
    fieldContext.findRenderObject();

    if (renderObject == null ||
        renderObject is! RenderBox ||
        !renderObject.attached) {
      return false;
    }

    try {
      _fieldSize = renderObject.size;

      _fieldPosition =
          renderObject.localToGlobal(
            Offset.zero,
          );

      return true;
    } catch (e) {
      debugPrint(
        "Item dropdown position error: $e",
      );

      return false;
    }
  }

  /// ============================================================
  /// OPEN
  /// ============================================================

  void _openDropdown() {
    if (_overlayEntry != null) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final bool positionAvailable =
    _updateFieldPosition();

    if (!positionAvailable) return;

    _searchController.clear();

    filteredItems =
    List<Map<String, dynamic>>.from(
      widget.items,
    );

    _overlayEntry =
        _createOverlayEntry();

    final OverlayState overlay =
    Overlay.of(
      context,
      rootOverlay: true,
    );

    overlay.insert(
      _overlayEntry!,
    );

    if (mounted) {
      setState(() {
        isDropdownOpen = true;
      });
    }
  }

  /// ============================================================
  /// CLOSE
  /// ============================================================

  void _closeDropdown() {
    _searchFocusNode.unfocus();

    try {
      _overlayEntry?.remove();
    } catch (e) {
      debugPrint(
        "Item dropdown remove error: $e",
      );
    }

    _overlayEntry = null;

    if (mounted) {
      setState(() {
        isDropdownOpen = false;
      });
    }
  }

  /// ============================================================
  /// SEARCH
  /// ============================================================

  void _search(String value) {
    final String query =
    value.trim().toLowerCase();

    if (query.isEmpty) {
      filteredItems =
      List<Map<String, dynamic>>.from(
        widget.items,
      );
    } else {
      filteredItems =
          widget.items.where(
                (item) {
              return _itemSearchText(item)
                  .toLowerCase()
                  .contains(query);
            },
          ).toList();
    }

    _overlayEntry?.markNeedsBuild();
  }

  /// 🔍 Keyboard nu search button — ek j item male to select
  void _onSearchSubmitted(String value) {
    _search(value);

    final String query = value.trim().toLowerCase();

    if (query.isEmpty) {
      _searchFocusNode.unfocus();
      return;
    }

    Map<String, dynamic>? pick;

    if (filteredItems.length == 1) {
      pick = filteredItems.first;
    } else {
      for (final item in filteredItems) {
        if (_itemName(item).trim().toLowerCase() == query) {
          pick = item;
          break;
        }
      }
    }

    if (pick != null) {
      widget.onChanged(pick);
      _closeDropdown();
      return;
    }

    _searchFocusNode.unfocus();
    _overlayEntry?.markNeedsBuild();
  }

  /// ============================================================
  /// SELECTED CHECK
  /// ============================================================

  bool _isSelected(
      Map<String, dynamic> item,
      ) {
    if (widget.value == null) {
      return false;
    }

    final dynamic selectedId =
    widget.value!["id"];

    final dynamic currentId =
    item["id"];

    if (selectedId == null ||
        currentId == null) {
      return false;
    }

    return selectedId.toString() ==
        currentId.toString();
  }

  /// ============================================================
  /// OVERLAY
  /// ============================================================

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final MediaQueryData mediaQuery =
        MediaQuery.of(
          overlayContext,
        );

        final Size screenSize =
            mediaQuery.size;

        final double keyboardHeight =
            mediaQuery.viewInsets.bottom;

        final double usableBottom =
            screenSize.height -
                keyboardHeight;

        final double safeTop =
            mediaQuery.padding.top;

        double spaceBelow =
            usableBottom -
                _fieldPosition.dy -
                _fieldSize.height -
                8;

        double spaceAbove =
            _fieldPosition.dy -
                safeTop -
                8;

        if (spaceBelow < 0) {
          spaceBelow = 0;
        }

        if (spaceAbove < 0) {
          spaceAbove = 0;
        }

        /// Open above if bottom space is less
        final bool showAbove =
            spaceBelow < 180 &&
                spaceAbove > spaceBelow;

        final double availableHeight =
        showAbove
            ? spaceAbove
            : spaceBelow;

        if (availableHeight < 70) {
          return const SizedBox.shrink();
        }

        double dropdownHeight =
            widget.dropdownMaxHeight;

        if (dropdownHeight >
            availableHeight) {
          dropdownHeight =
              availableHeight;
        }

        if (dropdownHeight >
            screenSize.height) {
          dropdownHeight =
              screenSize.height;
        }

        double topPosition;

        if (showAbove) {
          topPosition =
              _fieldPosition.dy -
                  dropdownHeight -
                  6;
        } else {
          topPosition =
              _fieldPosition.dy +
                  _fieldSize.height +
                  6;
        }

        if (topPosition <
            safeTop + 4) {
          topPosition =
              safeTop + 4;
        }

        double leftPosition =
            _fieldPosition.dx;

        double dropdownWidth =
            _fieldSize.width;

        /// Minimum dropdown width
        if (dropdownWidth < 260) {
          dropdownWidth = 260;
        }

        /// Right overflow protection
        if (leftPosition +
            dropdownWidth >
            screenSize.width - 5) {
          leftPosition =
              screenSize.width -
                  dropdownWidth -
                  5;
        }

        if (leftPosition < 5) {
          leftPosition = 5;
        }

        /// Screen width safety
        if (dropdownWidth >
            screenSize.width - 10) {
          dropdownWidth =
              screenSize.width - 10;

          leftPosition = 5;
        }

        return Stack(
          children: [
            /// ==============================================
            /// OUTSIDE TAP
            /// ==============================================

            Positioned.fill(
              child: GestureDetector(
                behavior:
                HitTestBehavior.translucent,
                onTap: _closeDropdown,
                child:
                const SizedBox.expand(),
              ),
            ),

            /// ==============================================
            /// DROPDOWN
            /// ==============================================

            Positioned(
              left: leftPosition,
              top: topPosition,
              width: dropdownWidth,
              height: dropdownHeight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                    border: Border.all(
                      color:
                      AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(
                          0.15,
                        ),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset:
                        const Offset(
                          0,
                          6,
                        ),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                    child: Column(
                      children: [
                        /// ==================================
                        /// SEARCH
                        /// ==================================

                        Padding(
                          padding:
                          const EdgeInsets.all(
                            0,
                          ),
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller:
                              _searchController,
                              focusNode:
                              _searchFocusNode,
                              onChanged: _search,
                              onSubmitted:
                              _onSearchSubmitted,
                              scrollPadding:
                              EdgeInsets.zero,
                              textInputAction:
                              TextInputAction
                                  .search,
                              style:
                              const TextStyle(
                                color:
                                Colors.black87,
                                fontSize: 13,
                              ),
                              decoration:
                              InputDecoration(
                                hintText:
                                "Search Item...",

                                hintStyle:
                                TextStyle(
                                  color: Colors
                                      .grey
                                      .shade500,
                                  fontSize: 12,
                                ),

                                prefixIcon:
                                const Icon(
                                  Icons
                                      .search_rounded,
                                  size: 18,
                                  color: AppColors
                                      .primaryDark,
                                ),

                                suffixIcon:
                                _searchController
                                    .text
                                    .isNotEmpty
                                    ? IconButton(
                                  padding:
                                  EdgeInsets
                                      .zero,
                                  constraints:
                                  const BoxConstraints(),
                                  onPressed:
                                      () {
                                    _searchController
                                        .clear();

                                    _search(
                                      "",
                                    );
                                  },
                                  icon:
                                  const Icon(
                                    Icons
                                        .close,
                                    size:
                                    16,
                                  ),
                                )
                                    : null,

                                filled: true,

                                fillColor: Colors
                                    .grey
                                    .shade50,

                                isDense: true,

                                contentPadding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),

                                border:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    7,
                                  ),
                                  borderSide:
                                  BorderSide(
                                    color:
                                    AppColors
                                        .border,
                                  ),
                                ),

                                enabledBorder:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    7,
                                  ),
                                  borderSide:
                                  BorderSide(
                                    color:
                                    AppColors
                                        .border,
                                  ),
                                ),

                                focusedBorder:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    7,
                                  ),
                                  borderSide:
                                  const BorderSide(
                                    color:
                                    AppColors
                                        .primaryDark,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        Divider(
                          height: 1,
                          color:
                          AppColors.border,
                        ),

                        /// ==================================
                        /// RECORD COUNT
                        /// ==================================

                        Container(
                          width: double.infinity,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            "${filteredItems.length} items found",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors
                                  .grey
                                  .shade500,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ),

                        Divider(
                          height: 1,
                          color: Colors
                              .grey
                              .shade200,
                        ),

                        /// ==================================
                        /// ITEM LIST
                        /// ==================================

                        Expanded(
                          child:
                          filteredItems
                              .isEmpty
                              ? _emptyWidget()
                              : ListView
                              .separated(
                            padding:
                            const EdgeInsets
                                .only(
                              bottom: 5,
                            ),
                            keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior
                                .onDrag,
                            itemCount:
                            filteredItems
                                .length,
                            separatorBuilder:
                                (
                                context,
                                index,
                                ) {
                              return Divider(
                                height: 1,
                                indent: 10,
                                endIndent:
                                10,
                                color: Colors
                                    .grey
                                    .shade200,
                              );
                            },
                            itemBuilder:
                                (
                                context,
                                index,
                                ) {
                              final item =
                              filteredItems[
                              index];

                              return _dropdownItem(
                                item:
                                item,
                                isSelected:
                                _isSelected(
                                  item,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ============================================================
  /// ITEM ROW
  /// ============================================================

  Widget _dropdownItem({
    required Map<String, dynamic> item,
    required bool isSelected,
  }) {
    final String name =
    _itemName(item);

    final String code =
        item["item_code"]?.toString() ??
            item["code"]?.toString() ??
            "";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          /// Return full item
          widget.onChanged(item);

          _closeDropdown();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          color: isSelected
              ? AppColors.primaryDark
              .withOpacity(0.06)
              : Colors.transparent,
          child: Row(
            children: [
              /// ITEM ICON
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.primaryDark
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    7,
                  ),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 17,
                  color: isSelected
                      ? Colors.white
                      : AppColors.primaryDark,
                ),
              ),

              const SizedBox(width: 10),

              /// ITEM NAME + CODE
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight:
                        isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),

                    if (code.isNotEmpty) ...[
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        code,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors
                              .grey
                              .shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (isSelected)
                Container(
                  width: 21,
                  height: 21,
                  decoration:
                  const BoxDecoration(
                    color:
                    AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 13,
                  ),
                )
              else
                Icon(
                  Icons
                      .keyboard_arrow_right_rounded,
                  size: 18,
                  color:
                  Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// EMPTY
  /// ============================================================

  Widget _emptyWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryDark
                  .withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 22,
              color: AppColors.primaryDark,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "No Item Found",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            "Try another item name",
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// BUILD
  /// ============================================================

  @override
  Widget build(BuildContext context) {
    final String selectedText =
    widget.value == null
        ? ""
        : _itemName(
      widget.value!,
    );

    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          /// LABEL
          if (widget.label.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                if (widget.requiredField)
                  const Text(
                    " *",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
              ],
            ),

          if (widget.label.isNotEmpty)
            const SizedBox(height: 6),

          /// FIELD
          InkWell(
            key: _fieldKey,
            onTap: _toggleDropdown,
            borderRadius:
            BorderRadius.circular(8),
            child: AnimatedContainer(
              duration:
              const Duration(
                milliseconds: 150,
              ),
              height: 48,
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? Colors.white
                    : Colors.grey.shade100,
                borderRadius:
                BorderRadius.circular(8),
                border: Border.all(
                  color: isDropdownOpen
                      ? AppColors.primaryDark
                      : AppColors.border,
                  width:
                  isDropdownOpen
                      ? 1.3
                      : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.035),
                    blurRadius: 6,
                    offset:
                    const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  /// ITEM ICON
                  Container(
                    width: 30,
                    height: 30,
                    decoration:
                    BoxDecoration(
                      color: AppColors
                          .primaryDark
                          .withOpacity(0.08),
                      borderRadius:
                      BorderRadius
                          .circular(6),
                    ),
                    child: const Icon(
                      Icons
                          .inventory_2_outlined,
                      size: 17,
                      color: AppColors
                          .primaryDark,
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// SELECTED ITEM
                  Expanded(
                    child: Text(
                      selectedText.isEmpty
                          ? widget.hint
                          : selectedText,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        selectedText.isEmpty
                            ? FontWeight
                            .w400
                            : FontWeight
                            .w500,
                        color:
                        selectedText.isEmpty
                            ? Colors.grey
                            .shade500
                            : Colors
                            .black87,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color:
                    AppColors.primaryDark,
                  ),

                  const SizedBox(width: 3),

                  AnimatedRotation(
                    turns:
                    isDropdownOpen
                        ? 0.5
                        : 0,
                    duration:
                    const Duration(
                      milliseconds: 180,
                    ),
                    child: Icon(
                      Icons
                          .keyboard_arrow_down_rounded,
                      size: 22,
                      color:
                      Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// DISPOSE
  /// ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    try {
      _overlayEntry?.remove();
    } catch (_) {}

    _overlayEntry = null;

    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }
}
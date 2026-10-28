import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:pecifician_sysytem/Role%20&%20Permission/RoleScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/PermissionDeniedWidget.dart';

/// ================= JEWELLERY PALETTE =================

class _Lux {
  static const gold = Color(0xFFC9A24A);
  static const goldLight = Color(0xFFE8CC85);
  static const goldDeep = Color(0xFF94702E);
  static const ivory = Color(0xFFFBF8F1);
  static const line = Color(0xFFEADFC8);
  static const onyx = Color(0xFF1F1B16);
  static const muted = Color(0xFF8A8172);

  static const goldGradient = LinearGradient(
    colors: [goldLight, gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// ================= MODELS =================

class PermissionAction {
  final int id;
  final String name;
  final String label;
  bool value;

  PermissionAction({
    required this.id,
    required this.name,
    required this.label,
    this.value = false,
  });
}

class PermissionModule {
  final String key;
  final String label;
  final List<PermissionAction> actions;

  PermissionModule({
    required this.key,
    required this.label,
    required this.actions,
  });

  int get selectedCount => actions.where((a) => a.value).length;
  bool get allChecked => actions.isNotEmpty && selectedCount == actions.length;
}

class PermissionGroup {
  final String key;
  final String label;
  final List<PermissionModule> modules;

  PermissionGroup({
    required this.key,
    required this.label,
    required this.modules,
  });

  List<PermissionAction> get allActions =>
      modules.expand((m) => m.actions).toList();

  int get total => allActions.length;
  int get selectedCount => allActions.where((a) => a.value).length;
}

/// ================= SCREEN =================

class Createrolescreen extends StatefulWidget {
  final int? roleId;

  const Createrolescreen({
    super.key,
    this.roleId,
  });

  @override
  State<Createrolescreen> createState() => _CreaterolescreenState();
}

class _CreaterolescreenState extends State<Createrolescreen> {
  final TextEditingController roleController = TextEditingController();

  /// 🔥 Menu → Module → Action
  List<PermissionGroup> permissionGroups = [];

  /// 🔥 permission_list ni ID (save karti vakhte aa j ID jase)
  final Map<String, int> nameToId = {};

  /// 🔥 Khulela menus
  final Set<String> expandedMenus = {};

  bool isLoading = true;
  bool isSaving = false;

  List<String> userPermissions = [];
  bool permissionsLoaded = false;

  bool get isEdit => widget.roleId != null;

  static const List<String> _actionOrder = [
    "view",
    "create",
    "edit",
    "delete",
    "manage",
  ];

  @override
  void initState() {
    super.initState();
    loadPermissions();
    loadData();
  }

  @override
  void dispose() {
    roleController.dispose();
    super.dispose();
  }

  /// ================= HELPERS =================

  List<PermissionAction> get allActions =>
      permissionGroups.expand((g) => g.allActions).toList();

  int get totalCount => allActions.length;
  int get selectedCount => allActions.where((a) => a.value).length;

  bool get selectAll => totalCount > 0 && selectedCount == totalCount;

  /// false = kai nahi, true = badhu, null = adhu
  bool? _tri(int selected, int total) {
    if (selected == 0 || total == 0) return false;
    if (selected == total) return true;
    return null;
  }

  int _toInt(dynamic v) => int.tryParse(v.toString()) ?? 0;

  String _titleCase(String s) => s
      .split(RegExp(r'[-\s]+'))
      .where((e) => e.isNotEmpty)
      .map((e) => e[0].toUpperCase() + e.substring(1))
      .join(" ");

  List<int> _selectedIds() {
    final ids = <int>{};
    for (final a in allActions) {
      if (a.value) ids.add(nameToId[a.name] ?? a.id);
    }
    return ids.toList();
  }

  void printSelectedIds() {
    print("🔥 Selected Permission IDs: ${_selectedIds()}");
  }

  /// Group ma kaya action columns chhe (View, Create, ... order ma)
  List<String> _columnsFor(PermissionGroup g) {
    final cols = <String>[];
    for (final m in g.modules) {
      for (final a in m.actions) {
        final k = a.label.toLowerCase();
        if (!cols.contains(k)) cols.add(k);
      }
    }
    int rank(String s) {
      final i = _actionOrder.indexOf(s);
      return i < 0 ? 99 : i;
    }

    cols.sort((a, b) => rank(a).compareTo(rank(b)));
    return cols;
  }

  PermissionAction? _actionFor(PermissionModule m, String col) {
    for (final a in m.actions) {
      if (a.label.toLowerCase() == col) return a;
    }
    return null;
  }

  IconData _actionIcon(String label) {
    switch (label.toLowerCase()) {
      case "view":
        return Icons.visibility_outlined;
      case "create":
        return Icons.add_circle_outline_rounded;
      case "edit":
        return Icons.edit_outlined;
      case "delete":
        return Icons.delete_outline_rounded;
      case "manage":
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.key_outlined;
    }
  }

  /// ================= PARSE: NEW RESPONSE (permission_groups) =================

  List<PermissionGroup> _parseGroups(List groups) {
    return groups.whereType<Map>().map<PermissionGroup>((g) {
      final modules =
      (g["modules"] as List? ?? []).whereType<Map>().map<PermissionModule>((m) {
        final actions = (m["actions"] as List? ?? [])
            .whereType<Map>()
            .map<PermissionAction>((a) => PermissionAction(
          id: _toInt(a["permission_id"]),
          name: a["permission_name"].toString(),
          label: (a["label"] ?? a["action"] ?? "").toString(),
          value: a["checked"] == true,
        ))
            .toList();

        return PermissionModule(
          key: m["module"].toString(),
          label: (m["label"] ?? m["module"]).toString(),
          actions: actions,
        );
      }).toList();

      return PermissionGroup(
        key: g["menu"].toString(),
        label: (g["label"] ?? g["menu"]).toString(),
        modules: modules,
      );
    }).toList();
  }

  /// ================= PARSE: OLD FLAT LIST (fallback) =================

  List<PermissionGroup> _groupFlatList(List items) {
    final Map<String, List<PermissionAction>> grouped = {};

    for (final item in items.whereType<Map>()) {
      final name = item["name"].toString();
      final parts = name.split("-");
      if (parts.length < 2) continue;

      final action = parts.last;
      final moduleKey = parts.sublist(0, parts.length - 1).join("-");

      grouped.putIfAbsent(moduleKey, () => []).add(
        PermissionAction(
          id: _toInt(item["id"]),
          name: name,
          label: _titleCase(action),
        ),
      );
    }

    return grouped.entries.map((e) {
      final label = _titleCase(e.key);
      return PermissionGroup(
        key: e.key,
        label: label,
        modules: [
          PermissionModule(key: e.key, label: label, actions: e.value),
        ],
      );
    }).toList();
  }

  /// ================= LOAD DATA =================

  Future<void> loadData() async {
    List<PermissionGroup> groups = [];

    try {
      /// 1️⃣ PERMISSION LIST
      final response =
      await ApiHelper().getRequest(ApiConstants.permission_list);

      print("user API URL: ${ApiConstants.permission_list}");
      print("users Raw Response: ${response.toString()}");

      if (response != null && response.statusCode == 200) {
        final data = response.data["data"];

        if (data is Map && data["permission_groups"] is List) {
          groups = _parseGroups(data["permission_groups"]);
        } else if (data is List) {
          for (final item in data.whereType<Map>()) {
            if (item["name"] != null && item["id"] != null) {
              nameToId[item["name"].toString()] = _toInt(item["id"]);
            }
          }

          groups = (data.isNotEmpty &&
              data.first is Map &&
              data.first["modules"] != null)
              ? _parseGroups(data)
              : _groupFlatList(data);
        }
      } else {
        print("❌ permission list API failed");
      }

      /// 2️⃣ ROLE DETAILS (EDIT MODE)
      if (isEdit) {
        groups = await getRoleDetails(groups);
      }
    } catch (e) {
      print("❌ LOAD ERROR: $e");
    }

    if (!mounted) return;

    setState(() {
      permissionGroups = groups;
      isLoading = false;

      /// Edit ma je menu ma selection chhe e khulla rakho
      expandedMenus
        ..clear()
        ..addAll(groups.where((g) => g.selectedCount > 0).map((g) => g.key));
    });

    print("✅ Total Permission Group: ${permissionGroups.length}");
  }

  Future<List<PermissionGroup>> getRoleDetails(
      List<PermissionGroup> listGroups) async {
    try {
      final response = await ApiHelper().getRequest(
        "${ApiConstants.baseUrl}roles/${widget.roleId}",
      );

      print("🔥 ROLE DETAILS: ${response?.data}");

      if (response != null && response.statusCode == 200) {
        final roleData = response.data["data"];

        /// 🔥 ROLE NAME
        roleController.text = roleData["name"] ?? "";

        /// 🔥 NAME THI MATCH (IDs mismatch chhe backend ma)
        final List<String> selectedNames =
        (roleData["permissions"] as List? ?? [])
            .map((e) => e["name"].toString())
            .toList();

        print("SELECTED NAMES : $selectedNames");

        /// 🔥 Role API na permission_groups use karo (menu/module structure)
        List<PermissionGroup> groups =
        roleData["permission_groups"] is List
            ? _parseGroups(roleData["permission_groups"])
            : listGroups;

        if (groups.isEmpty) groups = listGroups;

        for (final g in groups) {
          for (final a in g.allActions) {
            a.value = a.value || selectedNames.contains(a.name);
          }
        }

        return groups;
      }
    } catch (e) {
      print("❌ ROLE DETAILS ERROR: $e");
    }

    return listGroups;
  }

  Future<void> loadPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    print("🔥 All SharedPreferences Keys: ${prefs.getKeys()}");

    List<String> perms = prefs.getStringList("user_permissions") ?? [];
    print("🔥 user_permissions value: $perms");

    if (!mounted) return;
    setState(() {
      userPermissions = perms;
      permissionsLoaded = true;
    });
  }

  bool hasPermission(String permissionName) {
    return userPermissions.contains(permissionName);
  }

  /// ================= SELECTION ACTIONS =================

  void toggleAll(bool value) {
    setState(() {
      for (final a in allActions) {
        a.value = value;
      }
    });
    printSelectedIds();
  }

  void _setActions(List<PermissionAction> actions, bool value) {
    HapticFeedback.selectionClick();
    setState(() {
      for (final a in actions) {
        a.value = value;
      }
    });
    printSelectedIds();
  }

  void _toggleAction(PermissionAction a) {
    HapticFeedback.selectionClick();
    setState(() => a.value = !a.value);
    printSelectedIds();
  }

  void _toggleExpand(String key) {
    setState(() {
      expandedMenus.contains(key)
          ? expandedMenus.remove(key)
          : expandedMenus.add(key);
    });
  }

  /// ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    if (!permissionsLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!(hasPermission("role-view") || hasPermission("role-manage"))) {
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(isMobile),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: _Lux.gold),
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                children: [
                  _roleNameField(),
                  const SizedBox(height: 12),
                  _selectAllCard(),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 10),
                    child: Text(
                      "Access by section",
                      style: TextStyle(
                        color: _Lux.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (permissionGroups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          "No permissions found. Go back and open this screen again.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _Lux.muted),
                        ),
                      ),
                    ),
                  ...permissionGroups.map(_groupCard),
                ],
              ),
            ),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  /// ================= APPBAR =================

  Widget _appBar(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            isEdit ? "Edit Role" : "Create Role",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
              child: Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ================= ROLE NAME =================

  Widget _roleNameField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: roleController,
        style: const TextStyle(color: Colors.black, fontSize: 15),
        decoration: InputDecoration(
          hintText: "Enter Role Name",
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.black54,size: 20,),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  /// ================= GEM CHECKBOX (diamond) =================

  Widget _gem({required bool? value, double size = 20}) {
    final on = value == true;
    final partial = value == null;
    final side = size * 0.78;

    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: side,
            height: side,
            decoration: BoxDecoration(
              gradient: on ? _Lux.goldGradient : null,
              color: on ? null : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: on
                    ? _Lux.goldDeep
                    : partial
                    ? _Lux.gold
                    : const Color(0xFFD8CCB4),
                width: 1.3,
              ),
              boxShadow: on
                  ? [
                BoxShadow(
                  color: _Lux.gold.withOpacity(0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
                  : [],
            ),
            child: Center(
              child: on
                  ? Transform.rotate(
                angle: -math.pi / 4,
                child: Icon(
                  Icons.check_rounded,
                  size: size * 0.5,
                  color: Colors.white,
                ),
              )
                  : partial
                  ? Container(
                width: side * 0.38,
                height: side * 0.38,
                decoration: BoxDecoration(
                  color: _Lux.gold,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// ================= SELECT ALL =================

  Widget _selectAllCard() {
    final progress = totalCount == 0 ? 0.0 : selectedCount / totalCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 14),
      decoration: BoxDecoration(
        color: _Lux.ivory,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _Lux.line),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => toggleAll(!selectAll),
            child: Row(
              children: [
                _gem(
                  value: _tri(selectedCount, totalCount),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Select All Permissions",
                    style: TextStyle(
                      color: _Lux.onyx,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  "$selectedCount of $totalCount",
                  style: const TextStyle(
                    color: _Lux.goldDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: _Lux.line,
              valueColor: const AlwaysStoppedAnimation<Color>(_Lux.gold),
            ),
          ),
        ],
      ),
    );
  }

  /// ================= MENU GROUP CARD =================

  Widget _groupCard(PermissionGroup g) {
    final isOpen = expandedMenus.contains(g.key);
    final selected = g.selectedCount;
    final total = g.total;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected > 0 ? _Lux.gold.withOpacity(0.55) : _Lux.line,
        ),
        boxShadow: [
          BoxShadow(
            color: _Lux.goldDeep.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          /// HEADER
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggleExpand(g.key),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setActions(g.allActions, selected != total),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _gem(value: _tri(selected, total), size: 22),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.label,
                          style: const TextStyle(
                            color: _Lux.onyx,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.modules.length == 1
                              ? "1 module"
                              : "${g.modules.length} modules",
                          style: const TextStyle(
                            color: _Lux.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _countBadge(selected, total),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _Lux.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// BODY → PERMISSION MATRIX
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _permissionMatrix(g),
            ),
            crossFadeState:
            isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(int selected, int total) {
    final full = total > 0 && selected == total;
    final some = selected > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: full ? _Lux.goldGradient : null,
        color: full
            ? null
            : some
            ? _Lux.gold.withOpacity(0.13)
            : const Color(0xFFF2EFE9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        "$selected/$total",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: full
              ? Colors.white
              : some
              ? _Lux.goldDeep
              : _Lux.muted,
        ),
      ),
    );
  }

  /// ================= PERMISSION MATRIX =================
  /// Rows = modules, Columns = View / Create / Edit / Delete / Manage

  Widget _permissionMatrix(PermissionGroup g) {
    final cols = _columnsFor(g);
    const colW = 42.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _Lux.line,width: 1.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            /// COLUMN HEADER (tap = aakhi column select / clear)
            Container(
              color: _Lux.ivory,
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Module",
                      style: TextStyle(
                        color: _Lux.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...cols.map((c) => _columnHeader(g, c, colW)),
                ],
              ),
            ),
            Container(height: 1, color: _Lux.line),

            /// MODULE ROWS
            ...g.modules.asMap().entries.map((e) {
              final isLast = e.key == g.modules.length - 1;
              return Column(
                children: [
                  _moduleRow(e.value, cols, colW),
                  if (!isLast)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: _Lux.line.withOpacity(0.7),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _columnHeader(PermissionGroup g, String col, double w) {
    final actions = g.modules
        .map((m) => _actionFor(m, col))
        .whereType<PermissionAction>()
        .toList();
    final all = actions.isNotEmpty && actions.every((a) => a.value);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _setActions(actions, !all),
      child: SizedBox(
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _actionIcon(col),
              size: 16,
              color: all ? _Lux.goldDeep : _Lux.muted,
            ),
            const SizedBox(height: 3),
            Text(
              _titleCase(col),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: all ? FontWeight.w700 : FontWeight.w600,
                color: all ? _Lux.goldDeep : _Lux.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleRow(PermissionModule m, List<String> cols, double w) {
    final full = m.allChecked;
    final count = m.selectedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          /// MODULE NAME (tap = aakhi row select / clear)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _setActions(m.actions, !full),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: full ? _Lux.goldDeep : _Lux.onyx,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      full
                          ? "Full access"
                          : count == 0
                          ? "No access"
                          : "$count of ${m.actions.length}",
                      style: TextStyle(
                        color: full ? _Lux.gold : _Lux.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// ACTION CELLS
          ...cols.map((c) {
            final a = _actionFor(m, c);

            if (a == null) {
              return SizedBox(
                width: w,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _Lux.line,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleAction(a),
              child: SizedBox(
                width: w,
                height: 40,
                child: Center(child: _gem(value: a.value, size: 20)),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// ================= SAVE BUTTON =================

  Widget _saveButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isSaving
            ? null
            : () {
          if (isEdit) {
            updateRole();
          } else {
            addRole();
          }
          print("Create Role");
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryDark.withOpacity(0.7),
                AppColors.secondaryDark.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: isSaving
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              selectedCount > 0
                  ? "Save Role ($selectedCount)"
                  : "Save Role",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ================= ADD ROLE =================

  Future<void> addRole() async {
    Map<String, dynamic> body = {
      "name": roleController.text.trim(),
      "permissions": _selectedIds(),
    };

    print("🔥 REQUEST BODY: $body");

    setState(() => isSaving = true);

    try {
      final response =
      await ApiHelper().postRequest(ApiConstants.add_role, body);

      print("🔥 RESPONSE: ${response?.data}");

      if (!mounted) return;

      if (response != null && response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Role Added Successfully")),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Rolescreen()),
              (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed To Add Role")),
        );
      }
    } catch (e) {
      print("❌ ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// ================= UPDATE ROLE =================

  Future<void> updateRole() async {
    final userId = widget.roleId;

    Map<String, dynamic> body = {
      "name": roleController.text.trim(),
      "permissions": _selectedIds(),
    };

    print("🔥 REQUEST BODY: $body");

    setState(() => isSaving = true);

    try {
      final response = await ApiHelper()
          .putRequest("${ApiConstants.Rolelist}/$userId", body);

      print("🔥 RESPONSE: ${response?.data}");

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Role Added Successfully")),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Rolescreen()),
              (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed To Add Role")),
        );
      }
    } catch (e) {
      print("❌ ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}

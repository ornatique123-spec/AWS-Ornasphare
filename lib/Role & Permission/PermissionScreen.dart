import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/PermissionDeniedWidget.dart';

class Permissionscreen extends StatefulWidget {
  const Permissionscreen({super.key});

  @override
  State<Permissionscreen> createState() => _PermissionscreenState();
}

class _PermissionscreenState extends State<Permissionscreen> {
  TextEditingController searchController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  List userlist = [];

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text =
      "${picked.day}-${picked.month}-${picked.year}";
    }
  }

  List allUsers = []; // 🔥 original data store


  void searchUser(String value) {
    if (value.isEmpty) {
      setState(() {
        userlist = allUsers; // reset
      });
      return;
    }

    List filteredList = allUsers.where((user) {
      final name = user["name"]?.toString().toLowerCase() ?? "";
      final role = user["role"]?.toString().toLowerCase() ?? "";

      return name.contains(value.toLowerCase()) ||
          role.contains(value.toLowerCase());
    }).toList();

    setState(() {
      userlist = filteredList;
    });
  }

  void applyDateFilter() {
    if (fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {
      setState(() {
        userlist = allUsers;
      });
      return;
    }

    DateTime fromDate = _convertToDate(fromDateController.text);
    DateTime toDate = _convertToDate(toDateController.text);

    List filtered = allUsers.where((user) {
      if (user["created_at"] == null) return false;

      DateTime userDate = DateTime.parse(user["created_at"]);

      return userDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(toDate.add(const Duration(days: 1)));
    }).toList();

    setState(() {
      userlist = filtered;
    });
  }


  List<String> userPermissions = [];   // 🔥 ADD
  Future<void> loadPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 🔥 Full prefs debug
    Set<String> keys = prefs.getKeys();
    print("🔥 All SharedPreferences Keys: $keys");

    List<String> perms = prefs.getStringList("user_permissions") ?? [];
    print("🔥 user_permissions value: $perms");

    setState(() {
      userPermissions = perms;
    });
  }

  /// 🔥 Permission check helper
  bool hasPermission(String permissionName) {
   // print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    category();
    loadPermissions();
  }
  @override
  Widget build(BuildContext context) {

    if(!(
        hasPermission("permission-view") ||
            hasPermission("permission-manage")
    )){
      return Scaffold(
        body: PermissionDeniedWidget(
          onBack: (){
            Navigator.pop(context);
          },
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final isMobile = width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => const HomeScreen(),
        //   ),
        // );
        Navigator.pop(context,true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [

            /// 🔥 MAIN CONTENT
            Column(
              children: [

                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 40,
                ),


                Expanded(
                  child: userlist.isEmpty
                      ? const Center(
                    child: Text(
                      "No Data Found",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: userlist.length,
                    itemBuilder: (context, index) {
                      return buildUserCard(
                        userlist[index],
                        index,
                      );
                    },
                  ),
                ),

                if (hasPermission("permission-create"))
                /// Bottom Button
                InkWell(
                  onTap: () {
                    showCreatePermissionDialog();
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark.withOpacity(0.7),
                            AppColors.secondaryDark.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          "+ Create Permission",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                    const Text(
                      "Permission",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    /// ✅ LEFT BACK ICON
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => const HomeScreen(),
                          //   ),
                          // );
                          Navigator.pop(context,true);
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color:AppColors.primaryDark,
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

                    /// RIGHT NOTIFICATION ICON
                    // Align(
                    //   alignment: Alignment.centerRight,
                    //
                    //   child: Container(
                    //     padding: EdgeInsets.all(isMobile ? 6 : 8),
                    //
                    //     decoration: BoxDecoration(
                    //       color: Colors.white,
                    //
                    //       borderRadius: BorderRadius.circular(8),
                    //
                    //       boxShadow: [
                    //         BoxShadow(
                    //           color: AppColors.shadow,
                    //
                    //           blurRadius: 20,
                    //
                    //           offset: const Offset(5, 10),
                    //         ),
                    //       ],
                    //     ),
                    //
                    //     child: Stack(
                    //       clipBehavior: Clip.none,
                    //
                    //       children: [
                    //         Icon(
                    //           Icons.notifications_none,
                    //
                    //           size: isMobile ? 22 : 24,
                    //
                    //           color: Colors.red,
                    //         ),
                    //
                    //         Positioned(
                    //           right: -2,
                    //
                    //           top: -2,
                    //
                    //           child: Container(
                    //             height: 8,
                    //
                    //             width: 8,
                    //
                    //             decoration: const BoxDecoration(
                    //               color: Colors.red,
                    //
                    //               shape: BoxShape.circle,
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            )

          ],
        ),
      ),
    );

  }



  int? expandedPermissionId;

  Widget buildUserCard(Map user, int index) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;

    /// =========================================================
    /// UNIQUE ID
    /// =========================================================
    final int id =
        int.tryParse(user["id"]?.toString() ?? "0") ?? 0;

    final bool isExpanded = expandedPermissionId == id;

    /// =========================================================
    /// DATA
    /// =========================================================
    final String name =
    (user["name"] == null ||
        user["name"].toString().trim().isEmpty)
        ? "-"
        : user["name"].toString();

    final String createdAt =
        user["created_at"]?.toString() ?? "";

    final int rolesCount =
        int.tryParse(user["roles_count"]?.toString() ?? "0") ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),

      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),

        border: Border.all(
          color: isExpanded
              ? AppColors.primaryDark.withOpacity(0.45)
              : AppColors.border,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),

        child: Column(
          children: [

            /// =====================================================
            /// HEADER
            /// ALWAYS VISIBLE
            /// =====================================================
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 10,
                vertical: isTablet ? 12 : 10,
              ),

              child: Row(
                children: [

                  /// =================================================
                  /// INDEX
                  /// =================================================
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,

                    decoration: BoxDecoration(
                      color: AppColors.gradientBlue,
                      borderRadius: BorderRadius.circular(5),
                    ),

                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  /// =================================================
                  /// PERMISSION NAME + ROLE COUNT
                  /// =================================================
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// Permission Name
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 3),

                        /// Role Count
                        Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              "Roles: $rolesCount",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  /// =================================================
                  /// EDIT
                  /// =================================================
                  if (hasPermission("permission-edit") ||
                      hasPermission("permission-manage")) ...[
                    premiumIconBtn(
                      Icons.edit_rounded,
                      AppColors.gradientBlue,
                      onTap: () {
                        showEditPermissionDialog(user);
                      },
                    ),

                    SizedBox(
                      width: isTablet ? 8 : 5,
                    ),
                  ],

                  /// =================================================
                  /// DELETE
                  /// =================================================
                  if (hasPermission("permission-delete") &&
                      rolesCount == 0) ...[
                    premiumIconBtn(
                      Icons.delete_outline_rounded,
                      Colors.red,
                      onTap: () {
                        _showDeleteDialog(user);
                      },
                    ),

                    SizedBox(
                      width: isTablet ? 8 : 5,
                    ),
                  ],

                  /// =================================================
                  /// EXPAND BUTTON
                  /// =================================================
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedPermissionId == id) {
                          /// Same card click -> Close
                          expandedPermissionId = null;
                        } else {
                          /// New card open
                          /// Previous automatically close
                          expandedPermissionId = id;
                        }
                      });
                    },

                    borderRadius: BorderRadius.circular(20),

                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,

                      duration: const Duration(
                        milliseconds: 250,
                      ),

                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,

                        decoration: BoxDecoration(
                          color:
                          AppColors.primaryDark.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// =====================================================
            /// EXPANDED SECTION
            /// =====================================================
            AnimatedCrossFade(
              duration: const Duration(
                milliseconds: 250,
              ),

              firstChild: const SizedBox(
                width: double.infinity,
                height: 0,
              ),

              secondChild: Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(
                  10,
                  0,
                  10,
                  10,
                ),

                child: Column(
                  children: [

                    /// =================================================
                    /// DIVIDER
                    /// =================================================
                    Divider(
                      height: 1,
                      color: AppColors.border,
                    ),

                    const SizedBox(height: 10),

                    /// =================================================
                    /// ERP DETAILS
                    /// =================================================
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.background,

                        border: Border.all(
                          color: AppColors.border,
                          width: 1.2,
                        ),

                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: Column(
                        children: [

                          /// ===========================================
                          /// DATE / ROLE COUNT
                          /// ===========================================
                          _erpRow(
                            "Date",
                            createdAt.isNotEmpty
                                ? formatDate(createdAt)
                                : "-",

                            "Role Count",
                            rolesCount.toString(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ),
      ),
    );
  }



  Future<void> category() async {

    final response =
    await ApiHelper().getRequest(ApiConstants.permission_list);

    print("user API URL: ${ApiConstants.permission_list}");
    print("users Raw Response: ${response.toString()}");

    if (response!.statusCode == 200) {

      final data = response.data;

      // ✅ success check
      final List categories = data['data'];

      setState(() {
        userlist = categories;
        allUsers = categories; // 🔥 store original
      });

      print("✅ Total user: ${userlist.length}");

    } else {
      setState(() {
        userlist = [];
      });
      print("❌ userlist API failed");
    }
  }


  void _showDeleteDialog(Map user) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Delete",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final screenWidth = MediaQuery.of(context).size.width;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              width: screenWidth * 0.85,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  /// 🔥 Delete Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xffff4e50),
                          Color(0xfff00000),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Delete User?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Are you sure you want to delete ${user["name"]}?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Row(
                    children: [

                      /// Cancel Button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// Delete Button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff00000),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {

                            Navigator.pop(context); // close dialog

                            deleteUser(user["id"].toString()); // Your API call

                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> deleteUser(String ID) async {
    try {
      final response = await ApiHelper().deleteRequest(
        "${ApiConstants.permission_list}/$ID",
      );

      if (response?.statusCode == 200) {
        print("✅ Deleted Successfully");
        print("Response: ${response?.data}");

        category();

      } else {
        print("❌ Logout failed | Status: ${response?.statusCode}");
      }

    } catch (e) {
      print("❌ Logout exception: $e");
    }
  }

  Future<void> update_permision(String ID,String text) async {

    final body = {

      "name": text.trim(),
    };

    try {

      final response = await ApiHelper().putRequest(

        "${ApiConstants.permission_list}/$ID",

        body, // 🔥 IMPORTANT
      );

      if (response != null &&
          response.statusCode == 200) {

        print("✅ Permission Updated Successfully");

        print("Response: ${response.data}");

        //Navigator.pop(context);

        category();

      } else {

        print(
          "❌ Update failed | Status: ${response?.statusCode}",
        );

        print("Response: ${response?.data}");
      }

    } catch (e) {

      print("❌ Update exception: $e");
    }
  }

  void showCreatePermissionDialog() {

    TextEditingController permissionController =
    TextEditingController();

    showDialog(

      context: context,

      barrierDismissible: true,

      builder: (context) {

        return Dialog(

          backgroundColor: const Color(0xff1E2235),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),

          child: Container(

            width: MediaQuery.of(context).size.width * 0.7,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                /// HEADER
                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),

                  decoration: const BoxDecoration(

                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xff2B3152),
                      ),
                    ),
                  ),

                  child: const Text(

                    "Create Permission",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 22,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// BODY
                Padding(

                  padding: const EdgeInsets.all(20),

                  child: Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      const Text(

                        "Permission Name",

                        style: TextStyle(

                          color: Colors.white70,

                          fontSize: 15,

                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(

                        controller: permissionController,

                        style: const TextStyle(
                          color: Colors.white,
                        ),

                        decoration: InputDecoration(

                          filled: true,

                          fillColor:
                          const Color(0xff2A2F4F),

                          hintText: "Enter Permission",

                          hintStyle: const TextStyle(
                            color: Colors.white54,
                          ),

                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 14,
                          ),

                          border: OutlineInputBorder(

                            borderRadius:
                            BorderRadius.circular(2),

                            borderSide: BorderSide.none,
                          ),

                          enabledBorder:
                          OutlineInputBorder(

                            borderRadius:
                            BorderRadius.circular(2),

                            borderSide: BorderSide.none,
                          ),

                          focusedBorder:
                          OutlineInputBorder(

                            borderRadius:
                            BorderRadius.circular(2),

                            borderSide: const BorderSide(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// FOOTER
                Container(

                  padding: const EdgeInsets.all(18),

                  decoration: const BoxDecoration(

                    border: Border(
                      top: BorderSide(
                        color: Color(0xff2B3152),
                      ),
                    ),
                  ),

                  child: Row(

                    mainAxisAlignment:
                    MainAxisAlignment.end,

                    children: [

                      /// BACK
                      ElevatedButton(

                        style: ElevatedButton.styleFrom(

                          backgroundColor:
                          Colors.blue,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                        ),

                        onPressed: () {

                          Navigator.pop(context);
                        },

                        child: const Text(

                          "Back",

                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// CREATE
                      ElevatedButton(

                        style: ElevatedButton.styleFrom(

                          backgroundColor:
                          Colors.green,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                        ),

                        onPressed: () async {

                          Navigator.pop(context);

                          createPermission(
                            permissionController.text,
                          );
                        },

                        child: const Text(

                          "Create",

                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> createPermission(String text) async {

    final body = {

      "name": text.trim(),
    };

    try {

      final response = await ApiHelper().postRequest(

        ApiConstants.Add_permission_list,

        body,
      );

      if (response != null &&
          (response.statusCode == 200 ||
              response.statusCode == 201)) {

        print("✅ Permission Created");

        print(response.data);

        category();

      } else {

        print(
          "❌ Create failed | ${response?.statusCode}",
        );

        print(response?.data);
      }

    } catch (e) {

      print("❌ Create exception: $e");
    }
  }

  Widget premiumIconBtn(IconData icon, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _erpRow(String t1, String v1, String t2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [

          /// Left Field
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    t1,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    v1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Right Field
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    t2,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black, // ✅ FIX
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    v2,
                    style: const TextStyle(
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                      color: Colors.black, // ✅ FIX
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String date) {
    return date.split("T")[0].split("-").reversed.join("-");
  }

  DateTime _convertToDate(String input) {
    final parts = input.split("-");
    return DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
  }

  void showEditPermissionDialog(Map user) {

    TextEditingController permissionController =
    TextEditingController(
      text: user["name"] ?? "",
    );

    showDialog(

      context: context,

      barrierDismissible: true,

      builder: (context) {

        return Dialog(

          backgroundColor: const Color(0xff1E2235),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),

          child: Container(

            width: MediaQuery.of(context).size.width * 0.7,

            padding: const EdgeInsets.all(0),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                /// HEADER
                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),

                  decoration: const BoxDecoration(

                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xff2B3152),
                      ),
                    ),
                  ),

                  child: const Text(

                    "Edit Permission",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 22,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// BODY
                Padding(

                  padding: const EdgeInsets.all(20),

                  child: Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      const Text(

                        "Permission Name",

                        style: TextStyle(

                          color: Colors.white70,

                          fontSize: 15,

                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(

                        controller: permissionController,

                        style: const TextStyle(
                          color: Colors.white,
                        ),

                        decoration: InputDecoration(

                          filled: true,

                          fillColor:
                          const Color(0xff2A2F4F),

                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 14,
                          ),

                          border: OutlineInputBorder(

                            borderRadius:
                            BorderRadius.circular(2),

                            borderSide: BorderSide.none,
                          ),

                          enabledBorder:
                          OutlineInputBorder(

                            borderRadius:
                            BorderRadius.circular(2),

                            borderSide: BorderSide.none,
                          ),

                          focusedBorder:
                          OutlineInputBorder(

                            borderRadius:
                            BorderRadius.circular(2),

                            borderSide: const BorderSide(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// FOOTER BUTTONS
                Container(

                  padding: const EdgeInsets.all(18),

                  decoration: const BoxDecoration(

                    border: Border(
                      top: BorderSide(
                        color: Color(0xff2B3152),
                      ),
                    ),
                  ),

                  child: Row(

                    mainAxisAlignment:
                    MainAxisAlignment.end,

                    children: [

                      /// BACK BUTTON
                      ElevatedButton(

                        style: ElevatedButton.styleFrom(

                          backgroundColor:
                          Colors.blue,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                        ),

                        onPressed: () {

                          Navigator.pop(context);
                        },

                        child: const Text(

                          "Back",

                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// UPDATE BUTTON
                      ElevatedButton(

                        style: ElevatedButton.styleFrom(

                          backgroundColor:
                          Colors.green,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                        ),

                        onPressed: () async {

                          Navigator.pop(context);

                          update_permision(

                            user["id"].toString(),

                            permissionController.text,
                          );
                        },

                        child: const Text(

                          "Update",

                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

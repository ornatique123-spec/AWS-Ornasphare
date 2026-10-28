import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Worker/CreateJobWorker.dart';
import 'package:pecifician_sysytem/User/CreateCustomer.dart';
import 'package:pecifician_sysytem/User/CreteUserScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Dashboard/HomeScreen.dart';
import '../../Extra/PermissionDeniedWidget.dart';


class Jobworkerscreen extends StatefulWidget {
  const Jobworkerscreen({super.key});

  @override
  State<Jobworkerscreen> createState() => _JobworkerscreenState();
}

class _JobworkerscreenState extends State<Jobworkerscreen> {
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

    DateTime fromDate =
    _convertToDate(fromDateController.text);

    DateTime toDate =
    _convertToDate(toDateController.text);

    List filtered = allUsers.where((user) {

      /// 🔥 USE MAIN created_at
      if (user["created_at"] == null) {
        return false;
      }

      DateTime userDate =
      DateTime.parse(user["created_at"]);

      return userDate.isAfter(
          fromDate.subtract(const Duration(days: 1))) &&
          userDate.isBefore(
              toDate.add(const Duration(days: 1)));

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
    //print("🔥 Checking '$permissionName' in $userPermissions => ${userPermissions.contains(permissionName)}");
    return userPermissions.contains(permissionName);
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadPermissions();
    DateTime today = DateTime.now();
    DateTime sevenDaysAgo = today.subtract(const Duration(days: 7));

    String formatDate(DateTime date) {
      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    }

    fromDateController.text = formatDate(sevenDaysAgo);
    toDateController.text = formatDate(today);

    String from = DateFormat("yyyy-MM-dd").format(
      DateFormat("dd-MM-yyyy").parse(fromDateController.text),
    );

    String to = DateFormat("yyyy-MM-dd").format(
      DateFormat("dd-MM-yyyy").parse(toDateController.text),
    );

    category();
  }
  @override
  Widget build(BuildContext context) {


    if(!(
        hasPermission("job-worker-view") ||
            hasPermission("job-worker-manage")
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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,  // ⭐ IMPORTANT FIX
        backgroundColor: AppColors.white,
        body: Stack(
          children: [

            /// ✅ Background Image
            // Positioned.fill(
            //   child: Image.asset(
            //     "assets/static/img_3.png",
            //     fit: BoxFit.fill,
            //   ),
            // ),

            /// 🔥 MAIN CONTENT
            Column(
              children: [

                /// IMPORTANT: top padding space leave karvu (AppBar mate)
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 40,
                ),

                filterWidget(),

                // Row(
                //   children: [
                //
                //     /// PDF BUTTON
                //     Expanded(
                //       child: pdfBtn(() {
                //         openPdf();
                //         print("PDF Click");
                //       }),
                //     ),
                //
                //     const SizedBox(width: 10),
                //
                //     /// EXCEL BUTTON
                //     Expanded(
                //       child: excelBtn(() {
                //         openexel();
                //         print("Excel Click");
                //       }),
                //     ),
                //
                //   ],
                // ),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: double.infinity,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark.withOpacity(0.1),
                        AppColors.primaryDark,
                        AppColors.secondaryDark.withOpacity(0.4),
                        AppColors.primaryDark.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                      return buildUserCard(userlist[index]);
                    },
                  ),
                ),
                if (hasPermission("job-worker-create"))
                /// Bottom Button
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Createjobworker(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient:LinearGradient(
                          colors: [
                            AppColors.primaryDark.withOpacity(0.7),
                            AppColors.secondaryDark.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          "+ Create Job Worker",
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
                      "Job Worker",
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





  Widget buildUserCard(Map user) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final isDesktop = size.width >= 1000;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// ================= MAIN CONTENT =================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// STATUS + ACTIONS ROW
                Row(
                  children: [


                    /// STATUS
                    statusChip(user["is_active"].toString()),
                    SizedBox(width: 20,),

                    Row(
                      children: [
                        Text(
                          user["name"] ?? "",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black, // ✅ FIX
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // const Spacer(),
                        // Text(
                        //   user["name"] ?? "",
                        //   style: const TextStyle(
                        //     fontSize: 15,
                        //     color: Colors.black, // ✅ FIX
                        //     fontWeight: FontWeight.w600,
                        //   ),
                        // ),
                      ],
                    ),

                    const Spacer(),

                    /// ACTION BUTTONS
                    Row(
                      children: [
                        if (hasPermission("job-worker-edit"))
                        premiumIconBtn(
                          Icons.edit,
                          Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    Createjobworker(userData: user),
                              ),
                            );
                          },
                        ),

                        SizedBox(width: isTablet ? 10 : 8),
                        if (hasPermission("job-worker-delete"))
                        premiumIconBtn(
                          Icons.delete,
                          Colors.red,
                          onTap: () {
                            setState(() {
                              _showDeleteDialog(user);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: isTablet ? 10 : 8),
                //
                // Row(
                //   children: [
                //     Text(
                //       user["role"] ?? "",
                //       style: const TextStyle(
                //         fontSize: 15,
                //         color: Colors.black, // ✅ FIX
                //         fontWeight: FontWeight.w600,
                //       ),
                //     ),
                //     const Spacer(),
                //     Text(
                //       user["name"] ?? "",
                //       style: const TextStyle(
                //         fontSize: 15,
                //         color: Colors.black, // ✅ FIX
                //         fontWeight: FontWeight.w600,
                //       ),
                //     ),
                //   ],
                // ),
                //
                // const SizedBox(height: 10),

                /// 🔥 ERP GRID (MAIN FIX)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color:AppColors.background,
                    border: Border.all(color: AppColors.border,width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [

                      /// Row 1
                      _erpRow(
                        "Date",
                        user["created_at"] != null
                            ? formatDate(user["created_at"])
                            : "-",
                        "Email",
                        user["email"]?.toString() ?? "-",
                      ),

                      Divider(height: 1, color: AppColors.border),


                      /// Row 2
                      _erpRow(
                        "City",
                        user["city"]?.toString() ?? "-",
                        "Mobile",
                        user["mobile_no"]?.toString() ?? "-",
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget permissionChip(String text, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 12,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1633),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: isTablet ? 12 : 11,
        ),
      ),
    );
  }



  Future<void> category() async {


    final response =
    await ApiHelper().getRequest(ApiConstants.Job_Worker);

    print("Customer List API URL: ${ApiConstants.Job_Worker}");
    print("Customer List Raw Response: ${response.toString()}");

    if (response!.statusCode == 200) {

      final data = response.data;

      // ✅ success check
      final List categories = data['data'];

      setState(() {
        userlist = categories;
        allUsers = categories; // 🔥 store original
      });
      applyDateFilter();
      print("✅ Total Customer: ${userlist.length}");

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
        "${ApiConstants.delete_job_worker}/$ID",
      );

      if (response?.statusCode == 200) {
        print("✅ Deleted Successfully");
        print("Response: ${response?.data}");

        String from = DateFormat("yyyy-MM-dd").format(
          DateFormat("dd-MM-yyyy").parse(fromDateController.text),
        );

        String to = DateFormat("yyyy-MM-dd").format(
          DateFormat("dd-MM-yyyy").parse(toDateController.text),
        );

        category();

      } else {
        print("❌ Logout failed | Status: ${response?.statusCode}");
      }

    } catch (e) {
      print("❌ Logout exception: $e");
    }
  }

  Widget filterWidget() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [

          /// 🔍 SEARCH FIELD
          TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.black),
            onChanged: (value) {
              searchUser(value); // 🔥 LIVE SEARCH
            },
            decoration: InputDecoration(
              hintText: "Search Job Worker",
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.search, color:AppColors.primaryDark),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border)
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color:AppColors.border),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: 5),



          /// 🔥 BUTTONS
          Row(
            children: [

              // Expanded(
              //   child: customButton(
              //     title: "Show",
              //     gradient: LinearGradient(
              //       colors: [
              //         AppColors.primaryDark,
              //         AppColors.secondaryDark,
              //       ],
              //     ),
              //     onTap: () {
              //       String from = DateFormat("yyyy-MM-dd").format(
              //         DateFormat("dd-MM-yyyy").parse(fromDateController.text),
              //       );
              //
              //       String to = DateFormat("yyyy-MM-dd").format(
              //         DateFormat("dd-MM-yyyy").parse(toDateController.text),
              //       );
              //
              //       category();
              //     },
              //   ),
              // ),

              //const SizedBox(width: 10),


              Expanded(
                child: customButton(
                  title: "PDF",
                  icon: Icons.picture_as_pdf,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xffE57373), Color(0xffD32F2F),Color(0xffE57373)
                    ],
                  ),
                  onTap: () {
                    openPdf();
                  },
                ),
              ),


              const SizedBox(width: 10),


              Expanded(
                child: customButton(
                  title: "Excel",
                  icon: Icons.table_chart,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff66BB6A), // light green
                      Color(0xff2E7D32), // dark green
                      Color(0xff66BB6A), // light green
                    ],
                  ),
                  onTap: () {
                    openexel();
                  },
                ),
              ),

            ],
          )
        ],
      ),
    );
  }

  Widget customButton({
    required String title,
    IconData? icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {

    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(5),

      child: Container(
        height: 35,

        decoration: BoxDecoration(

          gradient: gradient,

          borderRadius: BorderRadius.circular(5),

        ),


        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            if(icon != null)...[

              Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),

              const SizedBox(width: 6),

            ],


            Text(
              title,

              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),

            ),

          ],
        ),
      ),
    );
  }
  /// 🔹 Status Chip
  Widget statusChip(dynamic status) {

    Color startColor;
    Color endColor;
    String label;

    if (status == "true") {
      /// 🔹 Active
      startColor = const Color(0xffC8A96A);
      endColor   = const Color(0xffE6C58A);
      label = "Active";

    } else if (status == "false") {
      /// 🔹 Inactive
      startColor = const Color(0xffD9534F);
      endColor   = const Color(0xffF28B82);
      label = "Inactive";

    } else {
      /// 🔹 Unknown
      startColor = const Color(0xff9E9E9E);
      endColor   = const Color(0xffCFCFCF);
      label = "Unknown";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  Widget premiumIconBtn(IconData icon, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(4),
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
                  flex: 2,
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

  /// 🔹 PDF Button
  Widget pdfBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 0, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffE57373), Color(0xffD32F2F),Color(0xffE57373)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text("PDF",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500,fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget excelBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 10, 20, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff66BB6A), // light green
              Color(0xff2E7D32), // dark green
              Color(0xff66BB6A), // light green
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.table_chart, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              "Excel",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> openPdf() async {

    final response = await ApiHelper().getPdfRequest(
      ApiConstants.Job_export_pdf,
    );

    if (response != null && response.statusCode == 200) {

      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/job_workers.pdf");

      /// 🔥 SAFE CAST
      final bytes = response.data as List<int>;

      await file.writeAsBytes(bytes);

      OpenFile.open(file.path);

    } else {
      print("PDF Download Failed");
    }
  }


  Future<void> openexel() async {

    final response = await ApiHelper().getPdfRequest(
      ApiConstants.Job_export_exel,
    );

    if (response != null && response.statusCode == 200) {

      final dir = await getTemporaryDirectory();

      final file = File(
        "${dir.path}/job_workers_${DateTime.now().millisecondsSinceEpoch}.xlsx",
      );

      final bytes = response.data as List<int>;

      await file.writeAsBytes(bytes);

      OpenFile.open(file.path);

    } else {
      print("Excel Download Failed");
    }
  }




}

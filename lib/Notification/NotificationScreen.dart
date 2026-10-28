import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label/LabelScreen.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Work%20Issue/Jobwork_issue_Screen.dart';
import 'package:pecifician_sysytem/Job%20Work/Job%20Worker/JobWorkerScreen.dart';
import 'package:pecifician_sysytem/Job%20Work/Labour_Formula/Job_labourformula_Screen.dart';
import 'package:pecifician_sysytem/User/CustomerScreen.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';
import '../Approval/ApproveListScreen.dart';
import '../Extra/AppColors.dart';
import '../Extra/NotificationProvider.dart';
import '../Item_Mangement/Label_Items/label_item_screen.dart';
import '../Job Work/Production_Costs/ProductionCost.dart';
import '../Job Work/Production_Steps/ProoductionStepScreen.dart';
import '../Sell_estimate/Sell_list.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {



  List<NotificationModel> notifications = [];

  Future<void> getNotifications() async {
    try {
      final response = await ApiHelper().getRequest(ApiConstants.notification);

      print(response?.data);

      if (response != null && response.statusCode == 200) {
        final data = response.data;

        if (data["success"] == true) {
          if (!mounted) return;
          setState(() {
            notifications = (data["data"] as List)
                .map((e) => NotificationModel.fromJson(e))
                .where((e) => e.readAt == null)
                .toList();
          });
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getNotifications();
  }

  @override
  Widget build(BuildContext context) {

    int unread = notifications.where((e) => !e.isRead).length;

    return PopScope(
      canPop: false,
      // Phone nu back button pan true mokle
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,

        body: Stack(
          children: [

            /// Main Body
            Column(
              children: [

                /// AppBar Space
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 30,
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 10,bottom: 20),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      return notificationCard(notifications[index]);
                    },
                  ),
                ),
              ],
            ),

            /// Overlay AppBar
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

                    /// Title
                    Text(
                      unread > 0 ? "Notifications ($unread)" : "Notifications",
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black
                      ),
                    ),

                    /// Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        // 🔥 true → Home ma count refresh thay
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    /// Mark All Read
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: markAllRead,
                        child: const Text(
                          "Mark all read",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

      ),
    );

  }

  /// 🔔 Bell / drawer / home card no count server mathi farithi
  void _refreshCount() {
    if (!mounted) return;
    try {
      context.read<NotificationProvider>().loadNotificationCount();
    } catch (e) {
      debugPrint("Notification count refresh error: $e");
    }
  }

  bool _markingAll = false;

  /// App ma count dekhata badha module (drawer + home card).
  /// Notification list ma na hoy (pagination / limit) to pan count vala
  /// module pan read thai jay.
  static const List<String> _knownModules = [
    "item", "label_config", "item_set", "label_print", "other_charge",
    "labour_formula", "production_cost", "production_step", "job_worker",
    "jobwork_issue", "jobwork_receive",
    "vacuum_buch", "vacuum_process", "vacuum_voucher", "casting_heating",
    "casting_metal_issue", "casting_release", "tree_cutting_office",
    "tree_cutting_issue", "tree_cutting_receive", "casting_sorting",
    "voucher-history", "voucher_history",
    "role", "permission", "user", "users", "customer", "customers",
    "sale", "sales", "approval", "approval_return", "bullion",
    "visiting_card", "stock_gallery",
  ];

  /// 🔥 MARK ALL READ — badha module read (bell + premium card + drawer
  /// banne jagya e count jato rahe)
  Future<void> markAllRead() async {
    if (_markingAll) return;

    final NotificationProvider provider = context.read<NotificationProvider>();

    // 1) List ma dekhata module  2) jena count > 0 chhe e module
    final Set<String> modules = {
      ...notifications.map((e) => e.module).where((m) => m.isNotEmpty),
      ..._knownModules.where((m) {
        try {
          return provider.moduleCount(m) > 0;
        } catch (_) {
          return false;
        }
      }),
    };

    if (modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No unread notifications")),
      );
      return;
    }

    _markingAll = true;
    setState(() => notifications.clear());

    final results = await Future.wait(modules.map(readModule));
    _markingAll = false;
    if (!mounted) return;

    // Count turant + thodi var pachhi farithi (server late hoy to pan sacho)
    _refreshCount();
    Future.delayed(const Duration(milliseconds: 700), _refreshCount);

    if (results.contains(false)) {
      // Koi module fail → server mathi sachi list
      await getNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Some notifications could not be marked read")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All notifications marked as read")),
    );
  }

  bool _opening = false;

  /// 🔥 Notification click → read API → count minus → page open →
  /// back aave tyare list + count farithi
  Future<void> _onTapNotification(NotificationModel item) async {
    if (_opening) return;
    _opening = true;

    // Read-module aakha module ne read kare → e module ni badhi notification hatavo
    bool sameGroup(NotificationModel e) =>
        item.module.isNotEmpty ? e.module == item.module : e.id == item.id;

    setState(() => notifications.removeWhere(sameGroup));

    try {
      final bool success = await readModule(item.module);
      if (!mounted) return;

      if (!success) {
        await getNotifications(); // pachhi aavi jay
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not mark notification as read")),
        );
        return;
      }

      _refreshCount(); // badge turant minus

      await openNotification(item);
      if (!mounted) return;

      // Pachha aavya → navi list + count
      await getNotifications();
      _refreshCount();
    } finally {
      _opening = false;
    }
  }

  Widget notificationCard(NotificationModel item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: item.isRead
            ? const Color(0xff4A4F5B) // Read
            : const Color(0xff3A2738), // Unread
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xffFF3D81),
                Color(0xff8A4DFF),
              ],
            ),
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ),
          ),
          child: const Icon(
            Icons.info_outline,
            color: Colors.white,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              item.message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.createdAt,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => _onTapNotification(item),
      ),
    );
  }

  Future<bool> readModule(String module) async {
    try {
      final response = await ApiHelper().postRequest(
        "${ApiConstants.baseUrl}notifications/read-module",
        {
          "module": module,
        },
      );

      print("Read Module Response : ${response?.data}");

      return response != null &&
          response.statusCode == 200 &&
          response.data["success"] == true;
    } catch (e) {
      print("Read Module Error : $e");
      return false;
    }
  }

  Future<void> openNotification(NotificationModel item) async {

    final url = item.redirectUrl ?? "";

    if (url.contains("customers")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const Customerscreen(),
        ),
      );

    } else if (url.contains("sales")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SellList(),
        ),
      );

    } else if (url.contains("approval")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const InvoiceScreen(),
        ),
      );

    } else if (url.contains("labour-formula")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const JobLabourformulaScreen(),
        ),
      );

    } else if (url.contains("production-cost")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const Productioncost(),
        ),
      );

    } else if (url.contains("production-step")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const Prooductionstepscreen(),
        ),
      );

    } else if (url.contains("job-workers")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const Jobworkerscreen(),
        ),
      );

    } else if (url.contains("jobwork-issue")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const JobworkIssueScreen(),
        ),
      );

    } else if (url.contains("label-config")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const Labelscreen(),
        ),
      );

    } else if (url.contains("list_itemset")) {

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const label_item_screen(),
        ),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Page not found"),
        ),
      );

    }
  }

}

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String module;
  final String action;
  final String actor;
  final String? redirectUrl;
  late bool isRead;
  final String? readAt;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.module,
    required this.action,
    required this.actor,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.redirectUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json["id"],
      title: json["title"] ?? "",
      message: json["message"] ?? "",
      module: json["module"] ?? "",
      action: json["action"] ?? "",
      actor: json["actor"] ?? "",
      isRead: json["is_read"] ?? false,
      readAt: json["read_at"],
      createdAt: json["created_at"] ?? "",
      redirectUrl: json["redirect_url"],
    );
  }
}
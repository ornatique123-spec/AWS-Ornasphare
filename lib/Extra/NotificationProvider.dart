import 'package:flutter/material.dart';

import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';

class NotificationProvider extends ChangeNotifier {

  int total = 0;

  Map<String, int> modules = {};

  Map<String, String> labels = {};

  bool loading = false;

  bool _reloadPending = false;

  Future<void> loadNotificationCount() async {
    // Chalu call vakhte navi aave to gumavi nahi, pachhi farithi chalavo
    if (loading) {
      _reloadPending = true;
      return;
    }

    loading = true;

    try {
      final response = await ApiHelper()
          .getRequest(ApiConstants.notification_summary, showLoading: false);

      if (response != null &&
          response.statusCode == 200 &&
          response.data["success"] == true) {
        final data = response.data["data"] ?? {};

        total = int.tryParse("${data["total"] ?? 0}") ?? 0;

        // 🔥 modules: {} (count hoy) athva [] (khali) — banne chale
        final Map<String, int> m = {};
        final rawModules = data["modules"];
        if (rawModules is Map) {
          rawModules.forEach((k, v) {
            m["$k"] = int.tryParse("$v") ?? 0;
          });
        } else if (rawModules is List) {
          for (final e in rawModules) {
            if (e is Map && e["module"] != null) {
              m["${e["module"]}"] =
                  int.tryParse("${e["count"] ?? e["unread"] ?? 0}") ?? 0;
            }
          }
        }
        modules = m; // khali aave to badha module 0

        final rawLabels = data["labels"];
        labels = rawLabels is Map
            ? rawLabels.map((k, v) => MapEntry("$k", "$v"))
            : {};

        notifyListeners();
      }
    } catch (e) {
      print("Notification summary error: $e");
    } finally {
      loading = false;
    }

    // Vachche aavel request pachhi chalavo, etle chhello count sacho rahe
    if (_reloadPending) {
      _reloadPending = false;
      await loadNotificationCount();
    }
  }

  /// Total Notification Count
  int get totalCount => total;

  /// Module Count
  int moduleCount(String module) {
    return modules[module] ?? 0;
  }

  /// Module Label
  String moduleLabel(String module) {
    return labels[module] ?? module;
  }

  /// Check Notification Exists
  bool hasNotification(String module) {
    return modules.containsKey(module) && (modules[module] ?? 0) > 0;
  }

  /// Read One Module
  void clearModule(String module) {
    modules.remove(module);
    total = modules.values.fold(0, (a, b) => a + b);
    notifyListeners();
  }

  /// Read All
  void clearAll() {
    modules.clear();
    total = 0;
    notifyListeners();
  }

  /// Get All Modules with Count
  List<Map<String, dynamic>> get moduleList {
    return modules.entries.map((e) {
      return {
        "module": e.key,
        "count": e.value,
        "label": labels[e.key] ?? e.key,
      };
    }).toList();
  }

  int totalCountOf(List<String> moduleNames) {
    int total = 0;

    for (final module in moduleNames) {
      total += modules[module] ?? 0;
    }

    return total;
  }
}
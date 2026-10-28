import 'package:flutter/material.dart';
import '../Api_Constant/ApiConstants.dart';
import '../Api_Constant/api_helper.dart';

class ItemProvider extends ChangeNotifier {

  List items = [];
  bool isLoading = false;
  bool isLoaded = false; // 🔥 important


  /// 🔹 CUSTOMER LIST
  List customers = [];
  bool isCustomersLoaded = false;

  /// 🔹 CUSTOMER LIST jobwork
  List customers_list = [];
  bool isCustomers_list_Loaded = false;

  /// 🔹 labour formula LIST
  List labour_formula = [];
  bool isLabourformulaLoaded = false;

  /// 🔹 Production Cost LIST
  List Production_cost = [];
  bool isProduction_costLoaded = false;

  /// 🔹 Production Steps LIST
  List Production_steps = [];
  bool isProduction_stepLoaded = false;


  /// 🔹 Job Worker  LIST
  List Job_worker = [];
  bool isJobWorkerLoaded = false;

  /// 🔹 CUSTOMER LIST
  List customers_return = [];
  bool isCustomersreturnLoaded = false;

  /// 🔹 Approval CUSTOMER LIST
  List Approval_customers = [];
  bool isApprovalCustomersLoaded = false;

  /// 🔹 Approval CUSTOMER LIST
  List Vacuum_Process = [];
  bool isVacumProcessLoaded = false;

  /// 🔹 Buch LIST
  List Buch_list = [];
  bool isBuchlistLoaded = false;

  /// 🔹 category LIST
  List category = [];
  bool iscategory = false;

  /// 🔥 Customer Advance Balances

  Map<String, dynamic>? selectedCustomerAdvance;

  double cashBalance = 0;
  double goldBalance = 0;
  double silverBalance = 0;
  double otherBalance = 0;

  String cashType = "";
  String goldType = "";
  String silverType = "";
  String otherType = "";

  /// =========================================================
  /// 🔥 NEW — Silver used fine weight & balance after use
  /// =========================================================
  double silverUsedFineWeight = 0;
  double silverBalanceAfterUse = 0;
  String silverBalanceAfterUseType = "";

  /// =========================================================
  /// 🔥 NEW — Dynamic Active Metal (Gold/Silver/Other whichever
  /// has non-zero balance) + its Used/After-Use data
  /// =========================================================
  String activeMetalType = "gold";       // "gold" | "silver" | "other"
  String activeMetalLabel = "";          // e.g. "Gold Fine Balance"
  double activeMetalBalance = 0;
  String activeMetalBalanceType = "Credit";

  double activeMetalUsedFineWeight = 0;
  double activeMetalBalanceAfterUse = 0;
  String activeMetalBalanceAfterUseType = "Credit";

  /// Metal name capitalized — "Silver Used (Fine Wt)" jeva title banavva mate
  String get activeMetalDisplayName {
    switch (activeMetalType) {
      case "gold":
        return "Gold";
      case "other":
        return "Other";
      case "silver":
      default:
        return "Silver";
    }
  }


  /// 🔥 Load Only Once
  Future<void> loadItems() async {

    if (isLoaded) return; // Already Loaded

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.itemlist);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        items = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔄 Manual Refresh
  Future<void> refreshItems() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.itemlist);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        items = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔥 LOAD CUSTOMERS (ONLY ONCE)
  Future<void> loadCustomers() async {
    if (isCustomersLoaded) return;

    final response =
    await ApiHelper().getRequest(ApiConstants.customerlist); // 🔥 add API

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        customers = response.data['data'];
        isCustomersLoaded = true;
      }
    }

    notifyListeners();
  }

  /// 🔄 REFRESH CUSTOMERS
  Future<void> refreshCustomers() async {
    final response =
    await ApiHelper().getRequest(ApiConstants.customerlist);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        customers = response.data['data'];
      }
    }

    notifyListeners();
  }


  /// 🔥 Load Only Once
  Future<void> loadLabourformula() async {

    if (isLabourformulaLoaded) return;

    isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.job_formula);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        labour_formula = response.data['data'];
        isLabourformulaLoaded = true;
      }
    }

    isLoading = false;
    notifyListeners();
  }


  /// 🔄 Manual Refresh
  Future<void> refreshLabourformula() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.job_formula);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        labour_formula = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔥 Load Only Once
  Future<void> loadProductioncosts() async {

    if (isProduction_costLoaded) return;

    isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.Production_cost);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Production_cost = response.data['data'];
        isProduction_costLoaded = true;
      }
    }

    isLoading = false;
    notifyListeners();
  }


  /// 🔄 Manual Refresh
  Future<void> refreshProductioncosts() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.Production_cost);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Production_cost = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }


  /// 🔥 Load Only Once
  Future<void> loadProductionsteps() async {

    if (isProduction_stepLoaded) return;

    isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.Production_steps);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Production_steps = response.data['data'];
        isProduction_stepLoaded = true;
      }
    }

    //isLoading = false;
    notifyListeners();
  }


  /// 🔄 Manual Refresh
  Future<void> refreshProductionsteps() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.Production_steps);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Production_steps = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }


  /// 🔥 Load Only Once
  Future<void> loadJobWorker() async {

    if (isJobWorkerLoaded) return;

    isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.Job_Worker);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Job_worker = response.data['data'];
        isJobWorkerLoaded = true;
      }
    }

    isLoading = false;
    notifyListeners();
  }


  /// 🔄 Manual Refresh
  Future<void> refreshJobWorker() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.Job_Worker);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Job_worker = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔥 LOAD CUSTOMERS (ONLY ONCE)
  Future<void> loadreturnCustomers() async {
    if (isCustomersreturnLoaded) return;

    final response =
    await ApiHelper().getRequest(ApiConstants.advance_ledge_customerlist); // 🔥 add API

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        customers_return = response.data['data'];
        isCustomersreturnLoaded = true;
      }
    }

    notifyListeners();
  }

  /// 🔄 REFRESH CUSTOMERS
  Future<void> refreshreturnCustomers() async {
    final response =
    await ApiHelper().getRequest(ApiConstants.advance_ledge_customerlist);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        customers_return = response.data['data'];
      }
    }

    notifyListeners();
  }

  /// 🔥 Apprioval CUSTOMERS (ONLY ONCE)
  Future<void> ApprovalCustomers() async {
    if (isApprovalCustomersLoaded) return;

    final response =
    await ApiHelper().getRequest(ApiConstants.Approvalcustomer); // 🔥 add API

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Approval_customers = response.data['data'];
        isApprovalCustomersLoaded = true;
      }
    }

    notifyListeners();
  }

  /// 🔄 REFRESH CUSTOMERS
  Future<void> refreshapprovalCustomers() async {
    final response =
    await ApiHelper().getRequest(ApiConstants.Approvalcustomer);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Approval_customers = response.data['data'];
      }
    }

    notifyListeners();
  }

  /// 🔥 Load Only Once
  Future<void> loadprocess() async {

    if (isVacumProcessLoaded) return; // Already Loaded

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.vacuum_processes);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Vacuum_Process = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔄 Manual Refresh
  Future<void> refreshProcess() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.vacuum_processes);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Vacuum_Process = response.data['data'];
      }
    }

    //isLoading = false;
    notifyListeners();
  }

  /// 🔥 Load Only Once
  Future<void> loadbuchlist() async {

    if (isBuchlistLoaded) return; // Already Loaded

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.vacuum_buchs);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Buch_list = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔄 Manual Refresh
  Future<void> refreshbuchlist() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.vacuum_buchs);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        Buch_list = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  Future<void> loadcategory() async {

    if (iscategory) return;

    isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.category_persons);

    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        category = response.data['data'];
        iscategory = true;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  /// 🔥 Load Only Once
  Future<void> loadcustomerlist() async {

    if (isCustomers_list_Loaded) return; // Already Loaded

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.customer_list);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        customers_list = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  /// 🔄 Manual Refresh
  Future<void> refreshcustomerlist() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.customer_list);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        customers_list = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  Future<void> refreshcategorylist() async {

    //isLoading = true;
    notifyListeners();

    final response = await ApiHelper().getRequest(ApiConstants.category_persons);

    if (response!.statusCode == 200 && response.data != null) {

      if (response.data is Map && response.data['data'] != null) {
        category = response.data['data'];
      }
    }


    //isLoading = false;
    notifyListeners();
  }

  void setCustomerAdvance(Map<String, dynamic> customer) {
    double _d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;
    String _s(dynamic v, [String def = ""]) =>
        (v == null || v.toString().trim().isEmpty) ? def : v.toString();

    /// 🔥 Label ma type suffix (" Credit"/" Debit") embedded hoy che,
    /// e hataavi ne clean title banavo.
    String _cleanLabel(String label) =>
        label.replaceAll(RegExp(r'\s+(Credit|Debit)$'), '').trim();

    /// ============================================================
    /// CASH — hammesha fix
    /// ============================================================
    cashBalance = _d(
      customer["advance_cash_balance_display"] ??
          customer["advance_cash_balance"],
    );
    cashType = _s(customer["advance_cash_balance_type"], "Credit");

    /// ============================================================
    /// RAW BALANCES (priority nakki karva mate)
    /// ============================================================
    final double goldBal = _d(customer["advance_gold_fine_balance"]);
    final double silverBal = _d(customer["advance_silver_fine_balance"]);
    final double otherBal = _d(customer["advance_other_fine_balance"]);

    /// individual fields pan store karo (jo kyay direct joie to)
    goldBalance = _d(
      customer["advance_gold_fine_balance_display"] ??
          customer["advance_gold_fine_balance"],
    );
    goldType = _s(customer["advance_gold_fine_balance_type"], "Credit");

    silverBalance = _d(
      customer["advance_silver_fine_balance_display"] ??
          customer["advance_silver_fine_balance"],
    );
    silverType = _s(customer["advance_silver_fine_balance_type"], "Credit");

    otherBalance = _d(
      customer["advance_other_fine_balance_display"] ??
          customer["advance_other_fine_balance"],
    );
    otherType = _s(customer["advance_other_fine_balance_type"], "Credit");

    /// ============================================================
    /// 🔥 ACTIVE METAL DECIDE KARO
    /// Priority: Gold non-zero → Silver non-zero → Other non-zero
    /// Badhu 0 hoy to default Gold
    /// ============================================================
    if (silverBal != 0) {
      activeMetalType = "silver";
    } else if (goldBal != 0) {
      activeMetalType = "gold";
    } else if (otherBal != 0) {
      activeMetalType = "other";
    } else {
      activeMetalType = "silver"; // 🔥 default Silver
    }

    switch (activeMetalType) {
      case "gold":
        activeMetalLabel = _cleanLabel(
          _s(customer["advance_gold_fine_balance_label"], "Gold Fine Balance"),
        );
        activeMetalBalance = goldBalance;
        activeMetalBalanceType = goldType;

        /// Gold mate used/after-use concept API ma nathi — balance j vaparo
        activeMetalUsedFineWeight = 0;
        activeMetalBalanceAfterUse = goldBalance;
        activeMetalBalanceAfterUseType = goldType;
        break;

      case "silver":
        activeMetalLabel = _cleanLabel(
          _s(customer["advance_silver_fine_balance_label"], "Silver Fine Balance"),
        );
        activeMetalBalance = silverBalance;
        activeMetalBalanceType = silverType;

        activeMetalUsedFineWeight =
            _d(customer["advance_silver_used_fine_weight"]);

        activeMetalBalanceAfterUse = _d(
          customer["advance_silver_balance_after_use_display"] ??
              customer["advance_silver_balance_after_use"],
        );

        activeMetalBalanceAfterUseType = _s(
          customer["advance_silver_balance_after_use_type"],
          "Credit",
        );
        break;

      case "other":
        activeMetalLabel = _cleanLabel(
          _s(customer["advance_other_fine_balance_label"], "Other Metal Balance"),
        );
        activeMetalBalance = otherBalance;
        activeMetalBalanceType = otherType;

        /// Other mate pan used/after-use nathi — balance j vaparo
        activeMetalUsedFineWeight = 0;
        activeMetalBalanceAfterUse = otherBalance;
        activeMetalBalanceAfterUseType = otherType;
        break;
    }

    notifyListeners();
  }
}

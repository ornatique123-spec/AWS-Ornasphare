
class ApiConstants {
  // Base URL
  static const String baseUrl = 'https://ornasphere.com/api/';

  // API Endpoints
  static const String login = 'company/login';
  static const String verify_otp = 'company/verify-otp';
  static const String userProfile = 'company/me';
  static const String logout = 'company/logout';
  static const String Reset_2FA = 'reset2fa_users';
  // User
  static const String users = 'users';
  static const String create_users = 'create_users';
  static const String update_users = 'update_users';
  static const String delete_users = 'delete_users';
  // Cutomer
  static const String create_customer = 'customers';
  static const String update_customer = 'customers';
  static const String customer_list = 'customers';
  static const String delete_customer = 'customers';
  // Item managmnent
  static const String itemlist = 'items';
  static const String create_item = 'create_items';
  static const String update_items = 'update_items';
  static const String delete_items = 'delete_items';
  // Label
  static const String labellist = 'label-configs';
  static const String label_delete = 'label-configs';
  static const String create_label_configs = 'create-label-configs';
  static const String update_label_configs = 'update-label-configs';
  // Label Items
  static const String Create_label_item_list = 'item-sets';
  static const String label_item_list = 'itemsets_list';
  static const String label_item_bulk_list = 'itemsets_bulk_list';
  static const String label_item_delete = 'itemsets_delete';
  static const String label_item_update = 'itemsets_update';
  static const String multiple_items_label_configs = 'item-sets/bulk-save';
  static const String finalize_items_label_configs = 'item-sets/finalize';
  // Other charge
  static const String others = 'other-charges';
  static const String add_others_charges = 'add-other-charges';
  static const String update_other_charges = 'update-other-charges';
  static const String delete_other_charges = 'delete-other-charges';

  static const String customerlist = 'sales/customerlist';
  static const String custome_list = 'customers';
  static const String advance_ledge_customerlist = 'sales/advance-ledger/customers';
  // Sell Estimate
  static const String sales_add_to_cart = 'sales/add-to-cart';
  static const String sales_cart_items = 'sales/cart-items';
  static const String sales_confirm_sale = 'sales/confirm-sale';
  static const String sales_store = 'sales/store';
  static const String label_print = 'itemsets/qr-list';
  static const String Qr_pdf = 'itemsets/qr/pdf';
  static const String sale_list = 'sale-list';
  static const String sale_cart_remove = 'sales/cart/remove';
  static const String sale_item_update = 'sales';
  static const String Sale_update = 'sales/update';
  static const String Sale_pdf = 'sales/pdf';
  // Sell Return
  static const String return_customer = 'returns/customers';
  static const String return_list = 'returns/list';
  static const String return_sale = 'returns/sale';
  static const String return_pdf = 'returns/pdf';
  static const String return_Qr_Sale = 'returns/scan-product';
  static const String return_Qr_list = 'returns/cart-list';
  static const String return_Qr_list_remove = 'returns/cart-remove';
  static const String return_Store = 'returns/confirm-return';
  static const String returns_search = 'returns/search-return';
  static const String returns_store = 'returns/store';
  static const String returns_cart_remove = 'returns/cart-remove';
  static const String returns_vouchar = 'returns';
  static const String returns_approval_items = 'returns/approval-items';
  // Approval
  static const String label_Approval_list = 'sales/add-label-from-approval';
  static const String Approval_list = 'approvals';
  static const String Approval_dailog_list = 'approvals';
  static const String Approval_pdf = 'approvals/pdf';
  static const String item_sets_pdf = 'item-sets/print-pdf';
  static const String Approval_search = 'approvals/search-itemsets';
  static const String Approval_store = 'approvals/store';
  static const String Approval_scan_qr = 'approvals/scan-qr';
  static const String Approval_scan_list = 'approvals/cart-list';
  static const String Approval_cart_remove = 'approvals/cart-remove';
  static const String Approval_update = 'approvals/update';
  static const String Approval_return_qr_item = 'returns/approval-items';  //22 Jun 2026 new api Add
  static const String approval_cart_add = 'returns/approval-cart/add';  //22 Jun 2026 new api Add
  static const String Approval_cart_add = "approvals/cart/add";

  // Job Work
  static const String job_formula = 'labour-formulas';
  static const String job_add_formula = 'add-labour-formulas';
  static const String job_Update_formula = 'update-labour-formulas';
  static const String job_delete_formula = 'delete-labour-formulas';

  // Production Cost
  static const String Production_cost = 'production-costs';
  static const String Add_Production_cost = 'add-production-costs';
  static const String Update_Production_cost = 'update-production-costs';
  static const String Production_cost_delete = 'delete-production-costs';

  // Production Steps
  static const String Production_steps = 'production-steps';
  static const String delete_Production_steps = 'delete-production-steps';
  static const String add_Production_steps = 'add-production-steps';
  static const String Update_Production_steps = 'update-production-steps';

  // Job Worker
  static const String Job_Worker = 'job-workers';
  static const String Job_export_pdf = 'export-job-workers/pdf';
  static const String Job_export_exel = 'export-job-workers/excel';
  static const String Add_job_worker = 'create-job-workers';
  static const String Update_job_worker = 'update-job-workers';
  static const String delete_job_worker = 'delete-job-workers';

  // Job Work Issue
  static const String jobwork_issues = 'jobwork-issues';
  static const String jobwork_issues_pdf = 'jobwork-issues/export/pdf';
  static const String jobwork_issues_exel = 'jobwork-issues/export/excel';
  static const String jobwork_issues_delete = 'delete-jobwork-issues';
  static const String jobwork_issues_other_charges = 'jobwork-issues/other-charges';
  static const String create_jobwork_issues = 'create-jobwork-issues';
  static const String Update_jobwork_issues = 'jobwork-issues';
  static const String Update_Jobwork_issues = 'update-jobwork-issues';

  // Job Work Receive
  static const String jobwork_receive = 'jobwork-receive';
  static const String jobwork_receive_pdf = 'jobwork-receive/pdf';
  static const String jobwork_receive_direct = 'jobwork-receive/direct';

  // Barcode Report
  static const String Barcode_report = 'reports/barcode-history';
  static const String Barcode_report_pdf = 'reports/barcode-history/export/pdf';
  static const String Barcode_report_excel = 'barcode-history/export/excel';
  static const String Barcode_sale_vouchar = 'sales';

  // Sale Summary Report
  static const String Sale_Summary_report = 'reports/sales-summary';
  static const String Sale_Summary_report_pdf = 'reports/sales-summary/export/pdf';
  static const String Sale_Summary_report_excel = 'reports/sales-summary/export/excel';

  // Purchase Summary Report
  static const String Purchase_Summary_report = 'reports/purchase-receiver-summary';
  static const String Purchase_Summary_report_pdf = 'reports/purchase-receiver-summary/export/pdf';
  static const String Purchase_Summary_report_excel = 'reports/purchase-receiver-summary/export/excel';

  // Stock Postion Report
  static const String Stock_Position_report = 'reports/stock-position';
  static const String Stock_Position_report_pdf = 'reports/stock-position/export/pdf';
  static const String Stock_Position_report_excel = 'reports/stock-position/export/excel';

  // Approval Outstanding  Report
  static const String Approval_Outstanding_report = 'reports/approval-outstanding';
  static const String Approval_Outstanding_report_pdf = 'reports/approval-outstanding/export/pdf';
  static const String Approval_Outstanding_report_excel = 'reports/approval-outstanding/export/excel';
  static const String Approval_Outstanding_report_details = 'reports/approval-outstanding';

  // OutStanding Report
  static const String OutStanding_amount_report = 'reports/outstanding-amount';
  static const String OutStanding_amount_report_pdf = 'reports/outstanding-amount/export/pdf';
  static const String OutStanding_amount_report_excel = 'reports/outstanding-amount/export/excel';

  // Extra
  static const String other_charge = 'other-charges/options';
  static const String removebg_list = 'background-remove/list';
  static const String upload_removebg_image = 'background-remove/store';
  static const String delete_removebg_image = 'background-remove/delete';
  static const String deletesingle_removebg_image = 'background-remove/delete-image';

  // Roles & Permissions
  static const String permission_list = 'permissions';
  static const String Add_permission_list = 'add-permissions';
  static const String Rolelist = 'roles';
  static const String add_role = 'add-roles';
  // Add more API endpoints or constants as needed


  // Return/recive/purchase
  static const String advance_ledger_summary = 'sales/advance-ledger/summary';
  static const String sales_advance_ledger_entries = 'sales/advance-ledger/entries';
  static const String sales_advance_ledger_pdf = 'sales/advance-ledger/pdf-url';
  static const String sales_advance_ledger_vouchers = 'sales/advance-ledger/vouchers';
  static const String sales_advance_ledger_vouchers_pdf = 'sales/advance-ledger/vouchers/pdf';

  // Visiting Card
  static const String visiting_cards_extract = 'visiting-cards/extract-bulk';
  static const String visiting_cards_save = 'visiting-cards/bulk-save';
  static const String visiting_card_pdf = 'visiting-cards/export/pdf';
  static const String visiting_card_excel = 'visiting-cards/export/excel';
  static const String visiting_card_list = 'visiting-cards';
  static const String Update_visiting_card = 'visiting-cards';

  // Approval customer
  static const String Approvalcustomer = 'approvals/customers';

  // Notification
  static const String notification = 'notifications';
  static const String notification_summary = 'notifications/summary';
  static const String notifications_read_module = 'notifications/read-module';

  // Vacuum
  static const String vacuum_buchs = 'vacuum-buchs';
  static const String vacuum_buchs_delete = 'vacuum-buchs';

  // Vacuum process
  static const String vacuum_processes = 'vacuum-processes';
  static const String vacuum_vouchers = 'vouchers';
  static const String vacuum_voucherspdf = 'vouchers_pdf';
  static const String vacuum_vouchers_print = 'vouchers_print_labels_pdf';

  // Casting Heating
  static const String casting_heating = 'casting-heating';

  // Casting Metal
  static const String casting_metal_issue = 'casting-metal-issue';
  static const String casting_metal_issue_pdf = 'casting_metal_issue_pdf';

  // Casting Recive
  static const String casting_receive = 'casting-receive';
  static const String casting_receive_pdf = 'casting_receive_pdf';

  // Tree Cutting Issue
  static const String tree_cutting_office = 'tree-cutting-office';
  static const String tree_cutting_office_pdf = 'tree_cutting_office_pdf';
  static const String tree_cutting_issue = 'tree-cutting-issue';
  static const String tree_cutting_issue_pdf = 'tree_cutting_issue_pdf';
  static const String tree_cutting_receive = 'tree-cutting-receive';
  static const String tree_cutting_receive_pdf = 'tree_cutting_receive_pdf';
  static const String casting_sorting = 'casting-sorting';
  static const String casting_sorting_pdf = 'casting_sorting_pdf';
  static const String voucher_history_pdf = 'voucher_history_pdf';
  static const String voucher_history_excel = 'voucher_history_excel';
  static const String company_profile = 'company/profile';
  static const String live_metal_rates = 'live-metal-rates';
  static const String category_persons = 'category-persons';
  static const String officeAccessSettings = 'office-access/settings';
  static const String deviceAccessSettings = 'office-access/devices';
  static const String deviceApproveAccessSettings = 'office-access/devices/approve-by-device';
  static const String devicerejectAccessSettings = 'office-access/devices/reject-by-device';
  static const String deviceinactiveAccessSettings = 'office-access/devices/inactive-by-device';
  static const String itemset = 'item-sets';
  static const String itemSetUploadImage = 'item-sets/upload-image';
  static const String itemSetImage = 'itemsets_image';
  static const String stock_gallery = 'stock-gallery';
  static const String worker_loss_report = 'reports/worker-loss';
  static const String company_branches = 'company/branches';
  static const String company_opening_balances = 'company/opening-balances';

  // QR Making

  static const String qr_making = 'qr-making';



  // Timeout duration
  static const int connectTimeout = 5000; // 5 seconds
  static const int receiveTimeout = 5000; // 5 seconds
}
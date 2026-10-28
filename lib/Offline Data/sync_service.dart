import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../Api_Constant/api_helper.dart';
import 'offline_service.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  bool _isSyncing = false;

  Future<void> syncPendingData() async {
    /// Already syncing hoy to duplicate sync prevent
    if (_isSyncing) {
      print("⚠️ SYNC ALREADY RUNNING");
      return;
    }

    /// ============================================================
    /// INTERNET CHECK
    /// ============================================================
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      print("📴 NO INTERNET => SYNC SKIPPED");
      return;
    }

    _isSyncing = true;

    print("==========================================");
    print("🔄 OFFLINE SYNC START");
    print("==========================================");

    try {
      /// ==========================================================
      /// GET ALL PENDING RECORDS
      /// ==========================================================
      final pending = await OfflineService.instance.getPendingData();

      print("📦 TOTAL PENDING => ${pending.length}");

      if (pending.isEmpty) {
        print("✅ NOTHING TO SYNC");
        return;
      }

      /// ==========================================================
      /// SYNC ONE BY ONE
      /// ==========================================================
      for (final item in pending) {
        final id = item["id"];

        try {
          final String method =
              item["method"]?.toString().toUpperCase() ?? "";

          final String apiUrl =
              item["api_url"]?.toString() ?? "";

          final Map<String, dynamic> body =
          jsonDecode(item["body"] ?? "{}")
          as Map<String, dynamic>;

          print("");
          print("------------------------------------------");
          print("🔄 SYNC RECORD ID => $id");
          print("METHOD => $method");
          print("URL => $apiUrl");
          print("BODY => $body");
          print("------------------------------------------");

          Response? response;

          /// ======================================================
          /// API CALL
          /// ======================================================
          switch (method) {
            case "POST":
              response = await ApiHelper().postRequest(
                apiUrl,
                body,
              );
              break;

            case "PUT":
              response = await ApiHelper().putRequest(
                apiUrl,
                body,
              );
              break;

            case "DELETE":
              response = await ApiHelper().deleteRequest(
                apiUrl,
                data: body,
              );
              break;

            default:
              print("❌ UNKNOWN METHOD => $method");

              /// Invalid queue record remove kari do
              await OfflineService.instance.deleteRecord(id);

              print(
                "🗑️ INVALID QUEUE RECORD [$id] DELETED",
              );

              continue;
          }

          /// ======================================================
          /// NULL RESPONSE
          /// ======================================================
          if (response == null) {
            print(
              "⚠️ NULL RESPONSE => RECORD [$id] KEPT FOR RETRY",
            );
            continue;
          }

          final int statusCode =
              response.statusCode ?? 0;

          final dynamic responseData =
              response.data;

          print("📥 STATUS CODE => $statusCode");
          print("📥 RESPONSE DATA => $responseData");

          /// ======================================================
          /// 1. SUCCESS
          /// ======================================================
          if (statusCode >= 200 &&
              statusCode < 300) {

            await OfflineService.instance.deleteRecord(id);

            print(
              "✅ SYNC SUCCESS => QUEUE RECORD [$id] DELETED",
            );

            continue;
          }

          /// ======================================================
          /// 2. VALIDATION ERROR
          ///
          /// Example:
          /// 422
          /// The name has already been taken.
          ///
          /// Server aa record accept nahi kare.
          /// Retry karvano koi benefit nathi.
          /// Etle local sync queue mathi DELETE.
          /// ======================================================
          if (statusCode == 422) {
            String message = "Validation error";

            try {
              if (responseData is Map) {
                message =
                    responseData["message"]?.toString() ??
                        "Validation error";
              }
            } catch (_) {}

            print(
              "⚠️ VALIDATION FAILED => $message",
            );

            /// 🔥 IMPORTANT
            /// 422 record automatically delete
            await OfflineService.instance.deleteRecord(id);

            print(
              "🗑️ 422 QUEUE RECORD [$id] DELETED",
            );

            continue;
          }

          /// ======================================================
          /// 3. OTHER CLIENT ERRORS
          /// 400 / 401 / 403 / 404 etc.
          ///
          /// Atyare queue ma keep kariye.
          /// ======================================================
          if (statusCode >= 400 &&
              statusCode < 500) {

            print(
              "⚠️ CLIENT ERROR [$statusCode]",
            );

            print(
              "📦 Queue record [$id] KEPT",
            );

            continue;
          }

          /// ======================================================
          /// 4. SERVER ERROR
          /// 500 / 502 / 503 etc.
          ///
          /// Delete nahi karvano.
          /// Later retry thase.
          /// ======================================================
          if (statusCode >= 500) {
            print(
              "🔴 SERVER ERROR [$statusCode]",
            );

            await OfflineService.instance.deleteRecord(id);

            print(
              "🗑️ QUEUE RECORD [$id] DELETED (server error $statusCode)",
            );

            continue;
          }

          /// Unknown response
          print(
            "⚠️ UNKNOWN RESPONSE [$statusCode] => RECORD KEPT",
          );
        }

        /// ========================================================
        /// DIO EXCEPTION
        /// ========================================================
        on DioException catch (e) {
          final int? statusCode =
              e.response?.statusCode;

          final dynamic responseData =
              e.response?.data;

          print("❌ DIO ERROR RECORD [$id]");
          print("STATUS => $statusCode");
          print("DATA => $responseData");

          /// 🔥 VERY IMPORTANT
          ///
          /// Tamara ApiHelper DioException throw karto hoy
          /// to 422 uparna normal response block sudhi
          /// pohchse j nahi.
          ///
          /// Etle ahi pan 422 delete karvo compulsory.
          if (statusCode == 422) {
            String message = "Validation error";

            try {
              if (responseData is Map) {
                message =
                    responseData["message"]?.toString() ??
                        "Validation error";
              }
            } catch (_) {}

            print(
              "⚠️ 422 VALIDATION FAILED => $message",
            );

            await OfflineService.instance.deleteRecord(id);

            print(
              "🗑️ 422 QUEUE RECORD [$id] DELETED",
            );

            continue;
          }

          if (statusCode == 422) {
            String message = "Validation error";

            if (responseData is Map) {
              message =
                  responseData["message"]?.toString() ??
                      "Validation error";
            }

            print("⚠️ VALIDATION FAILED => $message");

            await OfflineService.instance.deleteRecord(id);

            print("🗑️ 422 QUEUE RECORD [$id] DELETED");

            /// 🔥 IMPORTANT
            /// Aa record nu processing ahi j completely stop
            continue;
          }

          /// Network/server issue hoy to record retain
          print(
            "📦 Queue record [$id] kept for retry",
          );
        }

        /// ========================================================
        /// OTHER ERROR
        /// ========================================================
        catch (e, stackTrace) {
          print(
            "❌ SYNC ERROR RECORD [$id] => $e",
          );

          print(stackTrace);

          /// Unknown error ma data delete nahi karvano
          print(
            "📦 Queue record [$id] kept for retry",
          );
        }
      }
    } catch (e, stackTrace) {
      print("❌ SYNC SERVICE ERROR => $e");
      print(stackTrace);
    } finally {
      _isSyncing = false;

      print("==========================================");
      print("🏁 OFFLINE SYNC FINISHED");
      print("==========================================");
    }
  }
}
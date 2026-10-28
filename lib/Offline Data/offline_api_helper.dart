import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../Api_Constant/api_helper.dart';
import 'offline_service.dart';

class OfflineApiHelper {
  OfflineApiHelper._();

  static final OfflineApiHelper instance = OfflineApiHelper._();

  /// GET
  Future<Response?> getRequest(String endpoint) async {
    final connectivity = await Connectivity().checkConnectivity();

    // ONLINE
    if (connectivity != ConnectivityResult.none) {
      try {
        final response = await ApiHelper().getRequest(endpoint);

        if (response != null &&
            response.statusCode == 200) {

          await OfflineService.instance.saveCache(
            apiUrl: endpoint,
            response: jsonEncode(response.data),
          );

          return response;
        }
      } catch (_) {}
    }

    // OFFLINE
    final cache = await OfflineService.instance.getCache(endpoint);

    if (cache != null) {
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        statusCode: 200,
        data: jsonDecode(cache),
      );
    }

    return Response(
      requestOptions: RequestOptions(path: endpoint),
      statusCode: 202,
      data: {
        "success": false,
        "offline": true,
        "message": "No offline data found.",
        "data": [],
      },
    );
  }

  /// POST
  /// POST
  Future<Response?> postRequest(
      String endpoint,
      Map<String, dynamic> body, {
        Duration? receiveTimeout,
        Duration? sendTimeout,
      }) async {
    // ------------------------------------------------------------
    // Internet che? (connectivity_plus juna + nava banne version)
    // ------------------------------------------------------------
    final dynamic connectivity = await Connectivity().checkConnectivity();

    final bool isOnline = connectivity is List
        ? !connectivity.contains(ConnectivityResult.none)
        : connectivity != ConnectivityResult.none;

    if (isOnline) {
      final api = ApiHelper();

      try {
        final response = await api.postRequest(
          endpoint,
          body,
          receiveTimeout: receiveTimeout,
          sendTimeout: sendTimeout,
        );

        /// ✅ Server e jawab aapyo (200 / 422 / 500 game te) → e j return
        if (response != null) {
          return response;
        }
      } catch (_) {}

      // ------------------------------------------------------------
      // ⏳ TIMEOUT: request server par pohnchi gai hati.
      // Server kadach save kari chukyo hoy → OFFLINE SAVE NAHI
      // (nahi to sync vakhte duplicate sale bane)
      // ------------------------------------------------------------
      final type = api.lastErrorType;

      if (type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.sendTimeout) {
        return Response(
          requestOptions: RequestOptions(path: endpoint),
          statusCode: 408,
          data: {
            "success": false,
            "timeout": true,
            "message": "Server is still processing. "
                "Please check the list before saving again.",
          },
        );
      }
    }

    // ------------------------------------------------------------
    // 📴 Genuine no-internet / connection error → Offline Save
    // ------------------------------------------------------------
    await OfflineService.instance.saveOffline(
      apiUrl: endpoint,
      method: "POST",
      body: body,
    );

    return Response(
      requestOptions: RequestOptions(path: endpoint),
      statusCode: 202,
      data: {
        "success": true,
        "offline": true,
        "message": "Data saved offline successfully.",
      },
    );
  }

  /// PUT
  /// PUT
  Future<Response?> putRequest(
      String endpoint,
      Map<String, dynamic> body,
      ) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity != ConnectivityResult.none) {
      try {
        final response = await ApiHelper().putRequest(
          endpoint,
          body,
        );

        /// 🔥 Server no response (success ya error) direct return karo
        if (response != null) {
          return response;
        }
      } catch (_) {}
    }

    await OfflineService.instance.saveOffline(
      apiUrl: endpoint,
      method: "PUT",
      body: body,
    );

    return Response(
      requestOptions: RequestOptions(path: endpoint),
      statusCode: 202,
      data: {
        "success": true,
        "offline": true,
        "message": "Data saved offline successfully.",
      },
    );
  }

  /// DELETE
  /// DELETE
  Future<Response?> deleteRequest(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity != ConnectivityResult.none) {
      try {
        final response = await ApiHelper().deleteRequest(
          endpoint,
          data: body,
        );

        /// 🔥 Server no response (success ya error) direct return karo
        if (response != null) {
          return response;
        }
      } catch (_) {}
    }

    await OfflineService.instance.saveOffline(
      apiUrl: endpoint,
      method: "DELETE",
      body: body ?? {},
    );

    return Response(
      requestOptions: RequestOptions(path: endpoint),
      statusCode: 202,
      data: {
        "success": true,
        "offline": true,
        "message": "Delete request saved offline.",
      },
    );
  }

  /// POST FORM DATA
  Future<Response?> postFormData(
      String endpoint,
      FormData formData,
      ) async {
    final connectivity = await Connectivity().checkConnectivity();

    // ONLINE
    if (connectivity != ConnectivityResult.none) {
      try {
        final response = await ApiHelper().postFormData(
          endpoint,
          formData,
        );

        if (response != null &&
            response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return response;
        }
      } catch (_) {}
    }

    // Convert FormData to Map
    final Map<String, dynamic> body = {};

    // Fields
    for (final field in formData.fields) {
      body[field.key] = field.value;
    }

    // Files
    for (final file in formData.files) {
      body[file.key] = file.value.filename;
      // 👉 જો જરૂર હોય તો અહીં file.path પણ store કરી શકો.
    }

    // Save Offline
    await OfflineService.instance.saveOffline(
      apiUrl: endpoint,
      method: "POST_FORM_DATA",
      body: body,
    );

    return Response(
      requestOptions: RequestOptions(path: endpoint),
      statusCode: 202,
      data: {
        "success": true,
        "offline": true,
        "message": "FormData saved offline successfully.",
      },
    );
  }
}
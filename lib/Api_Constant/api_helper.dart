// import 'dart:convert';
//
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Extra/AppColors.dart';
// import '../Extra/LoadingService.dart';
// import '../Splash/LoginScreen.dart';
// import '../main.dart' as NavigationService;
// import 'ApiConstants.dart';
//
// class ApiHelper {
//   static final ApiHelper _instance = ApiHelper._internal();
//   late Dio _dio;
//
//   String? _bearerToken;
//
//   factory ApiHelper() => _instance;
//
//   ApiHelper._internal() {
//     _dio = Dio(
//       BaseOptions(
//         baseUrl: ApiConstants.baseUrl,
//         connectTimeout: const Duration(seconds: 30),
//         receiveTimeout: const Duration(seconds: 30),
//         headers: {
//           'Accept': 'application/json',
//         },
//       ),
//     );
//
//     _dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) {
//
//           final bool showLoading =
//               options.extra["showLoading"] ?? true;
//
//           if (showLoading) {
//             LoadingService.instance.show();
//           }
//
//           final noTokenEndpoints = ['/login', '/register'];
//
//           // ✅ Add Bearer Token except login/register
//           if (!noTokenEndpoints.contains(options.path)) {
//             if (_bearerToken != null && _bearerToken!.isNotEmpty) {
//               options.headers['Authorization'] = 'Bearer $_bearerToken';
//             }
//           }
//
//           print("📤 REQUEST [${options.method}] ${options.path}");
//           print("Headers: ${options.headers}");
//           print("Body: ${options.data}");
//
//           return handler.next(options);
//         },
//
//         onResponse: (response, handler) async {
//
//           // ✅ Hide Loading
//           final bool showLoading =
//               response.requestOptions.extra["showLoading"] ?? true;
//
//           if (showLoading) {
//             LoadingService.instance.hide();
//           }
//
//           print("📥 RESPONSE [${response.statusCode}] ${response.requestOptions.path}");
//           print("Data: ${response.data}");
//
//           await _checkUserStatus(response);
//
//           return handler.next(response);
//         },
//
//         onError: (DioException e, handler) {
//
//           // ✅ Hide Loading
//           final bool showLoading =
//               e.requestOptions.extra["showLoading"] ?? true;
//
//           if (showLoading) {
//             LoadingService.instance.hide();
//           }
//
//           _checkUserStatus(e.response);   // 👈 ADD
//           print("❌ ERROR [${e.response?.statusCode}] ${e.requestOptions.path}");
//           print("Message: ${e.message}");
//
//           return handler.next(e);
//         },
//       ),
//     );
//   }
//
//   // 🔐 Set token in memory
//   void setBearerToken(String token) {
//     _bearerToken = token;
//     AppDialog.sessionHandled = false;   // 👈 navu login thay tyare pacho reset
//   }
//
//   void clearToken() {
//     _bearerToken = null;
//   }
//
//   // 🔄 Load token from SharedPreferences on app start
//   Future<void> loadTokenFromPrefs() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     _bearerToken = prefs.getString('token');
//     print("🔐 Token Loaded: $_bearerToken");
//   }
//
//   Future<Response?> getRequest(
//       String endpoint, {
//         Map<String, dynamic>? queryParams,
//         bool showLoading = true,
//
//         // 🔥 OPTIONAL TIMEOUT
//         Duration? receiveTimeout,
//       }) async {
//     try {
//       debugPrint("==========================================");
//       debugPrint("➡️ GET REQUEST");
//       debugPrint("URL => $endpoint");
//       debugPrint("QUERY => $queryParams");
//       debugPrint("SHOW LOADING => $showLoading");
//       debugPrint(
//         "RECEIVE TIMEOUT => "
//             "${receiveTimeout ?? const Duration(seconds: 30)}",
//       );
//       debugPrint("==========================================");
//
//       final response = await _dio.get(
//         endpoint,
//         queryParameters: queryParams,
//         options: Options(
//           extra: {
//             "showLoading": showLoading,
//           },
//
//           // 🔥 CUSTOM TIMEOUT
//           // pass na karo to 30 seconds
//           receiveTimeout:
//           receiveTimeout ??
//               const Duration(seconds: 30),
//
//           validateStatus: (s) =>
//           s != null && s < 500,
//         ),
//       );
//
//       debugPrint("✅ GET STATUS => ${response.statusCode}");
//
//       return response;
//     } on DioException catch (e) {
//       debugPrint("==========================================");
//       debugPrint("❌ GET DIO ERROR");
//       debugPrint("TYPE => ${e.type}");
//       debugPrint("MESSAGE => ${e.message}");
//       debugPrint("URL => ${e.requestOptions.uri}");
//       debugPrint("==========================================");
//
//       return e.response;
//     } catch (e) {
//       debugPrint("❌ GET ERROR => $e");
//       return null;
//     }
//   }
//
//   Future<Response?> getPdfRequest(String endpoint) async {
//     try {
//       final response = await _dio.get(
//         endpoint,
//         options: Options(
//           responseType: ResponseType.bytes, // 🔥 only for file
//           validateStatus: (s) => s! < 500,
//         ),
//       );
//       return response;
//     } catch (e) {
//       print("PDF ERROR: $e");
//       return null;
//     }
//   }
//
//   Future<Response?> getpdfapprovalreturnRequest(
//       String endpoint, {
//         Map<String, dynamic>? queryParams,
//         ResponseType? responseType,
//       }) async {
//     try {
//       final response = await _dio.get(
//         endpoint,
//         queryParameters: queryParams,
//         options: Options(
//           responseType: responseType,
//           validateStatus: (s) => s! < 500,
//         ),
//       );
//
//       return response;
//     } catch (e) {
//       print("GET ERROR: $e");
//       return null;
//     }
//   }
//
//   Future<Response?> getRequestWithParams(
//       String endpoint, {
//         Map<String, dynamic>? params,
//       }) async {
//     try {
//       // 🔍 REQUEST PRINT
//       print("➡️ GET REQUEST");
//       print("URL → ${_dio.options.baseUrl}$endpoint");
//       print("PARAMS → ${jsonEncode(params)}");
//       print("HEADERS → ${jsonEncode(_dio.options.headers)}");
//
//       final response = await _dio.get(
//         endpoint,
//         queryParameters: params,
//         options: Options(
//           validateStatus: (s) => s! < 500,
//         ),
//       );
//
//       // ✅ RESPONSE PRINT
//       print("✅ STATUS → ${response.statusCode}");
//       print("📦 RESPONSE → ${response.data}");
//
//       return response;
//     } catch (e) {
//       print("❌ GET ERROR → $e");
//       return null;
//     }
//   }
//
//
//
//   Future<Response?> postRequest(
//       String endpoint,
//       dynamic data, {
//         Map<String, dynamic>? queryParams,
//         bool showLoading = true,
//       }) async {
//     try {
//       final response = await _dio.post(
//         endpoint,
//
//         /// POST BODY
//         data: data ?? {},
//
//         /// OPTIONAL QUERY PARAMETERS
//         queryParameters: queryParams,
//
//         options: Options(
//           extra: {
//             "showLoading": showLoading,
//           },
//           validateStatus: (s) => s != null && s < 500,
//         ),
//       );
//
//       return response;
//     } on DioException catch (e) {
//       print("POST DIO ERROR: ${e.message}");
//
//       /// 🔥 IMPORTANT: null na badle e.response return karo,
//       /// jethi 500 status code SyncService sudhi pohche ane
//       /// retry/delete logic sahi rite chale.
//       return e.response;
//     } catch (e) {
//       print("POST ERROR: $e");
//       return null;
//     }
//   }
//
//
//
//   Future<Response?> putRequest(String endpoint, dynamic data) async {
//     try {
//       final response = await _dio.put(
//         endpoint,
//         data: data ?? {},
//         options: Options(validateStatus: (s) => s! < 500),
//       );
//       return response;
//     } catch (e) {
//       print("PUT ERROR: $e");
//       return null;
//     }
//   }
//
//   Future<Response?> postFormData(String url, FormData formData) async {
//     try {
//       final response = await _dio.post(
//         url,
//         data: formData,
//         options: Options(validateStatus: (s) => s! < 500),
//       );
//
//       return response;
//     } on DioException catch (e) {
//       print("❌ DIO ERROR: ${e.message}");
//       print("❌ RESPONSE: ${e.response}");
//       print("❌ DATA: ${e.response?.data}");
//       return e.response; // 🔥 important (null નહીં)
//     } catch (e) {
//       print("❌ UNKNOWN ERROR: $e");
//       return null;
//     }
//   }
//
//
//   Future<Response?> deleteRequest(
//       String endpoint, {
//         Map<String, dynamic>? data,
//       }) async {
//     try {
//       final response = await _dio.delete(
//         endpoint,
//         data: data ?? {}, // optional body
//         options: Options(
//           validateStatus: (s) => s! < 500,
//         ),
//       );
//
//       return response;
//     } catch (e) {
//       print("DELETE ERROR: $e");
//       return null;
//     }
//   }
//
//   Future<Response?> postRequest1(String url, dynamic body) async {
//     try {
//       Response response = await _dio.post(
//         url,
//         data: body,
//         options: Options(
//           responseType: ResponseType.bytes,   // 🔥 IMPORTANT
//         ),
//       );
//
//       return response;
//
//     } catch (e) {
//       print("API ERROR: $e");
//       return null;
//     }
//   }
//
//
//   Future<Response?> getRequestWithId(
//       String endpoint,
//       int id, {
//         Map<String, dynamic>? queryParams,
//         ResponseType responseType = ResponseType.json,
//       }) async {
//     try {
//
//       final response = await _dio.get(
//         "$endpoint/$id",
//         queryParameters: queryParams,
//         options: Options(
//           responseType: responseType,
//           validateStatus: (s) => s! < 500,
//         ),
//       );
//
//       print("➡️ GET WITH ID");
//       print("URL → ${_dio.options.baseUrl}$endpoint/$id");
//       print("STATUS → ${response.statusCode}");
//
//       return response;
//
//     } catch (e) {
//
//       print("❌ GET WITH ID ERROR: $e");
//       return null;
//
//     }
//   }
//
//   Future<Response?> getRequestWithItemId(
//       String endpoint,
//       String? itemId, {
//         ResponseType responseType = ResponseType.json,
//       }) async {
//
//     try {
//
//       final response = await _dio.get(
//         endpoint,
//         queryParameters: itemId != null && itemId.isNotEmpty
//             ? {
//           "item_id": itemId,
//         }
//             : null,
//
//         options: Options(
//           responseType: responseType,
//           validateStatus: (s) => s! < 500,
//         ),
//       );
//
//
//       print("➡️ GET WITH ITEM ID");
//       print("URL → ${response.requestOptions.uri}");
//       print("STATUS → ${response.statusCode}");
//
//
//       return response;
//
//
//     } catch (e) {
//
//       print("❌ GET WITH ITEM ID ERROR: $e");
//       return null;
//
//     }
//
//   }
//
//   Future<Response?> putFormData(String url, FormData formData) async {
//     try {
//       Response response = await _dio.put(
//         url,
//         data: formData,
//         options: Options(
//           contentType: "multipart/form-data",
//         ),
//       );
//
//       return response;
//     } on DioException catch (e) {
//       if (e.response != null) {
//         print("Status Code: ${e.response?.statusCode}");
//         print("Response: ${e.response?.data}");
//         return e.response; // 👈 422 response પણ return થશે
//       }
//
//       print("API ERROR: $e");
//       return null;
//     } catch (e) {
//       print("API ERROR: $e");
//       return null;
//     }
//   }
//
//   Future<void> _checkUserStatus(Response? response) async {
//     try {
//       if (response == null) return;
//
//       dynamic raw = response.data;
//
//       // 401 + bytes response
//       if (raw is List<int> && response.statusCode == 401) {
//         raw = utf8.decode(raw);
//       }
//
//       // String -> JSON
//       if (raw is String) {
//         try {
//           raw = jsonDecode(raw);
//         } catch (_) {
//           return;
//         }
//       }
//
//       if (raw is! Map) return;
//
//       final data = Map<String, dynamic>.from(raw);
//
//       final code = data["code"]?.toString();
//
//       debugPrint("🔐 USER STATUS CODE => $code");
//
//       // ============================================================
//       // SESSION REPLACED
//       // ============================================================
//       if (response.statusCode == 401 &&
//           code == "SESSION_REPLACED") {
//
//         debugPrint("🚨 SESSION_REPLACED DETECTED");
//
//         // Old token clear
//         clearToken();
//
//         // 🔥 IMPORTANT:
//         // All stacked/pending loaders clear
//         LoadingService.instance.reset();
//
//         final message = data["message"]?.toString() ??
//             "Your account was logged in on another device. Please login again.";
//
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           AppDialog.showSessionReplacedDialog(message);
//         });
//
//         return;
//       }
//
//       // ============================================================
//       // USER INACTIVE
//       // ============================================================
//       if (code == "USER_INACTIVE") {
//         await AppDialog.showInactiveDialog(
//           data["message"]?.toString() ??
//               "Your account has been deactivated. Please contact your company admin.",
//         );
//       }
//     } catch (e, stack) {
//       debugPrint("❌ User Status Check Error: $e");
//       debugPrint("$stack");
//     }
//   }
//
//   Future<Response?> getRequestWithQuery(
//       String endpoint, {
//         Map<String, dynamic>? queryParameters,
//         bool showLoading = true,
//       }) async {
//     try {
//       final response = await _dio.get(
//         endpoint,
//
//         queryParameters: queryParameters,
//
//         /// ============================================
//         /// IMPORTANT - LOADING CONTROL
//         /// ============================================
//         options: Options(
//           extra: {
//             "showLoading": showLoading,
//           },
//
//           validateStatus: (status) {
//             return status != null && status < 500;
//           },
//         ),
//       );
//
//
//       return response;
//     } on DioException catch (e) {
//
//
//       return e.response;
//     } catch (e) {
//       debugPrint("❌ GET ERROR => $e");
//       return null;
//     }
//   }
//
//
// }
//
//
//
//
//
// class AppDialog {
//   static bool isShowing = false;
//
//   static Future<void> showInactiveDialog(
//       String message, {
//         bool logout = true,
//       }) async {
//     if (isShowing) return;
//
//     isShowing = true;
//
//     await showGeneralDialog(
//       context: NavigationService.navigatorKey.currentContext!,
//       barrierDismissible: false,
//       barrierLabel: "",
//       barrierColor: Colors.black54,
//       transitionDuration: const Duration(milliseconds: 250),
//       pageBuilder: (_, __, ___) {
//         return Center(
//           child: Material(
//             color: Colors.transparent,
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 24),
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(22),
//                 boxShadow: const [
//                   BoxShadow(
//                     color: Colors.black26,
//                     blurRadius: 25,
//                     offset: Offset(0, 10),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   /// Icon
//                   Container(
//                     height: 75,
//                     width: 75,
//                     decoration: BoxDecoration(
//                       color: AppColors.primaryDark.withOpacity(.1),
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(
//                       Icons.lock_person_rounded,
//                       color: AppColors.primaryDark,
//                       size: 40,
//                     ),
//                   ),
//
//                   const SizedBox(height: 18),
//
//                   const Text(
//                     "Account Inactive",
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
//
//                   const SizedBox(height: 10),
//
//                   Text(
//                     message,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 15,
//                       color: Colors.grey,
//                       height: 1.5,
//                     ),
//                   ),
//
//                   const SizedBox(height: 25),
//
//                   SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppColors.primaryDark,
//                         elevation: 0,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                       onPressed: () async {
//                         isShowing = false;
//
//                         Navigator.pop(
//                           NavigationService.navigatorKey.currentContext!,
//                         );
//
//                         if (logout) {
//                           SharedPreferences prefs =
//                           await SharedPreferences.getInstance();
//
//                           await prefs.clear();
//
//                           NavigationService.navigatorKey.currentState!
//                               .pushAndRemoveUntil(
//                             MaterialPageRoute(
//                               builder: (_) => const LoginScreen(),
//                             ),
//                                 (route) => false,
//                           );
//                         }
//                       },
//                       child: const Text(
//                         "OK",
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: Colors.white,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//       transitionBuilder: (_, animation, __, child) {
//         return ScaleTransition(
//           scale: CurvedAnimation(
//             parent: animation,
//             curve: Curves.easeOutBack,
//           ),
//           child: FadeTransition(
//             opacity: animation,
//             child: child,
//           ),
//         );
//       },
//     );
//
//     isShowing = false;
//   }
//
//   static bool isNoInternetShowing = false;
//
//   static Future<void> showNoInternetDialog() async {
//     if (isNoInternetShowing) return;
//
//     isNoInternetShowing = true;
//
//     showGeneralDialog(
//       context: NavigationService.navigatorKey.currentContext!,
//       barrierDismissible: false,
//       barrierLabel: "",
//       barrierColor: Colors.black45,
//       transitionDuration: const Duration(milliseconds: 250),
//       pageBuilder: (_, __, ___) {
//         return WillPopScope(
//           onWillPop: () async => false,
//           child: Center(
//             child: Material(
//               color: Colors.transparent,
//               child: Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 24),
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//
//                     const Icon(
//                       Icons.wifi_off_rounded,
//                       color: Colors.red,
//                       size: 70,
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     const Text(
//                       "No Internet Connection",
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     const SizedBox(height: 10),
//
//                     const Text(
//                       "Please check your Wi-Fi or Mobile Data connection.",
//                       textAlign: TextAlign.center,
//                     ),
//
//                     const SizedBox(height: 25),
//
//                     const CircularProgressIndicator(),
//
//                     const SizedBox(height: 15),
//
//                     const Text(
//                       "Waiting for connection...",
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   static void hideNoInternetDialog() {
//     if (!isNoInternetShowing) return;
//
//     isNoInternetShowing = false;
//
//     if (NavigationService.navigatorKey.currentContext != null) {
//       Navigator.of(
//         NavigationService.navigatorKey.currentContext!,
//         rootNavigator: true,
//       ).pop();
//     }
//   }
//
//   static bool isSessionDialogShowing = false;
//   static bool sessionHandled = false;
//
//   static Future<void> showSessionReplacedDialog(String message) async {
//     // Already showing / handled
//     if (isSessionDialogShowing || sessionHandled) {
//       debugPrint(
//         "⚠️ Session dialog skipped | "
//             "showing=$isSessionDialogShowing handled=$sessionHandled",
//       );
//       return;
//     }
//
//     final navigator = NavigationService.navigatorKey.currentState;
//
//     if (navigator == null || !navigator.mounted) {
//       debugPrint("❌ Navigator not ready for Session dialog");
//
//       // Navigator ready thay tyare retry
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         showSessionReplacedDialog(message);
//       });
//
//       return;
//     }
//
//     final context = navigator.overlay?.context;
//
//     if (context == null) {
//       debugPrint("❌ Overlay context is null");
//
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         showSessionReplacedDialog(message);
//       });
//
//       return;
//     }
//
//     // IMPORTANT
//     isSessionDialogShowing = true;
//     sessionHandled = true;
//
//     debugPrint("✅ Opening SESSION REPLACED dialog");
//
//     try {
//       await showGeneralDialog(
//         context: context,
//         useRootNavigator: true,
//         barrierDismissible: false,
//         barrierLabel: "Session Expired",
//         barrierColor: Colors.black54,
//         transitionDuration: const Duration(milliseconds: 250),
//
//         pageBuilder: (_, __, ___) {
//           return PopScope(
//             canPop: false,
//             child: Center(
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   margin: const EdgeInsets.symmetric(horizontal: 24),
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(22),
//                     boxShadow: const [
//                       BoxShadow(
//                         color: Colors.black26,
//                         blurRadius: 25,
//                         offset: Offset(0, 10),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // ICON
//                       Container(
//                         height: 75,
//                         width: 75,
//                         decoration: BoxDecoration(
//                           color: AppColors.primaryDark.withOpacity(.1),
//                           shape: BoxShape.circle,
//                         ),
//                         child: const Icon(
//                           Icons.devices_other_rounded,
//                           color: AppColors.primaryDark,
//                           size: 40,
//                         ),
//                       ),
//
//                       const SizedBox(height: 18),
//
//                       const Text(
//                         "Session Expired",
//                         style: TextStyle(
//                           fontSize: 22,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                         ),
//                       ),
//
//                       const SizedBox(height: 10),
//
//                       Text(
//                         message,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 15,
//                           color: Colors.grey,
//                           height: 1.5,
//                         ),
//                       ),
//
//                       const SizedBox(height: 25),
//
//                       SizedBox(
//                         width: double.infinity,
//                         height: 50,
//                         child: Material(
//                           color: Colors.transparent,
//                           child: InkWell(
//                             borderRadius: BorderRadius.circular(10),
//
//                             onTap: () async {
//                               debugPrint(
//                                 "🚪 SESSION REPLACED -> LOGIN",
//                               );
//
//                               // Clear API token
//                               ApiHelper().clearToken();
//
//                               // Clear local session
//                               final prefs =
//                               await SharedPreferences.getInstance();
//
//                               await prefs.clear();
//
//                               // Close dialog
//                               if (navigator.mounted) {
//                                 Navigator.of(
//                                   context,
//                                   rootNavigator: true,
//                                 ).pop();
//                               }
//
//                               // Reset flags
//                               isSessionDialogShowing = false;
//
//                               // Go Login
//                               if (navigator.mounted) {
//                                 navigator.pushAndRemoveUntil(
//                                   MaterialPageRoute(
//                                     builder: (_) => const LoginScreen(),
//                                   ),
//                                       (route) => false,
//                                 );
//                               }
//                             },
//
//                             child: Ink(
//                               decoration: BoxDecoration(
//                                 gradient: const LinearGradient(
//                                   colors: [
//                                     AppColors.primaryDark,
//                                     AppColors.gradientBlue,
//                                   ],
//                                   begin: Alignment.centerLeft,
//                                   end: Alignment.centerRight,
//                                 ),
//                                 borderRadius: BorderRadius.circular(10),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.primaryDark
//                                         .withOpacity(0.25),
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 3),
//                                   ),
//                                 ],
//                               ),
//                               child: const Center(
//                                 child: Text(
//                                   "OK",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//
//         transitionBuilder: (_, animation, __, child) {
//           return ScaleTransition(
//             scale: CurvedAnimation(
//               parent: animation,
//               curve: Curves.easeOutBack,
//             ),
//             child: FadeTransition(
//               opacity: animation,
//               child: child,
//             ),
//           );
//         },
//       );
//     } catch (e) {
//       debugPrint("❌ Session dialog error: $e");
//
//       isSessionDialogShowing = false;
//     }
//   }
// }


import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Extra/AppColors.dart';
import '../Extra/LoadingService.dart';
import '../Splash/LoginScreen.dart';
import '../main.dart' as NavigationService;
import 'ApiConstants.dart';

class ApiHelper {
  static final ApiHelper _instance = ApiHelper._internal();
  late Dio _dio;

  String? _bearerToken;

  /// =========================================================
  /// 🔥 Chhelli request kem fail thai (timeout / network ...)
  /// Screen ma check karo: ApiHelper().lastErrorType
  /// =========================================================
  DioExceptionType? lastErrorType;

  /// Default timeout (pass na karo to aa vaparay)
  static const Duration _defaultTimeout = Duration(seconds: 30);

  factory ApiHelper() => _instance;

  ApiHelper._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: _defaultTimeout,
        receiveTimeout: _defaultTimeout,
        sendTimeout: _defaultTimeout,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final bool showLoading = options.extra["showLoading"] ?? true;

          if (showLoading) {
            LoadingService.instance.show();
          }

          final noTokenEndpoints = ['/login', '/register'];

          // ✅ Add Bearer Token except login/register
          if (!noTokenEndpoints.contains(options.path)) {
            if (_bearerToken != null && _bearerToken!.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $_bearerToken';
            }
          }

          /// 🔥 Moṭa log fakt debug build ma
          if (kDebugMode) {
            print("📤 REQUEST [${options.method}] ${options.path}");
            print("Headers: ${options.headers}");
            print("Body: ${options.data}");
          }

          return handler.next(options);
        },

        onResponse: (response, handler) async {
          final bool showLoading =
              response.requestOptions.extra["showLoading"] ?? true;

          if (showLoading) {
            LoadingService.instance.hide();
          }

          if (kDebugMode) {
            print(
              "📥 RESPONSE [${response.statusCode}] "
                  "${response.requestOptions.path}",
            );
            print("Data: ${response.data}");
          }

          await _checkUserStatus(response);

          return handler.next(response);
        },

        onError: (DioException e, handler) {
          final bool showLoading =
              e.requestOptions.extra["showLoading"] ?? true;

          if (showLoading) {
            LoadingService.instance.hide();
          }

          _checkUserStatus(e.response);

          debugPrint(
            "❌ ERROR [${e.response?.statusCode}] ${e.requestOptions.path}",
          );
          debugPrint("TYPE => ${e.type} | MESSAGE => ${e.message}");

          return handler.next(e);
        },
      ),
    );
  }

  /// Status 500 thi niche no koi pan response "valid" gaṇay
  static bool _validStatus(int? s) => s != null && s < 500;

  // 🔐 Set token in memory
  void setBearerToken(String token) {
    _bearerToken = token;
    AppDialog.sessionHandled = false; // 👈 navu login thay tyare pacho reset
  }

  void clearToken() {
    _bearerToken = null;
  }

  // 🔄 Load token from SharedPreferences on app start
  Future<void> loadTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _bearerToken = prefs.getString('token');
    debugPrint("🔐 Token Loaded: ${_bearerToken != null ? "YES" : "NO"}");
  }

  // ============================================================
  // GET
  // ============================================================
  Future<Response?> getRequest(
      String endpoint, {
        Map<String, dynamic>? queryParams,
        bool showLoading = true,
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(
          extra: {"showLoading": showLoading},
          receiveTimeout: receiveTimeout ?? _defaultTimeout,
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ GET DIO ERROR => ${e.type} | ${e.requestOptions.uri}");
      return e.response;
    } catch (e) {
      debugPrint("❌ GET ERROR => $e");
      return null;
    }
  }

  Future<Response?> getPdfRequest(
      String endpoint, {
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 60),
          validateStatus: _validStatus,
        ),
      );
      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ PDF DIO ERROR => ${e.type}");
      return e.response;
    } catch (e) {
      debugPrint("❌ PDF ERROR => $e");
      return null;
    }
  }

  Future<Response?> getpdfapprovalreturnRequest(
      String endpoint, {
        Map<String, dynamic>? queryParams,
        ResponseType? responseType,
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(
          responseType: responseType,
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 60),
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ PDF DIO ERROR => ${e.type}");
      return e.response;
    } catch (e) {
      debugPrint("❌ GET ERROR => $e");
      return null;
    }
  }

  Future<Response?> getRequestWithParams(
      String endpoint, {
        Map<String, dynamic>? params,
      }) async {
    lastErrorType = null;

    try {
      if (kDebugMode) {
        print("➡️ GET REQUEST");
        print("URL → ${_dio.options.baseUrl}$endpoint");
        print("PARAMS → ${jsonEncode(params)}");
      }

      final response = await _dio.get(
        endpoint,
        queryParameters: params,
        options: Options(validateStatus: _validStatus),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ GET DIO ERROR → ${e.type}");
      return e.response;
    } catch (e) {
      debugPrint("❌ GET ERROR → $e");
      return null;
    }
  }

  // ============================================================
  // POST
  // ============================================================
  Future<Response?> postRequest(
      String endpoint,
      dynamic data, {
        Map<String, dynamic>? queryParams,
        bool showLoading = true,
        Duration? receiveTimeout,
        Duration? sendTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.post(
        endpoint,
        data: data ?? {},
        queryParameters: queryParams,
        options: Options(
          extra: {"showLoading": showLoading},
          receiveTimeout: receiveTimeout ?? _defaultTimeout,
          sendTimeout: sendTimeout ?? _defaultTimeout,
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ POST DIO ERROR => ${e.type} | ${e.message}");

      /// 🔥 null na badle e.response — 500 status SyncService sudhi pohche
      return e.response;
    } catch (e) {
      debugPrint("❌ POST ERROR => $e");
      return null;
    }
  }

  // ============================================================
  // PUT  🔥 (Sale update mate custom timeout)
  // ============================================================
  Future<Response?> putRequest(
      String endpoint,
      dynamic data, {
        bool showLoading = true,
        Duration? receiveTimeout,
        Duration? sendTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.put(
        endpoint,
        data: data ?? {},
        options: Options(
          extra: {"showLoading": showLoading},
          receiveTimeout: receiveTimeout ?? _defaultTimeout,
          sendTimeout: sendTimeout ?? _defaultTimeout,
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ PUT DIO ERROR => ${e.type} | ${e.message}");

      /// Server no response (jem ke 500) hoy to e pan screen sudhi pohche
      return e.response;
    } catch (e) {
      debugPrint("❌ PUT ERROR => $e");
      return null;
    }
  }

  Future<Response?> postFormData(
      String url,
      FormData formData, {
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ DIO ERROR: ${e.type} | ${e.message}");
      debugPrint("❌ DATA: ${e.response?.data}");
      return e.response; // 🔥 important (null nahi)
    } catch (e) {
      debugPrint("❌ UNKNOWN ERROR: $e");
      return null;
    }
  }

  // ============================================================
  // DELETE
  // ============================================================
  Future<Response?> deleteRequest(
      String endpoint, {
        Map<String, dynamic>? data,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.delete(
        endpoint,
        data: data ?? {},
        options: Options(validateStatus: _validStatus),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ DELETE DIO ERROR => ${e.type}");
      return e.response;
    } catch (e) {
      debugPrint("❌ DELETE ERROR => $e");
      return null;
    }
  }

  Future<Response?> postRequest1(
      String url,
      dynamic body, {
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.bytes, // 🔥 IMPORTANT
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 60),
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ API DIO ERROR => ${e.type}");
      return null;
    } catch (e) {
      debugPrint("❌ API ERROR => $e");
      return null;
    }
  }

  Future<Response?> getRequestWithId(
      String endpoint,
      int id, {
        Map<String, dynamic>? queryParams,
        ResponseType responseType = ResponseType.json,
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.get(
        "$endpoint/$id",
        queryParameters: queryParams,
        options: Options(
          responseType: responseType,
          receiveTimeout: receiveTimeout ?? _defaultTimeout,
          validateStatus: _validStatus,
        ),
      );

      debugPrint("➡️ GET WITH ID → $endpoint/$id | ${response.statusCode}");

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ GET WITH ID DIO ERROR => ${e.type}");
      return e.response;
    } catch (e) {
      debugPrint("❌ GET WITH ID ERROR: $e");
      return null;
    }
  }

  Future<Response?> getRequestWithItemId(
      String endpoint,
      String? itemId, {
        ResponseType responseType = ResponseType.json,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: itemId != null && itemId.isNotEmpty
            ? {"item_id": itemId}
            : null,
        options: Options(
          responseType: responseType,
          validateStatus: _validStatus,
        ),
      );

      debugPrint(
        "➡️ GET WITH ITEM ID → ${response.requestOptions.uri} | "
            "${response.statusCode}",
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ GET WITH ITEM ID DIO ERROR => ${e.type}");
      return e.response;
    } catch (e) {
      debugPrint("❌ GET WITH ITEM ID ERROR: $e");
      return null;
    }
  }

  Future<Response?> putFormData(String url, FormData formData) async {
    lastErrorType = null;

    try {
      final response = await _dio.put(
        url,
        data: formData,
        options: Options(
          contentType: "multipart/form-data",
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;

      if (e.response != null) {
        debugPrint("Status Code: ${e.response?.statusCode}");
        debugPrint("Response: ${e.response?.data}");
        return e.response; // 👈 422 response pan return thase
      }

      debugPrint("❌ API ERROR: ${e.type}");
      return null;
    } catch (e) {
      debugPrint("❌ API ERROR: $e");
      return null;
    }
  }

  /// Ek sathe ghani API fail thay to dialog ek j vaar khule
  static bool _statusDialogOpen = false;

  Future<void> _checkUserStatus(Response? response) async {
    try {
      if (response == null) return;

      dynamic raw = response.data;

      // 401 / 403 + bytes response (PDF jevi API ma)
      if (raw is List<int> &&
          (response.statusCode == 401 || response.statusCode == 403)) {
        raw = utf8.decode(raw);
      }

      // String -> JSON
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {
          return;
        }
      }

      if (raw is! Map) return;

      final data = Map<String, dynamic>.from(raw);
      final code = data["code"]?.toString();

      // ============================================================
      // SESSION REPLACED
      // ============================================================
      if (response.statusCode == 401 && code == "SESSION_REPLACED") {
        debugPrint("🚨 SESSION_REPLACED DETECTED");

        clearToken();
        LoadingService.instance.reset();

        final message = data["message"]?.toString() ??
            "Your account was logged in on another device. Please login again.";

        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppDialog.showSessionReplacedDialog(message);
        });
        return;
      }

      // ============================================================
      // 🏢 COMPANY INACTIVE
      // ============================================================
      if (code == "COMPANY_INACTIVE") {
        debugPrint("🚨 COMPANY_INACTIVE DETECTED");

        if (_statusDialogOpen) return;
        _statusDialogOpen = true;

        clearToken();
        LoadingService.instance.reset();

        final message = data["message"]?.toString() ??
            "Your company has been deactivated. Please contact the administrator.";

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await AppDialog.showInactiveDialog(message);
          } finally {
            _statusDialogOpen = false;
          }
        });
        return;
      }

      // ============================================================
      // USER INACTIVE
      // ============================================================
      if (code == "USER_INACTIVE") {
        if (_statusDialogOpen) return;
        _statusDialogOpen = true;

        LoadingService.instance.reset();

        try {
          await AppDialog.showInactiveDialog(
            data["message"]?.toString() ??
                "Your account has been deactivated. Please contact your company admin.",
          );
        } finally {
          _statusDialogOpen = false;
        }
      }
    } catch (e, stack) {
      debugPrint("❌ User Status Check Error: $e");
      debugPrint("$stack");
    }
  }

  Future<Response?> getRequestWithQuery(
      String endpoint, {
        Map<String, dynamic>? queryParameters,
        bool showLoading = true,
        Duration? receiveTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          extra: {"showLoading": showLoading},
          receiveTimeout: receiveTimeout ?? _defaultTimeout,
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      return e.response;
    } catch (e) {
      debugPrint("❌ GET ERROR => $e");
      return null;
    }
  }

  // ============================================================
  // PATCH
  // ============================================================
  Future<Response?> patchRequest(
      String endpoint,
      dynamic data, {
        Map<String, dynamic>? queryParams,
        bool showLoading = true,
        Duration? receiveTimeout,
        Duration? sendTimeout,
      }) async {
    lastErrorType = null;

    try {
      final response = await _dio.patch(
        endpoint,
        data: data ?? {},
        queryParameters: queryParams,
        options: Options(
          extra: {"showLoading": showLoading},
          receiveTimeout: receiveTimeout ?? _defaultTimeout,
          sendTimeout: sendTimeout ?? _defaultTimeout,
          validateStatus: _validStatus,
        ),
      );

      return response;
    } on DioException catch (e) {
      lastErrorType = e.type;
      debugPrint("❌ PATCH DIO ERROR => ${e.type} | ${e.message}");
      return e.response;
    } catch (e) {
      debugPrint("❌ PATCH ERROR => $e");
      return null;
    }
  }
}

class AppDialog {
  static bool isShowing = false;

  static Future<void> showInactiveDialog(
      String message, {
        bool logout = true,
      }) async {
    if (isShowing) return;

    isShowing = true;

    await showGeneralDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: false,
      barrierLabel: "",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 25,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 75,
                    width: 75,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: AppColors.primaryDark,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Account Inactive",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        isShowing = false;

                        Navigator.pop(
                          NavigationService.navigatorKey.currentContext!,
                        );

                        if (logout) {
                          SharedPreferences prefs =
                          await SharedPreferences.getInstance();

                          await prefs.clear();

                          NavigationService.navigatorKey.currentState!
                              .pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                                (route) => false,
                          );
                        }
                      },
                      child: const Text(
                        "OK",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );

    isShowing = false;
  }

  static bool isNoInternetShowing = false;

  static Future<void> showNoInternetDialog() async {
    if (isNoInternetShowing) return;

    isNoInternetShowing = true;

    showGeneralDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: false,
      barrierLabel: "",
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.red,
                      size: 70,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "No Internet Connection",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Please check your Wi-Fi or Mobile Data connection.",
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 25),
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text(
                      "Waiting for connection...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void hideNoInternetDialog() {
    if (!isNoInternetShowing) return;

    isNoInternetShowing = false;

    if (NavigationService.navigatorKey.currentContext != null) {
      Navigator.of(
        NavigationService.navigatorKey.currentContext!,
        rootNavigator: true,
      ).pop();
    }
  }

  static bool isSessionDialogShowing = false;
  static bool sessionHandled = false;

  static Future<void> showSessionReplacedDialog(String message) async {
    if (isSessionDialogShowing || sessionHandled) {
      debugPrint(
        "⚠️ Session dialog skipped | "
            "showing=$isSessionDialogShowing handled=$sessionHandled",
      );
      return;
    }

    final navigator = NavigationService.navigatorKey.currentState;

    if (navigator == null || !navigator.mounted) {
      debugPrint("❌ Navigator not ready for Session dialog");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSessionReplacedDialog(message);
      });

      return;
    }

    final context = navigator.overlay?.context;

    if (context == null) {
      debugPrint("❌ Overlay context is null");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSessionReplacedDialog(message);
      });

      return;
    }

    isSessionDialogShowing = true;
    sessionHandled = true;

    debugPrint("✅ Opening SESSION REPLACED dialog");

    try {
      await showGeneralDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierLabel: "Session Expired",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) {
          return PopScope(
            canPop: false,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 75,
                        width: 75,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.devices_other_rounded,
                          color: AppColors.primaryDark,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Session Expired",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              debugPrint("🚪 SESSION REPLACED -> LOGIN");

                              ApiHelper().clearToken();

                              final prefs =
                              await SharedPreferences.getInstance();

                              await prefs.clear();

                              if (navigator.mounted) {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();
                              }

                              isSessionDialogShowing = false;

                              if (navigator.mounted) {
                                navigator.pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                      (route) => false,
                                );
                              }
                            },
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.gradientBlue,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                    AppColors.primaryDark.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "OK",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, animation, __, child) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("❌ Session dialog error: $e");

      isSessionDialogShowing = false;
    }
  }
}